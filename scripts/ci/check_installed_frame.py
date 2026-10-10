#!/usr/bin/env python3
"""Find the regression video's six color bars in an X11 RGB capture."""

import argparse
from pathlib import Path


def color(r, g, b):
    if r > 150 and g < 110 and b < 110:
        return 'red'
    if g > 150 and r < 110 and b < 110:
        return 'green'
    if r > 150 and g > 150 and b < 110:
        return 'yellow'
    if b > 150 and r < 110 and g < 110:
        return 'blue'
    if r > 150 and b > 150 and g < 110:
        return 'magenta'
    if g > 150 and b > 150 and r < 110:
        return 'cyan'
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('rgb', type=Path)
    parser.add_argument('width', type=int)
    parser.add_argument('height', type=int)
    args = parser.parse_args()

    data = args.rgb.read_bytes()
    expected_size = args.width * args.height * 3
    if len(data) != expected_size:
        raise ValueError(f'capture has {len(data)} bytes; expected {expected_size}')

    expected = ('red', 'green', 'yellow', 'blue', 'magenta', 'cyan')
    minimum_run = max(40, args.width // 40)
    for y in range(args.height // 8, args.height * 7 // 8, 8):
        runs = []
        current = None
        start = 0
        for x in range(args.width + 1):
            if x == args.width:
                next_color = None
            else:
                offset = (y * args.width + x) * 3
                next_color = color(*data[offset:offset + 3])
            if next_color != current:
                if current is not None and x - start >= minimum_run:
                    runs.append((current, start, x))
                current = next_color
                start = x
        index = 0
        matched = []
        for run in runs:
            if run[0] == expected[index]:
                matched.append(run)
                index += 1
                if index == len(expected):
                    print(f'PASS installed video color bars at y={y}: {matched}')
                    return
    raise AssertionError('six ordered regression-video color bars not visible')


if __name__ == '__main__':
    main()
