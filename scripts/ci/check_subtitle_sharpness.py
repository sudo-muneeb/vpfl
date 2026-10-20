#!/usr/bin/env python3
"""Compare ASS caption shape and edges in mpv and VPFL's final X11 window."""

import argparse
import json
import shutil
import tempfile
import time
from pathlib import Path

from mpv_subtitle_check import MpvIPC
from subtitle_pixels import decode_png


def capture_reference(fixture: Path, width: int, height: int,
                      output: Path, seconds: float,
                      subtitle_file: Path | None = None, *,
                      full_chroma: bool = True) -> tuple[Path, Path]:
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    process_dir = Path(tempfile.mkdtemp(prefix='mpv-', dir=output))
    shown = output / 'native-mpv-on.png'
    hidden = output / 'native-mpv-off.png'
    mpv = None
    try:
        mpv = MpvIPC(process_dir, output / 'mpv.log')
        # Scaling before libass rasterizes the caption gives a reference at
        # the actual display size.
        # Actual RGB window readback is available separately below.
        # Composite colored glyphs without YUV420 chroma subsampling, matching
        # the RGB window output. This also supports odd viewport dimensions.
        # Source-sized media_kit screenshots use the original video format.
        scaling = (f'lavfi=[scale={width}:{height},format=yuv444p]'
                   if full_chroma else f'scale={width}:{height}')
        mpv.command('vf', 'add', scaling)
        mpv.load(fixture)
        if subtitle_file is not None:
            mpv.command('sub-add', str(subtitle_file.resolve()), 'select')
        mpv.seek(seconds)
        mpv.screenshot(shown, 'subtitles')
        mpv.screenshot(hidden, 'video')
    finally:
        if mpv is not None:
            mpv.close()
        shutil.rmtree(process_dir)
    return shown, hidden


def capture_window_reference(fixture: Path, width: int, height: int,
                             output: Path, seconds: float,
                             subtitle_file: Path | None = None, *,
                             video_output: str = 'gpu') -> tuple[Path, Path]:
    """Use mpv's actual RGB video output, preserving its viewport geometry."""
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='mpv-window-', dir=output) as folder:
        gpu_options = ('--gpu-context=x11egl', '--opengl-glfinish=yes') if video_output == 'gpu' else ()
        mpv = MpvIPC(Path(folder), output / 'mpv.log', (
            f'--vo={video_output}', *gpu_options, '--force-window=yes',
            # Synchronize GPU readback. CI selects the explicit x11 reference
            # because this host's llvmpipe GPU VO intermittently draws black.
            '--no-border', '--keepaspect-window=no',
            f'--geometry={width}x{height}+0+0',
        ))
        try:
            if video_output == 'x11':
                # Preserve color edges when the software VO composites ASS.
                mpv.command('vf', 'add', 'lavfi=[format=yuv444p]')
            mpv.load(fixture)
            if subtitle_file is not None:
                mpv.command('sub-add', str(subtitle_file.resolve()), 'select')
            mpv.seek(seconds)
            deadline = time.monotonic() + 3
            while True:
                dimensions = mpv.command('get_property', 'osd-dimensions', optional=True)
                if dimensions and (dimensions['w'], dimensions['h']) == (width, height):
                    break
                if time.monotonic() >= deadline:
                    raise AssertionError(f'mpv window dimensions differ: {dimensions}, '
                                         f'expected {width}x{height}')
                time.sleep(0.02)
            shown, hidden = output / 'native-mpv-on.png', output / 'native-mpv-off.png'
            mpv.screenshot(shown, 'window')
            mpv.command('set_property', 'sid', 'no')
            mpv.seek(seconds)
            mpv.screenshot(hidden, 'window')
            properties = {name: mpv.command('get_property', name, optional=True)
                          for name in ('sub-ass-override', 'sub-scale',
                                       'sub-scale-with-window', 'sub-ass-scale-with-window',
                                       'video-aspect-override', 'osd-dimensions', 'current-vo')}
            (output / 'properties.json').write_text(json.dumps(properties, indent=2) + '\n')
            return shown, hidden
        finally:
            mpv.close()


