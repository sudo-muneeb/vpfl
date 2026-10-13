# Native subtitle verification (Part 3)

This opt-in check exercises the generated Part 2 media below VPFL's Flutter
UI. It starts a fresh standalone mpv process for each case, then uses the
repository's pinned `media_kit` in a separate Dart process. It changes no
playback code or fixture definitions. The scripts live in `scripts/ci/`; all
PNG captures, native logs, JSON results, and the comparison report go under
ignored `build/ci-native-subtitles/`.

From the repository root on Linux with FFmpeg, FFprobe, mpv, Dart, libmpv,
libass, and fontconfig installed:

```bash
python3 scripts/ci/generate_fixtures.py --out build/ci-video-fixtures --subtitle-suite
python3 scripts/ci/verify_fixtures.py --dir build/ci-video-fixtures --subtitle-suite
python3 -m unittest discover -s test/ci -p 'test_*.py' -v
python3 scripts/ci/run_native_subtitle_checks.py \
  --fixtures build/ci-video-fixtures --out build/ci-native-subtitles
```

The final command reruns the subtitle fixture verifier before native checks.
It writes `comparison.json`, `report.md`, `versions.json`, per-engine result
JSON, logs, subtitle-inclusive PNGs, video-only PNG controls, and difference
PNGs. A failed case keeps its images and native log; the command exits nonzero.
The media_kit run has a 10-minute process limit, while individual operations
and IPC events have shorter limits. Missing native tools fail explicitly.

Standalone mpv uses `--no-config`, private XDG directories, a unique private
Unix IPC socket per process, `vo=null`, `ao=null`, and `hwdec=no`. The IPC
reader separates asynchronous events from replies using request IDs. File
loads wait for `file-loaded` and `playback-restart`; exact seeks wait for a
new `playback-restart`. mpv's documented `screenshot-to-file` command captures
`subtitles` and `video` at the same paused frame. The test checks real
`track-list`, `sid`, `sub-text`, native properties, cue intervals, and image
pixels. It tests automatic sidecar matching and explicit `sub-add` separately.

The Dart harness uses `PlayerConfiguration(libass: true, vo: 'null')`,
`Player.state`/streams, `setSubtitleTrack`, `NativePlayer` properties, and
`Player.screenshot(includeLibassSubtitles: true/false)`. In the pinned
media_kit version, a player without a Flutter `VideoController` starts with
`vid=no`; the harness sets `vid=auto` solely to enable native video decoding.
It waits for media and track readiness, then polls screenshots within a
bounded interval after seeks because `sub-text` can update before the new
rendered frame. Python validates the Dart PNGs independently.

Image decoding uses the repository's FFmpeg dependency, with no new runtime
package. A cue must change at least 120 pixels from its video-only control;
an empty cue interval permits at most 20 changed pixels. Ordinary captions
must change at least 80 pixels in the lower third. Authored ASS checks
separate top/middle/bottom regions, red/blue/green foreground pixels, and
dark outline pixels. Timed `\\move` and `\\t` checks compare frames within
the same cue. The thresholds tolerate font rasterization differences while
failing when a caption is missing or persists into a gap. The script saves
per-case metrics, bounding boxes, and source images for inspection.

`vo=null` still permits mpv/libass screenshots on the tested host, so no
desktop display is required for this native path. This does **not** validate
the final VPFL Flutter texture or compositor; later project parts must do
that. Urdu, Arabic, and Japanese text values and visible pixels are checked,
but correct joining, direction, and individual glyph shapes need manual
review of the saved PNGs. An embedded font attachment is checked through
FFprobe metadata, native attachment/font-selection logs, and rendered pixels;
font selection in the installed system can differ elsewhere. The host's
standalone mpv executable and media_kit-loaded libmpv paths are recorded
separately in the generated results.

The new native suite is kept separate from ordinary `flutter test` and the
required PR jobs because it depends on host mpv, libass, and font resources.
The existing fixture generation job still runs in CI. See the
[observed Part 3 results](../compatibility/native-subtitle-verification.md)
for this host's evidence and limits.
