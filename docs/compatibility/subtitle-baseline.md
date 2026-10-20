# Subtitle baseline (Part 1 audit)

Audited `origin/main` at `3b61ef5` on 13 October 2026. This document records
the implemented behavior and test coverage; it does not add subtitle features.
The code and tests below take precedence over future-facing rows in
[`01-product-scope-fixed.md`](../01-product-scope-fixed.md).

## Ownership and path to the screen

1. [`PlayerScreen`](../../lib/ui/player/player_screen.dart) receives a media URI,
   waits for the video renderer, and calls `PlaybackService.openWithDirectory`.
   The service keeps one `media_kit` `Player`, serializes source opens, and calls
   `Player.open`. Directory siblings form VPFL's navigation queue; only the
   selected item is passed to mpv at each open.
2. **mpv** demuxes embedded tracks. Its `sub-auto=exact` default also searches
   for matching nearby subtitle files, including language suffixes, subject to
   filesystem access. VPFL has no separate sidecar scanner and does not set
   `sub-auto`. The matrix does not exercise automatic sidecar discovery.
3. **media_kit 1.2.6** observes mpv's `track-list`, converts `sub` entries into
   `SubtitleTrack` objects, and emits `Player.stream.tracks`. Its list includes
   synthetic `auto` and `no` options. `PlaybackService.tracks` and
   `tracksStream` forward this state; [`RealMediaTracks`](../../lib/data/model/real_media_tracks.dart)
   removes the synthetic options for counts and the inspector.
4. The user can choose Auto, Off, or a discovered track in
   [`PlayerControls`](../../lib/ui/player/player_controls.dart). At widths below
   600 pixels the choice is under the overflow menu. Both menus rebuild from
   `tracksStream`; `PlayerScreen` also rebuilds when `tracksStream` or
   `selectedTracksStream` emits. Selecting a track calls
   `PlaybackService.setTrack` and then `Player.setSubtitleTrack`.
5. The Load subtitle file action opens the native picker for `.srt`, `.ass`,
   `.ssa`, and `.vtt`. [`PlaybackService.loadSubtitleFile`](../../lib/data/services/playback_service.dart)
   checks existence and the extension, converts the path to a file URI, and
   passes `SubtitleTrack.uri` to media_kit. media_kit sends mpv `sub-add` with
   `select`. mpv parses and adds the file; a later `track-list` event is what
   makes the track appear in the CC menu. VPFL does not parse subtitle text.
6. VPFL constructs `PlayerConfiguration(libass: true)`. media_kit sets mpv's
   `sub-ass`, `sub-visibility`, and `secondary-sub-visibility` to `yes`.
   **libass**, via the system mpv build, renders text subtitles into the native
   video frame. The vendored `media_kit_video` texture widget suppresses its
   Flutter `SubtitleView` when libass is enabled; it presents mpv frames and
   overlays the controls. VPFL screenshots request libass subtitle inclusion.

No subtitle selection, delay, or style preference is persisted by VPFL.
`selectedTracks` forwards media_kit's `Player.state.track`, and
`selectedTracksStream` forwards `Player.stream.track`. A new `Player.open`
calls media_kit `stop(open: true)`, which resets available and selected track
state before mpv discovers tracks for the next file. VPFL does not explicitly
restore a subtitle choice on a source switch.

Picker cancellation makes no change. A missing path or unsupported extension
throws from `PlaybackService.loadSubtitleFile` and `PlayerScreen` shows a
`Could not load subtitles` snackbar. Asynchronous media_kit errors are logged
and forwarded by `PlaybackService.errorStream`; `PlayerScreen` treats them as
possible media-open failures and probes for playback progress after three
seconds. This is a general media error path, not a subtitle-specific
confirmation or rollback path. The native command-result limitation below
further narrows which subtitle failures reach the snackbar.

## Versions and source provenance

| Component | Baseline |
| --- | --- |
| Flutter / Dart used locally | 3.47.5 / 3.13.4; CI pins Flutter 3.47.5 |
| `media_kit` | 1.2.6, hosted and lockfile pinned; VPFL does not patch it |
| `media_kit_video` | 2.0.1 API, path override to `third_party/media_kit_video` |
| `media_kit_libs_video` / Linux transitive package | 1.0.7 / `media_kit_libs_linux` 1.2.1 |
| Linux native mpv on this Ubuntu host | mpv/libmpv 0.37.0, `libmpv.so.2`; `libmpv2` Debian package `0.37.0-1ubuntu4` |
| Linux libass on this host | `libass.so.9`; `libass9` Debian package `1:0.17.1-2build1` |
| Other native libraries on this host | libepoxy `1.5.10-1build1`; FFmpeg `6.1.1-3ubuntu5`; fontconfig `2.15.0-1.1ubuntu2` |

