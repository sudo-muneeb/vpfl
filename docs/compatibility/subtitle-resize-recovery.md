# Subtitle recovery after Linux window resizing

## Acceptance and evidence limits

The owner's clarified requirement is correct rendering after the resize stops.
Temporary interpolation during a drag is acceptable. The reported failure is a
caption that stays irregular until another resize or a fullscreen transition.
A successful screenshot several seconds later is insufficient to close that
report. This investigation preserves the existing working tree and isolates
the settled presentation defect before changing production placement.

The earlier sharpness test checked seven settled sizes, native screenshot
parity, caption bounds, edge variance, and a thresholded silhouette overlap.
Its CC menu interaction and four-second overlay wait delayed each capture. Its
forced native-size mismatch test inspected `Texture.filterQuality`; it did not
prove what pixels were displayed throughout a real drag, or whether the last
resize had left a stale frame. The authored colors were compared at one size.
Its arbitrary 999×800 client produces a 562-pixel-high texture with 198 pixels
of vertical letterbox padding; the new 1000×800 case produces 563 pixels with
197 pixels of padding. That one-pixel width change exposes the half-pixel
vertical placement absent from the earlier arbitrary-size case.

## Original ASS definitions

`test/fixtures/subtitles/sources/authored.ass` defines a 640×360 script with
WrapStyle 0. All three styles use Noto Sans Display, size 30, normal weight,
no italic, underline, or strikeout; horizontal/vertical scale 100, spacing 0,
angle 0, border style 1, outline 3, shadow 1, alignment 2, margins 20/20/25,
and encoding 1. Outline and background are opaque black; secondary color is
opaque white. Primary alpha is zero (opaque).

- Red: `AUTHORED RED`, primary `&H000000FF`, position (480,70), 1.0–2.5s.
- Blue: `AUTHORED BLUE`, primary `&H00FF0000`, position (160,170), 4.0–5.5s.
- Green: `AUTHORED GREEN`, primary `&H0000FF00`, position (320,300), 6.0–7.5s.

These events do not overlap and contain no animation, transforms, move tags,
or per-event scale or border overrides. Red and blue differ in text geometry,
position, time, and color. A comparison of these two events cannot attribute a
problem to color alone.

## Controlled sources and recovery diagnostic

The existing subtitle manifest and generator now include four sidecars with
identical `AUTHORED BLUE` text, font, style, position, and cue intervals. Only
foreground red, blue, green, or white changes. A fifth source varies position,
outline width, font size, text, overlap, and motion independently, and includes
the original red event recolored blue. Existing subtitle sources and the
31-case media matrix are unchanged. All generated media stays under `build/`.

The integration case `ASS recovers after repeated Linux window resizes` mounts
the production PlayerScreen, pauses at manifest times, and exercises a sequence
of programmatic resizes and an actual GTK border drag. Window managers can
coalesce pointer motions, so the drag is checked at its actual released size,
not an assumed target. It requires native
and displayed physical dimensions to converge within 1500ms, then captures an
early frame and another frame 500ms later without another resize. Both are
compared with native mpv at the same dimensions, plus a source-sized media_kit
screenshot. When both trajectories reach the same size, their final images
must agree. A one-pixel resize away and back at the released size must not
repair or change the previously captured caption. CC Off is
captured only after both visible frames so toggling subtitles cannot repair a
stuck visible frame before it is recorded.

The test logs resize requests, Flutter/window/texture sizes, native dimension
notifications, DPR, filter, rendering mode, and capture times. A dimension
notification is not labeled as GPU completion or presentation. Window captures
use X11 `window_id` to exclude unrelated desktop applications. Logs and pixels
are under `build/ci-logs/subtitle-settle/<pid>/`.

Odd viewport dimensions are retained. The installed mpv 0.37 headless
screenshot compositor crashes on an odd YUV420 frame; headless diagnostic
references use full chroma planes rather than excluding those sizes.

## Root cause status

Initial hypotheses included missed resize notifications, stale pixel content,
and final fractional placement. The placement experiment below isolates a
repeatable final presentation defect; implementation validation follows it.

## Reproduced presentation defect

On the physical AMD Radeon (radeonsi/Mesa 25.2.8) X11 display at DPR 1, a
1000×800 client window places its 1000×563 native video at y=138.5 when
centered. This leaves a settled native texture at a half-pixel screen origin.
The native size and paused timestamp stay unchanged while the public
`VideoState.update(alignment: ...)` API alternates between top-center and
center. Top-center puts the same video at integer y=40. The result is
repeatable in both directions:

- Original red: integer origin 99.96% raw glyph-mask overlap with native mpv;
  return to half-pixel center 98.86%.
