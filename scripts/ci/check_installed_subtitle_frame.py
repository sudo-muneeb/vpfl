#!/usr/bin/env python3
"""Detect fixture caption pixels in an installed VPFL X11 screen capture."""

import argparse
import json
from pathlib import Path


def analyze(data: bytes, width: int, height: int, kind: str) -> dict:
    if len(data) != width * height * 3:
        raise ValueError(f'RGB capture has {len(data)} bytes, expected {width * height * 3}')

    def pixel(x: int, y: int) -> tuple[int, int, int]:
        offset = (y * width + x) * 3
        return data[offset], data[offset + 1], data[offset + 2]

    def background(rgb: tuple[int, int, int]) -> bool:
        r, g, b = rgb
        return 15 <= r <= 65 and 25 <= g <= 85 and 60 <= b <= 125

    blue_rows = []
    for y in range(height):
        blue = sum(background(pixel(x, y)) for x in range(0, width, 4))
        if blue > width // 12:
            blue_rows.append(y)
    if len(blue_rows) < 200:
        raise AssertionError('VPFL blue video surface is absent or too small')
    top, bottom = min(blue_rows), max(blue_rows)
    middle_y = (top + bottom) // 2
    blue_columns = [x for x in range(width) if background(pixel(x, middle_y))]
    if len(blue_columns) < 400:
        raise AssertionError('VPFL video texture has no wide blue region')
    left, right = min(blue_columns), max(blue_columns)
    x0 = left + (right - left) // 5
    x1 = right - (right - left) // 5
    y0 = top + (bottom - top) // 20
    y1 = bottom - (bottom - top) // 20
    captions = {'red_top': 0, 'blue_middle': 0, 'green_bottom': 0,
                'white_bottom': 0}
    controls = 0
    caption_edge_pixels = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = pixel(x, y)
            if kind == 'ass':
                if y < top + (bottom - top) // 3:
                    captions['red_top'] += r > 140 and r > g + 60 and r > b + 60
                elif y < top + (bottom - top) * 2 // 3:
                    captions['blue_middle'] += b > 140 and b > r + 60 and b > g + 60
                else:
                    captions['green_bottom'] += g > 140 and g > r + 60 and g > b + 60
            else:
                if y >= top + (bottom - top) * 2 // 3:
                    captions['white_bottom'] += (min(r, g, b) > 160 and
                                                 max(r, g, b) - min(r, g, b) < 45)
            if y > bottom - (bottom - top) // 5:
                controls += r > 150 and r > g + 60 and r > b + 40
    if kind == 'ass':
        for y in range(top, bottom):
            for x in range(max(left, right - 4), right + 1):
                r, g, b = pixel(x, y)
                caption_edge_pixels += (
                    (r > 140 and r > g + 60 and r > b + 60) or
                    (g > 140 and g > r + 60 and g > b + 60) or
                    (b > 140 and b > r + 60 and b > g + 60))
    control_red_line = 0
    control_bright_line = 0
    for y in range(top + (bottom - top) * 2 // 3, min(height, bottom + 120)):
        red_in_row = bright_in_row = 0
        for x in range(left, right + 1):
            r, g, b = pixel(x, y)
            red_in_row += r > 150 and r > g + 60 and r > b + 40
            bright_in_row += max(r, g, b) > 110
        control_red_line = max(control_red_line, red_in_row)
        control_bright_line = max(control_bright_line, bright_in_row)
    return {'kind': kind, 'video_rect': [left, top, right, bottom],
            'caption_pixels': max(captions.values()),
            'caption_regions': captions, 'control_red_pixels': controls,
            'control_red_line_pixels': control_red_line,
            'control_bright_line_pixels': control_bright_line,
            'caption_edge_pixels': caption_edge_pixels}


def validate(metrics: dict) -> None:
    video_width = metrics['video_rect'][2] - metrics['video_rect'][0] + 1
    if (metrics['control_red_pixels'] > 80 or
            metrics['control_red_line_pixels'] > max(80, min(180, video_width // 6)) or
            metrics['control_bright_line_pixels'] > video_width * 3 // 5):
        raise AssertionError('playback controls overlap the subtitle region')
    if metrics['caption_edge_pixels'] > 10:
        raise AssertionError('authored ASS caption is clipped at the video edge')
    if metrics['caption_pixels'] < 120:
        raise AssertionError(f"{metrics['kind'].upper()} caption is absent from installed VPFL window")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('rgb', type=Path)
    parser.add_argument('width', type=int)
    parser.add_argument('height', type=int)
    parser.add_argument('kind', choices=('ass', 'srt'))
    args = parser.parse_args()
    metrics = analyze(args.rgb.read_bytes(), args.width, args.height, args.kind)
    print(json.dumps(metrics, sort_keys=True))
    validate(metrics)


if __name__ == '__main__':
    main()
