# VPFL subtitle window checks

The Linux graphical test starts the real VPFL executable through Flutter's
integration runner. It mounts the production `PlayerScreen`, opens generated
media, uses the CC menu and timing dialog, and captures X11 root-window pixels
with FFmpeg. It locates the VPFL X11 window by process ID and crops to the
actual Flutter `Texture` bounds. This capture crosses media_kit, libmpv,
libass, the Linux video texture, Flutter, GTK, and X11. The native comparison
in [Part 3](native-subtitle-verification.md) remains a separate check.

Run from the repository root with Flutter, FFmpeg, Xvfb, `xdotool`, `wmctrl`,
and Metacity or Openbox installed:

```bash
python3 scripts/ci/generate_fixtures.py --out build/ci-video-fixtures --subtitle-suite
python3 scripts/ci/verify_fixtures.py --dir build/ci-video-fixtures --subtitle-suite
bash scripts/ci/run_display.sh x11 bash scripts/ci/run_subtitle_window.sh \
  flutter test integration_test/subtitle_window_linux_test.dart -d linux \
  --dart-define=VPFL_SUBTITLE_FIXTURES="$PWD/build/ci-video-fixtures" \
  --plain-name='VPFL X11 window renders subtitle fixtures through the player UI' \
  --reporter expanded
bash scripts/ci/run_display.sh x11 bash scripts/ci/run_subtitle_window.sh \
  flutter test integration_test/subtitle_window_linux_test.dart -d linux \
  --dart-define=VPFL_SUBTITLE_FIXTURES="$PWD/build/ci-video-fixtures" \
  --plain-name='Home and reopen restore visible subtitles in VPFL window' \
  --reporter expanded
bash scripts/ci/run_display.sh x11 bash scripts/ci/run_subtitle_window.sh \
  flutter test integration_test/subtitle_window_linux_test.dart -d linux \
  --dart-define=VPFL_SUBTITLE_FIXTURES="$PWD/build/ci-video-fixtures" \
  --plain-name='Attached ASS stays sharp at native, resized, and fullscreen sizes' \
  --reporter expanded
VPFL_TEST_FAIL_GPU_INIT=1 bash scripts/ci/run_display.sh x11 \
  bash scripts/ci/run_subtitle_window.sh \
  flutter test integration_test/subtitle_window_linux_test.dart -d linux \
  --dart-define=VPFL_SUBTITLE_FIXTURES="$PWD/build/ci-video-fixtures" \
  --plain-name='Attached ASS stays sharp at native, resized, and fullscreen sizes' \
  --reporter expanded
```

For the stopped-resize regression, run both VPFL rendering paths explicitly:

```bash
for software in 0 1; do
  VPFL_TEST_FAIL_GPU_INIT="$software" bash scripts/ci/run_display.sh x11 \
    bash scripts/ci/run_subtitle_window.sh \
    flutter test integration_test/subtitle_window_linux_test.dart -d linux \
    --dart-define=VPFL_SUBTITLE_FIXTURES="$PWD/build/ci-video-fixtures" \
    --dart-define=VPFL_REFERENCE_VO=x11 \
    --plain-name='ASS recovers after repeated Linux window resizes' \
    --reporter expanded
done
```

The test pauses on manifest cue times and saves paired CC On/Off PNGs under
ignored `build/ci-logs/subtitle-window/<app-pid>/`. Each app process has its
own capture directory. `check_subtitle_window.py` compares the same video
texture region at the same native position. A caption requires
at least 120 changed pixels, including 80 in the expected third of the
texture; a cue gap permits at most 20. A permanently burned caption must
remain visible after CC Off. The check rejects a black texture, long red or
pale playback progress lines, and changes in the surrounding window UI. A
plain-video capture must also have no bright caption pixels. Captures are
checked before comparison, with bounded retries if controls are
still visible. It writes JSON metrics for every comparison and a difference
PNG if an assertion fails. The test also checks native track counts and
selected state, including after returning Home and reopening through the
real app shell; those properties cannot replace window pixels. Each case
starts a fresh Linux runner and X11 display to isolate native resources.

The sharpness test pauses `attached_ass.mkv` at 1.5 seconds and captures native
mpv, media_kit's native screenshot, and paired CC On/Off VPFL X11 screenshots.
The source-sized mpv and media_kit screenshots must have identical pixels.
The graphical job runs this comparison with GPU output and injected GPU
initialization failure to verify software fallback too.
It checks the actual video surface at the default window size, a smaller
window, exactly 640×360 video pixels inside the minimum-sized GTK window, an
1124×632 comparison surface, an arbitrary resized window, fullscreen, and the
return from fullscreen. Xvfb provides a device pixel ratio of 1. The checker
renders the native reference at each displayed video size, subtracts the
matching CC Off image, and compares caption bounds and edge variance with the
VPFL window. The final
window must retain at least 85% of native edge variance and caption-mask
overlap. The authored red, blue, and green cues require at least 95% mask
overlap to detect changed glyph shapes even when caption bounds still match.
A visible but blurred or malformed subtitle fails these checks; screenshots
alone do not count as an assertion. The PNGs and JSON metrics are under ignored
`build/ci-logs/subtitle-sharpness/<app-pid>/`.

