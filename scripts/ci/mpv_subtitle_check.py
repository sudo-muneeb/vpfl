#!/usr/bin/env python3
"""Headless, isolated mpv JSON-IPC subtitle checks using Part 2 fixtures."""

from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import tempfile
import threading
import time
from pathlib import Path

if __package__:
    from .subtitle_fixture_suite import DEFAULT_MANIFEST, SUITE_DIR, load_manifest
    from .subtitle_pixels import assert_absent, assert_visible, compare_pngs
else:
    from subtitle_fixture_suite import DEFAULT_MANIFEST, SUITE_DIR, load_manifest
    from subtitle_pixels import assert_absent, assert_visible, compare_pngs


class IPCError(RuntimeError):
    pass


class MpvIPC:
    """Separate command responses from asynchronous events by request ID."""

    def __init__(self, directory: Path, log: Path,
                 extra_arguments: tuple[str, ...] = ()):
        self.directory = directory
        self.socket_path = directory / 'ipc'
        self.condition = threading.Condition()
        self.responses: dict[int, dict] = {}
        self.events: list[tuple[int, dict]] = []
        self.sequence = 0
        self.request_id = 0
        self.reader_error: str | None = None
        env = dict(os.environ)
        for key, name in [('XDG_CONFIG_HOME', 'config'),
                          ('XDG_CACHE_HOME', 'cache'), ('XDG_DATA_HOME', 'data')]:
            path = directory / name
            path.mkdir()
            env[key] = str(path)
        self.process = subprocess.Popen(
            ['mpv', '--no-config', '--idle=yes', '--keep-open=yes', '--pause=yes',
             '--vo=null', '--ao=null', '--hwdec=no', '--osc=no', '--osd-level=0',
             '--input-ipc-server=ipc', f'--log-file={log}',
             '--msg-level=all=info', *extra_arguments],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, env=env, cwd=directory,
        )
        try:
            deadline = time.monotonic() + 8
            while not self.socket_path.exists():
                if self.process.poll() is not None:
                    raise IPCError(f'mpv exited {self.process.returncode} before IPC opened; see {log}')
                if time.monotonic() >= deadline:
                    raise IPCError(f'mpv IPC socket did not appear; see {log}')
                time.sleep(0.02)
            self.socket = socket.socket(socket.AF_UNIX)
            # /proc/<pid>/cwd keeps the client address below Linux's 108-byte
            # sockaddr_un limit even when the artifact directory is deeply nested.
            self.socket.connect(f'/proc/{self.process.pid}/cwd/ipc')
        except Exception:
            if hasattr(self, 'socket'):
                self.socket.close()
            self.process.terminate()
            try:
                self.process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=3)
            raise
        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()

    def _read(self) -> None:
        try:
            with self.socket.makefile('rb') as stream:
                for line in stream:
                    message = json.loads(line)
                    with self.condition:
                        if 'request_id' in message:
                            self.responses[message['request_id']] = message
                        elif 'event' in message:
                            self.sequence += 1
                            self.events.append((self.sequence, message))
                        self.condition.notify_all()
        except (OSError, ValueError) as error:
            self.reader_error = str(error)
        finally:
            with self.condition:
                self.condition.notify_all()

    def command(self, *args, optional: bool = False, timeout: float = 8):
        with self.condition:
            self.request_id += 1
            request_id = self.request_id
        payload = json.dumps({'command': list(args), 'request_id': request_id}) + '\n'
        self.socket.sendall(payload.encode())
        deadline = time.monotonic() + timeout
        with self.condition:
            while request_id not in self.responses:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or self.reader_error or self.process.poll() is not None:
                    raise IPCError(f'mpv command timed out or exited: {args}; '
                                   f'reader={self.reader_error}, exit={self.process.poll()}')
                self.condition.wait(remaining)
            response = self.responses.pop(request_id)
        if response.get('error') != 'success':
            if optional and response.get('error') == 'property unavailable':
                return None
            raise IPCError(f'mpv command {args} returned {response.get("error")}: {response}')
        return response.get('data')

    def event_after(self, name: str, sequence: int, timeout: float = 8) -> tuple[int, dict]:
        deadline = time.monotonic() + timeout
        with self.condition:
            while True:
                for event_sequence, event in self.events:
                    if event_sequence > sequence and event.get('event') == name:
                        return event_sequence, event
                for event_sequence, event in self.events:
                    if (event_sequence > sequence and event.get('event') == 'end-file'
                            and event.get('reason') == 'error'):
                        raise IPCError(f'mpv ended file before {name}: {event}')
                remaining = deadline - time.monotonic()
                if remaining <= 0 or self.reader_error or self.process.poll() is not None:
                    raise IPCError(f'mpv event {name} timed out; '
                                   f'reader={self.reader_error}, exit={self.process.poll()}')
                self.condition.wait(remaining)

    def load(self, path: Path) -> None:
        sequence = self.sequence
        self.command('loadfile', str(path.resolve()), 'replace')
        loaded_sequence, _ = self.event_after('file-loaded', sequence)
        self.event_after('playback-restart', loaded_sequence)

    def seek(self, seconds: float) -> None:
        sequence = self.sequence
        self.command('seek', seconds, 'absolute+exact')
        self.event_after('playback-restart', sequence)
        position = self.property('time-pos')
        if position is None or abs(float(position) - seconds) > 0.13:
            raise IPCError(f'mpv seek to {seconds} reached {position}')

    def property(self, name: str):
        return self.command('get_property', name, optional=True)

    def set_property(self, name: str, value) -> None:
        self.command('set_property', name, value)

    def subtitles(self) -> list[dict]:
        return [track for track in self.property('track-list')
                if track.get('type') == 'sub']

    def screenshot(self, path: Path, mode: str) -> None:
        self.command('screenshot-to-file', str(path), mode)
        if not path.is_file() or path.stat().st_size == 0:
            raise IPCError(f'mpv returned success but did not write {path}')

    def close(self) -> None:
        try:
            self.command('quit', timeout=2)
        except (IPCError, OSError):
            pass
        self.socket.close()
        try:
            self.process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=3)
        self.reader.join(timeout=1)


