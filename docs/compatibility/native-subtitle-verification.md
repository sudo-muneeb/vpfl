# Native subtitle verification (Part 3)

Tested on 13 October 2026 on branch `audit/subtitle-baseline`. The suite in
[`scripts/ci/`](../../scripts/ci/run_native_subtitle_checks.py) uses the Part 2
[manifest](../../test/fixtures/subtitles/subtitle-matrix.json) and generated
media, first with isolated standalone mpv JSON IPC and then with the pinned
`media_kit` in a minimal Dart process. No VPFL player, Flutter window, or
production dependency was changed. Reproduction commands and pixel thresholds
are in the [CI guide](../ci/native-subtitle-verification.md).

## Tested environment

| Component | Observed version or path |
| --- | --- |
| Flutter / Dart | 3.47.5 / 3.13.4 |
| `media_kit` | 1.2.6 from `pubspec.lock` |
| `media_kit_video` | 2.0.1 API; VPFL path override `third_party/media_kit_video` |
| `media_kit_libs_video` / `media_kit_libs_linux` | 1.0.7 / 1.2.1 |
| Standalone mpv | 0.37.0 Ubuntu executable |
| media_kit native libmpv | `/usr/lib/x86_64-linux-gnu/libmpv.so.2.2.0`, `libmpv2` 0.37.0-1ubuntu4; verified from the Dart process's `/proc/self/maps` |
| libass | `libass9` 1:0.17.1-2build1 |
| FFmpeg | 6.1.1-3ubuntu5; exact linked library versions in `versions.json` |
| fontconfig / HarfBuzz / FriBidi | 2.15.0-1.1ubuntu2 / 8.3.0-2build2 / 1.0.13-3build1 (host packages) |
| Native output | `vo=null`, `ao=null`, `hwdec=no` for mpv; `vo=null` and `ao=null` for media_kit. X11, EGL, and AMD GPU are available on the host, but screenshots did not require a display. |

The standalone executable is a separate program; it does not dynamically load
`libmpv.so`. The recorded process maps and `ldd` results establish the actual
libraries used by each test. The pub lockfile does not pin the host libmpv,
libass, FFmpeg, or fonts.

During embedded SRT playback both engines reported `sub-auto=exact`,
`sub-delay=0`, `sub-ass-override=yes`, `embeddedfonts=yes`,
`sub-font-provider=auto`, and `sub-ass=yes`. The effective default `sid` was
stream 1, while media_kit's requested subtitle state was still `auto` before
manual selection. Per-case native properties are saved in the validated JSON.

## Results

Both engines passed 18 of 18 scenario groups and 94 screenshot/control pairs
each on the tested host. The [machine-readable comparison](../../build/ci-native-subtitles/comparison.json)
records the fixture, manifest cue times and text, track expectations, status,
versions, logs, and artifact paths for every group. The matching
[generated report](../../build/ci-native-subtitles/report.md) summarizes the
results. These artifacts are ignored build outputs and must be regenerated on
another checkout.

| Behavior | Evidence |
| --- | --- |
| Embedded SRT, ASS, MP4 `mov_text`, multilingual streams | Real native track metadata, effective `sid`, expected `sub-text`, and visible glyph pixels at cues for both engines. The `mov_text` track has language and codec but no title in the native track list, despite FFprobe's handler metadata. |
| External SRT, VTT, ASS | Explicit loading added a native track and visibly rendered each manifest cue. Nearby `movie.srt` and `movie.ur.srt` loaded automatically with `sub-auto=exact`; unrelated SRT did not. |
| Timing and state | Samples before, inside, between, and after cues; overlapping cues; backward/repeated seeks; pause/resume; English, Urdu, and Japanese selection; Auto/Off; and switching to a video with no subtitles and back produced the expected pixels and track lists. |
| Authored ASS | Red top-right, blue middle-left, and green bottom captions rendered with dark outlines. The first cue changed 3,508 pixels (1,595 red); second 3,779 (1,841 blue); third 4,150 (1,567 green) against video-only controls. `sub-ass-override=yes` and `embeddedfonts=yes` were observed, with no VPFL style override in this test. |
| Timed ASS effects | A `\\move` cue bounding box shifted from `[70,227,207,249]` to `[385,77,522,99]`; a later `\\t` color cue gained 1,312 red pixels. Both engines showed these results. |
| Embedded font | FFprobe validates the MKV font attachment and MIME type. Both native logs identify `NotoSansDisplay-Regular.ttf` and show `fontselect` choosing `NotoSansDisplay-Regular` for the authored family. Captions are visible. |
| Missing font | Both logs show `VPFL Unavailable Font 999` substituted by the host's Noto Sans. Captions remain visible and playback recovers normally; no missing-glyph diagnostic was seen. This does not establish that every glyph is available. |
| Unicode | Expected English, Urdu, Arabic, Japanese, and mixed RTL/LTR `sub-text` values matched, and each cue produced glyph pixels. Saved Arabic and Urdu frames were inspected for gross layout errors; detailed shaping, direction, and glyph quality remain a manual check on target environments. |