The Linux plugin links to **system** libmpv and libepoxy. Package versions are
distribution dependent; a pub lockfile does not pin native libmpv or libass.
The checked-in [`media_kit_video` patch](../../patches/media_kit_video/README.md)
changes Linux EGL/shared texture, software fallback, and renderer status. It
does not implement subtitle discovery, selection, parsing, or style policy.

## mpv property baseline

Read-only queries used a throwaway native `media_kit` `Player` with the exact
VPFL `PlayerConfiguration(libass: true, title: 'VPFL')`. A separate
`mpv --no-config` IPC process supplied this host's mpv 0.37.0 defaults. These
are initial values before selecting a media track; they are not evidence about
the effective `sid` while a file plays.

| Property | VPFL-equivalent player | Host mpv default | Owner |
| --- | --- | --- | --- |
| `sub-auto` | `exact` | `exact` | mpv default; VPFL does not set it |
| `sid` | `auto` | `auto` | mpv default; media_kit changes it for manual selection |
| `sub-delay` | `0.000000` | `0` | mpv default; VPFL has no delay control |
| `sub-ass-override` | `yes` | `yes` | mpv 0.37.0 default; VPFL does not set it |
| `embeddedfonts` | `yes` | `yes` | mpv default; VPFL does not set it |
| `sub-font-provider` | `auto` | `auto` | mpv default; on Linux this tries fontconfig |

Additionally, `sub-ass=yes` was observed. media_kit explicitly sets it from
VPFL's `libass: true` choice, so VPFL does **not** disable native libass.
None of the six requested properties is set by VPFL at player creation. The
present configuration does not disable mpv's automatic nearby subtitle search
or embedded font loading. mpv's [subtitle options](https://mpv.io/manual/stable/#subtitles)
describe exact matching and ASS overrides. The installed mpv version and its
queried defaults govern this baseline if the current online manual differs.

ASS/SSA is passed to mpv/libass with no VPFL style conversion. That gives
authored styles a native rendering path, but **style fidelity is unverified**:
the baseline has no styled glyph assertion, embedded font fixture, or
font-provider check during playback. The default `sub-ass-override=yes` can
apply mpv ASS override options; VPFL sets none of those options.

## Existing capabilities

The current app exposes embedded tracks and mpv-discovered nearby tracks in
the CC menu, plus a manual local SRT/ASS/SSA/VTT picker. It offers Auto and
Off, forwards manual selection to media_kit, and uses native libass rendering.
The inspector lists the discovered subtitle streams. These are implemented
paths, not a claim that every format, automatic match, or authored style has
been visibly validated.

## Confirmed code defects and limits

- **The reported selected subtitle is a request, not necessarily mpv's active
  track.** media_kit 1.2.6 writes `Player.state.track.subtitle` when its
  `setSubtitleTrack` method is called, but its observed-property list includes
  `track-list` and not `sid`. mpv can select an embedded or nearby track while
  media_kit still reports `auto`. `PlaybackService.selectedTracks` inherits
  this limitation. The CC menus show choices but no selected marker, so they
  also cannot communicate the effective track. This is directly established
  by the installed media_kit native player code and the VPFL menu code; the
  exact user-facing result for a multilingual video still needs a native case.
- **A failed mpv subtitle command can appear successful to the caller.** In
  media_kit 1.2.6, `_command` logs a negative mpv result to `stream.log` but
  completes its `Future<void>` normally. `setSubtitleTrack` then
  updates its requested selection. VPFL catches thrown errors from
  `loadSubtitleFile`, so it cannot reliably show a load failure for a rejected
  `sub-add`. `stream.error` is populated only for selected mpv log prefixes,
  not directly from `_command` failures. A positive track-list event is the
  current observable success signal; no VPFL code waits for it. This is
  specific upstream source evidence, not a claim that any valid fixture failed.
- **Inspector external labeling is incomplete.** media_kit constructs mpv
  `track-list` entries as new numeric-ID `SubtitleTrack` objects without the
  `uri` or `data` flag. [`PlayerInspector`](../../lib/ui/player/player_inspector.dart)
  writes `External` only when one of those flags is true. Thus an external
  track rediscovered through mpv's `track-list` has no External label. Track
  discovery itself still works.

