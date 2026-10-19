"""The final-window sharpness gate distinguishes crisp and softened cues."""

import importlib.util
import sys
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / 'scripts/ci/check_subtitle_sharpness.py'
sys.path.insert(0, str(SCRIPT.parent))
SPEC = importlib.util.spec_from_file_location('subtitle_sharpness', SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def frame(soften=False, shift=0, vertical_shift=0):
    width, height = 180, 100
    base = (32, 48, 79)
    pixels = bytearray(base * (width * height))
    for y in range(70 + vertical_shift, 84 + vertical_shift):
        for x in range(45 + shift, 135 + shift):
            color = ((240, 240, 240) if 48 <= x - shift < 132 and
                     73 + vertical_shift <= y < 81 + vertical_shift
                     else (0, 0, 0))
            pixels[(y * width + x) * 3:(y * width + x + 1) * 3] = bytes(color)
    if soften:
        original = bytes(pixels)
        for y in range(69 + vertical_shift, 85 + vertical_shift):
            for x in range(44 + shift, 136 + shift):
                for channel in range(3):
                    values = [original[((neighbor_y * width + neighbor_x) * 3)
                                       + channel]
                              for neighbor_y in range(y - 1, y + 2)
                              for neighbor_x in range(x - 1, x + 2)]
                    pixels[(y * width + x) * 3 + channel] = sum(values) // 9
    return bytes(pixels)


class SubtitleSharpnessTest(unittest.TestCase):
    def setUp(self):
        self.blank = bytes((32, 48, 79)) * (180 * 100)
        self.native = MODULE.caption_edges(frame(), self.blank, 180, 100)

    def test_crisp_window_matches_native(self):
        result = MODULE.compare(self.native, self.native)
        self.assertEqual(result['edge_variance_ratio'], 1)
        MODULE.require_shape_overlap(
            MODULE.caption_shape_overlap(frame(), self.blank,
                                         frame(), self.blank), 0.95)

    def test_softened_caption_fails_despite_visible_pixels(self):
        soft = MODULE.caption_edges(frame(soften=True), self.blank, 180, 100)
        self.assertGreater(soft['changed_pixels'], 120)
        with self.assertRaisesRegex(AssertionError, 'softened'):
            MODULE.compare(self.native, soft)

    def test_wrong_caption_position_fails(self):
        shifted = MODULE.caption_edges(frame(shift=12), self.blank, 180, 100)
        with self.assertRaisesRegex(AssertionError, 'misaligned'):
            MODULE.compare(self.native, shifted)

    def test_missing_caption_fails(self):
        with self.assertRaisesRegex(AssertionError, 'only 0 changed pixels'):
            MODULE.caption_edges(self.blank, self.blank, 180, 100)

    def test_authored_cue_region_is_checked(self):
        middle = MODULE.caption_edges(
            frame(vertical_shift=-40), self.blank, 180, 100, 'middle')
        top = MODULE.caption_edges(
            frame(vertical_shift=-65), self.blank, 180, 100, 'top')
        self.assertLess(top['bbox'][1], middle['bbox'][1])
        with self.assertRaisesRegex(AssertionError, 'expected middle'):
            MODULE.caption_edges(frame(), self.blank, 180, 100, 'middle')

    def test_glyph_shape_change_is_visible_with_same_caption_bounds(self):
        changed = bytearray(frame())
        for y in range(75, 80):
            for x in range(70, 110):
                offset = (y * 180 + x) * 3
                changed[offset:offset + 3] = self.blank[offset:offset + 3]
        metrics = MODULE.caption_edges(bytes(changed), self.blank, 180, 100)
        self.assertEqual(metrics['bbox'], self.native['bbox'])
        overlap = MODULE.caption_shape_overlap(
            frame(), self.blank, bytes(changed), self.blank)
        with self.assertRaisesRegex(AssertionError, 'glyph shape differs'):
            MODULE.require_shape_overlap(overlap, 0.95)

    def test_shape_threshold_does_not_round_up_and_rgb_is_complete(self):
        with self.assertRaisesRegex(AssertionError, 'glyph shape differs'):
            MODULE.require_shape_overlap(0.94999, 0.95)
        with self.assertRaisesRegex(ValueError, 'complete RGB pixels'):
            MODULE.caption_shape_overlap(b'\x00', b'\x00', b'\x00', b'\x00')

    def test_registration_allows_one_pixel_translation_but_not_thicker_strokes(self):
        translated = MODULE.caption_alignment(
            frame(), self.blank, frame(shift=1), self.blank, 180, 100, 1)
        self.assertEqual(translated['registered_overlap'], 1)
        self.assertEqual(translated['translation_pixels'], [-1, 0])
        thicker = bytearray(frame())
        for y in (69, 84):
            for x in range(45, 135):
                offset = (y * 180 + x) * 3
                thicker[offset:offset + 3] = b'\x00\x00\x00'
        altered = MODULE.caption_alignment(
            frame(), self.blank, bytes(thicker), self.blank, 180, 100, 1)
        with self.assertRaisesRegex(AssertionError, 'glyph shape differs'):
            MODULE.require_shape_overlap(altered['registered_overlap'], 0.95)


if __name__ == '__main__':
    unittest.main()
