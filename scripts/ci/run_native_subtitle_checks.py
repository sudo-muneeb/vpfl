#!/usr/bin/env python3
"""Run and compare isolated mpv and pinned media_kit native subtitle probes."""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

if __package__:
    from .mpv_subtitle_check import Suite as MpvSuite, active_cues
    from .subtitle_fixture_suite import (DEFAULT_MANIFEST, DEFAULT_SOURCES,
                                         SUITE_DIR, load_manifest, verify_suite)
    from .subtitle_pixels import assert_absent, assert_visible, compare_pngs
else:
    from mpv_subtitle_check import Suite as MpvSuite, active_cues
    from subtitle_fixture_suite import (DEFAULT_MANIFEST, DEFAULT_SOURCES,
                                        SUITE_DIR, load_manifest, verify_suite)
    from subtitle_pixels import assert_absent, assert_visible, compare_pngs


ROOT = Path(__file__).resolve().parents[2]


def command_output(*args: str, timeout: int = 20) -> str:
    try:
        process = subprocess.run(args, capture_output=True, text=True,
                                 timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        return f'unavailable: {error}'
    return (process.stdout or process.stderr).strip()


def versions() -> dict:
    lock = (ROOT / 'pubspec.lock').read_text()
    def locked_version(package: str) -> str:
        start = re.search(rf'^  {re.escape(package)}:\n', lock, re.MULTILINE)
        if start is None:
            raise RuntimeError(f'{package} missing from pubspec.lock')
        tail = lock[start.end():]
        next_package = re.search(r'^  [^ ]+:\n', tail, re.MULTILINE)
        block = tail[:next_package.start()] if next_package else tail
        version = re.search(r'^    version: "([^"]+)"$', block, re.MULTILINE)
        if version is None:
            raise RuntimeError(f'{package} has no pinned version')
        return version.group(1)

    ffmpeg = command_output('ffmpeg', '-version')
    result = {
        'flutter': command_output('flutter', '--version').splitlines()[0],
        'dart': command_output('dart', '--version').splitlines()[0],
        'mpv': command_output('mpv', '--version').splitlines()[0],
        'ffmpeg': ffmpeg.splitlines()[0],
        'ffmpeg_libraries': ffmpeg.splitlines()[3:11],
        'libass_package': command_output('dpkg-query', '-W',
                                         '-f=${Version}', 'libass9'),
        'libmpv_package': command_output('dpkg-query', '-W',
                                         '-f=${Version}', 'libmpv2'),
        'fontconfig_package': command_output('dpkg-query', '-W',
                                             '-f=${Version}', 'libfontconfig1'),
        'harfbuzz_package': command_output('dpkg-query', '-W',
                                           '-f=${Version}', 'libharfbuzz0b'),
        'fribidi_package': command_output('dpkg-query', '-W',
                                          '-f=${Version}', 'libfribidi0'),
        'standalone_libraries': command_output('ldd', shutil.which('mpv') or
                                               '/usr/bin/mpv'),
        'media_kit_version': locked_version('media_kit'),
        'media_kit_video_version': locked_version('media_kit_video'),
        'media_kit_video_source': 'VPFL path override: third_party/media_kit_video',
        'media_kit_libs_video_version': locked_version('media_kit_libs_video'),
        'media_kit_libs_linux_version': locked_version('media_kit_libs_linux'),
        'display': {key: os.environ.get(key) for key in
                    ('DISPLAY', 'WAYLAND_DISPLAY', 'XDG_SESSION_TYPE')},
        'glxinfo': command_output('glxinfo', '-B'),
        'eglinfo': command_output('eglinfo', '-B'),
        'font_match_urdu': command_output('fc-match', 'Noto Sans Arabic'),
        'font_match_missing': command_output('fc-match', 'VPFL Unavailable Font 999'),
    }
    return result


def validate_media_kit(rows: list[dict], manifest: dict) -> list[dict]:
    sources = {entry['id']: entry for entry in manifest['sources']}
    videos = {entry['id']: entry for entry in manifest['videos']}
    checked = copy.deepcopy(rows)
    for row in checked:
        if row['status'] != 'pass':
            continue
        try:
            events = row.get('stream_events', [])
            if not any(event['stream'] == 'tracks' and event['subtitles']
                       for event in events):
                raise AssertionError('media_kit tracks stream did not report subtitles')
            if not any(event['stream'] == 'track' for event in events):
                raise AssertionError('media_kit selected-track stream did not emit')
            for capture in row['captures']:
                source = sources.get(capture['source'], {'cues': []})
                expected = active_cues(source, capture['seconds'])
                actual = capture.get('sub_text') or ''
                for text in expected:
                    if text not in actual:
                        raise AssertionError(f'{capture["label"]}: {text!r} '
                                             f'not in native sub-text {actual!r}')
                if not expected and actual:
                    raise AssertionError(f'{capture["label"]}: stale sub-text {actual!r}')
                metrics = compare_pngs(Path(capture['subtitles_png']),
                                       Path(capture['video_png']),
                                       Path(capture['difference_png']))
                capture['expected_text'] = expected
                capture['metrics'] = metrics
                if expected:
                    markers = source.get('markers', [])
                    positioned = any('\\pos(' in marker or '\\move(' in marker
                                     for marker in markers)
                    assert_visible(metrics, capture['label'],
                                   region=None if positioned else 'bottom')
                else:
                    assert_absent(metrics, capture['label'])
            if row['name'].startswith('embedded_'):
                matched = [entry for entry in videos.values()
                           if entry['file'] == row['fixture']]
                if len(matched) != 1:
                    raise AssertionError('embedded video is absent from manifest')
                expected = matched[0]['tracks']
                actual = row.get('tracks', [])
                if len(actual) != len(expected):
                    raise AssertionError(f'expected {len(expected)} tracks, got {actual}')
                for track in expected:
                    candidates = [item for item in actual
                                  if item['language'] == track['language']]
                    if len(candidates) != 1:
                        raise AssertionError(f'language {track["language"]} missing')
                    observed = candidates[0]
                    if (observed['codec'], observed['default']) != (
                            track['codec'], bool(track['default'])):
                        raise AssertionError(f'track metadata differs: {observed}')
                    if observed['title'] is not None and observed['title'] != track['title']:
                        raise AssertionError(f'track title differs: {observed}')
                default = next((track for track in expected if track['default']), None)
                if default is not None:
                    selected = next(track for track in actual
                                    if track['language'] == default['language'])
                    if row.get('initial_sid') != selected['id']:
                        raise AssertionError('native initial sid differs from default track: '
                                             f'{row.get("initial_sid")} != {selected["id"]}')
            if row['name'] == 'nearby_auto_and_repeat':
                expected_names = {Path(item['file']).name for item in
                                  manifest['nearby']['sidecars']
                                  if item['match'] != 'unrelated'}
                names = {item['title'] for item in row['tracks']}
                if names != expected_names or row['select_repeat_count'] != 2:
                    raise AssertionError(f'nearby or repeat behavior differs: {row["tracks"]}')
            if row['name'] == 'selection_seek_pause_source_switch':
                if row.get('after_plain_tracks') or len(row.get('after_reopen_tracks', [])) != 3:
                    raise AssertionError('stale or missing tracks after source switch')
            if row['name'] == 'malformed_then_recover' and row.get('malformed_tracks'):
                raise AssertionError('malformed file unexpectedly added a track')
            row['screenshot_validation'] = 'pass'
        except Exception as error:
            row['status'] = 'fail'
            row['screenshot_validation'] = 'fail'
            row['render_error'] = f'{type(error).__name__}: {error}'
    return checked


def verify_style(rows: list[dict], manifest: dict) -> list[dict]:
    """Assert spatial color, outline, motion, and cross-language differences."""
    authored_entry = next(entry for entry in manifest['videos']
                          if any(manifest_source(manifest, track['source']).get('markers')
                                 and '\\pos(' in ''.join(manifest_source(
                                     manifest, track['source'])['markers'])
                                 for track in entry['tracks']))
    authored_name = f'embedded_{authored_entry["id"]}_{authored_entry["tracks"][0]["language"]}'
    for row in rows:
        if row['status'] != 'pass':
            continue
        try:
            captures = {capture['label']: capture for capture in row['captures']}
            if row['name'] == authored_name:
                for label, region, color in [('first', 'top', 'red'),
                                              ('second', 'middle', 'blue'),
                                              ('last', 'bottom', 'green')]:
                    metrics = captures[label]['metrics']
                    if (metrics['regions'][region] < 400 or
                            metrics['dominant_colors'][color] < 100 or
                            metrics['darker_pixels'] < 100):
                        raise AssertionError(f'{label} authored ASS style not visible: {metrics}')
                row['style_validation'] = 'authored color, position, outline pass'
            if 'move_start' in captures and 'move_end' in captures:
                start = captures['move_start']['metrics']['bbox']
                end = captures['move_end']['metrics']['bbox']
                if start is None or end is None:
                    raise AssertionError('timed move has no rendered bbox')
                distance = abs((start[0] + start[2]) / 2 - (end[0] + end[2]) / 2)
                if distance < 70:
                    raise AssertionError(f'timed ASS move shifted only {distance:.1f} pixels')
                before = captures['color_start']['metrics']['dominant_colors']['red']
                after = captures['color_end']['metrics']['dominant_colors']['red']
                if abs(after - before) < 150:
                    raise AssertionError(f'timed ASS color changed only {before} -> {after} pixels')
                row['style_validation'] = 'timed move and color pass'
            if row['name'] == 'selection_seek_pause_source_switch':
                english = Path(captures['eng']['subtitles_png'])
                urdu = Path(captures['urd']['subtitles_png'])
                metrics = compare_pngs(english, urdu,
                                       english.parent / 'english-versus-urdu.png')
                if metrics['changed_pixels'] < 120:
                    raise AssertionError('English and Urdu render identically')
                row['language_difference'] = metrics
        except Exception as error:
            row['status'] = 'fail'
            row['style_error'] = f'{type(error).__name__}: {error}'
    return rows


def manifest_source(manifest: dict, source_id: str) -> dict:
    return next(entry for entry in manifest['sources'] if entry['id'] == source_id)


def verify_font_logs(rows: list[dict], manifest: dict) -> list[dict]:
    attached = {f'embedded_{entry["id"]}_{track["language"]}'
                for entry in manifest['videos'] if entry.get('font_attachment')
                for track in entry['tracks']}
    missing_source = next(source for source in manifest['sources']
                          if source['id'] == 'missing_font')
    missing_family = missing_source['markers'][0]
    missing = {entry['id'] for entry in manifest['external']
               if entry['source'] == missing_source['id']}
    attachment_name = manifest['font']['attachment_name']
    family = manifest['font']['family']
    for row in rows:
        if row['status'] != 'pass' or row['name'] not in attached | missing:
            continue
        try:
            log = Path(row['log']).read_text(errors='replace')
            if row['name'] in attached:
                if (f'Attachment: {attachment_name}' not in log or
                        'application/x-truetype-font' not in log or
                        f'fontselect: ({family},' not in log or
                        f'-> {Path(attachment_name).stem}' not in log):
                    raise AssertionError('attachment or its font selection is absent from native log')
                row['font_validation'] = 'attachment recognized and selected'
            else:
                if (missing_family not in log or
                        'Using default font family' not in log):
                    raise AssertionError('missing-font fallback is absent from native log')
                row['font_validation'] = 'fallback selected; pixels visible'
            row['missing_glyph_diagnostics'] = [line for line in log.splitlines()
                                                if 'missing glyph' in line.lower()]
        except Exception as error:
            row['status'] = 'fail'
            row['font_error'] = f'{type(error).__name__}: {error}'
    return rows


def comparison(mpv: list[dict], media_kit: list[dict], versions_data: dict,
               manifest: dict, output: Path) -> list[dict]:
    by_name = {row['name']: row for row in media_kit}
    rows = []
    for native in mpv:
        wrapped = by_name.get(native['name'])
        if wrapped is None:
            status = 'fail'
            classification = 'unresolved (media_kit harness produced no case result)'
        elif native['status'] == wrapped['status'] == 'pass':
            status = 'pass'
            classification = None
        else:
            status = 'fail'
            failed = wrapped if native['status'] == 'pass' else native
            error = str(failed.get('error') or failed.get('render_error') or
                        failed.get('style_error') or failed.get('font_error') or '')
            if 'font' in error.lower() or 'glyph' in error.lower():
                classification = 'fontconfig or system font problem (hypothesis)'
            elif 'socket' in error.lower() or 'IPC' in error:
                classification = 'standalone mpv configuration or IPC harness (hypothesis)'
            elif 'screenshot' in error.lower() or 'rendered frame' in error.lower():
                classification = 'graphics or screenshot environment (hypothesis)'
            elif native['status'] == 'pass':
                classification = 'media_kit integration (hypothesis)'
            else:
                classification = 'fixture, libmpv, or libass; unresolved'
        expected = {'fixture': native['fixture'],
                    'capture_points': [
                        {'time': capture['seconds'],
                         'text': capture['expected_text']}
                        for capture in native['captures']],
                    'subtitle_tracks': [track for video in manifest['videos']
                                        if video['file'] == native['fixture']
                                        for track in video['tracks']]}
        external = next((entry for entry in manifest['external']
                         if entry['id'] == native['name']), None)
        if external is not None:
            source = manifest_source(manifest, external['source'])
            expected['external'] = {'source_type': external['source_type'],
                                    'codec': source['codec'],
                                    'language': source['language'],
                                    'cues': source['cues']}
        if native['name'] == 'nearby_auto_and_repeat':
            expected['nearby_sidecars'] = [entry for entry in
                                           manifest['nearby']['sidecars']
                                           if entry['match'] != 'unrelated']
            expected['unrelated_excluded'] = True
            expected['repeat_select_adds'] = 2
            expected['repeat_cached_adds'] = 0
        if native['name'] == 'selection_seek_pause_source_switch':
            expected['track_counts_during_switch'] = [3, 0, 3]
            expected['languages_selected'] = ['eng', 'urd', 'jpn']
            expected['off_sid'] = 'no'
        if native['name'] == 'malformed_then_recover':
            expected['malformed_track_count'] = 0
            expected['recovered_track_count'] = 1
        rows.append({
            'capability': native['name'],
            'fixture': native['fixture'],
            'expected': expected,
            'standalone_mpv': native['status'],
            'media_kit': wrapped['status'] if wrapped else 'missing',
            'screenshot_validation': {
                'mpv': native['status'],
                'media_kit': wrapped.get('screenshot_validation', 'unrun') if wrapped else 'unrun',
            },
            'native_versions': {'mpv': versions_data['mpv'],
                                'libmpv': versions_data['libmpv_package'],
                                'libass': versions_data['libass_package']},
            'logs': {'mpv': native.get('log'),
                     'media_kit': wrapped.get('log') if wrapped else None},
            'artifacts': {'mpv': str(output / 'mpv' / native['name']),
                          'media_kit': str(output / 'media_kit' / native['name'])},
            'status': status,
            'suspected_cause': classification,
            'errors': {'mpv': native.get('error') or native.get('style_error') or
                       native.get('font_error'),
                       'media_kit': (wrapped.get('error') or wrapped.get('render_error') or
                                     wrapped.get('style_error') or wrapped.get('font_error'))
                                     if wrapped else 'missing result'},
        })
    return rows


def write_report(output: Path, fixtures: Path, rows: list[dict], versions_data: dict,
                 mpv: list[dict], media_kit: list[dict]) -> None:
    lines = [
        '# Native subtitle comparison', '',
        f'Fixture suite: `{fixtures.resolve() / SUITE_DIR}`',
        'Rendering backend: isolated mpv `vo=null` and pinned media_kit '
        '`vo=null`, both using libass.', '',
        f"Standalone mpv: {versions_data['mpv']}",
        f"media_kit: {versions_data['media_kit_version']}; "
        f"media_kit_video: {versions_data['media_kit_video_version']}",
        f"System libmpv: {versions_data['libmpv_package']}; "
        f"libass: {versions_data['libass_package']}", '',
        '| Capability | mpv | media_kit | Screenshot check |',
        '| --- | --- | --- | --- |',
    ]
    for row in rows:
        result = row['screenshot_validation']
        lines.append(f"| `{row['capability']}` | {row['standalone_mpv']} | "
                     f"{row['media_kit']} | mpv {result['mpv']}; "
                     f"media_kit {result['media_kit']} |")
    lines += ['', '## Observations', '']
    for row in rows:
        if row['status'] != 'pass':
            lines.append(f"- `{row['capability']}` failed: {row['errors']}; "
                         f"suspected cause: {row['suspected_cause']}.")
    nearby = next((row for row in mpv if row['name'] == 'nearby_auto_and_repeat'), {})
    malformed = next((row for row in media_kit
                      if row['name'] == 'malformed_then_recover'), {})
    lines += [
        f"- mpv `sub-add select` loaded {nearby.get('select_repeat_count')} "
        'additional copies when an auto-discovered SRT was added twice. '
        '`sub-add cached` added no further copy.',
        '- The malformed SRT produced no track. The media_kit requested '
        f"selection was `{malformed.get('malformed_requested', {}).get('id')}`, "
        'despite the native track list remaining empty; a valid SRT loaded afterward.',
        '- Unicode cue text and subtitle pixels are checked automatically. '
        'Human review of the saved Urdu and Arabic screenshots is still needed '
        'to assess shaping, direction, and individual glyph correctness.',
        '- Standalone mpv and media_kit use the host libraries recorded in '
        '`versions.json` and `media_kit/native-libraries.json`. This does not '
        'establish identical video output paths for the VPFL Flutter window.',
        '', 'Failures retain PNGs, difference images, JSON results, and logs '
        'under this ignored build directory.',
    ]
    (output / 'report.md').write_text('\n'.join(lines) + '\n')


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--fixtures', type=Path,
                        default=Path('build/ci-video-fixtures'))
    parser.add_argument('--out', type=Path,
                        default=Path('build/ci-native-subtitles'))
    parser.add_argument('--manifest', type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args()
    for tool in ('mpv', 'ffmpeg', 'ffprobe', 'dart'):
        if shutil.which(tool) is None:
            parser.error(f'{tool} is required for native subtitle verification')
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=True)
    manifest = load_manifest(args.manifest)
    verify_suite(args.manifest, DEFAULT_SOURCES, args.fixtures)
    for engine in ('mpv', 'media_kit'):
        folder = output / engine
        if folder.exists():
            shutil.rmtree(folder)
    versions_data = versions()
    (output / 'versions.json').write_text(json.dumps(versions_data, indent=2) + '\n')
    mpv = MpvSuite(args.fixtures, output / 'mpv', args.manifest).run()
    dart_command = ['dart', 'run', 'scripts/ci/media_kit_subtitle_check.dart',
                    str((args.fixtures / SUITE_DIR).resolve()),
                    str(args.manifest.resolve()), str(output / 'media_kit')]
    media_kit_process_ok = False
    try:
        process = subprocess.run(dart_command, cwd=ROOT, text=True,
                                 capture_output=True, timeout=600, check=False)
        media_kit_process_ok = process.returncode == 0
        (output / 'media_kit-stdout.log').write_text(process.stdout + process.stderr)
        print(process.stdout, end='')
        if process.returncode:
            print(f'media_kit harness exited {process.returncode}; '
                  f'see {output / "media_kit-stdout.log"}', file=sys.stderr)
    except subprocess.TimeoutExpired as error:
        (output / 'media_kit-stdout.log').write_text(
            f'media_kit timed out after 600 s: {error}\n')
        print('media_kit harness timed out; see log', file=sys.stderr)
    raw_file = output / 'media_kit/raw-results.json'
    media_kit = json.loads(raw_file.read_text()) if raw_file.is_file() else []
    media_kit = verify_font_logs(verify_style(
        validate_media_kit(media_kit, manifest), manifest), manifest)
    mpv = verify_font_logs(verify_style(mpv, manifest), manifest)
    (output / 'media_kit').mkdir(exist_ok=True)
    (output / 'media_kit/validated-results.json').write_text(
        json.dumps(media_kit, indent=2, ensure_ascii=False) + '\n')
    (output / 'mpv/validated-results.json').write_text(
        json.dumps(mpv, indent=2, ensure_ascii=False) + '\n')
    rows = comparison(mpv, media_kit, versions_data, manifest, output)
    (output / 'comparison.json').write_text(json.dumps(rows, indent=2,
                                                       ensure_ascii=False) + '\n')
    write_report(output, args.fixtures, rows, versions_data, mpv, media_kit)
    passed = sum(row['status'] == 'pass' for row in rows)
    print(f'native comparison: {passed}/{len(rows)} passed; '
          f'report {output / "report.md"}')
    return 1 if passed != len(rows) or not media_kit_process_ok else 0


if __name__ == '__main__':
    raise SystemExit(main())