- Original green: integer origin 99.92%; return to center 95.65% raw / 98.32%
  after allowing a one-pixel translation.
- The controlled red, blue, green, and white captures at the same final
  viewport have exactly the same 8,952-pixel silhouette (100% overlap with
  the blue control). Color alone does not alter their geometry.
- The final controlled placement experiment reproduces the original red
  event's 99.96% integer / 98.86% half-pixel overlap after recoloring it blue,
  with identical caption masks in both colors. The original blue event stays
  at 99.99% in both positions. Thus the difference follows the cue's text and
  position rather than its foreground color. Its four-mode measurements are
  saved in `geometry-color-results.json` and `geometry-color-complete.log`.

These differences remain after the window has stopped resizing. A fullscreen
or another resize can change whether the centered origin is integral,
explaining why the appearance can recover after that interaction. Native
libass rasterization is not replaced: the defect is introduced by presenting
its already rendered texture at a fractional pixel origin with nearest
sampling. The original cue's different text geometry and positions make the
visible edge differences unequal; their color comparison was not controlled.

The previous dynamic filter policy compared texture and displayed dimensions.
Those dimensions already agree in this reproduction, so it selects nearest
sampling without addressing the fractional origin. In the controlled original
red sample, centered linear sampling instead drops the edge-variance ratio to
0.736; integer placement gives 0.994 with either nearest or linear sampling.
Changing filters can change the symptom but does not correct the placement.

Before changing production code, an A/B/A placement experiment reproduced the
persistent difference without changing the media, font, subtitle definition,
viewport dimensions, native output dimensions, or cue timestamp. Artifacts
are under `build/ci-logs/subtitle-settle/` and the experiment is selected by
`VPFL_RESIZE_PIXEL_PHASE=true` in the integration test.

The checker itself also needed correction: native YUV420 subtitle screenshots
are not a reliable RGB window reference for saturated ASS colors. For a red
cue at 1124×632, standalone mpv's actual X11 window has edge variance 3710.214,
while the YUV420 screenshot has 1453.292; a full-chroma screenshot has 3509.229.
An mpv RGB window readback agrees with an independent X11 window capture at
1000×563 by 99.976% silhouette overlap. The recovery test now compares with
that actual-size mpv RGB output, with no video filter resizing. Source-sized
media_kit screenshots retain their separate, original-format equality check.

The application fix is to snap the contained video's final screen
origin to physical pixels while retaining native rendering at the displayed
resolution. Temporary drag interpolation is outside the acceptance target.


## Implementation

PlayerScreen now uses the public video alignment API after layout to center
its rendered texture on physical pixel boundaries. The output still uses the
existing native size calculation and libass renderer. The correction applies
when letterbox padding changes even if the native output dimensions do not.
The maximum change from geometric centering is half a physical pixel.

The application changes are in [PlayerScreen](../../lib/ui/player/player_screen.dart)
and the [size/alignment helpers](../../lib/ui/player/video_output_size.dart).
The small native paused-resize invalidation is in
[video_output.cc](../../third_party/media_kit_video/linux/video_output.cc) and
the maintained patch. Diagnostics live in the
[Linux window integration test](../../integration_test/subtitle_window_linux_test.dart)
and [sharpness checker](../../scripts/ci/check_subtitle_sharpness.py).

The review also caught a neighboring regression in the initial output-sizing
implementation: requesting a native texture with the Stretch viewport's aspect
ratio lets mpv letterbox the video before Flutter stretches that texture. An
actual VPFL capture at a 999×800 client showed only 74.4% video coverage inside
the supposed stretched surface. This is recorded in `fit-probe.log`,
`fit-before-metrics.json`, and `subtitle-sharpness/119478/fit-fill.png` under
the CI log directory. The helper now preserves the source aspect ratio in the
native texture for both crop and Stretch, rendering at the larger required
scale; Flutter applies the existing crop/stretch operation. No native aspect
property or subtitle style is changed. Stretch intentionally retains its
existing nonuniform scaling and is not a promise of unstretched glyph shapes.
The seven-size integration case also checks actual plain-video coverage in
Fit, Fill and crop, and Stretch modes, with the subtitle disabled.

The previous vendored automatic filter switching is removed. Its mismatch
assertions tested a workaround for drag appearance; they have been replaced
by physical-origin assertions and stopped-window image comparisons, matching
the owner's clarified acceptance criterion. No extra media_kit_video widget
patch is needed for pixel placement. The existing Linux native paused-size
refresh remains necessary and unchanged.