Upstream evidence was checked in the resolved pub-cache source
`media_kit-1.2.6/lib/src/player/native/player/real.dart`: `setSubtitleTrack`
(around line 1086), `track-list` handling (around line 1707), property setup
(around line 2434), and `_command` (around line 2613). These are findings for
the pinned version, not assumptions about later media_kit releases.

## Questions requiring native reproduction

- Does `sub-auto=exact` find and select `movie.en.srt` and `movie.ur.srt` for
  VPFL's file-URI/loadlist path, and how does access through a sandbox or
  document portal change that result?
- Does every valid external SRT, ASS, SSA, and VTT fixture show the intended
  text during its cue interval? The current matrix waits only for a new track.
- Does libass preserve authored position, color, fonts, and complex shaping on
  the packaged mpv/libass versions? The simple ASS fixture cannot establish it.
- If the file picker is open while the video changes, can its eventual result
  attach to the new source? `PlayerScreen._pickSubtitleFile` has no source
  generation check, but this transition has not been reproduced.
- What does the UI display when mpv rejects corrupt subtitle content, and
  does a failed load leave the previous subtitle selection intact?

## Existing subtitle test inventory

The fixture generator is [`scripts/ci/generate_fixtures.py`](../../scripts/ci/generate_fixtures.py),
driven by [`ci/media-matrix.json`](../../ci/media-matrix.json). The verifier
checks file hashes, metadata, and FFmpeg decode; it does not inspect subtitle
appearance. The required X11, Wayland, and XWayland matrix lanes are in
[`.github/workflows/ci.yml`](../../.github/workflows/ci.yml).

| Test and source | Fixture and actual subtitle assertion | Level; detects | Misses |
| --- | --- | --- | --- |
| `selection options do not count as media streams` in [`real_media_tracks_test.dart`](../../test/data/model/real_media_tracks_test.dart) | Synthetic `Tracks()` and a video/audio-only list; subtitle result is empty. | Model metadata; accidental counting of `auto`/`no` when none are present. | Real mpv discovery, selection, pixels, timing. |
| `multiple streams retain external subtitles but exclude cover art` in the same file | Synthetic embedded track plus `SubtitleTrack.uri('file:///tmp/example.srt')`; result length 2 and last `uri == true`. | Model metadata; dropping supplied external track or counting synthetic options. | mpv's numeric track-list representation, actual loading, selection, rendering. |
| `compact controls keep shuffle clear of transport buttons` in [`player_controls_test.dart`](../../test/ui/player_controls_test.dart) | Stubbed controls at 480 px; asserts overflow contains `Subtitles…`. | Widget UI presence; missing compact entry. | Opening subtitle dialog, selecting a track, stream updates, playback, pixels. |
| `every declared fixture plays through VPFL` external loop in [`media_matrix_test.dart`](../../integration_test/media_matrix_test.dart) | `sub_srt`, `sub_vtt`, `sub_ass`, `sub_ssa` with `h264_mkv`; asserts real subtitle-track count increases after each `loadSubtitleFile`. | Native track metadata; format load that never appears in `track-list`. | Selected `sid`, cues, timing, style, failure handling, pixels. |
| Same matrix test, embedded case | `embed_srt_mkv`; asserts one real subtitle track and a non-null screenshot with red/green/blue video patches. | Native metadata and decoded video pixels; missing embedded track or damaged video frame. | Subtitle glyphs or placement: sampled patches are outside the cue area. It does not check final Flutter composition. |
| `media and diagnostics stay in a non-modal right inspector` in [`player_inspector_linux_test.dart`](../../integration_test/player_inspector_linux_test.dart) | Caller-supplied `VPFL_TEST_VIDEO`; optional expected subtitle count and optional `VPFL_TEST_EXTERNAL_SUBTITLE` count increase. Always asserts the inspector's `Subtitles` heading. | Native metadata/UI heading when the optional defines are supplied. | In its default no-source run the test is skipped; without optional defines it does not establish subtitle count or loading. The source must still be playing at the external-load step; the test has no EOF guard. Never checks selected track or glyphs. |

No test exercises the CC menu's Auto/Off/track choice, selected-track updates,
automatic sidecars, subtitle state across a source switch, bad content, or
subtitle pixels. A screenshot capture alone is not a subtitle rendering
assertion. The matrix's `_checkPatches` checks video color samples only.

## Missing tests for subsequent parts

- Native cases for exact sidecar matches, language suffixes, a nonmatching
  neighbor, and inaccessible siblings, with actual mpv `track-list` and `sid`
  observations.
