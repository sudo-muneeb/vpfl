"""Check the installed-app screen detector against representative colors."""

import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / 'scripts/ci/check_installed_subtitle_frame.py'
SPEC = importlib.util.spec_from_file_location('installed_subtitle_frame', SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def screen(caption=None):
    width, height = 640, 360
    pixels = bytearray((34, 48, 81)) * (width * height)
    if caption:
        name, color = caption
        bounds = {'red': (390, 440, 45, 65),
                  'blue': (160, 210, 155, 175),
                  'green': (280, 330, 290, 310),
                  'white': (270, 320, 290, 310)}
        x0, x1, y0, y1 = bounds[name]
        for y in range(y0, y1):
            for x in range(x0, x1):
                offset = (y * width + x) * 3
                pixels[offset:offset + 3] = bytes(color)
    return bytes(pixels)


def with_pixels(data, bounds, color):
    pixels = bytearray(data)
    x0, x1, y0, y1 = bounds
    for y in range(y0, y1):
        for x in range(x0, x1):
            offset = (y * 640 + x) * 3
            pixels[offset:offset + 3] = bytes(color)
    return bytes(pixels)


class InstalledSubtitleFrameTest(unittest.TestCase):
    def test_authored_ass_position_and_colors(self):
        for color, rgb, region in [
            ('red', (235, 20, 20), 'red_top'),
            ('blue', (20, 20, 235), 'blue_middle'),
            ('green', (20, 235, 20), 'green_bottom'),
        ]:
            with self.subTest(color=color):
                result = MODULE.analyze(screen((color, rgb)), 640, 360, 'ass')
                self.assertGreater(result['caption_regions'][region], 120)
                MODULE.validate(result)

    def test_external_srt_bright_caption_and_absence(self):
        caption = MODULE.analyze(
            screen(('white', (235, 235, 235))), 640, 360, 'srt')
        blank = MODULE.analyze(screen(), 640, 360, 'srt')
        self.assertGreater(caption['caption_pixels'], 120)
        self.assertEqual(blank['caption_pixels'], 0)
        MODULE.validate(caption)
        with self.assertRaisesRegex(AssertionError, 'absent'):
            MODULE.validate(blank)

    def test_playback_progress_line_rejected(self):
        image = with_pixels(screen(('red', (235, 20, 20))),
                            (80, 560, 310, 313), (180, 180, 180))
        result = MODULE.analyze(image, 640, 360, 'ass')
        self.assertGreater(result['caption_pixels'], 120)
        with self.assertRaisesRegex(AssertionError, 'playback controls'):
            MODULE.validate(result)

    def test_clipped_authored_caption_rejected(self):
        image = with_pixels(screen(('red', (235, 20, 20))),
                            (635, 640, 45, 65), (235, 20, 20))
        result = MODULE.analyze(image, 640, 360, 'ass')
        self.assertGreater(result['caption_edge_pixels'], 10)
        with self.assertRaisesRegex(AssertionError, 'clipped'):
            MODULE.validate(result)

    def test_invalid_frame_size_fails(self):
        with self.assertRaisesRegex(ValueError, 'RGB capture'):
            MODULE.analyze(b'bad', 640, 360, 'ass')


if __name__ == '__main__':
    unittest.main()
