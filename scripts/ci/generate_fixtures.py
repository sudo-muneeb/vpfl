#!/usr/bin/env python3
"""Generate the checked-in VPFL media matrix with FFmpeg for CI tests."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import sys


def call(cmd):
    proc = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise RuntimeError(f"command failed: {cmd!r}\n{proc.stderr[-3000:]}")
    return proc.stdout


def sha256(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for buf in iter(lambda: f.read(1024 * 1024), b''):
            h.update(buf)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--manifest', type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[2] / 'ci/media-matrix.json')
    ap.add_argument('--out', type=pathlib.Path, required=True)
    ap.add_argument('--only', help='comma-separated IDs for initial validation; omit for full every-PR matrix')
    args = ap.parse_args()
    m = json.loads(args.manifest.read_text())
    args.out.mkdir(parents=True, exist_ok=True)
    selected = set(args.only.split(',')) if args.only else None
    unknown = (selected or set()) - {f['id'] for t in ['fixtures','subtitle_fixtures','embedded_subtitle_fixtures'] for f in m.get(t, [])}
    if unknown: raise ValueError(f'unknown fixture IDs: {sorted(unknown)}')
    summary = {'ffmpeg_version': call(['ffmpeg','-version']).splitlines()[0], 'manifest_sha256': sha256(args.manifest), 'fixtures': []}
    for f in m['fixtures']:
        if selected is not None and f['id'] not in selected: continue
        output = args.out / (f['id'] + '.' + f['extension'])
        video_filter = f"testsrc2=size={m['width']}x{m['height']}:rate={m['fps']}:duration={m['duration_seconds']}"
        cmd = ['ffmpeg','-nostdin','-hide_banner','-loglevel','error','-y',
               '-f','lavfi','-i',video_filter,
               '-f','lavfi','-i',f"sine=frequency=880:sample_rate=48000:duration={m['duration_seconds']}",
               '-map','0:v:0','-map','1:a:0','-t',str(m['duration_seconds']),
               '-c:v',f['video_encoder'],'-pix_fmt',f['pix_fmt'],
               *f.get('video_args',[]),'-vf','drawbox=x=0:y=0:w=48:h=48:color=red:t=fill,drawbox=x=272:y=0:w=48:h=48:color=green:t=fill,drawbox=x=0:y=132:w=48:h=48:color=blue:t=fill','-c:a',f['audio_encoder'],
               '-threads','2','-f',f['format'],str(output)]
        print('generating',f['id'],flush=True)
        call(cmd)
        probe=json.loads(call(['ffprobe','-v','error','-show_entries','stream=codec_type,codec_name,width,height,pix_fmt:format=duration,format_name', '-of','json',str(output)]))
        v=next((x for x in probe['streams'] if x['codec_type']=='video'),None)
        a=next((x for x in probe['streams'] if x['codec_type']=='audio'),None)
        if not v or v['codec_name']!=f['codec']: raise RuntimeError(f"{f['id']}: wrong video codec: {v}")
        if not a or a['codec_name']!=f['audio_codec']: raise RuntimeError(f"{f['id']}: wrong audio codec: {a}")
        if v.get('pix_fmt') != f['pix_fmt']:
            raise RuntimeError(f"{f['id']}: expected pixel format {f['pix_fmt']}, got {v.get('pix_fmt')}")
        if (v.get('width'),v.get('height'))!=(m['width'],m['height']): raise RuntimeError(f"{f['id']}: unexpected resolution")
        duration=float(probe['format']['duration'])
        if not (m['duration_seconds']-0.6 < duration < m['duration_seconds']+0.6): raise RuntimeError(f'{f["id"]}: unexpected duration {duration}')
        call(['ffmpeg','-nostdin','-v','error','-xerror','-i',str(output),'-f','null','-'])
        summary['fixtures'].append({'id':f['id'],'file':output.name,'sha256':sha256(output),'bytes':output.stat().st_size,'streams':probe['streams'],'duration':duration})
    texts = {
      'srt': '1\n00:00:00,200 --> 00:00:02,200\nVPFL subtitle test\n',
      'vtt': 'WEBVTT\n\n00:00:00.200 --> 00:00:02.200\nVPFL subtitle test\n',
      'ass': '[Script Info]\nTitle: VPFL test\nScriptType: v4.00+\n[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\nStyle: Default,Arial,24,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,1,0,2,10,10,10,1\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\nDialogue: 0,0:00:00.20,0:00:02.20,Default,,0,0,0,,VPFL subtitle test\n',
      'ssa': '[Script Info]\nTitle: VPFL test\nScriptType: v4.00\n[V4 Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, TertiaryColour, BackColour, Bold, Italic, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, AlphaLevel, Encoding\nStyle: Default,Arial,24,16777215,16777215,0,0,0,0,1,1,0,2,10,10,10,0,0\n[Events]\nFormat: Marked, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\nDialogue: Marked=0,0:00:00.20,0:00:02.20,Default,,0000,0000,0000,,VPFL subtitle test\n',
    }
    for f in m.get('subtitle_fixtures', []):
        if selected is not None and f['id'] not in selected: continue
        output = args.out / (f['id'] + '.' + f['extension'])
        output.write_text(texts[f['extension']],encoding='utf-8')
        summary['fixtures'].append({'id':f['id'],'file':output.name,'sha256':sha256(output),'bytes':output.stat().st_size,'type':'subtitle'})
    for f in m.get('embedded_subtitle_fixtures', []):
        if selected is not None and f['id'] not in selected: continue
        src = next(x for x in m['fixtures'] if x['id']==f['source'])
        srcpath = args.out / (src['id']+'.'+src['extension'])
        sub = next(x for x in m['subtitle_fixtures'] if x['id']==f['subtitle'])
        subpath = args.out / (sub['id']+'.'+sub['extension'])
        if not srcpath.is_file() or not subpath.is_file():
            raise RuntimeError(f"{f['id']}: prerequisite files are absent: {srcpath.name}, {subpath.name}; generate full suite")
        output = args.out / (f['id']+'.'+f['extension'])
        call(['ffmpeg','-nostdin','-hide_banner','-loglevel','error','-y','-i',str(srcpath),'-i',str(subpath),'-map','0','-map','1:0','-c','copy','-c:s','srt',str(output)])
        probe=json.loads(call(['ffprobe','-v','error','-show_entries','stream=codec_type,codec_name','-of','json',str(output)]))
        if not any(s['codec_type']=='subtitle' and s['codec_name']==f['subtitle_codec'] for s in probe['streams']):
            raise RuntimeError(f"{f['id']}: embedded subtitle missing")
        call(['ffmpeg','-nostdin','-v','error','-xerror','-i',str(output),'-f','null','-'])
        summary['fixtures'].append({'id':f['id'],'file':output.name,'sha256':sha256(output),'bytes':output.stat().st_size,'streams':probe['streams']})
    if not summary['fixtures']: raise RuntimeError('fixture selection generated no files')
    expected = sum(len(m.get(group, [])) for group in ('fixtures', 'subtitle_fixtures', 'embedded_subtitle_fixtures'))
    if selected is None and len(summary['fixtures']) != expected:
        raise RuntimeError(f"generated {len(summary['fixtures'])}/{expected} fixtures")
    (args.out / 'index.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('generated', len(summary['fixtures']), 'fixtures, total bytes', sum(x['bytes'] for x in summary['fixtures']))


if __name__ == '__main__':
    try: main()
    except Exception as e:
        print(f'FAILED: {e}', file=sys.stderr)
        sys.exit(1)
