# CI test inventory and lane responsibilities

Audited against `origin/main` c0442ea before restructuring. Test bodies and
advertised formats remain intact. Commands run from the repository root;
Flutter is pinned to 3.47.5. Unless stated otherwise, native commands use
`scripts/ci/run_display.sh x11` (Xvfb, isolated XDG config/data/cache), libmpv,
GTK, Mesa, and a separate `flutter test FILE -d linux --reporter expanded`
invocation for each file. The wrapper saves output in `build/ci-logs/`.
Native checks use synthetic fixtures and temporary/in-memory databases.

Individual test runtimes were not available in the Actions API summaries;
job/step durations below include compilation/setup where applicable and are
not per-test timings. New local command timings are in
[the validation record](restructure-validation.md). Do not add estimates as
measurements. Classification details are in [the CI guide](README.md).

## Core quality and fixture coverage

Every non-documentation PR and every release runs:

- `flutter pub get --enforce-lockfile`: root lockfile resolution.
- `dart format --output=none --set-exit-if-changed lib test integration_test`.
- `flutter analyze`: application and integration source analysis.
- `flutter test --reporter expanded`: **every** file under `test/` ending in
  `_test.dart`. No test list filtering or exclusions are introduced.
- `flutter analyze packages/vpfl_desktop_linux` and
  `flutter test packages/vpfl_desktop_linux/test --reporter expanded`:
  plugin channel contracts, encoded URIs, per-MIME defaults and failures.
  These were omitted as an explicit suite in the old quality job. Root
  dependency resolution supplies the plugin dependencies without another
  independent dependency installation.
- `python3 -m unittest discover -s test/ci -p 'test_*.py' -v`:
  `test_commit_messages.py` (heading format/length),
  `test_subtitle_fixture_suite.py` (manifest/source/hash/stream integrity),
  `test_native_subtitle_harness.py` (comparison validation),
  `test_subtitle_window_pixels.py` (visible/absent pixel metrics),
  `test_subtitle_sharpness.py` (sharpness geometry/thresholds), and
  `test_installed_subtitle_frame.py` (installed capture validation).
  New `test_ci_policy.py` checks selection boundaries and rejects failed,
  canceled, unexpectedly skipped/successful, missing, and malformed results,
  including a release accidentally receiving PR selection.
- `python3 scripts/ci/generate_fixtures.py --out build/ci-fixtures --subtitle-suite`
  and `python3 scripts/ci/verify_fixtures.py --dir build/ci-fixtures --subtitle-suite`:
  26 video cases with audio, four external subtitles, one embedded-subtitle
  video, and 25 additional subtitle suite files. Manifest hashes, file
  hashes/sizes, codecs, pixel formats, duration, streams, font attachments,
  metadata and FFmpeg decoding are validated. The suite uses the committed
  `test/fixtures/media-matrix.json` and `test/fixtures/subtitles/` sources/font contract.
- `bash scripts/ci/generate_regression_video.sh build/ci-fixtures/regression.mp4`:
  FFmpeg/FFprobe produce and decode 30-second MP4 and 45-second MKV.

The Dart inventory is grouped below; each named file is invoked by the same
unfiltered core command above. These need Flutter's test engine and temporary
files/databases; they do not establish native compositor or driver behavior.

- `test/routing/media_open_request_test.dart`: open request validation.
- `test/ci/completion_observer_test.dart`: natural completion observation.
- `test/data/model/real_media_tracks_test.dart`: real track filtering/labels.
- `test/data/repositories/database_migration_test.dart` and
  `persistence_repositories_test.dart`: migrations and durable repository state.
- `test/data/services/`: `default_app_prompt_service_test.dart`,
  `library_scanner_test.dart`, `linux_file_manager_service_test.dart`,
  `media_format_policy_contract_test.dart`, `media_metadata_service_test.dart`,
  `media_source_identity_test.dart`, `playback_open_coordinator_test.dart`,
  `queue_progression_test.dart`, `subtitle_delay_test.dart`,
  `subtitle_file_identity_test.dart`, and `thumbnail_service_test.dart`:
  prompt decisions, scanning/format policy, URI handling, metadata, source
  identity, open concurrency, queue progression, delay, subtitle identity,
  and thumbnail contracts respectively.
- `test/ui/`: `theme_test.dart`, `seek_ten_icon_test.dart` (committed PNG
  goldens), `video_controls_overlay_test.dart`, `video_output_size_test.dart`,
  and `player_controls_test.dart`: appearance, controls, geometry and actions.
- `test/ui/home/home_screen_test.dart`, `settings/settings_screen_test.dart`,
  `shell/app_shell_test.dart`, and `shell/app_top_bar_test.dart`: home,
  settings, navigation, title-bar state and actions.
- `test/ui/library/`: `media_card_test.dart`, `library_views_context_test.dart`,
  `video_context_menu_test.dart`, and `video_details_panel_test.dart`: library
  presentation, context actions, and metadata UI.

In hosted run 42391780435, old quality took 73 seconds and fixtures 77 seconds;
the old quality job did not explicitly run plugin tests. Those timings do not
predict the revised job durations.

