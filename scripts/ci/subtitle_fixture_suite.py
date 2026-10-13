"""Deterministic subtitle media built beside the existing CI media matrix."""

from __future__ import annotations

import hashlib
import html
import json
import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = ROOT / 'test/fixtures/subtitles/subtitle-matrix.json'
DEFAULT_SOURCES = ROOT / 'test/fixtures/subtitles/sources'
SUITE_DIR = 'subtitle-suite'
TIMESTAMP = re.compile(r'^(\d\d):(\d\d):(\d\d),(\d\d\d)$')


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require_tools() -> None:
    for name in ('ffmpeg', 'ffprobe'):
        if shutil.which(name) is None:
            raise RuntimeError(f'{name} is required to generate and validate subtitle fixtures')


def run(*args: str) -> str:
    try:
        process = subprocess.run(args, text=True, capture_output=True, check=False)
    except FileNotFoundError as error:
        raise RuntimeError(f'{args[0]} is missing; install FFmpeg and FFprobe') from error
    if process.returncode:
        raise RuntimeError(
            f'{args[0]} failed (exit {process.returncode}) for {args[-1]}:\n'
            f'{process.stderr[-3000:]}')
    return process.stdout


def probe(path: Path) -> dict:
    raw = run('ffprobe', '-v', 'error', '-show_streams', '-show_format',
              '-of', 'json', str(path))
    try:
        result = json.loads(raw)
    except json.JSONDecodeError as error:
        raise RuntimeError(f'{path}: ffprobe returned invalid JSON: {error}') from error
    if not isinstance(result, dict) or not isinstance(result.get('streams'), list) or not isinstance(result.get('format'), dict):
        raise RuntimeError(f'{path}: ffprobe omitted streams or format')
    return result


def _seconds(value: str) -> float:
    match = TIMESTAMP.fullmatch(value)
    if match is None:
        raise RuntimeError(f'invalid SRT timestamp from FFmpeg: {value!r}')
    hours, minutes, seconds, millis = map(int, match.groups())
    return hours * 3600 + minutes * 60 + seconds + millis / 1000


def _cues_as_srt(path: Path, stream_index: int | None = None) -> list[list]:
    args = ['ffmpeg', '-nostdin', '-v', 'error', '-i', str(path)]
    if stream_index is not None:
        args += ['-map', f'0:s:{stream_index}']
    args += ['-f', 'srt', '-']
    output = run(*args)
    cues = []
    for block in re.split(r'\r?\n\s*\r?\n', output.strip()):
        if not block:
            continue
        lines = block.splitlines()
        if len(lines) < 3 or not lines[0].isdigit() or ' --> ' not in lines[1]:
            raise RuntimeError(f'{path}: invalid decoded SRT cue: {block!r}')
        start, end = lines[1].split(' --> ', 1)
        text = '\n'.join(lines[2:])
        text = html.unescape(re.sub(r'<[^>]*>|\{[^}]*\}', '', text)).strip()
        cues.append([_seconds(start), _seconds(end), text])
    return cues


def _check_cues(actual: list[list], expected: list[list], label: str) -> None:
    if len(actual) != len(expected):
        raise RuntimeError(f'{label}: expected {len(expected)} cues, got {len(actual)}: {actual}')
    for index, (found, want) in enumerate(zip(actual, expected, strict=True), 1):
        if abs(found[0] - want[0]) > 0.05 or abs(found[1] - want[1]) > 0.05 or found[2] != want[2]:
            raise RuntimeError(f'{label}: cue {index} expected {want!r}, got {found!r}')


def _safe_file(base: Path, relative: str) -> Path:
    path = Path(relative)
    if path.is_absolute() or '..' in path.parts or not path.parts:
        raise RuntimeError(f'unsafe fixture path: {relative!r}')
    return base / path


