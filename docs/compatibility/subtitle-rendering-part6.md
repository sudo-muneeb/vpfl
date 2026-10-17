# Subtitle rendering in the VPFL Linux window (Part 6)

Tested on 17 October 2026 from `audit/subtitle-baseline` at base revision
`1c7a1bc`, with the unstaged Part 6 test and CI changes described here.
The [window test guide](../ci/subtitle-window-checks.md) gives reproduction
commands and artifact locations. This report covers final GTK/X11 pixels;
[Part 3](native-subtitle-verification.md) covers mpv and media_kit's native
frames, and [Parts 4](subtitle-integration-part4.md) and
[5](subtitle-settings-part5.md) cover service state and timing.

## Rendering boundary and environment

VPFL's `PlayerScreen` and CC controls select tracks through `PlaybackService`.
The pinned `media_kit` 1.2.6 uses host libmpv, which uses libass for styled
subtitles. VPFL's path override of `media_kit_video` 2.0.1 presents the
native output as a Flutter texture in the GTK window. No production playback
engine or vendored package source was changed in Part 6. The targeted
`PlayerScreen` fullscreen context correction is described below.

This host uses Flutter 3.47.5, Dart 3.13.4, Ubuntu libmpv
`0.37.0-1ubuntu4`, libass `1:0.17.1-2build1`, fontconfig 2.15.0,
HarfBuzz 8.3.0, and FriBidi 1.0.13. The lockfile also pins
`media_kit_libs_linux` 1.2.1 and `media_kit_libs_video` 1.0.7. The app test
used a private Xvfb display with Metacity; video output logged GPU mode.
The host packages, fonts, and compositor are not pinned by `pubspec.lock`.

## Evidence boundaries

The graphical integration test runs the actual VPFL Linux executable with
production `PlayerScreen`, `PlaybackService`, CC menu, timing dialog, native
video texture, and an isolated in-memory database. FFmpeg `x11grab` captures
the X11 root window. The test identifies VPFL's window by process ID and
derives the crop from Flutter's `Texture` bounds. It compares CC On and Off
captures at the same native paused position. These captures establish final
application output through GTK/X11, unlike `Player.screenshot()`.

The pixel check requires a lit video texture, a visible caption difference
in the expected screen region, stable surrounding UI, and hidden playback
controls. ASS checks also constrain authored red, blue, and green foreground,
dark outlines, position, and timed movement. Cue gaps require no difference.
The burned-caption control requires caption pixels to remain when CC is Off.
The pixel tests include deliberately missing captions and black textures, so
those failures cannot pass as a successful comparison.

The final X11 run passed in 17 minutes 28 seconds. It saved 91 PNG captures
and 44 comparison-metric JSON files under
`build/ci-logs/subtitle-window/119569/`; the runner log is
`build/ci-logs/subtitle-window/test-main-production-fix.log`. Representative
same-frame differences were 7,182 pixels for embedded SRT and 6,167 for the
automatically selected nearby SRT. The authored ASS top, middle, and bottom
cues had 3,884 red, 4,143 blue, and 4,689 green pixels in their respective
regions, each with visible dark outlines. The `\move` bounding box shifted
from `[100,404,342,445]` to `[694,121,936,163]`; the `\t` color cue gained
3,287 red pixels. The overlap cue changed 8,593 pixels, while its deliberate
gap changed zero. Burned captions remained with CC Off (7,784 bright caption
pixels), and the plain video had no caption pixels. Fullscreen and resized
window captions changed 8,008 and 5,889 pixels respectively. These window
metrics are not compared pixel for pixel against native mpv captures, whose
size and presentation path differ; they check the same authored properties.

Screenshots and JSON metrics are under ignored
`build/ci-logs/subtitle-window/`; failure difference PNGs are retained.
Native comparison artifacts are under `build/ci-native-subtitles-part6/`.
These are generated results, not committed goldens.

The 20-file subtitle suite exercises embedded SRT/ASS/MP4 `mov_text`,
English/Urdu/Japanese selection, no-subtitle and burned-caption video,
automatic exact and language-suffixed sidecars, explicit SRT/VTT/ASS,
authored ASS layout and `\move`/`\t` effects, an MKV font attachment,
missing-font fallback, Unicode, overlap/gap cues, and malformed/missing
external paths. The visual test checks selected-track state and native track
count alongside window pixels, including reuse after repeated external loads
and recovery after errors. Its Home case uses `VpflApp`, not only a standalone
player widget.

## Fullscreen teardown defect