def active_cues(source: dict, seconds: float) -> list[str]:
    return [cue[2] for cue in source['cues'] if cue[0] <= seconds < cue[1]]


def sample_times(source: dict) -> dict[str, float]:
    cues = source['cues']
    intervals = sorted((cue[0], cue[1]) for cue in cues)
    merged: list[list[float]] = []
    for start, end in intervals:
        if merged and start <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], end)
        else:
            merged.append([start, end])
    gaps = [(left[1] + right[0]) / 2 for left, right in zip(merged, merged[1:])
            if right[0] - left[1] >= 0.2]
    if not gaps:
        raise AssertionError(f'{source["id"]}: no cue gap to test')
    return {'before': intervals[0][0] / 2,
            'first': (cues[0][0] + cues[0][1]) / 2,
            'gap': gaps[0],
            'second': (cues[1][0] + cues[1][1]) / 2,
            'last': (cues[-1][0] + cues[-1][1]) / 2}


class Suite:
    def __init__(self, fixtures: Path, output: Path, manifest_path: Path):
        self.manifest = load_manifest(manifest_path)
        self.fixtures = fixtures.resolve() / SUITE_DIR
        self.output = output.resolve()
        self.output.mkdir(parents=True, exist_ok=True)
        self.sources = {item['id']: item for item in self.manifest['sources']}
        self.videos = {item['id']: item for item in self.manifest['videos']}
        self.results: list[dict] = []

    def case(self, name: str, fixture: str, action) -> None:
        folder = self.output / name
        folder.mkdir(parents=True, exist_ok=True)
        result = {'name': name, 'fixture': fixture, 'engine': 'mpv',
                  'status': 'pass', 'captures': [], 'log': str(folder / 'mpv.log')}
        try:
            with tempfile.TemporaryDirectory(prefix='ipc-', dir=folder) as temporary:
                ipc = MpvIPC(Path(temporary), folder / 'mpv.log')
                try:
                    action(ipc, folder, result)
                finally:
                    ipc.close()
        except Exception as error:
            result['status'] = 'fail'
            result['error'] = f'{type(error).__name__}: {error}'
        self.results.append(result)
        print(f'{result["status"].upper()} mpv {name}' +
              (f': {result.get("error")}' if result['status'] == 'fail' else ''), flush=True)
        (self.output / 'results.json').write_text(json.dumps(self.results, indent=2,
                                                               ensure_ascii=False) + '\n')

    def capture(self, ipc: MpvIPC, folder: Path, result: dict, label: str,
                seconds: float, source: dict, *, region: str | None = None) -> dict:
        ipc.seek(seconds)
        expected = active_cues(source, seconds)
        actual = ipc.property('sub-text') or ''
        if expected:
            for text in expected:
                if text not in actual:
                    raise AssertionError(f'{label}: expected {text!r} in sub-text {actual!r}')
        elif actual:
            raise AssertionError(f'{label}: stale sub-text {actual!r} outside cue')
        shown = folder / f'{label}-subtitles.png'
        video = folder / f'{label}-video.png'
        diff = folder / f'{label}-difference.png'
        ipc.screenshot(shown, 'subtitles')
        ipc.screenshot(video, 'video')
        metrics = compare_pngs(shown, video, diff)
        item = {'label': label, 'seconds': seconds, 'expected_text': expected,
                'sub_text': actual, 'sid': ipc.property('sid'), 'metrics': metrics,
                'subtitles_png': str(shown), 'video_png': str(video),
                'difference_png': str(diff)}
        result['captures'].append(item)
        if expected:
            assert_visible(metrics, label, region=region)
        else:
            assert_absent(metrics, label)
        return item

    def embedded(self, entry: dict) -> None:
        for track in entry['tracks']:
            name = f'embedded_{entry["id"]}_{track["language"]}'
            def action(ipc, folder, result, entry=entry, track=track):
                ipc.load(self.fixtures / entry['file'])
                found = ipc.subtitles()
                if len(found) != len(entry['tracks']):
                    raise AssertionError(f'expected {len(entry["tracks"])} tracks, got {found}')
                for expected in entry['tracks']:
                    match = [item for item in found if item.get('lang') == expected['language']]
                    if len(match) != 1:
                        raise AssertionError(f'language {expected["language"]} missing: {found}')
                    actual = match[0]
                    if (actual.get('codec'), bool(actual.get('default'))) != (
                            expected['codec'], bool(expected['default'])):
                        raise AssertionError(f'track metadata mismatch: {actual} vs {expected}')
                    if actual.get('title') is not None and actual['title'] != expected['title']:
                        raise AssertionError(f'track title mismatch: {actual} vs {expected}')
                default = next((item for item in entry['tracks'] if item['default']), None)
                if default is not None:
                    selected_initial = [item for item in found if item.get('selected')]
                    if (len(selected_initial) != 1 or
                            selected_initial[0].get('lang') != default['language']):
                        raise AssertionError(f'default selection differs: {found}')
                result['initial_sid'] = ipc.property('sid')
                selected = [item for item in found if item['lang'] == track['language']][0]
                ipc.set_property('sid', selected['id'])
                if ipc.property('sid') != selected['id']:
                    raise AssertionError('sid did not select requested language')
                result['tracks'] = found
                result['properties'] = self.properties(ipc)
                source = self.sources[track['source']]
                for label, seconds in sample_times(source).items():
                    region = 'bottom' if track['codec'] != 'ass' else None
                    self.capture(ipc, folder, result, label, seconds, source, region=region)
            self.case(name, entry['file'], action)

    @staticmethod
    def properties(ipc: MpvIPC) -> dict:
        return {key: ipc.property(key) for key in
                ('sid', 'sub-auto', 'sub-delay', 'sub-ass-override',
                 'embeddedfonts', 'sub-font-provider', 'sub-ass', 'pause')}

    def external(self, entry: dict) -> None:
        source = self.sources[entry['source']]
        if source.get('valid') is False:
            return
        video = self.videos[entry['video']]
        def action(ipc, folder, result):
            ipc.load(self.fixtures / video['file'])
            if ipc.subtitles():
                raise AssertionError('plain video unexpectedly has subtitle tracks')
            ipc.command('sub-add', str(self.fixtures / entry['file']), 'select')
            found = ipc.subtitles()
            if len(found) != 1 or not found[0].get('external'):
                raise AssertionError(f'explicit external track missing: {found}')
            result['tracks'] = found
            for label, seconds in sample_times(source).items():
                self.capture(ipc, folder, result, label, seconds, source,
                             region='bottom' if source['codec'] != 'ass' else None)
            markers = source.get('markers', [])
            if any('\\move(' in marker for marker in markers):
                first = source['cues'][source.get('motion_cue_index', 0)]
                for label, seconds in [('move_start', first[0] + 0.2),
                                       ('move_end', first[1] - 0.2)]:
                    self.capture(ipc, folder, result, label, seconds, source)
            if any('\\t(' in marker for marker in markers):
                second = source['cues'][1]
                for label, seconds in [('color_start', second[0] + 0.2),
                                       ('color_end', second[1] - 0.2)]:
                    self.capture(ipc, folder, result, label, seconds, source)
        self.case(entry['id'], entry['file'], action)

    def nearby(self) -> None:
        nearby = self.manifest['nearby']
        names = {item['match']: item for item in nearby['sidecars']}
        def action(ipc, folder, result):
            ipc.load(self.fixtures / nearby['video'])
            tracks = ipc.subtitles()
            filenames = [Path(item.get('external-filename', '')).name for item in tracks]
            if len(tracks) != 2 or sorted(filenames) != sorted(
                    Path(names[key]['file']).name for key in ('exact', 'language_suffix')):
                raise AssertionError(f'exact/language sidecar discovery mismatch: {tracks}')
            if Path(names['unrelated']['file']).name in filenames:
                raise AssertionError('unrelated sidecar was discovered')
            result['tracks'] = tracks
            result['properties'] = self.properties(ipc)
            for key in ('exact', 'language_suffix'):
                match = next(item for item in tracks
                             if Path(item['external-filename']).name ==
                             Path(names[key]['file']).name)
                ipc.set_property('sid', match['id'])
                source = self.sources[names[key]['source']]
                self.capture(ipc, folder, result, key, sample_times(source)['first'],
                             source, region='bottom')
            exact_file = self.fixtures / names['exact']['file']
            before = len(ipc.subtitles())
            ipc.command('sub-add', str(exact_file), 'select')
            ipc.command('sub-add', str(exact_file), 'select')
            after_select = len(ipc.subtitles())
            result['select_repeat_count'] = after_select - before
            if after_select != before + 2:
                raise AssertionError(f'repeated sub-add select count {after_select}, expected {before + 2}')
            ipc.command('sub-add', str(exact_file), 'cached')
            if len(ipc.subtitles()) != after_select:
                raise AssertionError('sub-add cached added another duplicate')
        self.case('nearby_auto_and_repeat', nearby['video'], action)

    def transitions(self) -> None:
        entry = self.videos['multilingual']
        sources = self.sources
        def action(ipc, folder, result):
            ipc.load(self.fixtures / entry['file'])
            tracks = ipc.subtitles()
            selected = [track for track in tracks if track.get('selected')]
            if len(selected) != 1 or selected[0].get('lang') != 'eng':
                raise AssertionError(f'default selection is not English: {tracks}')
            for language in ('eng', 'urd', 'jpn'):
                track = next(item for item in tracks if item.get('lang') == language)
                ipc.set_property('sid', track['id'])
                source_id = next(item['source'] for item in entry['tracks']
                                 if item['language'] == language)
                source = sources[source_id]
                self.capture(ipc, folder, result, language,
                             sample_times(source)['first'], source, region='bottom')
            english = next(item for item in tracks if item.get('lang') == 'eng')
            ipc.set_property('sid', english['id'])
            source = sources['english']
            for label in ('first', 'gap', 'second', 'before', 'last', 'first'):
                self.capture(ipc, folder, result, f'seek_{label}_{len(result["captures"])}',
                             sample_times(source)[label], source, region='bottom')
            ipc.set_property('pause', False)
            if ipc.property('pause') is not False:
                raise AssertionError('resume did not clear pause')
            ipc.set_property('pause', True)
            if ipc.property('pause') is not True:
                raise AssertionError('pause did not stick')
            self.capture(ipc, folder, result, 'paused_cue',
                         sample_times(source)['first'], source, region='bottom')
            ipc.set_property('sid', 'no')
            off = self.capture(ipc, folder, result, 'off',
                               sample_times(source)['first'],
                               {'id': 'off', 'cues': []})
            assert_absent(off['metrics'], 'subtitle Off')
            ipc.set_property('sid', 'auto')
            if ipc.property('sid') == 'no':
                raise AssertionError('Auto left subtitles disabled')
            self.capture(ipc, folder, result, 'auto',
                         sample_times(source)['first'], source, region='bottom')
            ipc.load(self.fixtures / self.videos['plain']['file'])
            if ipc.subtitles():
                raise AssertionError('old subtitle tracks survived source switch')
            result['after_plain_sid'] = ipc.property('sid')
            ipc.load(self.fixtures / entry['file'])
            if len(ipc.subtitles()) != len(entry['tracks']):
                raise AssertionError('subtitle tracks did not reappear after source switch')
        self.case('selection_seek_pause_source_switch', entry['file'], action)

    def malformed(self) -> None:
        invalid = next(item for item in self.manifest['external']
                       if self.sources[item['source']].get('valid') is False)
        valid = next(item for item in self.manifest['external']
                     if self.sources[item['source']]['codec'] == 'subrip'
                     and self.sources[item['source']].get('valid') is not False)
        def action(ipc, folder, result):
            ipc.load(self.fixtures / self.videos[invalid['video']]['file'])
            try:
                ipc.command('sub-add', str(self.fixtures / invalid['file']), 'select')
                result['malformed_command'] = 'success'
            except IPCError as error:
                result['malformed_command'] = str(error)
            result['malformed_tracks'] = ipc.subtitles()
            source = self.sources[valid['source']]
            ipc.command('sub-add', str(self.fixtures / valid['file']), 'select')
            if len(ipc.subtitles()) != 1:
                raise AssertionError('valid subtitle did not load after malformed file')
            self.capture(ipc, folder, result, 'recovered',
                         sample_times(source)['first'], source, region='bottom')
        self.case('malformed_then_recover', invalid['file'], action)

    def run(self) -> list[dict]:
        for entry in self.manifest['videos']:
            if entry['tracks']:
                self.embedded(entry)
        for entry in self.manifest['external']:
            self.external(entry)
        self.nearby()
        self.transitions()
        self.malformed()
        return self.results


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--fixtures', type=Path, required=True)
    parser.add_argument('--out', type=Path, default=Path('build/ci-native-subtitles/mpv'))
    parser.add_argument('--manifest', type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args()
    results = Suite(args.fixtures, args.out, args.manifest).run()
    print(f'mpv: {sum(item["status"] == "pass" for item in results)}/{len(results)} passed')
    return 1 if any(item['status'] == 'fail' for item in results) else 0


if __name__ == '__main__':
    raise SystemExit(main())
