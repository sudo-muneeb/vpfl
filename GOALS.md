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

## Previous milestone

### Goal 0 — Playback compatibility and repository baseline — Core complete

The Linux release build and single-file playback path are established.
Hardware GL video rendering is verified on X11, and the integration run
confirmed playback, seek, and pause. Flatpak build/run is deferred to Goal 7
because `flatpak-builder` is unavailable in this environment. First-frame
capture, hardware decoder state, Wayland, and dispose/reopen remain unverified.
The optional CUDA probe warning is expected on this AMD machine and is not a
playback blocker.

The local `media_kit_video` patch is maintained as a small diff plus a refresh
script; use `./tool/update_media_kit_video.sh <version>` to rebase it on a
published package release.

## Previous milestone

### Goal 1 — Application architecture and shell — Complete

**Objective:** Establish feature UI, semantic themes, routing, and app shell.
**Files/modules:** `lib/ui/core/`, `lib/ui/shell/`, `lib/routing/`.
**Dependencies:** Goal 0 playback baseline.
**Acceptance criteria:** Home, All Videos, Folders, and Settings navigation
works with VPFL light/dark theme tokens.
**Tests required:** Shell/sidebar widget behavior and light/dark rendering.
**Risks/unknowns:** Final responsive dimensions remain design-tunable.

**Result:** Added responsive expanded/compact sidebar navigation, home and
library/folder empty states, and a working System/Light/Dark appearance
selector. Navigation and theme widget tests pass.

### Goal 2 — Playback foundation — Complete

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

**Result:** Added serialized latest-request-wins source opening, queue
navigation and shuffle, relative seeking, playback speed, volume/mute, track
selection, and fullscreen controls. Coordinator and widget tests pass; the
Linux integration run verified playback, seek, pause, speed, volume, and moving
to the next queue item. The integration environment fell back to software GL,
so this run does not verify hardware rendering.

## Current goal

### Goal 3 — Persistence and recent media — Complete

**Objective:** Persist successful playback history, resume position, and
settings in versioned SQLite storage.
**Files/modules:** `lib/data/model/`, repositories/services, domain models.
**Dependencies:** Goal 2; Drift selected for versioned SQLite storage.
**Acceptance criteria:** Recent items and one-time resume survive restart;
failed/private sessions follow the documented history policy.
**Tests required:** Temporary-database CRUD, migrations, resume and privacy
unit/widget tests.
**Risks/unknowns:** Migration backup/recovery policy needs implementation before
later schema upgrades.

**Result:** Added schema version 1 with Drift, recent playback history, watched
position, completion state, and app preferences stored beneath XDG data home.
History starts after playback enters the playing state; failed opens create no
entry. Disabling history stops new recording and keeps existing entries. Home
shows recent items, resume seeks once when reopening, and appearance/history/
resume preferences persist. The Linux shell and player now share a top bar with
the VPFL logo, Open File, quick appearance selection, and Settings. The native
file selector supports Linux.

Repository tests cover schema initialization, settings, completion/resume
rules, reactive recent history, and disk persistence after reopening. The
Linux integration test verified stored history and resume position; all 18
unit/widget tests, analysis, and the Linux release build pass. The integration
test fell back to software GL; GPU rendering is not assessed by this phase.

### Goal 4 — Saved folders and indexed library — Implemented

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

**Result:** Added schema version 2 for saved roots and indexed media, with an
upgrade migration from version 1. The library scans saved roots at launch and
when added or refreshed, walks directories without following symlinks, batches
index updates, and skips media whose size and modified time have not changed.
It does not read video contents or generate artwork. The sidebar lists saved
roots; folder browsing, All Videos, and Home now show indexed media, and video
cards open playback. The library uses a lazy grid. The VPFL mark now appears in
the sidebar, GTK window, and Flatpak app icon; the packaged PNG is correctly
512 × 512.

`flutter analyze` and a Linux release build pass. Focused Goal 4 tests and
Flatpak portal persistence behavior still need runtime validation.

## Next goals

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
- Added a minimal player, the single-session `PlaybackService`, CLI path
  routing, VPFL light/dark theme baseline, and six focused routing/control
  tests. `media_kit` packages are pinned to 1.2.6 / 2.0.1 / 1.0.7.
- `flutter analyze`, all six `flutter test` cases, and
  `flutter build linux --release` pass. The Linux playback integration run
  advances, seeks, and pauses the 1440p sample.
- Added the Phase 0 compatibility report and an early Flatpak manifest/build
  script using Freedesktop 26.08. The Flatpak build itself is unverified.
- Fixed Linux hardware-render context creation by carrying a narrow patch to
  `media_kit_video` 2.0.1 under `third_party/`. The EGL context now uses a 1×1
  pbuffer surface, avoiding a surfaceless `eglMakeCurrent` failure on this Mesa
  driver. Debug integration and release smoke runs with all four local videos
  (4K landscape, 4K portrait, and two 1440p samples) initialized the hardware
  GL context.

## Known issues

- The repository started as a Flutter counter template. Playback now has a
  baseline service and UI; repositories, database, home library, and saved
  folders are still unimplemented.
- `docs/07-roadmap.md`, `docs/09-sources.md`, and
  `TESTING_GUIDELINES.md` referenced by the brief are absent. Phase 0 is taken
  from the explicit first-task section in `docs/08-coding-agent-brief.md`.
- `.agents/PERFORMANCE.md` mentions conversion progress, which conflicts with
  the current product scope and coding brief. Conversion remains excluded.
- The upstream hardware-render failure came from reading Flutter's
  thread-local EGL context in a GTK callback after Flutter moved it to the
  raster thread. The local patch obtains EGL from GDK and creates an isolated
  context backed by a pbuffer. X11 rendering is verified; Wayland and visible
  first-frame presentation still need verification.
- mpv may log `Cannot load libcuda.so.1` while probing its optional NVIDIA
  backend. This is expected on the AMD test machine and does not affect
  rendering. VAAPI or other hardware decoding selection remains unknown.
- `flatpak` 1.14.6 exists, but `flatpak-builder` is not installed. No media
  fixture is tracked in the repository; the user's `videos/` directory is
  deliberately ignored by Git. Installing the missing package was declined.

## Decisions discovered during implementation

- The product scope and coding brief are more specific than the generic Flutter
  style notes: Riverpod is the documented state approach, and conversion stays
  out of scope.
- The Linux manifest uses existing `com.app.vpfl` runner identity as a
  placeholder. Choose the project-owned reverse-domain ID before public
  packaging.
- The Flatpak manifest targets Freedesktop 26.08, the current stable runtime
  when this baseline was prepared.
- The upstream hardware-render failure was caused by reading Flutter's
  thread-local EGL context in a GTK callback after Flutter moved that context
  to its raster thread. The local patch obtains EGL from GDK and creates an
  isolated OpenGL ES 2 context backed by a pbuffer.