def caption_edges(shown: bytes, hidden: bytes, width: int,
                  height: int, expected_region: str = 'bottom') -> dict:
    if len(shown) != width * height * 3 or len(hidden) != len(shown):
        raise ValueError('RGB frame size differs from the declared dimensions')
    difference = bytearray(width * height)
    left, top, right, bottom = width, height, -1, -1
    changed = 0
    for index in range(width * height):
        offset = index * 3
        value = max(abs(shown[offset + channel] - hidden[offset + channel])
                    for channel in range(3))
        difference[index] = value
        if value >= 24:
            x, y = index % width, index // width
            left, top = min(left, x), min(top, y)
            right, bottom = max(right, x), max(bottom, y)
            changed += 1
    if changed < 120:
        raise AssertionError(f'caption has only {changed} changed pixels')
    center_y = (top + bottom) / 2
    actual_region = ('top' if center_y < height / 3 else
                     'middle' if center_y < height * 2 / 3 else 'bottom')
    if actual_region != expected_region:
        raise AssertionError(
            f'caption is in {actual_region}, expected {expected_region}: '
            f'{[left, top, right, bottom]}')

    x0, x1 = max(1, left - 8), min(width - 2, right + 8)
    y0, y1 = max(1, top - 8), min(height - 2, bottom + 8)
    count = total = squared = 0
    for y in range(y0, y1 + 1):
        row = y * width
        for x in range(x0, x1 + 1):
            index = row + x
            laplacian = (difference[index - 1] + difference[index + 1] +
                         difference[index - width] + difference[index + width] -
                         4 * difference[index])
            total += laplacian
            squared += laplacian * laplacian
            count += 1
    mean = total / count
    return {'bbox': [left, top, right, bottom], 'changed_pixels': changed,
            'edge_variance': round(squared / count - mean * mean, 3)}


def compare(native: dict, window: dict, minimum_ratio: float = 0.85) -> dict:
    a, b = native['bbox'], window['bbox']
    if any(abs(a[index] - b[index]) > 6 for index in range(4)):
        raise AssertionError(f'native and window captions are misaligned: {a} vs {b}')
    ratio = window['edge_variance'] / native['edge_variance']
    result = {'native': native, 'window': window,
              'edge_variance_ratio': round(ratio, 3)}
    if ratio < minimum_ratio:
        raise AssertionError(f'VPFL subtitle edges are softened: {json.dumps(result)}')
    return result


