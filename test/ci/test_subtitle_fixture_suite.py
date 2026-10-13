"""Behavior checks for the opt-in FFmpeg subtitle fixture suite."""

import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from scripts.ci import subtitle_fixture_suite as suite


class SubtitleFixtureSuiteTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workspace = tempfile.TemporaryDirectory(prefix='vpfl-subtitle-test-')
        cls.output = Path(cls.workspace.name)
        suite.generate_suite(suite.DEFAULT_MANIFEST, suite.DEFAULT_SOURCES, cls.output)
        cls.manifest = suite.load_manifest(suite.DEFAULT_MANIFEST)

    @classmethod
    def tearDownClass(cls):
        cls.workspace.cleanup()

    def test_inventory_manifest_and_independent_validation(self):
        expected = suite.expected_files(self.manifest)
        generated = self.output / suite.SUITE_DIR
        index = json.loads((generated / 'index.json').read_text())
        self.assertEqual(len(expected), 20)
        self.assertEqual({row['file'] for row in index['files']}, expected)
        self.assertEqual(index['manifest_sha256'], suite.digest(suite.DEFAULT_MANIFEST))
        self.assertEqual(len(index['source_sha256']), 14)
        self.assertEqual(self.manifest['source_switch'], ['plain', 'multilingual'])
        self.assertEqual(len(self.manifest['videos'][0]['tracks']), 0)
        self.assertEqual(len(self.manifest['videos'][4]['tracks']), 3)
        suite.verify_suite(suite.DEFAULT_MANIFEST, suite.DEFAULT_SOURCES, self.output)

    def test_missing_ffmpeg_and_ffprobe_report_the_tool(self):
        for missing in ('ffmpeg', 'ffprobe'):
            with self.subTest(missing=missing):
                with mock.patch.object(suite.shutil, 'which',
                                       side_effect=lambda name: None if name == missing else '/usr/bin/' + name):
                    with self.assertRaisesRegex(RuntimeError, missing + ' is required'):
                        suite.require_tools()

    def test_invalid_or_incomplete_ffprobe_output_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            fake = Path(folder) / 'ffprobe'
            for output, message in [('not json', 'invalid JSON'), ('{}', 'omitted streams or format')]:
                fake.write_text('#!/bin/sh\nprintf \'%s\' \'' + output + '\'\n')
                fake.chmod(0o755)
                with mock.patch.dict(os.environ, {'PATH': folder + os.pathsep + os.environ['PATH']}):
                    with self.assertRaisesRegex(RuntimeError, message):
                        suite.probe(self.output / suite.SUITE_DIR / 'plain.mp4')

    def test_wrong_subtitle_count_is_rejected_but_no_subtitle_neighbor_passes(self):
        generated = self.output / suite.SUITE_DIR
        sources = {entry['id']: entry for entry in self.manifest['sources']}
        plain = self.manifest['videos'][0]
        suite.validate_video(plain, self.manifest, sources, generated / plain['file'])
        embedded = self.manifest['videos'][1]
        wrong = {**embedded, 'tracks': embedded['tracks'] * 2}
        with self.assertRaisesRegex(RuntimeError, 'expected 2 subtitle streams, got 1'):
            suite.validate_video(wrong, self.manifest, sources, generated / embedded['file'])

    def test_changed_source_cue_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            sources = Path(folder) / 'sources'
            shutil.copytree(suite.DEFAULT_SOURCES, sources)
            english = sources / 'english.srt'
            english.write_text(english.read_text().replace('ENGLISH FIRST', 'WRONG FIRST'))
            with self.assertRaisesRegex(RuntimeError, 'expected.*ENGLISH FIRST'):
                suite.validate_sources(self.manifest, sources)

    def test_rerun_replaces_stale_files_and_keeps_stream_metadata(self):
        generated = self.output / suite.SUITE_DIR
        before = suite.probe(generated / 'multilingual.mkv')
        (generated / 'stale.srt').write_text('obsolete fixture')
        suite.generate_suite(suite.DEFAULT_MANIFEST, suite.DEFAULT_SOURCES, self.output)
        self.assertFalse((generated / 'stale.srt').exists())
        after = suite.probe(generated / 'multilingual.mkv')
        fields = lambda item: (item['codec_type'], item['codec_name'],
                               item.get('tags', {}).get('language'),
                               item.get('tags', {}).get('title'),
                               item.get('disposition', {}).get('default'))
        self.assertEqual([fields(s) for s in before['streams']],
                         [fields(s) for s in after['streams']])
        suite.verify_suite(suite.DEFAULT_MANIFEST, suite.DEFAULT_SOURCES, self.output)


if __name__ == '__main__':
    unittest.main()