def load_manifest(manifest_path: Path) -> dict:
    try:
        manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f'{manifest_path}: invalid subtitle manifest: {error}') from error
    if manifest.get('schema_version') != 1:
        raise RuntimeError(f'{manifest_path}: unsupported subtitle manifest schema')
    if (manifest.get('duration_seconds'), manifest.get('width'), manifest.get('height'), manifest.get('fps')) != (10, 640, 360, 24):
        raise RuntimeError(f'{manifest_path}: subtitle timing/video geometry changed unexpectedly')
    sources = {entry['id']: entry for entry in manifest['sources']}
    videos = {entry['id']: entry for entry in manifest['videos']}
    if len(sources) != len(manifest['sources']) or len(videos) != len(manifest['videos']):
        raise RuntimeError(f'{manifest_path}: duplicate source or video ID')
    for entry in manifest['sources']:
        _safe_file(Path('.'), entry['file'])
        if entry['source_type'] != 'subtitle_file' or not re.fullmatch(r'[a-z]{3}', entry['language']):
            raise RuntimeError(f"{entry['id']}: invalid subtitle source type or language")
    for entry in manifest['videos']:
        _safe_file(Path('.'), entry['file'])
        if entry['source_type'] != 'video':
            raise RuntimeError(f"{entry['id']}: invalid video source type")
        for track in entry['tracks']:
            if track['source'] not in sources:
                raise RuntimeError(f"{entry['id']}: unknown source {track['source']}")
            if track['source_type'] != 'embedded':
                raise RuntimeError(f"{entry['id']}: invalid embedded source type")
            if track['language'] != sources[track['source']]['language']:
                raise RuntimeError(f"{entry['id']}: track/source language mismatch")
    for entry in manifest['external']:
        _safe_file(Path('.'), entry['file'])
        if entry['source'] not in sources or entry['video'] not in videos:
            raise RuntimeError(f"{entry['id']}: unknown source or video")
        if entry['source_type'] != 'external':
            raise RuntimeError(f"{entry['id']}: invalid external source type")
    _safe_file(Path('.'), manifest['nearby']['video'])
    for entry in manifest['nearby']['sidecars']:
        _safe_file(Path('.'), entry['file'])
        if entry['source'] not in sources:
            raise RuntimeError(f"{entry['file']}: unknown source")
        if entry['source_type'] != 'nearby':
            raise RuntimeError(f"{entry['file']}: invalid nearby source type")
    switch = manifest['source_switch']
    if len(switch) != 2 or any(video_id not in videos for video_id in switch):
        raise RuntimeError('source_switch must name two known videos')
    if len(videos[switch[0]]['tracks']) == len(videos[switch[1]]['tracks']):
        raise RuntimeError('source_switch videos must have different subtitle counts')
    return manifest


def validate_sources(manifest: dict, source_dir: Path) -> None:
    for entry in manifest['sources']:
        source = _safe_file(source_dir, entry['file'])
        if not source.is_file():
            raise RuntimeError(f'{entry["id"]}: missing subtitle source {source}')
        raw = source.read_text(encoding='utf-8')
        for marker in entry.get('markers', []):
            if marker not in raw:
                raise RuntimeError(f'{entry["id"]}: missing authored marker {marker!r}')
        if entry.get('valid') is False:
            try:
                decoded = _cues_as_srt(source)
            except RuntimeError:
                continue
            if decoded:
                raise RuntimeError(f'{entry["id"]}: malformed source unexpectedly has valid cues')
            continue
        details = probe(source)
        subtitle = [stream for stream in details['streams'] if stream.get('codec_type') == 'subtitle']
        if len(subtitle) != 1 or subtitle[0].get('codec_name') != entry['codec']:
            raise RuntimeError(f'{entry["id"]}: source codec/stream mismatch: {subtitle}')
        _check_cues(_cues_as_srt(source), entry['cues'], entry['id'])


def expected_files(manifest: dict) -> set[str]:
    files = {entry['file'] for entry in manifest['videos']}
    files.update(entry['file'] for entry in manifest['external'])
    files.add(manifest['nearby']['video'])
    files.update(entry['file'] for entry in manifest['nearby']['sidecars'])
    total = len(manifest['videos']) + len(manifest['external']) + 1 + len(manifest['nearby']['sidecars'])
    if len(files) != total:
        raise RuntimeError('subtitle manifest contains duplicate output paths')
    return files


def _track_codec(track: dict) -> str:
    return {'subrip': 'srt', 'ass': 'ass', 'mov_text': 'mov_text'}[track['codec']]


