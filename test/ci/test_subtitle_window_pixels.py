"""Behavior checks for final-window pixel validation."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/ci/check_subtitle_window.py'


def save_png(path: Path, pixels: bytes):
    result = subprocess.run(
        ['ffmpeg', '-nostdin', '-v', 'error', '-y', '-f', 'rawvideo',
         '-pixel_format', 'rgb24', '-video_size', '160x120', '-i', '-',
         '-frames:v', '1', str(path)],
        input=pixels, capture_output=True, check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.decode())


def frame(*, caption=False, controls=False, pale_controls=False,
          black=False, burned=False, outer=False, red_caption=False):
    pixels = bytearray((0, 0, 0) if black else (34, 48, 81)) * (160 * 120)
    if caption:
        for y in range(90, 99):
            for x in range(55, 105):
                offset = (y * 160 + x) * 3
                pixels[offset:offset + 3] = b'\xff\xff\xff'
    if red_caption:
        for y in range(90, 99):
            for x in range(55, 105):
                offset = (y * 160 + x) * 3
                pixels[offset:offset + 3] = b'\xff\x10\x10'
    if controls:
        for y in range(103, 107):
            for x in range(10, 150):
                offset = (y * 160 + x) * 3
                pixels[offset:offset + 3] = b'\xff\x20\x20'
    if pale_controls:
        for y in range(103, 107):
            for x in range(10, 150):
                offset = (y * 160 + x) * 3
                pixels[offset:offset + 3] = b'\xb0\xb0\xb0'
    if burned:
        for y in range(50, 59):
            for x in range(55, 105):
                offset = (y * 160 + x) * 3
                pixels[offset:offset + 3] = b'\xff\xff\xff'
    if outer:
        for y in range(50, 60):
            for x in range(1, 21):
                offset = (y * 160 + x) * 3
                pixels[offset:offset + 3] = b'\xff\xff\xff'
    return bytes(pixels)


class SubtitleWindowPixelsTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)

    def check(self, enabled, disabled, expected, rect=(0, 0, 160, 120)):
        first = self.directory / 'on.png'
        second = self.directory / 'off.png'
        save_png(first, enabled)
        save_png(second, disabled)
        return subprocess.run(
            [sys.executable, str(SCRIPT), str(first), str(second),
             '--rect', *map(str, rect), '--expect', expected,
             '--region', 'bottom', '--metrics', str(self.directory / 'metrics.json'),
             '--difference', str(self.directory / 'difference.png')],
            cwd=ROOT, capture_output=True, text=True, check=False,
        )

    def test_visible_caption_passes_and_writes_metrics(self):
        result = self.check(frame(caption=True), frame(), 'visible')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"changed_pixels": 450', result.stdout)
        self.assertTrue((self.directory / 'metrics.json').is_file())

    def test_missing_caption_fails_and_retains_difference(self):
        result = self.check(frame(), frame(), 'visible')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('subtitle is not visible', result.stderr)
        self.assertTrue((self.directory / 'difference.png').is_file())

    def test_same_frame_without_caption_passes_absence(self):
        result = self.check(frame(), frame(), 'absent')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_plain_video_rejects_a_caption_even_in_matching_captures(self):
        blank = self.check(frame(), frame(), 'plain')
        self.assertEqual(blank.returncode, 0, blank.stderr)
        stale = self.check(frame(caption=True), frame(caption=True), 'plain')
        self.assertIn('unsubtitled video has visible caption', stale.stderr)

    def test_black_texture_and_control_overlay_fail(self):
        black = self.check(frame(black=True), frame(black=True), 'absent')
        self.assertIn('black or missing', black.stderr)
        controls = self.check(frame(caption=True), frame(controls=True), 'visible')
        self.assertIn('playback controls cover', controls.stderr)
        same_control_frame = self.check(
            frame(controls=True), frame(controls=True), 'absent')
        self.assertIn('playback controls cover', same_control_frame.stderr)

    def test_burned_caption_remains_after_cc_off(self):
        shown = self.check(frame(burned=True), frame(burned=True), 'burned')
        self.assertEqual(shown.returncode, 0, shown.stderr)
        missing = self.check(frame(), frame(), 'burned')
        self.assertIn('burned caption is absent', missing.stderr)

    def test_change_beside_video_fails(self):
        result = self.check(frame(outer=True), frame(), 'absent',
                            rect=(20, 10, 120, 100))
        self.assertIn('window UI changed', result.stderr)

    def test_red_ass_caption_is_not_a_progress_bar(self):
        result = self.check(frame(red_caption=True), frame(red_caption=True),
                            'absent')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_control_bar_below_texture_is_detected(self):
        result = self.check(frame(controls=True), frame(controls=True),
                            'absent', rect=(0, 0, 160, 100))
        self.assertIn('playback controls cover', result.stderr)
        pale = self.check(frame(pale_controls=True),
                          frame(pale_controls=True), 'absent',
                          rect=(0, 0, 160, 100))
        self.assertIn('playback controls cover', pale.stderr)


if __name__ == '__main__':
    unittest.main()
