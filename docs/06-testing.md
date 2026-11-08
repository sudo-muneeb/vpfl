# Testing VPFL

Run checks from the repository root using the SDK and dependencies in
[CONTRIBUTING](../CONTRIBUTING.md#set-up-a-development-checkout). The
[CI guide](ci/README.md) owns hosted job definitions and full native commands.
Do not run multimedia CI solely for documentation edits: review links, paths,
commands, claims, and `git diff --check` instead.

## Lightweight local checks

For application code:

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --reporter expanded
```

For the internal desktop plugin, also run its package tests explicitly:

```bash
flutter test packages/vpfl_desktop_linux/test/vpfl_desktop_linux_test.dart
```

For changes to Python CI harnesses:

```bash
python3 -m unittest discover -s test/ci -p 'test_*.py' -v
```

These tests do not launch native video windows. A Linux release build checks
compilation and bundling, separately from runtime behavior:

```bash
flutter build linux --release
```

## Existing unit and widget coverage

`test/data/` covers isolated Drift persistence/migrations, history/resume rules,
scanner policy and incomplete walks, thumbnails, metadata cancellation,
source identity, open coordination, queue progression, subtitle file identity
and delay, and desktop service behavior. `test/routing/` covers local media
arguments. Tests use temporary or in-memory databases and temporary file trees.

`test/ui/` covers Home/library cards and context actions, Details, shell and
top-bar navigation, player controls and overlays, output size/alignment,
settings, themes, and seek icons. The checked-in goldens cover seek icons at
multiple scales/themes; there is no complete screen golden suite.
`test/ci/` tests fixture/pixel oracles and other harness logic, including
negative samples that must be rejected.

Add tests at the lowest useful layer. Keep assertions on user-visible results
or stable contracts rather than widget nesting or copies of the algorithm.
For async behavior, await meaningful state/completion signals with diagnostic
bounds. Test the affected input/transition class, relevant boundaries, and
neighboring behavior. A regression assertion should reject the original bug;
use a pre-fix run or controlled fault injection when practical. See
[AGENTS](../AGENTS.md#preserve-test-integrity) for agent test-integrity rules.

## Native and multimedia checks

`integration_test/` contains Linux tests requiring Flutter's runner, libmpv,
a display stack, and suitable fixtures. Native tests are more expensive and
must be selected for the affected behavior:

- `media_matrix_test.dart`: fixture tracks, decoded RGB patches, pause, seek,
  resume, completion, stop, renderer/backend selection. Audio stream assertions
  with a null sink do not establish audible output.
- Playback, queue, repeat-one, resume, open-failure, codec-recovery, inspector,
  and lifecycle suites: actual source transitions and persistent resume,
  recovery, Home/reopen, and controller reuse.
- Subtitle integration, file-identity, picker, delay, and lifecycle cases:
  effective native selection/counts, rejected-load recovery, stale operations,
  timing, and source resets.
- `subtitle_window_linux_test.dart`: paired CC On/Off X11 captures, authored
  styles, native-size sharpness, stopped-resize recovery, and video-fit pixels.
- `window_state_linux_test.dart`: external GTK maximize/restore;
  `default_manager_linux_test.dart` and `file_manager1_linux_test.dart`:
  native desktop services. Some cases require explicit opt-in environment
  variables; read each test's prerequisites before invoking it.
- Metadata and library tests: real media inspection/open failures. The
  active-library rescan case is opt-in and touches the selected profile;
  use isolated data for normal testing.

For the complete media/regression sequence, use
[CI: Run locally](ci/README.md#run-locally). It generates/verifies the short
matrix **and** the longer regression MP4/MKV before running the regressions.
The old resume example omitted regression-fixture generation; the matrix
generator alone does not create `regression.mp4`.

Use the existing display wrapper to isolate XDG directories and provision
Xvfb/Weston sessions. Native subtitle reproduction commands live in the
[native comparison](ci/native-subtitle-verification.md) and
[window check](ci/subtitle-window-checks.md) guides. Run the documented
subtitle test invocations separately; a combined Flutter-runner lifecycle
failure is recorded in the historical reports.

For external maximize/restore, with Xvfb, Metacity, and `wmctrl` installed:

```bash
xvfb-run -a bash -c 'metacity --replace --no-composite >/tmp/vpfl-metacity.log 2>&1 & sleep 2; VPFL_TEST_EXTERNAL_MAXIMIZE=1 flutter test integration_test/window_state_linux_test.dart -d linux'
```

That setup delay starts the window manager; application assertions still wait
for observable window state. Use [native packaging](compatibility/native-packages.md)
for installed-package tests; compilation alone does not validate dependencies,
launcher integration, or final window output.

## Evidence and limits

A decoded mpv screenshot, Flutter texture dimensions, a compositor capture,
a physical GPU renderer, and an observed hardware decoder are different
assertions. Report which boundary a test verifies. Xvfb/Mesa software GL is
not physical-GPU evidence; native/headless Wayland tests do not prove visible
subtitles under a desktop compositor. See [CI limits](ci/README.md#known-limits).

Performance targets in [04-performance.md](04-performance.md) require named
profile/release measurements, including idle, scan while playing, large-library
scrolling, repeated source changes, resize/fullscreen, and resource trends.
They are not measured by the normal PR fixture suite. Accessibility review
should include semantics, focus, keyboard operation, target sizes, contrast,
and text scaling for affected custom controls.

Record exact commands, exit status, environment, fixtures, and remaining gaps.
Historical test counts describe their checkpoint, not the current suite size.
Never use personal media/database state as a normal test fixture or count
unrun checks as passes.