- Native selection transitions for Auto, an embedded track, a manual external
  track, Off, another media file, and stop/reopen. Compare the requested
  media_kit selection with effective mpv `sid`.
- SRT/VTT cue presence and absence before, during, and after its interval;
  ASS/SSA authored color, alignment, font attachment, and complex-script
  examples. Assert meaningful pixel regions or another reliable rendered
  output, including an end-to-end compositor check where the claim is final
  Flutter presentation.
- Missing file, unsupported extension, corrupt/empty content, cancellation,
  and source change while the picker is open; assert user-visible feedback and
  retained playback/selection state.
- Widget assertions that the desktop and compact CC menus update from track
  events and invoke the intended selection. Keep these distinct from native
  rendering checks.

## Boundaries for later parts

Keep VPFL responsible for picker UX, permission-aware file access, menu state,
source generation, and observable error reporting. Use media_kit's public
track and stream APIs for ordinary selection and track discovery. Treat the
effective mpv `sid`, `sub-delay`, and other native properties as a small Linux
adapter concern only where public state cannot answer the product question.
mpv owns matching, demuxing, and selection; libass owns native text layout.
Assess a media_kit upstream fix or narrow adapter before considering a fork.
Do not add a VPFL subtitle parser or settings as a consequence of this audit.

## Validation on this checkout

The checkout was clean before the audit. Local `main` was fast-forwarded to
`origin/main`, then `audit/subtitle-baseline` was created. No source code or
tests were modified. Local commands and observed results:

| Command | Exit and result |
| --- | --- |
| `flutter test test/data/model/real_media_tracks_test.dart test/ui/player_controls_test.dart --reporter expanded` | 0; 17 unit/widget tests passed. |
| `python3 scripts/ci/generate_fixtures.py --out build/ci-video-fixtures` | 0; generated 31 fixtures. |
| `python3 scripts/ci/verify_fixtures.py --dir build/ci-video-fixtures` | 0; verified all 31 fixtures. |
| `./scripts/ci/run_display.sh x11 flutter test integration_test/media_matrix_test.dart -d linux --dart-define=VPFL_CI_FIXTURES="$PWD/build/ci-video-fixtures" --reporter expanded` | First run: 1; stalled at `h264_mp4` natural completion (`position=2.417 s`, `duration=2.521 s`, `playing=true`) before reaching subtitle cases. Exact rerun: 0; all 31 cases passed, including four external track additions and the embedded track. Cause of the first completion stall is not established. |
| `flutter pub get --enforce-lockfile` | 0; dependencies resolved with the path override. |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | 0; 71 files inspected, 0 changed. |
| `flutter analyze` | 0; no issues found. |
| `flutter test --reporter expanded` | 0; all 87 unit/widget tests passed. |
| `./scripts/ci/run_display.sh x11 flutter test integration_test/player_inspector_linux_test.dart -d linux --dart-define=VPFL_TEST_VIDEO="$PWD/build/ci-video-fixtures/embed_srt_mkv.mkv" --dart-define=VPFL_TEST_SUBTITLE_TRACKS=1 --dart-define=VPFL_TEST_EXTERNAL_SUBTITLE="$PWD/build/ci-video-fixtures/sub_srt.srt" --reporter expanded` | 1; external-load assertion observed `0 > 1`. The 2.5-second source may have ended during the inspector interactions, causing media_kit to clear tracks; EOF was not asserted in this run. This setup is shorter than the regression video used by CI. |
| `bash scripts/ci/generate_regression_video.sh build/ci-video-fixtures/regression.mp4` | 0; generated the longer existing regression fixture for the inspector rerun. |
| `./scripts/ci/run_display.sh x11 flutter test integration_test/player_inspector_linux_test.dart -d linux --dart-define=VPFL_TEST_VIDEO="$PWD/build/ci-video-fixtures/regression.mp4" --dart-define=VPFL_TEST_SUBTITLE_TRACKS=0 --dart-define=VPFL_TEST_EXTERNAL_SUBTITLE="$PWD/build/ci-video-fixtures/sub_srt.srt" --reporter expanded` | 0; inspector and optional external-track assertion passed with the 30-second video. |

The matrix and inspector passes verify native track discovery and decoded
video color patches, not visible subtitle glyphs. The failed first matrix
run is a host repeatability limit for this audit and needs separate
investigation if it recurs. The failed short inspector run shows that its
optional load assertion needs a source that remains active through UI steps.
Hosted results in [`docs/ci/README.md`](../ci/README.md) are separate evidence.
