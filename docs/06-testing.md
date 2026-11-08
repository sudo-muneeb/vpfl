# VPFL testing strategy

Follow Flutter's testing guidance:

```text
many focused unit tests
many focused widget tests
a smaller number of important integration tests
```

Test behavior rather than implementation details.

Prefer one behavior per test.

## Naming

Good:

```text
resume restores saved position after media opens

late player event does not replace the current session

subtitle button is disabled when no subtitle tracks exist
```

Avoid generic names such as:

```text
player test
home test
test 1
```

## Unit tests

Test:

* resume policy
* completion threshold
* natural filename sorting
* file identity
* saved-folder relinking
* playlist order
* shuffle behavior
* state transitions
* session generation
* time formatting
* repository rules
* settings migration

Use fakes for external dependencies.

## Widget tests

Test:

* home empty state
* recent section
* all videos section
* media cards
* sidebar
* Add Folder action
* folder browser
* player controls
* seek interaction
* volume UI
* speed menu
* subtitle menu
* overflow menu
* fullscreen overlay state
* settings
* errors

Verify what the user sees and can do.

Do not lock tests to unnecessary widget nesting.

## Keyboard shortcut regressions

`test/ui/player_shortcuts_test.dart` covers every player binding, repeat and
release behavior, rapid presses, exact modifiers, text entry, focus changes,
synthesized focus synchronization events, and modal input. The app shortcut
suite checks focused control activation, dialog dismissal, and preserved text
editing and Tab traversal. The details-panel suite checks held Escape.

The native `integration_test/keyboard_shortcuts_linux_test.dart` checks actual
pause, repeated and rapid seek, volume, mute, fullscreen, menu dismissal, source
switching, and completion recovery. It also holds Escape across fullscreen
exit. It runs in `scripts/ci/run_regressions.sh` with a generated 30-second video
and isolated XDG directories. Run it independently with:

```bash
bash scripts/ci/generate_regression_video.sh build/keyboard-fixtures/regression.mp4
bash scripts/ci/run_display.sh x11 flutter test \
  integration_test/keyboard_shortcuts_linux_test.dart -d linux \
  --dart-define=VPFL_TEST_VIDEO="$PWD/build/keyboard-fixtures/regression.mp4" \
  --reporter expanded
```

These tests inject Flutter key events. They do not establish physical keyboard,
compositor repeat settings, or native file-picker behavior on every desktop.

`test/ui/player_menu_shortcuts_test.dart` covers shortcuts with a popup menu
open: Space, held Space, rapid open/Space cycles with and without reduced
motion, Escape and held Escape, arrow keys, focused menu items, and dialogs.
`test/ui/video_controls_overlay_test.dart` covers hidden-control focus, keyboard
reveal, tooltip dismissal, shared motion timing, reduced motion, and player
menu/dialog cleanup when controls unmount or sources change.
`test/ui/shell/app_shell_test.dart` covers closing the details panel on
navigation.

## Fullscreen interaction tests

Explicitly test the top-bar contract:

```text
mouse moves in center
→ top bar remains hidden

mouse enters top activation zone
→ top bar appears

pointer leaves / idle timeout
→ top bar hides
```

Bottom playback controls can use their separate visibility policy.

## Window maximize state tests

The title-bar widget test sends a native `maximizedChanged` event without a
Flutter size change and checks both Maximize and Restore. The Linux integration
test `integration_test/window_state_linux_test.dart` uses an external X11 window
manager action to maximize and restore the real GTK window. Run it with
Openbox (or Metacity), Xvfb, D-Bus, Python GI, and `wmctrl` installed:

```bash
bash scripts/ci/run_desktop_regressions.sh
```

The command gives FileManager1 a private D-Bus session and tests maximize/
restore under an isolated X11 window manager. It runs on desktop-risk PRs and
on every release candidate.

## Integration tests

Use real Linux/native integration for things widget tests cannot prove:

* actual media open
* first frame
* pause
* seek
* audio
* embedded subtitle selection
* external subtitle file
* fullscreen
* resize during playback
* dispose and reopen
* file picker
* saved folder access
* `vpfl <file>`
* Flatpak execution

## Async tests

Do not use arbitrary sleeps as the main synchronization mechanism.

Wait for meaningful signals:

* first-frame/loaded state
* expected stream event
* widget appearance
* operation completion

