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

```text
test/
  ui/
    home/
    player/
    library/
    folders/
    settings/

  data/
    repositories/
    services/

  domain/
    models/

  routing/

  golden/
  accessibility/
  fixtures/

integration_test/
  startup_test.dart
  playback_test.dart
  subtitles_test.dart
  folder_access_test.dart
  command_line_open_test.dart
  lifecycle_test.dart
```

## Normal CI

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --reporter expanded
python3 scripts/ci/generate_fixtures.py --out build/ci-video-fixtures
python3 scripts/ci/verify_fixtures.py --dir build/ci-video-fixtures
./scripts/ci/run_display.sh x11 flutter test integration_test/media_matrix_test.dart \
  -d linux --dart-define=VPFL_CI_FIXTURES="$PWD/build/ci-video-fixtures"
```

The native integration command needs Xvfb and Linux playback libraries. The
manifest has 26 video cases, four external subtitle files, and one embedded
subtitle video. The video cases include audio streams; standalone audio files
are outside the V1 policy. The [CI guide](ci/README.md) lists the required
distribution and display jobs, current test assertions, and actual validation
status. A decoded mpv screenshot is not proof of final Flutter composition.

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