Two pre-fix graphical runs reached the final resized-window pixel comparison,
then failed while the player was detached. Flutter reported an unsafe ancestor
lookup from `FullscreenInheritedWidget.maybeOf` through
`VideoState.isFullscreen()` in `PlayerScreen`'s controls callback. The callback
was evaluating fullscreen state from media_kit_video's retained context while
that video subtree was deactivating. VPFL now resolves fullscreen inside a
`Builder` using the controls widget's active context. The same window test is
the regression check for teardown after fullscreen and resizing. This fix
changes only the context used for the fullscreen query; it does not alter
subtitle selection or rendering.

## Application behavior observed

- Embedded SRT, ASS, MP4 `mov_text`, and three multilingual selections each
  produced a visible CC On/Off difference. Rapid English/Urdu/Japanese
  selection changed the window pixels. Exact and language-suffixed sidecars
  appeared automatically; Auto displayed the nearby cue. Explicit SRT, VTT,
  and ASS loads appeared in the window. Repeating a discovered or loaded file
  kept its native track count; switching embedded and external tracks changed
  the displayed caption. Malformed and missing paths displayed an error,
  retained video playback, and allowed a later valid load.
- Authored ASS color, outline, placement, and timed movement survived the
  Flutter texture. The attached-font MKV and missing-font fallback both
  rendered captions. Urdu, Arabic, and mixed RTL/LTR cues produced visible
  glyph pixels; their saved screenshots show no obvious missing-glyph boxes
  on this host, but semantic shaping remains a manual review item.
- The timing popup showed signed 100 ms steps, repeated adjustments, reset,
  and the +5000 ms boundary. Same-frame window captures showed cues moving
  with +100, +200, and −100 ms delays, then returning after reset. Changing
  delay during playback, seeking, switching tracks with delay active, and
  opening a new source produced the expected displayed state and native
  reset. The UI did not step beyond its +5000 ms limit.
- Paired pixels passed in normal, fullscreen, after a fullscreen seek, after
  closing the timing popup, after returning to a window, and after resizing.
  A separate full-app test returned Home, cleared the native track, reopened
  the media, and regained visible captions. The extended lifecycle test
  covered three Home cycles and subtitle-count transitions 1→0→3→1.

## Release and platform limits

The CI workflow has a dedicated Ubuntu X11 graphical job after fixture and
native checks. DEB, RPM, and Arch package-install jobs run an installed-app
subtitle smoke for authored ASS and an automatically found SRT after their
existing package checks. The smoke detects caption pixels in the final X11
window, but paired CC On/Off assertions remain in the graphical integration
job. A successful package build alone is not counted as an installed-app pass.
An initial 640×480 Fedora smoke capture exposed a false positive: the old
detector accepted a partly clipped red ASS cue with transport controls over
the video. The strengthened detector rejects that saved frame by its long
control line and edge pixels. Package subtitle smoke now requests a
1280×1024 X11 screen and rejects an undersized screen before launch.

For Ubuntu, DEB dependency generation records libmpv; Ubuntu's `libmpv2`
depends on `libass9`, whose dependencies include fontconfig, FreeType,
FriBidi, and HarfBuzz. The RPM's ELF dependency generation and Arch's `mpv`
runtime dependency carry their distribution equivalents. GTK, EGL/GLES, and
Mesa/graphics drivers remain required for the Flutter texture. Fonts are an
environmental input; the dedicated graphical CI job installs Noto and checks
the attachment separately. The installed-package smoke verifies actual
rendering instead of assuming the dependency graph alone is sufficient.

X11 capture does not establish Wayland compositor pixels. The existing
Wayland/XWayland matrix jobs exercise playback and GTK backend selection;
final subtitle capture there remains untested. Pixel presence also cannot
prove Urdu/Arabic joining, bidi ordering, numerals, punctuation, or font
quality. Saved Unicode screenshots require human review on target desktops.
Physical GPU and hardware decoder paths remain outside the headless X11 lane.

The native engine's requested track can differ from mpv's effective `sid`,
and native versions and fonts can change rendered pixels. VPFL retains the
Part 4 native track reconciliation and error handling. Apart from the
fullscreen controls-context fix above, this phase changes verification and
CI only; it does not introduce a parser or style override.

The Part 3 native tests also reproduced mpv `sub-add select` creating duplicate
tracks for a repeatedly added auto-discovered file. VPFL's Part 4 reuse path
kept the native count stable in this window test. These engine behaviors are
recorded in [Part 3](native-subtitle-verification.md).

One invocation of `subtitle_integration_test.dart` containing both Part 4
cases failed during the second test's Flutter finalization: it reported
`did not complete` and a missing temporary `flutter_test_listener` path.
Each case passed when rerun in a separate Linux process. This is an
unresolved combined-runner lifecycle failure, so the results below count the
isolated runs and retain the failed log at
`build/ci-logs/part6-subtitle-integration.log`.