def _caption_masks(native_on: bytes, native_off: bytes,
                   window_on: bytes, window_off: bytes) -> tuple[set, set]:
    lengths = {len(native_on), len(native_off), len(window_on), len(window_off)}
    if len(lengths) != 1 or len(native_on) % 3:
        raise ValueError('caption frames need equal, complete RGB pixels')
    native_mask, window_mask = set(), set()
    for offset in range(0, len(native_on), 3):
        native = max(abs(native_on[offset + channel] -
                         native_off[offset + channel])
                     for channel in range(3)) >= 24
        window = max(abs(window_on[offset + channel] -
                         window_off[offset + channel])
                     for channel in range(3)) >= 24
        if native:
            native_mask.add(offset // 3)
        if window:
            window_mask.add(offset // 3)
    if not native_mask and not window_mask:
        raise AssertionError('neither frame contains caption pixels')
    return native_mask, window_mask


def caption_shape_overlap(native_on: bytes, native_off: bytes,
                          window_on: bytes, window_off: bytes) -> float:
    a, b = _caption_masks(native_on, native_off, window_on, window_off)
    return len(a & b) / len(a | b)


def caption_alignment(native_on: bytes, native_off: bytes,
                      window_on: bytes, window_off: bytes,
                      width: int, height: int, radius: int) -> dict:
    if len(native_on) != width * height * 3:
        raise ValueError('caption alignment dimensions differ from RGB data')
    native, window = _caption_masks(native_on, native_off, window_on, window_off)
    raw = best = len(native & window) / len(native | window)
    translation = [0, 0]
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            shifted = {(index // width + dy) * width + index % width + dx
                       for index in window
                       if 0 <= index % width + dx < width and
                       0 <= index // width + dy < height}
            overlap = len(native & shifted) / len(native | shifted)
            if overlap > best:
                best, translation = overlap, [dx, dy]
    return {'raw_overlap': raw, 'registered_overlap': best,
            'translation_pixels': translation}


def require_shape_overlap(overlap: float, minimum: float) -> None:
    if overlap < minimum:
        raise AssertionError(
            f'VPFL subtitle glyph shape differs from native mpv: '
            f'{overlap} < {minimum}')


def crop_rgb(data: bytes, width: int, rect: tuple[int, int, int, int]) -> bytes:
    x, y, crop_width, crop_height = rect
    return b''.join(data[((row * width + x) * 3):
                         ((row * width + x + crop_width) * 3)]
                    for row in range(y, y + crop_height))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture', type=Path, required=True)
    parser.add_argument('--window-on', type=Path, required=True)
    parser.add_argument('--window-off', type=Path, required=True)
    parser.add_argument('--media-kit-native', type=Path)
    parser.add_argument('--subtitle-file', type=Path)
    parser.add_argument('--reference-mode', choices=('headless', 'window'), default='headless')
    parser.add_argument('--reference-vo', choices=('gpu', 'x11'), default='gpu')
    parser.add_argument('--rect', type=int, nargs=4, required=True,
                        metavar=('X', 'Y', 'WIDTH', 'HEIGHT'))
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--seconds', type=float, default=1.5)
    parser.add_argument('--expected-region', choices=('top', 'middle', 'bottom'),
                        default='bottom')
    parser.add_argument('--minimum-ratio', type=float, default=0.85)
    parser.add_argument('--minimum-shape-overlap', type=float, default=0.85)
    parser.add_argument('--registration-radius', type=int, choices=(0, 1), default=0)
    args = parser.parse_args()
    if not 0 <= args.minimum_ratio <= 1:
        parser.error('--minimum-ratio must be between 0 and 1')
    if not 0 <= args.minimum_shape_overlap <= 1:
        parser.error('--minimum-shape-overlap must be between 0 and 1')
    rect = tuple(args.rect)
    width, height, pixels = decode_png(args.window_on)
    other_width, other_height, other_pixels = decode_png(args.window_off)
    x, y, crop_width, crop_height = rect
    if ((other_width, other_height) != (width, height) or x < 0 or y < 0 or
            crop_width < 100 or crop_height < 100 or
            x + crop_width > width or y + crop_height > height):
        raise ValueError(f'invalid window crop {rect} for {width}x{height}')
    if args.reference_mode == 'window':
        native_on, native_off = capture_window_reference(
            args.fixture, crop_width, crop_height, args.out, args.seconds,
            args.subtitle_file, video_output=args.reference_vo)
    else:
        native_on, native_off = capture_reference(
            args.fixture, crop_width, crop_height, args.out, args.seconds,
            args.subtitle_file)
    native_width, native_height, native_pixels = decode_png(native_on)
    off_width, off_height, native_without = decode_png(native_off)
    if (native_width, native_height) != (crop_width, crop_height) or (
            off_width, off_height) != (crop_width, crop_height):
        raise AssertionError('native mpv screenshot is not at display size')
    native = caption_edges(native_pixels, native_without,
                           crop_width, crop_height, args.expected_region)
    window_pixels = crop_rgb(pixels, width, rect)
    window_without = crop_rgb(other_pixels, width, rect)
    window = caption_edges(window_pixels, window_without,
                           crop_width, crop_height, args.expected_region)
    alignment = caption_alignment(native_pixels, native_without,
                                  window_pixels, window_without,
                                  crop_width, crop_height, args.registration_radius)
    overlap = alignment['registered_overlap']
    result = {'native': native, 'window': window,
              'edge_variance_ratio': round(
                  window['edge_variance'] / native['edge_variance'], 3),
              'caption_shape_overlap': round(alignment['raw_overlap'], 4),
              'registered_shape_overlap': round(overlap, 4),
              'translation_pixels': alignment['translation_pixels']}
    if args.media_kit_native is not None:
        media_width, media_height, media_pixels = decode_png(args.media_kit_native)
        source_on, _ = capture_reference(
            args.fixture, media_width, media_height, args.out / 'source',
            args.seconds, args.subtitle_file, full_chroma=False)
        source_width, source_height, source_pixels = decode_png(source_on)
        result['media_kit_native_matches_mpv'] = (
            (media_width, media_height) == (source_width, source_height)
            and media_pixels == source_pixels)
        if not result['media_kit_native_matches_mpv']:
            raise AssertionError(
                'media_kit native screenshot differs from source-size mpv')
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / 'metrics.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, sort_keys=True))
    compare(native, window, args.minimum_ratio)
    require_shape_overlap(overlap, args.minimum_shape_overlap)


if __name__ == '__main__':
    main()
