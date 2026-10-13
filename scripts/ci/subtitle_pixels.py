"""Inspect native subtitle PNGs against a same-frame video-only control.

FFmpeg is already required by the fixture suite, so this adds no Python image
package to VPFL's runtime or CI environment.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path


def _run(args: list[str], data: bytes | None = None) -> bytes:
    try:
        process = subprocess.run(args, input=data, capture_output=True,
                                 check=False, timeout=20)
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(f'{args[0]} timed out for {args[-1]}') from error
    if process.returncode:
        raise RuntimeError(f'{args[0]} failed for {args[-1]}: '
                           f'{process.stderr.decode(errors="replace")[-1200:]}')
    return process.stdout


def decode_png(path: Path) -> tuple[int, int, bytes]:
    probe = json.loads(_run(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
                             '-show_entries', 'stream=width,height', '-of', 'json',
                             str(path)]))
    if len(probe.get('streams', [])) != 1:
        raise RuntimeError(f'{path}: expected one PNG image stream')
    width = probe['streams'][0]['width']
    height = probe['streams'][0]['height']
    pixels = _run(['ffmpeg', '-v', 'error', '-i', str(path), '-frames:v', '1',
                   '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'])
    if len(pixels) != width * height * 3:
        raise RuntimeError(f'{path}: RGB data has {len(pixels)} bytes, '
                           f'expected {width * height * 3}')
    return width, height, pixels


def compare_pngs(subtitles: Path, video: Path, difference: Path | None = None) -> dict:
    width, height, shown = decode_png(subtitles)
    video_width, video_height, plain = decode_png(video)
    if (width, height) != (video_width, video_height):
        raise RuntimeError(f'{subtitles} and {video}: image sizes differ')

    changed = 0
    low = [width, height]
    high = [-1, -1]
    regions = {'top': 0, 'middle': 0, 'bottom': 0, 'left': 0, 'right': 0}
    dominant = {'red': 0, 'green': 0, 'blue': 0}
    darker = 0
    diff = bytearray(len(shown)) if difference is not None else None
    for offset in range(0, len(shown), 3):
        rgb = shown[offset:offset + 3]
        base = plain[offset:offset + 3]
        channel_diff = [abs(rgb[i] - base[i]) for i in range(3)]
        if max(channel_diff) < 24:
            continue
        pixel = offset // 3
        x, y = pixel % width, pixel // width
        changed += 1
        low[0], low[1] = min(low[0], x), min(low[1], y)
        high[0], high[1] = max(high[0], x), max(high[1], y)
        regions['top' if y < height / 3 else
                'middle' if y < 2 * height / 3 else 'bottom'] += 1
        regions['left' if x < width / 2 else 'right'] += 1
        if max(rgb) + 20 < max(base):
            darker += 1
        for index, color in enumerate(('red', 'green', 'blue')):
            if rgb[index] > max(rgb[(index + 1) % 3], rgb[(index + 2) % 3]) + 35:
                dominant[color] += 1
        if diff is not None:
            diff[offset:offset + 3] = bytes(min(255, value * 3) for value in channel_diff)

    if diff is not None:
        difference.parent.mkdir(parents=True, exist_ok=True)
        _run(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24',
              '-s', f'{width}x{height}', '-i', '-', '-frames:v', '1',
              str(difference)], bytes(diff))
    return {
        'width': width,
        'height': height,
        'changed_pixels': changed,
        'bbox': [*low, *high] if changed else None,
        'regions': regions,
        'dominant_colors': dominant,
        'darker_pixels': darker,
    }


def assert_visible(metrics: dict, label: str, *, region: str | None = None) -> None:
    if metrics['changed_pixels'] < 120:
        raise AssertionError(f'{label}: caption missing; {metrics}')
    if region is not None and metrics['regions'][region] < 80:
        raise AssertionError(f'{label}: caption absent from {region}; {metrics}')


def assert_absent(metrics: dict, label: str) -> None:
    if metrics['changed_pixels'] > 20:
        raise AssertionError(f'{label}: subtitle pixels persist outside cue; {metrics}')