The same-frame video-only control detects missing captions and captions
persisting into gaps. The ASS checks additionally constrain position, color,
outline darkness, and movement; passing them does not prove every ASS feature
or pixel-identical rendering across distributions.

## Repository validation

| Command | Result |
| --- | --- |
| `python3 scripts/ci/verify_fixtures.py --dir build/ci-video-fixtures` | Exit 0; 31 original fixtures verified. |
| `python3 scripts/ci/verify_fixtures.py --dir build/ci-video-fixtures --subtitle-suite` | Exit 0; 20 subtitle suite files verified. This check also runs inside the native comparison. |
| `python3 -m unittest discover -s test/ci -p 'test_*.py' -v` | Exit 0; all nine tests passed (six existing generator tests, three native harness tests). |
| `env -u DISPLAY -u WAYLAND_DISPLAY python3 scripts/ci/run_native_subtitle_checks.py --fixtures build/ci-video-fixtures --out build/ci-native-subtitles-headless` | Exit 0; 18/18 scenario groups passed in both engines without a display. |
| `python3 scripts/ci/run_native_subtitle_checks.py --fixtures build/ci-video-fixtures --out build/ci-native-subtitles` | Exit 0; 18/18 scenario groups passed in both engines. |
| `dart format --output=none --set-exit-if-changed lib test integration_test scripts/ci/media_kit_subtitle_check.dart` | Exit 0; 72 files checked, none changed. |
| `dart analyze scripts/ci/media_kit_subtitle_check.dart`; `flutter analyze` | Exit 0; no issues. |
| `flutter test --reporter expanded` | Exit 0; 87 tests passed. |
| `flutter build linux --release` | Exit 0; built `build/linux/x64/release/bundle/vpfl`. |
| `git diff --check` | Exit 0. |

An initial display-free attempt hit Linux's Unix socket path length limit in
one long artifact directory. The harness now gives mpv a relative socket path
within its private temporary directory and connects through the process's
`/proc` cwd link; the subsequent full display-free run passed. This was a
test-harness startup issue, not evidence of a subtitle engine failure.

## Reproduced upstream behavior and limits

- A malformed SRT returns `error running command` to standalone mpv IPC and
  adds no track. The minimal media_kit call completes, leaves the native track
  list empty, but reports the malformed file URI as its requested subtitle
  selection. A valid SRT loads and renders afterward. This reproduces the
  [Part 1 source-code finding](subtitle-baseline.md) about media_kit's command
  result and requested state. Use the `malformed_then_recover` row and logs as
  a minimal reproduction. VPFL's current picker cannot treat the returned
  `Future<void>` as confirmation of native success.
- Repeating mpv `sub-add ... select` on an automatically discovered matching
  SRT added two more native track entries. The `cached` flag added none. The
  media_kit URI path also added two entries on repeated selection because it
  delegates to mpv `sub-add select`. This is an upstream command behavior,
  reproduced in `nearby_auto_and_repeat`; it is not evidence of a VPFL
  scanner duplicating files.
- `Player.state.track.subtitle` records the requested track and can be `auto`
  while the native `sid` is a concrete default stream. The suite records both
  values. The effective selection should be checked against native `sid` when
  the UI needs to report the currently active track.
- `vo=null` native screenshots worked without `DISPLAY` or
  `WAYLAND_DISPLAY` on this host. This validates libmpv/libass output, not
  VPFL's Flutter texture, compositor, file picker, or installed packages.
  Hosted CI and other distributions may use different native libraries and
  fonts. The baseline's possible picker/source-switch race remains untested.

For Part 4, keep mpv responsible for discovery and libass responsible for
rendering. VPFL should treat a track-list update and effective selection as
evidence of successful external loading; surface a rejected load without
claiming success; avoid requesting the same external file repeatedly when it
is already present; and test picker completion against the current media
source. Reproduce these behaviors in the VPFL integration layer before
changing it. The present native results do not justify a custom subtitle
parser, renderer, font manager, or broad media_kit fork.
