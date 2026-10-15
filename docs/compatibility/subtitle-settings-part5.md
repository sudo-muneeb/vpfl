# Subtitle timing settings (Part 5)

VPFL's CC menu now opens a compact **Subtitle timing** dialog in both wide and
compact player layouts. It shows the applied delay in milliseconds, changes it
in 100 ms steps, and resets it to zero. Positive values show captions later;
negative values show them earlier. The UI offers a ±5 second range. A value
set outside that range through mpv remains visible and can be stepped toward
the range or reset; VPFL does not constrain mpv's native property.

`PlaybackService` sends decimal seconds through the pinned `media_kit` 1.2.6
`NativePlayer.setProperty('sub-delay', value)` interface, reads the native value
back before reporting success, and observes native changes without polling.
All subtitle operations use the Part 4 serialized operation queue and source
generation guard. A failed or rejected native write reports an error through
the player UI; the displayed value follows the observed native property.

## Lifecycle

The installed libmpv retains `sub-delay` when one `Player` opens another file.
VPFL therefore sets and confirms zero before each source open. It also resets
on Home/stop and failed-media stop. Returning to a video starts at zero, as does
a new player after closing or restarting VPFL. The delay is not persisted to
the database. The older [product matrix](../01-product-scope-fixed.md) places
per-media delay persistence in V1.1; this first control follows the Part 5
request's session scope and avoids storing an offset for unrelated videos.

## Native appearance baseline

The tested `media_kit`/libmpv host reported these initial properties:

| mpv property | Observed value |
| --- | --- |
| `sub-delay` | `0.000000` seconds |
| `sub-ass-override` | `yes` |
| `sub-scale` | `1.000000` |
| `sub-pos` | `100.000000` |
| `sub-font-size` | `55.000000` |
| `sub-ass-style-overrides` | empty |

The installed engine accepted `sub-delay=0.1` and `-0.1`, returning
`0.100000` and `-0.100000`. Opening a second video retained `-0.100000` before
VPFL's reset. The pinned `NativePlayer` property API takes and returns strings;
VPFL converts at the boundary and keeps whole milliseconds in application
logic.

VPFL leaves all five appearance properties untouched. The [Part 3 native
comparison](native-subtitle-verification.md) confirmed authored ASS colors,
positions, effects, font attachment use, and Unicode glyph pixels with the
current engine configuration. The [mpv manual](https://mpv.io/manual/stable/#subtitles)
warns that `sub-scale`, `sub-pos`, and ASS style overrides can break authored
layout. A scale or position control needs separate evidence for the Part 2 ASS
fixtures before it is offered; this phase adds only timing.

## Checks

The focused Linux timing test is:

```bash
./scripts/ci/run_display.sh x11 flutter test \
  integration_test/subtitle_delay_linux_test.dart -d linux \
  --dart-define=VPFL_SUBTITLE_FIXTURES="$PWD/build/ci-video-fixtures"
```

It uses the generated embedded SRT and plain video fixtures, native property
readback, cue text, and pixel differences between subtitle-inclusive and
video-only screenshots of the same frame. It checks negative and positive
timing, rapid steps, reset, track changes, seeking, source switches, and Home.
The widget tests cover both CC layouts, displayed native updates, controls,
and the UI range. The conversion unit tests cover signed values, invalid
native values, and repeated integer steps.

The pixel comparison captures mpv/libass output. It does not inspect the final
Flutter compositor or prove identical rendering on other libmpv versions.

## Validation record

Checked on 15 October 2026 on the Linux host described in the [Part 3
report](native-subtitle-verification.md):

| Command or check | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Exit 0; 81 files checked, none changed. |
| `flutter analyze` | Exit 0; no issues. |
| `flutter test --reporter expanded` | Exit 0; 95 tests passed. |
| `python3 -m unittest discover -s test/ci -p 'test_*.py' -v` | Exit 0; 9 tests passed. |
| `python3 scripts/ci/verify_fixtures.py --dir build/ci-video-fixtures --subtitle-suite` | Exit 0; 31 original fixtures and 20 subtitle suite files verified. |
| `python3 scripts/ci/run_native_subtitle_checks.py --fixtures build/ci-video-fixtures --out build/ci-native-subtitles-part5` | Exit 0; 18/18 mpv and 18/18 media_kit scenario groups passed, including authored ASS pixel checks. |
| Part 5 Linux timing test above | Exit 0; native timing, pixels, range, source changes, Home, and new player checked. |
| Part 4 subtitle integration, file identity, lifecycle, and picker Linux tests | Exit 0 when run separately; 5 cases passed. |
| `integration_test/media_matrix_test.dart` with `VPFL_CI_FIXTURES` | Exit 0; all 31 media cases passed. |
| `integration_test/linux_lifecycle_test.dart` with `VPFL_TEST_VIDEO` and `VPFL_TEST_CYCLES=3`; `integration_test/queue_playback_test.dart` with `VPFL_TEST_VIDEO` | Exit 0; three Home cycles and queue progression passed. |
| `flutter build linux --release` | Exit 0. |

An earlier combined Part 4 subtitle integration invocation lost its Linux test
connection after the first case; both cases passed in separate invocations.
The picker test initially tried to click CC while its preceding error snackbar
still covered the button. The test now dismisses the snackbar before the next
choice and passes. The timing test waits for mpv's target position and compares
subtitle-inclusive and video-only captures from the same frame; a one-shot
capture immediately after a paused seek was unreliable.
