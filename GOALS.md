# VPFL Goals

## Project assessment

VPFL is intended to be a local Linux desktop video player, distributed first
as a Flatpak. V1 centers on one foreground `media_kit` session, recent media
and resume history, user saved folders, subtitles, accessibility, and a
responsive player/library UI. Conversion, transcoding, and broad host access
are out of scope. Direct network playback and advanced native controls are
later milestones.

Flutter UI sends actions through feature view models/providers and
repositories to services that own `media_kit`, SQLite, filesystem access, and
Linux APIs. SQLite owns VPFL records; `media_kit` owns live playback state.
Thumbnails resolve from valid Freedesktop cache, VPFL cache, then placeholder;
frames may be cached after natural playback, never by seeking the active player.
The UI loads cached data before asynchronous scans. Position events stay
isolated from the app shell. Linux packaging must include native playback
libraries and use user-granted folder access. Tests are focused unit and widget
tests plus Linux/native integration checks; hardware and release claims require
runtime evidence.

## Current goal

### Goal 0 — Playback compatibility and repository baseline — In progress

**Objective:** Replace the starter counter with a minimal, locally playable
Linux app and prove the selected Flutter/media stack before expanding the UI.

**Files/modules:** `lib/main.dart`, initial `lib/data/` and `lib/ui/` player
modules, `pubspec.yaml` / `pubspec.lock`, Linux runner, `flatpak/`, and this
tracker.

**Dependencies:** Flutter 3.47.5 / Dart 3.13.4 are installed. Select exact
`media_kit` package versions and retain the lockfile. Flatpak tooling and a
media fixture are needed for full native verification.

**Acceptance criteria:** `vpfl` launches normally; `vpfl <file>` opens a local
file through one application action; one `media_kit` player is owned below the
UI; a Linux release build succeeds; a thin Flatpak manifest includes the
playback runtime; the compatibility report distinguishes tested behavior from
unverified hardware claims.

**Tests required:** Focused unit/widget coverage for argument/open routing and
player controls; Linux playback checks for open, first frame, pause, seek, and
dispose/reopen. Run formatter, analyzer, tests, and release build.

**Risks/unknowns:** The `media_kit` Linux rendering behavior must be checked on
the installed Mesa/X11 setup. Flatpak tooling or native package access may be
unavailable in this environment. No media fixtures are currently in the repo.

## Next goals

### Goal 1 — Application architecture and shell

**Objective:** Establish feature UI, semantic themes, routing, and app shell.
**Files/modules:** `lib/ui/core/`, `lib/ui/shell/`, `lib/routing/`.
**Dependencies:** Goal 0 playback baseline.
**Acceptance criteria:** Home, All Videos, Folders, and Settings navigation
works with VPFL light/dark theme tokens.
**Tests required:** Shell/sidebar widget behavior and light/dark rendering.
**Risks/unknowns:** Final responsive dimensions remain design-tunable.

### Goal 2 — Playback foundation

**Objective:** Add event-driven playback state, queue actions, and media open
routing while retaining one foreground session.
**Files/modules:** `lib/data/services/`, `lib/data/repositories/`,
`lib/ui/player/`, shared domain playback models.
**Dependencies:** Goal 0 compatibility baseline, Goal 1 shell.
**Acceptance criteria:** Source switches reject stale events; controls cover
play/pause, seek, speed, volume, fullscreen, and capability-gated tracks.
**Tests required:** State/session unit tests, control widget tests, native
playback integration.
**Risks/unknowns:** Native capabilities depend on the packaged mpv version.

### Goal 3 — Persistence and recent media

**Objective:** Persist successful playback history, resume position, and
settings in versioned SQLite storage.
**Files/modules:** `lib/data/model/`, repositories/services, domain models.
**Dependencies:** Goal 2; database package decision.
**Acceptance criteria:** Recent items and one-time resume survive restart;
failed/private sessions follow the documented history policy.
**Tests required:** Temporary-database CRUD, migrations, resume and privacy
unit/widget tests.
**Risks/unknowns:** Migration backup/recovery policy needs implementation.