## Ubuntu application regression suite

`bash scripts/ci/run_regressions.sh build/ci-fixtures` runs for **every
non-documentation PR** and every release. It preserves all previously invoked
application suites and adds metadata inspection. Individual invocations:

- `linux_playback_test.dart`, with `VPFL_TEST_VIDEO=regression.mp4`:
  real playback, seek/pause/resume, native video output.
- `library_open_failure_test.dart`, same define: invalid open must not advance
  history/queue; a later valid video recovers.
- `player_inspector_linux_test.dart`, same define: non-modal inspector and
  native diagnostics while playback continues.
- `recoverable_codec_error_test.dart`, same define: injected recoverable
  codec warning must not abort usable playback.
- `resume_playback_test.dart`, same define plus
  `VPFL_TEST_VIDEO_B=regression.mkv`, `VPFL_TEST_VIDEO_B_DURATION=45`:
  temporary SQLite persistence across Home/Recents/restart/source switches,
  failed restore, stale lookup, delayed history writes.
- `queue_playback_test.dart`, `VPFL_TEST_VIDEO=h264_mp4.mp4`: short-fixture
  natural EOF, queue switching and completion observation.
- `repeat_one_replay_test.dart`, `VPFL_TEST_VIDEO=regression.mp4`: repeat
  reopens correctly after a near-EOF seek in a long file.
- `linux_lifecycle_test.dart`, `VPFL_TEST_VIDEO=regression.mp4`,
  `VPFL_TEST_VIDEO_B=h264_mkv.mkv`, `VPFL_TEST_VIDEO_C=vp8_webm.webm`,
  `VPFL_TEST_CYCLES=3`: repeated playback/Home transitions across containers.
- `default_manager_linux_test.dart`, environment `VPFL_TEST_XDG_DEFAULTS=1`:
  GIO default associations in the wrapper's private profile. It already ran
  before this change; it is not a new coverage claim.
- `media_metadata_linux_test.dart`, `VPFL_CI_FIXTURES=build/ci-fixtures`:
  real paused mpv probe and inspection of another file while foreground
  playback remains unchanged. Previously omitted; mocked metadata unit tests
  and the inspector UI did not establish this native behavior.

Old regression step duration: 277 seconds in run 42391780435; 307–384 seconds
in the other sampled runs. It did not include the newly added metadata suite.

## Native desktop lane

`bash scripts/ci/run_desktop_regressions.sh` runs on desktop/plugin/packaging,
shared window, and unknown/high-risk PRs, plus every release:

- `file_manager1_linux_test.dart`: requires `VPFL_TEST_FAKE_FILE_MANAGER1=1`,
  `dbus-run-session`, Python GI, and `test/ci/file_manager1_fixture.py`.
  The Dart test starts the fake service, waits for READY, then verifies exact
  encoded item/folder URI calls and cleans up the service/files. The private
  bus prevents requests reaching the real desktop file manager. Previously
  omitted; plugin channel mocks did not prove native D-Bus interoperability.
- `window_state_linux_test.dart`: requires `VPFL_TEST_EXTERNAL_MAXIMIZE=1`,
  `wmctrl`, Xvfb and Openbox/Metacity. The existing `run_subtitle_window.sh`
  supplies a ready window manager and cleans it up. Tests real WM_CLASS,
  external maximize/restore, title-bar icon and native method-channel state.
  Previously omitted; title-bar widget tests only covered synthetic events.

The Ubuntu disposable dependency installer now explicitly supplies Python GI
and D-Bus. No workstation package installer is invoked by the local GPU tool.

## Media, distributions and displays

`integration_test/media_matrix_test.dart` is invoked with
`--dart-define=VPFL_CI_FIXTURES="$PWD/build/ci-fixtures"` after verification.
It runs full matrices on Ubuntu/Fedora/Arch X11 and Ubuntu
Wayland/XWayland/injected X11 fallback for compatibility-risk PRs and every
release. Low-risk PRs retain the representative Ubuntu playback suite above.
The optional local GPU command invokes this **same** full matrix directly
on the existing desktop, with isolated data/configuration and fresh fixtures.

The matrix asserts all manifest rows, codecs/audio tracks, RGB decoded
screenshots, pause/seek/resume/natural completion/stop, embedded subtitle
track discovery, and UI directory-queue advancement. Display lanes also
assert GTK backend; `VPFL_TEST_FAIL_GPU_INIT=1` requires software fallback.
The local tool reads GPU output and observed H.264 decoder evidence
separately from the matrix's flushed stage log (`VPFL_CI_LOG_DIR` selects a
unique local result directory); the pre-existing `VPFL_CI_REQUIRE_HARDWARE=1` strict rendering
and decoding assertions are preserved. Decoded mpv screenshots alone do not
prove Flutter compositor pixels. Headless GL does not prove physical GPU use.

In run 42391780435 the old native jobs took Ubuntu 626s, Fedora 320s, Arch
325s (including builds/setup); display jobs took 303–354s. Full matrices
remain unchanged in selected high-risk lanes rather than introducing a new
subset manifest. This trades some high-risk runtime for simpler maintenance.