The new recovery gate allows at most one pixel of registration for capture
rounding, then requires at least 99% glyph silhouette overlap with mpv's RGB
window output, as well as the existing sharpness comparison. Saved pre-fix
red (98.86%) and green (98.32% registered) captures fail this gate. Separate
synthetic tests reject missing strokes, changed stroke thickness, blur,
incorrect positions, and invalid RGB buffers. The A/B/A diagnostic captures
were recorded before the fix; after the fix PlayerScreen corrects fractional
centering requests automatically.

To repeat the controlled integer/half-pixel, nearest/linear placement
experiment on an isolated Xvfb display after generating the fixtures:

```bash
bash scripts/ci/run_display.sh x11 bash scripts/ci/run_subtitle_window.sh \
  flutter test integration_test/subtitle_window_linux_test.dart -d linux \
  --dart-define=VPFL_SUBTITLE_FIXTURES="$PWD/build/ci-video-fixtures" \
  --dart-define=VPFL_REFERENCE_VO=x11 \
  --dart-define=VPFL_RESIZE_CASES=original-red,original-blue,original_red_blue \
  --dart-define=VPFL_RESIZE_PIXEL_PHASE=true \
  --plain-name='ASS recovers after repeated Linux window resizes' \
  --reporter expanded
```

Only the optional diagnostic disables the application sizing callback while
forcing fractional alignment through public Video APIs. Its deliberately bad
placement samples are measured without acceptance thresholds; the normal
recovery captures still require the strict gate. Normal CI leaves this flag
off. Do not use the deliberately fractional samples as evidence of a failed
fixed production layout.

### Explicit reference backend in CI

On this host, standalone mpv's GPU VO under Xvfb/llvmpipe intermittently draws
a black video plane while drawing the colored foreground. Both the actual X11
capture and RGB window readback show it; this is an invalid reference, not a
VPFL rendering failure. `--opengl-glfinish=yes` did not reliably resolve it.
The recovery CI commands explicitly select `VPFL_REFERENCE_VO=x11`, using
mpv's X11 software VO with full-chroma conversion and no filter resizing.
This reference agrees with the physical GPU reference by 99.72% silhouette
overlap in the controlled red comparison. The physical Radeon tests use
`VPFL_REFERENCE_VO=gpu` (the default). VPFL's rendering mode is independent
of the reference VO; injected GPU failure must report `software`.

In this mpv 0.37 installation, the X11 VO's `screenshot window` can omit
letterbox bars for an off-aspect viewport: at 1000×760 its readback is all video,
while an independent X11 capture shows the expected 73.93% video coverage. Recovery comparisons
therefore use the fitted video rectangle at its matching aspect ratio, not
the full letterboxed player viewport. At the tested 1000×563 video rectangle,
an independent actual X11 capture of full-chroma mpv agrees with the physical
GPU reference by 99.81% silhouette overlap (edge ratio 0.993). These checks are
under `native-fill-probe/` and `x11-actual-reference/` in the diagnostic output.
The separate Fit/Stretch checks inspect actual VPFL X11 pixels, so a screenshot
API omitting borders cannot make those checks pass.

The reference-backend failures and diagnostic captures are retained under
`build/ci-logs/subtitle-settle/`. They are not counted as successful runs.

## Recorded verification

Initial local checks were recorded on 18 October 2026, with follow-up
validation on 19 October. These checks use Flutter 3.47.5, the pinned media_kit
dependencies, mpv 0.37, and the host libraries recorded in
`build/ci-native-subtitle-settle-final/versions.json`.

- Physical Radeon GPU recovery: all 14 cases, two resize paths, early and late
  captures (56 comparisons), passed in 5m36s. Minimum registered silhouette
  overlap was 99.82%; minimum edge-variance ratio was 0.989.
- Injected software recovery under Xvfb: the same 56 comparisons passed in
  6m25s. Minimum overlap was 99.91%; minimum edge ratio was 0.992.
- GPU recovery under Xvfb with the explicit X11 reference also passed all 56
  comparisons in 6m12s: minimum overlap 99.91%, minimum edge ratio 0.986.
- The complete physical GPU placement/color experiment passed in 3m11s,
  exit 0: three cue definitions, 12 positive early/late image comparisons,
  12 deliberately forced placement/filter measurements, and the same-size
  redraw checks. Pixel masks of the original red cue and its blue recolor are
  identical at both integer and half-pixel placements (100% pairwise overlap),
  recorded in `original-red-recolored-mask-parity.json`. An earlier optional
  diagnostic failed because remounting controls restarted their visibility
  timer; it now hides the remounted controls before the next resize sequence.
