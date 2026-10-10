#!/usr/bin/env python3
"""Fail closed when a media artifact differs from the source manifest."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(manifest_path, directory):
    manifest = json.loads(manifest_path.read_text())
    index = json.loads((directory / 'index.json').read_text())
    assert index['manifest_sha256'] == digest(manifest_path), 'manifest checksum changed'
    cases = {entry['id']: (group, entry) for group in (
        'fixtures', 'subtitle_fixtures',
        'embedded_subtitle_fixtures') for entry in manifest[group]}
    rows = {row['id']: row for row in index['fixtures']}
    assert len(rows) == len(index['fixtures']), 'duplicate index ID'
    assert rows.keys() == cases.keys(), f'missing/extra IDs: {cases.keys() ^ rows.keys()}'
    for case_id, (group, expected) in cases.items():
        row = rows[case_id]
        filename = f"{case_id}.{expected['extension']}"
        assert row['file'] == filename, f'{case_id}: wrong filename'
        source = directory / filename
        assert source.is_file() and source.stat().st_size == row['bytes'], f'{case_id}: missing or altered size'
        assert digest(source) == row['sha256'], f'{case_id}: SHA-256 mismatch'
        probe = json.loads(run('ffprobe', '-v', 'error', '-show_streams',
                               '-show_format', '-of', 'json', str(source)))
        streams = probe['streams']
        def one(kind, codec=None):
            matches = [s for s in streams if s['codec_type'] == kind]
            assert len(matches) == 1, f'{case_id}: expected one {kind} stream, got {len(matches)}'
            if codec:
                assert matches[0]['codec_name'] == codec, f'{case_id}: wrong {kind} codec'
            return matches[0]
        if group == 'fixtures':
            video = one('video', expected['codec'])
            one('audio', expected['audio_codec'])
            expected_format = 'mpeg' if expected['format'] == 'vob' else expected['format']
            formats = probe['format']['format_name'].split(',')
            assert expected_format in formats, f'{case_id}: wrong container {formats}'
            assert (video['width'], video['height']) == (manifest['width'], manifest['height']), f'{case_id}: wrong dimensions'
            assert video['pix_fmt'] == expected['pix_fmt'], f'{case_id}: wrong pixel format'
        elif group == 'embedded_subtitle_fixtures':
            one('video')
            one('audio')
            one('subtitle', expected['subtitle_codec'])
        else:
            one('subtitle', expected['subtitle_codec'])
        if group != 'subtitle_fixtures':
            duration = float(probe['format']['duration'])
            assert abs(duration - manifest['duration_seconds']) < 0.6, f'{case_id}: wrong duration {duration}'
        if group != 'subtitle_fixtures':
            run('ffmpeg', '-nostdin', '-v', 'error', '-xerror', '-i', str(source),
                '-f', 'null', '-')
        print(f'PASS {case_id}', flush=True)
    print(f'verified {len(cases)} fixtures')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--manifest', type=Path,
                        default=Path(__file__).resolve().parents[2] / 'ci/media-matrix.json')
    parser.add_argument('--dir', type=Path, required=True)
    args = parser.parse_args()
    verify(args.manifest, args.dir)