## Native and graphical subtitles

`bash scripts/ci/run_subtitle_regressions.sh build/ci-fixtures` runs five
separate native files with `VPFL_SUBTITLE_FIXTURES` pointing at the verified
suite. Subtitle/player/rendering/dependency/infrastructure risks and every
release select this lane:

- `subtitle_integration_test.dart`: automatic track reuse, rejected load,
  effective native selection and playback recovery.
- `subtitle_file_identity_linux_test.dart`: repeated paths, URI/symlink
  identity, same basename in different directories.
- `subtitle_lifecycle_linux_test.dart`: source changes/dispose drain in-flight
  loading; stale results cannot select another source's subtitle.
- `subtitle_picker_linux_test.dart`: injected picker response, rejection
  snackbar, successful subsequent load, stale picker result rejection.
- `subtitle_delay_linux_test.dart`: signed delay readback, actual cue pixel
  timing, and reset across sources.

These were documented manual invocations but absent from old workflow paths.
The graphical lane indirectly covered captions and some lifecycle transitions;
it did not replace these selection/concurrency/timing assertions.

The same job retains `python3 scripts/ci/run_native_subtitle_checks.py
--fixtures build/ci-fixtures --out build/ci-native-subtitles`. It invokes
`mpv_subtitle_check.py` and `media_kit_subtitle_check.dart` and compares
validated subtitle captures. Requires mpv, pinned media_kit, libass, FFmpeg,
Noto fonts, the attached fixture font and the verified suite. Diagnostics and
JSON/pixel reports are uploaded. This checks native engine layers, not final
Flutter composition.

`subtitle_window_linux_test.dart` runs through `run_display.sh x11` and
`run_subtitle_window.sh`, `VPFL_SUBTITLE_FIXTURES` set, using the **six existing
invocations** without reducing cases/assertions:

1. `VPFL X11 window renders subtitle fixtures through the player UI`.
2. `Home and reopen restore visible subtitles in VPFL window`.
3. `Attached ASS stays sharp at native, resized, and fullscreen sizes`.
4. The same sharpness case with `VPFL_TEST_FAIL_GPU_INIT=1`.
5. `ASS recovers after repeated Linux window resizes` with `VPFL_REFERENCE_VO=x11`.
6. The same resize case/reference with injected software fallback.

These require a window manager, xdotool/wmctrl, screenshot tools, mpv/libass
and fonts. They check final paired CC On/Off pixels, sharpness, geometry,
fullscreen and repeated resize recovery. They are still the slowest lane:
39m03s in run 42391780435, 47m18s in 42407385324 attempt 1 (whole jobs).
No Wayland pixel, text shaping semantics, or real GPU vendor claim follows.

## Package checks

Packaging/desktop/unknown/high-risk changes and every release build DEB/RPM/
Arch using `packaging/scripts/package-linux.sh` or
`scripts/ci/build_arch_package.sh` (which uses `makepkg` under an unprivileged
builder). Existing packaging scripts validate bundle/stage, notices, icons,
ELF paths, desktop/AppStream and declared package dependencies. Package format
metadata inspection also uses dpkg/rpm/namcap where the existing scripts specify.

`bash scripts/ci/run_installed_package.sh DISTRO PACKAGE
build/ci-fixtures/regression.mp4 build/ci-fixtures` runs in fresh matching
containers with explicit 1280x1024 X11 geometry for both smoke phases.
It checks installation, ldd resolution, metadata, launch,
video color bars, ASS/external SRT final pixels, close, removal, and profile
retention. Helpers `installed_app_smoke.sh`, `installed_subtitle_smoke.sh`,
`check_installed_frame.py`, and `check_installed_subtitle_frame.py` remain
shared. Old install jobs took 75–94s in run 42391780435. No assertions removed.

## Release stress and manual-only coverage

Every manual release invokes existing `linux_lifecycle_test.dart` with
`VPFL_TEST_VIDEO=regression.mp4` and `VPFL_TEST_CYCLES=30` under isolated X11.
This was the unique extra nightly invocation; its implementation is reused,
and its failure is required by the release gate. No nightly schedule remains.

`integration_test/library_rescan_test.dart` deliberately requires
`VPFL_RESCAN_ACTIVE_DB=true` and scans saved folders in the active database.
It remains manual, requires informed use of a disposable/copied profile,
and is never blindly globbed into CI. Core scanner/repository tests supply
synthetic filesystem/database coverage without traversing a real library.

Existing manual helpers `packaging/scripts/check-linux-close.sh` (process
close states), `check-default-manager-linux.sh` (isolated GIO drive), and
`clean-install-check.sh` (older clean DEB/RPM launch checks) remain available.
Current automated package smoke uses stronger pixel-based checks and clean
removal; Home/playback cycles do not claim to replace all process-exit stress
states. These helpers were not invoked by the old workflows and are not
silently presented as newly automated release coverage. Real desktop sessions,
physical GPU vendors, upgrades, long performance benchmarks, and Flatpak
remain separate manual/unsupported boundaries in the release checklist.