## Validation record

| Check on this host | Result |
| --- | --- |
| Generated fixture verifier, `--subtitle-suite` | Exit 0; 31 original media cases and 20 subtitle files accepted (51 entries). |
| Native Part 3 comparison | Exit 0; 18/18 scenario groups passed for standalone mpv and 18/18 for media_kit. See `build/ci-native-subtitles-part6/report.md`. |
| Python harness, `python3 -m unittest discover -s test/ci -p 'test_*.py' -v` | Exit 0; 23 tests passed, including missing-caption, black-texture, burned-caption, overlay, clipped ASS, and installed-frame detector cases. |
| Installed-frame detector against actual VPFL X11 captures | Exit 0; authored red ASS: 1,553 caption pixels, automatic SRT: 1,052, plain video: 0. The detector's 120-pixel threshold separates these saved frames. |
| `VPFL X11 window renders subtitle fixtures through the player UI`, through `run_display.sh x11` | Exit 0; 1 integration case, 17:28. Embedded/external/Auto, ASS styles and effects, Unicode presence, gaps, timing, fullscreen, resize, and teardown passed. |
| Dart formatting, `dart format --output=none --set-exit-if-changed lib test integration_test` | Exit 0; 82 files checked, none changed. |
| `flutter analyze` | Exit 0; no issues. |
| `flutter test --reporter expanded` | Exit 0; all 95 unit and widget tests passed. |
| `integration_test/media_matrix_test.dart` in Xvfb with `VPFL_CI_FIXTURES` | Exit 0; all 31 declared media fixtures passed in 1:30. |
| Part 4 Linux integration cases, each in its own `flutter test -d linux` process | Exit 0; 5/5 cases passed: sidecar reuse, rejected-load recovery, file identity, in-flight load cancellation, and picker error handling. |
| Part 5 `integration_test/subtitle_delay_linux_test.dart` in Xvfb | Exit 0; native delay pixels and resets across sources passed. |
| Extended `integration_test/linux_lifecycle_test.dart` with subtitle A (1 track), plain B (0), multilingual C (3), and 3 Home cycles | Exit 0; Home cleared tracks, reopen restored one, and A→B→C→A plus rapid source changes reported the expected native counts. |
| `bash scripts/ci/run_regressions.sh build/ci-video-fixtures` | Exit 0; all 8 existing Linux integration cases passed (playback, open failure, inspector, codec recovery, queue, repeat-one, standard lifecycle, default manager). |
| `bash packaging/scripts/package-linux.sh deb` | Exit 0; release bundle and `dist/vpfl_1.0.0-1_amd64.deb` validated. |
| `bash packaging/scripts/package-linux.sh rpm` | Exit 0; release bundle and `dist/vpfl-1.0.0-1.fc44.x86_64.rpm` validated. |
| `bash packaging/scripts/package-arch.sh`, then local-checksum `makepkg --nodeps` in Arch container | Exit 0; archive and `dist/vpfl-bin-1.0.0-1-x86_64.pkg.tar.zst` built. Dependency and installed-app validation remain separate. |
| Installed RPM smoke in prepared Fedora container with 1280×1024 Xvfb | Exit 0; installed `/usr/bin/vpfl` showed authored red ASS (1,483 cue pixels) and automatically found SRT (429), with no control overlay or edge clipping; package removal passed. Dependencies were preinstalled in this container. |
| Installed Arch package smoke in prepared Arch container with 1280×1024 Xvfb | Exit 0; installed `/usr/bin/vpfl` showed authored red ASS (2,444 cue pixels) and automatically found SRT (1,089), with no control overlay or edge clipping; package removal passed. `pacman -U --nodeps` bypassed dependency resolution, so this establishes runtime rendering with preinstalled libraries, not dependency completeness. |
| `run_installed_package.sh ubuntu` in a clean Ubuntu 24.04 container | Exit 0; DEB dependency install, `/usr/bin/vpfl`, desktop metadata, ELF linkage, regression-video pixels, authored red ASS (2,817 cue pixels), automatically found SRT (2,801), X11 backend, persistence, and package removal passed. Both subtitle captures had no detected controls or edge clipping. |
| Isolated `Home and reopen restore visible subtitles in VPFL window` integration case | Exit 0 in 54 seconds; one native track before Home, zero after stop, one after reopening; both real-window CC On/Off pairs passed. |

The hosted CI jobs have been configured but have not yet run against the
unstaged Part 6 changes. Fedora and Arch runtime checks used prepared
containers, so their clean dependency-resolution jobs remain unverified here.