def _generate_video(entry: dict, manifest: dict, sources: dict, source_dir: Path,
                    suite: Path, base: Path) -> None:
    output = _safe_file(suite, entry['file'])
    output.parent.mkdir(parents=True, exist_ok=True)
    if entry['id'] == 'plain':
        run('ffmpeg', '-nostdin', '-hide_banner', '-loglevel', 'error', '-y',
            '-f', 'lavfi', '-i', 'color=c=0x203050:size=640x360:rate=24:duration=10',
            '-map', '0:v:0', '-an', '-c:v', 'mpeg4', '-q:v', '8', '-pix_fmt', 'yuv420p',
            '-r', '24', '-t', '10', str(output))
        return
    if entry.get('burned_text'):
        font = ROOT / manifest['font']['path']
        if not font.is_file():
            raise RuntimeError(f'burned caption font is missing: {font}')
        draw = (f"drawtext=fontfile='{font}':text='{entry['burned_text']}':"
                'fontsize=40:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2:'
                'box=1:boxcolor=black@0.8:boxborderw=10')
        run('ffmpeg', '-nostdin', '-hide_banner', '-loglevel', 'error', '-y',
            '-f', 'lavfi', '-i', 'color=c=0x203050:size=640x360:rate=24:duration=10',
            '-map', '0:v:0', '-an', '-vf', draw, '-c:v', 'mpeg4', '-q:v', '8',
            '-pix_fmt', 'yuv420p', '-r', '24', '-t', '10', str(output))
        return
    args = ['ffmpeg', '-nostdin', '-hide_banner', '-loglevel', 'error', '-y',
            '-i', str(base)]
    for track in entry['tracks']:
        args += ['-i', str(_safe_file(source_dir, sources[track['source']]['file']))]
    args += ['-map', '0:v:0']
    for index, track in enumerate(entry['tracks']):
        args += ['-map', f'{index + 1}:s:0']
    args += ['-an', '-c:v', 'copy']
    for index, track in enumerate(entry['tracks']):
        args += [f'-c:s:{index}', _track_codec(track),
                 f'-metadata:s:s:{index}', f'language={track["language"]}',
                 f'-metadata:s:s:{index}', f'title={track["title"]}',
                 f'-disposition:s:{index}', 'default' if track['default'] else '0']
        if track['codec'] == 'mov_text':
            args += [f'-metadata:s:s:{index}', f'handler_name={track["title"]}']
    if entry.get('font_attachment'):
        font = ROOT / manifest['font']['path']
        if not font.is_file():
            raise RuntimeError(f'font attachment is missing: {font}')
        args += ['-attach', str(font), '-metadata:s:t:0',
                 f'mimetype={manifest["font"]["mime_type"]}',
                 '-metadata:s:t:0', f'filename={manifest["font"]["attachment_name"]}']
    args += ['-t', '10', str(output)]
    run(*args)


