#!/usr/bin/env python3
"""Compare X11 captures of VPFL's final window at one paused video frame.

Coordinates describe the visible video texture within root-window captures.
FFmpeg decodes PNGs so the check needs no additional Python image package.
"""

import argparse
import json
from pathlib import Path

from subtitle_pixels import compare_pngs, decode_png


def inspect(enabled: Path, disabled: Path, rect: tuple[int, int, int, int]):
    width, height, shown = decode_png(enabled)
    other_width, other_height, plain = decode_png(disabled)
    if (width, height) != (other_width, other_height):
        raise ValueError('X11 captures have different dimensions')
    x0, y0, crop_width, crop_height = rect
    if (crop_width < 100 or crop_height < 100 or x0 < 0 or y0 < 0 or
            x0 + crop_width > width or y0 + crop_height > height):
        raise ValueError(f'invalid video crop {rect} for {width}x{height}')
    changed = 0
    outer_changed = 0
    top = middle = bottom = 0
    red = green = blue = 0
    darker = 0
    low = [crop_width, crop_height]
    high = [-1, -1]
    dark_video = 0
    bright_video = 0
    control_red = 0
    control_red_line = 0
    control_bright_line = 0
    burned_white = 0
    total = crop_width * crop_height
    for y in range(y0, y0 + crop_height):
        red_in_row = 0
        for x in range(x0, x0 + crop_width):
            offset = (y * width + x) * 3
            current = shown[offset:offset + 3]
            control = plain[offset:offset + 3]
            if (y > y0 + crop_height * 4 // 5 and
                    control[0] > 150 and control[0] > control[1] + 60 and
                    control[0] > control[2] + 40):
                control_red += 1
                red_in_row += 1
            if max(current) > 18:
                dark_video += 1
            if max(current) > 130:
                bright_video += 1
            if (x0 + crop_width // 5 < x < x0 + crop_width * 4 // 5 and
                    y0 + crop_height // 3 < y < y0 + crop_height * 2 // 3 and
                    min(current) > 165 and max(current) - min(current) < 45):
                burned_white += 1
            if max(abs(a - b) for a, b in zip(current, control)) < 24:
                continue
            changed += 1
            low[0], low[1] = min(low[0], x - x0), min(low[1], y - y0)
            high[0], high[1] = max(high[0], x - x0), max(high[1], y - y0)
            if max(current) + 20 < max(control):
                darker += 1
            if y < y0 + crop_height // 3:
                top += 1
            elif y < y0 + crop_height * 2 // 3:
                middle += 1
            else:
                bottom += 1
            if current[0] > current[1] + 35 and current[0] > current[2] + 35:
                red += 1
            if current[1] > current[0] + 35 and current[1] > current[2] + 35:
                green += 1
            if current[2] > current[0] + 35 and current[2] > current[1] + 35:
                blue += 1
        control_red_line = max(control_red_line, red_in_row)
    # The control bar can extend below the texture crop. Inspect both captures
    # across that part of the window so even matching control overlays fail.
    for y in range(y0 + crop_height * 2 // 3,
                   min(height, y0 + crop_height + 120)):
        row_lengths = [0, 0]
        bright_lengths = [0, 0]
        for x in range(x0, x0 + crop_width):
            offset = (y * width + x) * 3
            for index, pixels in enumerate((shown, plain)):
                r, g, b = pixels[offset:offset + 3]
                if r > 150 and r > g + 60 and r > b + 40:
                    row_lengths[index] += 1
                if max(r, g, b) > 110:
                    bright_lengths[index] += 1
        control_red_line = max(control_red_line, *row_lengths)
        control_bright_line = max(control_bright_line, *bright_lengths)
    # Changes outside the texture indicate an overlay, notification or moving UI.
    for y in range(height):
        for x in range(width):
            if y0 <= y < y0 + crop_height and x0 <= x < x0 + crop_width:
                continue
            offset = (y * width + x) * 3
            if max(abs(shown[offset + i] - plain[offset + i]) for i in range(3)) >= 24:
                outer_changed += 1
    return {'changed_pixels': changed, 'outside_video_pixels': outer_changed,
            'bbox': [*low, *high] if changed else None,
            'regions': {'top': top, 'middle': middle, 'bottom': bottom},
            'dominant_colors': {'red': red, 'green': green, 'blue': blue},
            'darker_pixels': darker,
            'lit_video_fraction': round(dark_video / total, 3),
            'bright_video_pixels': bright_video,
            'control_red_pixels': control_red,
            'control_red_line_pixels': control_red_line,
            'control_bright_line_pixels': control_bright_line,
            'burned_white_pixels': burned_white}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('enabled', type=Path)
    parser.add_argument('disabled', type=Path)
    parser.add_argument('--rect', type=int, nargs=4, required=True,
                        metavar=('X', 'Y', 'WIDTH', 'HEIGHT'))
    parser.add_argument('--expect', choices=('visible', 'absent', 'burned', 'plain'), required=True)
    parser.add_argument('--region', choices=('top', 'middle', 'bottom'))
    parser.add_argument('--metrics', type=Path)
    parser.add_argument('--difference', type=Path)
    args = parser.parse_args()
    metrics = inspect(args.enabled, args.disabled, tuple(args.rect))
    print(json.dumps(metrics, sort_keys=True))
    if args.metrics:
        args.metrics.parent.mkdir(parents=True, exist_ok=True)
        args.metrics.write_text(json.dumps(metrics, indent=2) + '\n')
    try:
        if metrics['lit_video_fraction'] < 0.9:
            raise AssertionError('video texture is black or missing')
        if metrics['outside_video_pixels'] > 100:
            raise AssertionError('window UI changed between same-frame captures')
        if metrics['control_red_line_pixels'] > max(80, min(180, args.rect[2] // 6)):
            raise AssertionError('playback controls cover the subtitle capture')
        if metrics['control_bright_line_pixels'] > args.rect[2] * 3 // 5:
            raise AssertionError('playback controls cover the subtitle capture')
        if args.expect == 'visible' and metrics['changed_pixels'] < 120:
            raise AssertionError('subtitle is not visible in VPFL window')
        if args.expect == 'absent' and metrics['changed_pixels'] > 20:
            raise AssertionError('unexpected pixels changed in subtitle gap')
        if args.expect == 'plain':
            if metrics['changed_pixels'] > 20 or metrics['bright_video_pixels'] > 20:
                raise AssertionError('unsubtitled video has visible caption pixels')
        if args.expect == 'burned':
            if metrics['changed_pixels'] > 20:
                raise AssertionError('burned caption changed when CC was disabled')
            if metrics['burned_white_pixels'] < 120:
                raise AssertionError('burned caption is absent from VPFL window')
        if (args.expect == 'visible' and args.region and
                metrics['regions'][args.region] < 80):
            raise AssertionError(f'subtitle is not visible in {args.region} region')
    except AssertionError:
        if args.difference:
            compare_pngs(args.enabled, args.disabled, args.difference)
        raise


if __name__ == '__main__':
    main()