Use timeouts that fail with useful diagnostics.

## Database tests

Use temporary databases.

Test:

* create
* update
* delete
* transactions
* migrations
* duplicate handling
* interrupted operations
* missing folder state
* history retention
* playlist persistence

Never use the developer's real database.

## Filesystem tests

Use temporary folder trees.

Include:

* empty folder
* nested folders
* spaces
* Unicode
* duplicate names
* moved files
* deleted files
* inaccessible source when practical
* symbolic links when relevant

## Golden tests

Use goldens for stable Flutter UI:

* Home
* sidebar
* player controls
* settings
* empty/error states
* light theme
* dark theme

Do not use the real native video texture as the golden source.

Use a deterministic placeholder for the video surface.

## Accessibility

Test important custom controls for:

* semantic labels
* keyboard focus
* adequate target sizes
* text scaling
* contrast
* screen-reader semantics

Icon-only controls need meaningful labels.

## Regression rule

When fixing an important bug:

1. reproduce it with a failing test when practical
2. implement the fix
3. confirm the test passes
4. retain the test

Name the test after the behavior, not only the issue number.

Test the rule behind the bug, not just the exact report. For example, a queue
bug should cover the affected transition, a boundary, and a nearby transition
that must keep working. An input validation bug should cover a valid input,
the invalid class, and a boundary. Use a small table of cases when this makes
the rule easy to see. A test that only repeats the original example can pass
while the same bug remains for every other member of its class.

Before accepting a regression test, check that its assertion would fail with
the original defect still present. Prefer a failing run before the fix when
practical. Assert an observable result rather than mirroring the implementation
or mocking the very behavior under test. Keep fixture data and randomness
deterministic. Run the relevant existing suite as well as the new test, and
investigate failures instead of weakening assertions.

Native claims need native evidence: widget tests alone cannot establish that
media decodes, a frame is visible, a subtitle renders, a window changes state,
or an installed package launches. Use the corresponding integration lane where
the change affects that behavior, and distinguish decoded frame checks from
final compositor output in the report.

## Performance tests

Measure release/profile builds for:

* startup
* idle CPU
* RSS
* library scrolling
* scan while playing
* 1080p playback
* repeated seek
* repeated open/close
* fullscreen
* X11/Wayland where available

## Suggested test structure

Place unit and widget tests under `test/data/`, `test/routing/`, or `test/ui/`
near the behavior they cover. Linux tests live in `integration_test/`; use the
existing playback, lifecycle, window, media matrix, and library suites as
starting points. Inspect current filenames before adding or running a test.

## Verification selection

Automatic PR checks use changed paths; release candidates force full coverage.
See the [CI model](ci/README.md) and [test inventory](ci/test-inventory.md).
Physical GPU rendering and optional H.264 hardware decoding can be tested with
`bash scripts/testing/test_gpu.sh --decode`; inspect its local report before
voluntarily sharing it. There are no scheduled or self-hosted runner workflows.
`library_rescan_test.dart` remains an explicitly manual active-library audit;
do not include it in automatic directory-wide integration invocations.

## Local core and compatibility checks

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --reporter expanded
python3 scripts/ci/generate_fixtures.py --out build/ci-video-fixtures
python3 scripts/ci/verify_fixtures.py --dir build/ci-video-fixtures
./scripts/ci/run_display.sh x11 flutter test integration_test/media_matrix_test.dart \
  -d linux --dart-define=VPFL_CI_FIXTURES="$PWD/build/ci-video-fixtures"
bash scripts/ci/generate_regression_video.sh build/ci-video-fixtures/regression.mp4
bash scripts/ci/run_regressions.sh build/ci-video-fixtures
```

The native integration command needs Xvfb and Linux playback libraries. The
manifest has 26 video cases, four external subtitle files, and one embedded
subtitle video. The video cases include audio streams. The
[CI guide](ci/README.md) lists the required distribution and display jobs,
current test assertions, and actual validation status. A decoded mpv
screenshot is not proof of final Flutter composition.

## Completion checklist

```text
[ ] important logic has unit tests
[ ] important UI behavior has widget tests
[ ] error paths are covered
[ ] native behavior has integration coverage where needed
[ ] tests do not depend on arbitrary sleeps
[ ] tests are independent
[ ] test names describe behavior
[ ] accessibility is covered for custom controls
[ ] personal files or production data are never required
```