After those seven comparisons, the test disables subtitles and checks actual
window pixels for all three existing video fit modes. The visible image must
fill its intended surface; this rejects an extra mpv letterbox inside Stretch.
Crop captures are intersected with the visible Video widget bounds, since
their full Texture intentionally extends outside the clipped viewport.

The Linux player requests an mpv output texture sized to the displayed video
surface, in physical pixels. This lets libass rasterize glyphs at their final
size instead of having Flutter enlarge source-resolution text. The video
widget uses nearest texture sampling because `FilterQuality.low` blurred
glyphs at a fractional centered position even when output dimensions matched.
The player centers the video on physical pixel boundaries through the public
`VideoState.update(alignment: ...)` API. Odd letterbox sizes can otherwise
leave an already settled texture at a half-pixel origin, where nearest sampling
changes glyph edges. The previous automatic nearest/linear switching in the
vendored widget was removed after the placement experiment isolated this cause.
Temporary interpolation during a drag is acceptable; the required result is
correct rendering after the window stops. The [resize recovery investigation](../compatibility/subtitle-resize-recovery.md)
records the controlled experiments and comparisons against mpv's RGB window
output. The recovery test checks early and later stopped frames, GTK pointer
resize release, and a forced redraw at the same final size.
The local `media_kit_video` patch also refreshes the texture on paused size
changes.
Crop and Stretch native textures preserve the source aspect ratio at the
larger required scale. Flutter then applies the existing crop/stretch fit;
requesting an off-aspect native texture would cause mpv to letterbox it first.
Software output remains bounded by its existing 1920×1080 buffer; screens
larger than that need separate validation. X11 results do not establish
sharpness under a Wayland compositor or fractional display scaling.
The headless reference uses full chroma planes to avoid subsampling colored
glyphs and to support odd dimensions. The recovery test instead reads mpv's
actual RGB window output at matching viewport dimensions. Its separate
source-sized media_kit comparison retains the original video pixel format.
The recovery gate requires at least 99% silhouette overlap after at most one
pixel of registration for capture rounding, as well as the 85% edge-variance
gate. It checks all three original authored cues and eleven controlled cases
on both VPFL rendering paths. CI explicitly uses mpv's full-chroma X11 VO as
its reference because the local llvmpipe GPU VO intermittently draws a black
video plane under Xvfb. On a physical GPU display, omit
`VPFL_REFERENCE_VO=x11` to compare against mpv's GPU VO. This setting affects
only the diagnostic reference, not VPFL's renderer.

The original 1124×632 VPFL window capture had a caption edge-variance ratio
of 0.407 against native mpv. At that point the texture was still 640×360,
and Flutter enlarged the already-rasterized glyphs. At 640×360, native mpv
and media_kit screenshot pixels were identical. After sizing the native
output to the display surface, the default-window ratio rose to 0.824 with
linear texture sampling and 1.076 with nearest sampling. That earlier sizing
change produced a ratio of 0.950 at the original 1124×632 surface. The
graphical regression checks that size and the other window modes against a
0.85 minimum ratio; the newer stopped-resize results are recorded in the
resize recovery investigation linked above.

The packaged application smoke uses the installed `/usr/bin/vpfl` and the
same generated suite. It captures the X11 screen while playing authored ASS
and a video with an automatically discovered external SRT. A detector checks
the expected red/top, blue/middle, green/bottom, or white/bottom caption pixels
inside the blue fixture video surface and rejects visible transport controls
or authored ASS pixels cut off at the right video edge. The package runner
uses a 1280×1024 X11 screen; the authored positioning fixture can be clipped
by font substitution on a 640×480 screen.
Successful PNGs, raw RGB captures, metrics, and app logs are saved under
`build/ci-logs/installed-subtitles/`. This detector is a smoke test; the
paired CC On/Off graphical integration test gives stronger attribution.

The dedicated `ci / graphical-subtitles (ubuntu-x11)` job runs both native
mpv/media_kit comparisons and final-window checks with Noto fonts. The DEB,
RPM, and Arch package-install jobs run the installed subtitle smoke after
their existing video and package checks. These jobs need a working software
GL stack as well as libmpv and libass. An absent display, renderer, FFmpeg,
window manager, or required font causes an explicit failure.

X11 screenshots do not prove Wayland composition. The existing Wayland and
XWayland matrix checks verify playback/backend selection, but not final
subtitle pixels. Urdu, Arabic, and mixed RTL/LTR screenshots are retained for
human review of joining, ordering, numerals, punctuation, and missing glyphs;
pixel presence alone cannot establish correct shaping.
