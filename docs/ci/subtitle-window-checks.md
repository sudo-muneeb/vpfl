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
