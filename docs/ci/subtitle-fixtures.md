# Subtitle fixture suite

The subtitle suite extends the existing FFmpeg generator and verifier. The
31-case `ci/media-matrix.json` and its native playback test keep their current
contract. `test/fixtures/subtitles/subtitle-matrix.json` describes additional
media, and `test/fixtures/subtitles/sources/` contains the small, reviewed
text sources. Generated media goes to the ignored
`build/ci-video-fixtures/subtitle-suite/` directory.
No network download or generated binary is needed in the checkout.

From the repository root, with FFmpeg and FFprobe installed:

```bash
python3 -m unittest discover -s test/ci -p 'test_*.py' -v
python3 scripts/ci/generate_fixtures.py --out build/ci-video-fixtures --subtitle-suite
python3 scripts/ci/verify_fixtures.py --dir build/ci-video-fixtures --subtitle-suite
```

The last two commands generate and verify the original matrix and the subtitle
suite together. Repeating generation replaces the suite directory, removing
obsolete outputs. A failed subtitle generation reports the FFmpeg/FFprobe
command and retains the previous completed suite. The suite's `index.json`
records the manifest hash, source hashes, generated inventory, and output
hashes; output bytes need not match across FFmpeg versions.

All eight main videos are 10 seconds, 640×360, 24 fps, with a fixed color
background and explicit video/subtitle stream maps. They cover no subtitles,
embedded SRT, embedded ASS, MP4 `mov_text`, three distinct English/Urdu/Japanese
streams, authored ASS styles, an ASS stream with an attached font, and
permanently burned text. A ninth plain video sits beside an exactly named SRT,
a language-suffixed Urdu SRT, and an unrelated SRT. External copies cover SRT,
VTT, ASS, ASS motion/color effects, an unavailable font, mixed RTL/LTR text,
overlap and gaps, and malformed SRT. The `plain` and `multilingual` pair has
zero and three subtitle tracks for source-switch tests.

Five additional ASS sidecars support resize recovery experiments. The red,
blue, green, and white sources use the same `AUTHORED BLUE` text, 30-point Noto
Sans Display font, position (160,170), outline 3, shadow 1, alignment 2, timing,
and opaque alpha; only their primary foreground color differs. The variants
source changes position, outline, font size, text, overlapping events, and
motion independently, and includes the original red event recolored blue.
`resize_experiments` records the paused cue times and expected regions. These
files bring the generated suite inventory to 25 files without changing the
original media matrix or the existing subtitle sources.

Normal sources have cues at 1.0–2.5, 4.0–5.5, and 6.0–7.5 seconds; the first
0.8 seconds and the spaces between cues are intentionally blank. The overlap
source has cues at 1.0–3.0 and 2.0–4.0 seconds, then two cues after gaps.
The manifest records exact text, cue intervals, source codec and language,
output source type, track codec, title, default disposition, and attachment
metadata. Every embedded stream has identifiable caption text.

Generation probes and decodes each video immediately. Independent verification
checks the file inventory and hashes, container, one MPEG-4 video stream,
resolution, frame rate, pixel format, duration, subtitle count and codecs,
track language/title/default flags, font attachment MIME/name, and decoded
cue text and times. It checks ASS style/effect markers after muxing and compares
decoded burned-caption pixels with the plain video's pixels. Source files are
probed and converted to SRT separately to verify cue text and timing. The
malformed SRT must fail cue decoding or yield no cues. These checks establish
fixture properties; they do not assert how VPFL, mpv, or libass displays or
selects subtitles. Native rendering assertions belong in later project parts.

The attached and burned-caption font is the repository's existing
`assets/fonts/NotoSansDisplay-Regular.ttf`, licensed under SIL Open Font
License 1.1; see `assets/fonts/NOTO-COPYRIGHT`. No font is downloaded.
`missing_font.ass` deliberately names a nonexistent face. If a local FFmpeg
build cannot encode `mov_text`, mux the font attachment, or run `drawtext`, the
generator fails with that command's stderr rather than dropping the fixture.