### Goal 4 — Saved folders and indexed library

**Objective:** Add granted-folder persistence, bounded asynchronous scans, and
incremental SQLite indexing.
**Files/modules:** `lib/data/services/`, folder/media repositories,
`lib/ui/folders/`, `lib/ui/library/`.
**Dependencies:** Goal 3 and Linux folder picker/portal choice.
**Acceptance criteria:** Cached library renders before scans; scans skip
unchanged media and never decode files for artwork.
**Tests required:** Temporary-tree scanner/repository tests and folder/library
widget tests.
**Risks/unknowns:** Persistent portal grants differ across desktops/Flatpak.

### Goal 5 — Player UI

**Objective:** Complete primary controls, menus, subtitles, diagnostics, and
fullscreen interaction.
**Files/modules:** `lib/ui/player/`, theme tokens, playback adapters.
**Dependencies:** Goals 1 and 2.
**Acceptance criteria:** Secondary actions live in overflow; fullscreen top
bar activates only at the top edge; position changes do not rebuild the shell.
**Tests required:** Control, menu, seek, accessibility, and fullscreen widget
tests; relevant native media cases.
**Risks/unknowns:** Subtitle and diagnostic exposure varies by backend.

### Goal 6 — Linux integration

**Objective:** Add launcher identity, file association, file picker/drop, and
window integration for Linux.
**Files/modules:** `linux/`, desktop metadata, `lib/data/services/`.
**Dependencies:** Goals 0 and 2.
**Acceptance criteria:** `vpfl <file>` and Open With use the shared open
action; executable, desktop file, icon, and app ID agree.
**Tests required:** Linux runner/file-open integration on X11 and Wayland when
available.
**Risks/unknowns:** Existing GTK runner is the generated Flutter template.

### Goal 7 — Flatpak

**Objective:** Deliver a reproducible sandboxed package with bundled playback
libraries and narrow permissions.
**Files/modules:** `flatpak/`, app metadata, release documentation.
**Dependencies:** Goals 0 and 6.
**Acceptance criteria:** Clean offline build and launch without host libmpv;
granted folders and history survive restart/update.
**Tests required:** Flatpak build/install/launch, media open, and permission
checks.
**Risks/unknowns:** Flatpak builder/runtime availability and source checksums.

### Goal 8 — Testing and hardening

**Objective:** Close release gates for accessibility, lifecycle, data safety,
performance, and supported media formats.
**Files/modules:** `test/`, `integration_test/`, CI/release metadata, all
modules as findings require.
**Dependencies:** Goals 0–7.
**Acceptance criteria:** Documented V1 checklist passes on release artifacts;
performance and hardware claims include measurements.
**Tests required:** Full focused suite, Linux integration matrix, accessibility
review, and release/profile measurements.
**Risks/unknowns:** Wayland, NVIDIA, codecs, and target Flatpak runtime coverage.

## Completed

- Read the available VPFL product, architecture, structure, performance,
  Linux/Flatpak, testing, coding-agent, and UI design documentation.
- Inspected the starter Flutter app, lockfile, Linux runner, and existing test.
- Confirmed Flutter 3.47.5, Dart 3.13.4, and Linux Mesa/X11 toolchain are
  installed. The Linux target reports an AMD Radeon GPU; this does not verify
  video hardware decoding or media rendering.

## Known issues

- The repository is a Flutter counter template with no player, repositories,
  database, feature structure, or meaningful test coverage.
- `docs/07-roadmap.md`, `docs/09-sources.md`, and
  `TESTING_GUIDELINES.md` referenced by the brief are absent. Phase 0 is taken
  from the explicit first-task section in `docs/08-coding-agent-brief.md`.
- `.agents/PERFORMANCE.md` mentions conversion progress, which conflicts with
  the current product scope and coding brief. Conversion remains excluded.
- Flatpak tooling and media fixtures have not yet been checked.

## Decisions discovered during implementation

- The product scope and coding brief are more specific than the generic Flutter
  style notes: Riverpod is the documented state approach, and conversion stays
  out of scope.