- The seven-size attached ASS check and the three Fit/crop/Stretch pixel
  checks passed on GPU (3m18s) and injected software (3m19s), exit 0. All three
  modes had 100% video coverage in the inspected surface after the Stretch
  correction. Earlier runs failed at an invalid off-window crop in the new
  test helper; after correcting that helper, `fit-probe.log` reproduced the
  actual Stretch letterbox regression before the production sizing correction.
  Final commands/output are `fit-fixed-gpu.command`/`.log` and
  `fit-fixed-software.command`/`.log` in the diagnostic directory.
- The convergence check itself lasted 87–150ms on the physical GPU and
  138–340ms on software across the resize sequences. Including the harness's
  initial 100ms pump, actual pointer release to confirmed stable geometry was
  212–224ms and 261–304ms, respectively. The early PNG completed 408–477ms and
  511–586ms after release. These are diagnostic observation/capture latencies,
  not measurements of the first completed GPU presentation.
- `flutter test --no-pub --reporter expanded`: 97 tests passed, exit 0.
- The final focused software recovery run passed the original red and green
  cues with an explicit `software` renderer assertion (1m07s), exit 0.
- `flutter analyze --no-pub`: no issues found, exit 0. The final run took
  166.6s; its output is `analyze-complete.log` in the diagnostic directory.
- `flutter build linux --release`: passed after the final sizing correction,
  exit 0. Output: `build/linux/x64/release/bundle/vpfl`; command and log:
  `release-complete.command` and `release-complete.log`.
- `dart format --output=none --set-exit-if-changed lib test integration_test
  scripts/ci/media_kit_subtitle_check.dart`: 85 files, no changes, exit 0.
  `git diff --check` and the changed documentation's local link checks passed.
- `Home and reopen restore visible subtitles in VPFL window` passed in 51s,
  and the original 31-case media playback matrix passed in 1m29s, exit 0.
  Their commands/output are saved under `home-reopen.*` and `media-matrix.*`.
- The existing `VPFL X11 window renders subtitle fixtures through the player
  UI` integration case passed in 17m15s, exit 0. This includes embedded and
  external loading, selection, authored styles/effects, attachment use,
  Unicode pixels, cue gaps, burned captions, delay updates/resets, fullscreen,
  seeking, and final window resizing. Commands use the wrappers documented in
  [subtitle window checks](../ci/subtitle-window-checks.md); exact expanded
  invocations and output are saved as `full-subtitle-window.command` and
  `full-subtitle-window.log` under `build/ci-logs/subtitle-settle/`.
- `python3 -m unittest discover -s test/ci -p 'test_*.py' -v`: 32 tests passed,
  exit 0. Synthetic corruption cases reject blur, missing strokes, increased
  thickness, invalid RGB, and displaced captions.
- `python3 scripts/ci/generate_fixtures.py --out build/ci-video-fixtures
  --subtitle-suite` and the corresponding `verify_fixtures.py --dir` command
  generated/validated all 31 media cases and 25 subtitle suite files, exit 0.
- `python3 scripts/ci/run_native_subtitle_checks.py --fixtures
  build/ci-video-fixtures --out build/ci-native-subtitle-settle-final`: 23/23
  comparisons passed, exit 0. An initial run exposed the harness's assumption
  that every motion effect occupied the first cue. The manifest now identifies
  the motion cue explicitly; existing motion/color assertions remain enabled.

Physical GPU artifacts are in `build/ci-logs/subtitle-settle/165986/`, software
artifacts in `247700/`. `comparison/original-red-before-after-3x.png` and the
corresponding green image place the before capture on the left and the fixed
capture on the right, with nearest enlargement only for inspection. The
native-size PNGs and numeric comparisons are the assertions.

`software-resize.mkv` records the private Xvfb display at a requested and
reported 60fps, 1280×1024. It includes standalone reference windows between
VPFL resize sequences and intentional CC Off intervals; the lossless per-window
PNGs remain the quality evidence. `recorded-frames/` contains a 60fps excerpt and
`software-resize-contact-sheet.png` provides navigation. The recording is not
a guarantee of unique presented frames at every timestamp.

Wayland compositor pixels, physical fractional display scaling, and displays
larger than the existing software buffer were not verified. The widget test
exercises placement at DPR 1.25; that is not a substitute for real compositor
captures. No claim is made about perfect frames while the border is moving,
temporal flicker during the drag, GPU utilization, or release performance.
The automated acceptance target is recovery after release; a moving ASS cue
is sampled at a fixed timestamp to keep the reference comparison controlled.
Window pixel results use the debug integration runner. A release build is a
separate compilation check; installed-package and release-window pixel checks
were not repeated for this follow-up.