def generate_suite(manifest_path: Path, source_dir: Path, directory: Path) -> None:
    require_tools()
    manifest = load_manifest(manifest_path)
    expected_files(manifest)
    validate_sources(manifest, source_dir)
    directory.mkdir(parents=True, exist_ok=True)
    suite = directory / SUITE_DIR
    staging = directory / f'.{SUITE_DIR}.tmp'
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir()
    sources = {entry['id']: entry for entry in manifest['sources']}
    try:
        base = staging / 'plain.mp4'
        for entry in manifest['videos']:
            _generate_video(entry, manifest, sources, source_dir, staging, base)
            validate_video(entry, manifest, sources, staging / entry['file'])
            print(f'generated subtitle video {entry["id"]}', flush=True)
        for entry in manifest['external']:
            target = _safe_file(staging, entry['file'])
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(_safe_file(source_dir, sources[entry['source']]['file']), target)
        nearby = manifest['nearby']
        movie = _safe_file(staging, nearby['video'])
        movie.parent.mkdir(parents=True, exist_ok=True)
        run('ffmpeg', '-nostdin', '-hide_banner', '-loglevel', 'error', '-y',
            '-i', str(base), '-map', '0:v:0', '-an', '-c:v', 'copy', str(movie))
        validate_video({'id': 'nearby', 'file': nearby['video'], 'container': 'matroska,webm', 'tracks': []},
                       manifest, sources, movie)
        for entry in nearby['sidecars']:
            target = _safe_file(staging, entry['file'])
            shutil.copyfile(_safe_file(source_dir, sources[entry['source']]['file']), target)
        index = {
            'manifest_sha256': digest(manifest_path),
            'source_sha256': {entry['file']: digest(_safe_file(source_dir, entry['file']))
                              for entry in manifest['sources']},
            'ffmpeg_version': run('ffmpeg', '-version').splitlines()[0],
            'files': [{'file': relative, 'bytes': _safe_file(staging, relative).stat().st_size,
                       'sha256': digest(_safe_file(staging, relative))}
                      for relative in sorted(expected_files(manifest))],
        }
        (staging / 'index.json').write_text(json.dumps(index, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        if suite.exists():
            shutil.rmtree(suite)
        staging.rename(suite)
    except BaseException:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    print(f'generated {len(expected_files(manifest))} subtitle suite files in {suite}', flush=True)


def _rendered_frame(path: Path) -> bytes:
    try:
        process = subprocess.run(
            ['ffmpeg', '-nostdin', '-v', 'error', '-ss', '1.5', '-i', str(path),
             '-frames:v', '1', '-vf', 'crop=320:100:160:130,format=gray',
             '-f', 'rawvideo', '-'], capture_output=True, check=False)
    except FileNotFoundError as error:
        raise RuntimeError('ffmpeg is missing; install FFmpeg') from error
    if process.returncode or len(process.stdout) != 320 * 100:
        raise RuntimeError(f'{path}: cannot decode burned caption region: {process.stderr.decode(errors="replace")[-1000:]}')
    return process.stdout


def validate_video(entry: dict, manifest: dict, sources: dict, path: Path) -> None:
    details = probe(path)
    streams = details['streams']
    videos = [stream for stream in streams if stream.get('codec_type') == 'video']
    subtitles = [stream for stream in streams if stream.get('codec_type') == 'subtitle']
    attachments = [stream for stream in streams if stream.get('codec_type') == 'attachment']
    unexpected = [stream for stream in streams if stream.get('codec_type') not in
                  ('video', 'subtitle', 'attachment')]
    if unexpected:
        raise RuntimeError(f'{entry["id"]}: unexpected streams: {unexpected}')
    if len(videos) != 1 or videos[0].get('codec_name') != 'mpeg4':
        raise RuntimeError(f'{entry["id"]}: expected one MPEG-4 video stream, got {videos}')
    video = videos[0]
    if (video.get('width'), video.get('height'), video.get('pix_fmt')) != (640, 360, 'yuv420p'):
        raise RuntimeError(f'{entry["id"]}: wrong video geometry/pixel format: {video}')
    if video.get('avg_frame_rate') != '24/1':
        raise RuntimeError(f'{entry["id"]}: wrong frame rate: {video.get("avg_frame_rate")}')
    if not set(entry['container'].split(',')) & set(details['format']['format_name'].split(',')):
        raise RuntimeError(f'{entry["id"]}: wrong container {details["format"]["format_name"]}')
    duration = float(details['format']['duration'])
    if abs(duration - manifest['duration_seconds']) > 0.15:
        raise RuntimeError(f'{entry["id"]}: wrong duration {duration}')
    expected = entry['tracks']
    if len(subtitles) != len(expected):
        raise RuntimeError(f'{entry["id"]}: expected {len(expected)} subtitle streams, got {len(subtitles)}')
    for index, (stream, track) in enumerate(zip(subtitles, expected, strict=True)):
        tags = stream.get('tags', {})
        if stream.get('codec_name') != track['codec']:
            raise RuntimeError(f'{entry["id"]}: subtitle {index} codec {stream.get("codec_name")} != {track["codec"]}')
        actual_title = tags.get('handler_name') if track['codec'] == 'mov_text' else tags.get('title')
        if tags.get('language') != track['language'] or actual_title != track['title']:
            raise RuntimeError(f'{entry["id"]}: subtitle {index} language/title mismatch: {tags}')
        if stream.get('disposition', {}).get('default') != track['default']:
            raise RuntimeError(f'{entry["id"]}: subtitle {index} default disposition mismatch')
        _check_cues(_cues_as_srt(path, index), sources[track['source']]['cues'],
                    f'{entry["id"]} subtitle {index}')
        if track['codec'] == 'ass':
            authored = run('ffmpeg', '-nostdin', '-v', 'error', '-i', str(path),
                           '-map', f'0:s:{index}', '-f', 'ass', '-')
            for marker in sources[track['source']].get('markers', []):
                if marker not in authored:
                    raise RuntimeError(f'{entry["id"]} subtitle {index}: '
                                       f'authored ASS marker {marker!r} was lost')
    if entry.get('font_attachment'):
        font = manifest['font']
        if len(attachments) != 1:
            raise RuntimeError(f'{entry["id"]}: expected one font attachment, got {len(attachments)}')
        tags = attachments[0].get('tags', {})
        if tags.get('mimetype') != font['mime_type'] or tags.get('filename') != font['attachment_name']:
            raise RuntimeError(f'{entry["id"]}: font attachment MIME/name mismatch: {tags}')
    elif attachments:
        raise RuntimeError(f'{entry["id"]}: unexpected attachment streams: {attachments}')
    run('ffmpeg', '-nostdin', '-v', 'error', '-xerror', '-i', str(path), '-f', 'null', '-')


def verify_suite(manifest_path: Path, source_dir: Path, directory: Path) -> None:
    require_tools()
    manifest = load_manifest(manifest_path)
    validate_sources(manifest, source_dir)
    suite = directory / SUITE_DIR
    try:
        index = json.loads((suite / 'index.json').read_text(encoding='utf-8'))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f'{suite}: missing or invalid index.json: {error}') from error
    if index.get('manifest_sha256') != digest(manifest_path):
        raise RuntimeError('subtitle suite manifest checksum changed')
    for entry in manifest['sources']:
        if index.get('source_sha256', {}).get(entry['file']) != digest(_safe_file(source_dir, entry['file'])):
            raise RuntimeError(f'{entry["id"]}: subtitle source changed since generation')
    wanted = expected_files(manifest)
    indexed = {row['file']: row for row in index.get('files', [])}
    if len(indexed) != len(index.get('files', [])) or set(indexed) != wanted:
        raise RuntimeError(f'subtitle suite index inventory mismatch: {set(indexed) ^ wanted}')
    present = {str(path.relative_to(suite)) for path in suite.rglob('*') if path.is_file()} - {'index.json'}
    if present != wanted:
        raise RuntimeError(f'subtitle suite file inventory mismatch: {present ^ wanted}')
    sources = {entry['id']: entry for entry in manifest['sources']}
    videos = {entry['id']: entry for entry in manifest['videos']}
    for relative in sorted(wanted):
        path = _safe_file(suite, relative)
        row = indexed[relative]
        if row['bytes'] != path.stat().st_size or row['sha256'] != digest(path):
            raise RuntimeError(f'{relative}: size or SHA-256 differs from generated index')
    for entry in manifest['videos']:
        validate_video(entry, manifest, sources, _safe_file(suite, entry['file']))
        print(f'PASS subtitle video {entry["id"]}', flush=True)
    nearby = manifest['nearby']
    validate_video({'id': 'nearby', 'file': nearby['video'], 'container': 'matroska,webm', 'tracks': []},
                   manifest, sources, _safe_file(suite, nearby['video']))
    print('PASS subtitle nearby movie', flush=True)
    for entry in manifest['external']:
        source = sources[entry['source']]
        target = _safe_file(suite, entry['file'])
        if target.read_bytes() != _safe_file(source_dir, source['file']).read_bytes():
            raise RuntimeError(f'{entry["id"]}: external copy differs from source')
        print(f'PASS subtitle {entry["id"]}', flush=True)
    for entry in nearby['sidecars']:
        source = sources[entry['source']]
        if _safe_file(suite, entry['file']).read_bytes() != _safe_file(source_dir, source['file']).read_bytes():
            raise RuntimeError(f'{entry["file"]}: nearby sidecar differs from source')
        print(f'PASS subtitle sidecar {entry["match"]}', flush=True)
    plain = _rendered_frame(_safe_file(suite, videos['plain']['file']))
    burned = _rendered_frame(_safe_file(suite, videos['burned']['file']))
    changed = sum(a != b for a, b in zip(plain, burned, strict=True))
    if changed < 1000:
        raise RuntimeError(f'burned caption: only {changed} pixels differ from plain background')
    print(f'verified {len(wanted)} subtitle suite files; burned caption region differs at {changed} pixels')
