# VPFL coding agent brief

This brief contains design guidance from early implementation work. Check the
current code, tests, and [CI guide](ci/README.md) before treating an example or
milestone as implemented behavior.

## Architecture

Follow the project structure in `03-project-structure.md`.

Use:

```text
ui/
data/
routing/
```

Organize UI by feature.

Organize data by repositories/services.

Keep models near their owners; introduce a shared domain model only when
multiple layers need it.

Use Riverpod for view-model/state responsibilities.

Do not create a single global widgets folder.

## Playback

Use one foreground `media_kit` player.

Keep:

```text
widgets
→ playbackServiceProvider
→ PlaybackService
→ media_kit
```

Persistence uses separate repositories. Add a playback repository only when
the behavior needs one, not to match an older layer diagram.

Do not expose raw native playback properties in widget code.

Use stream/event state rather than polling.

Isolate high-frequency position state.

Protect source switches against stale async results.

## No conversion feature

Do not add:

* conversion UI
* transcoding queue
* conversion service
* standalone conversion executable
* background media conversion jobs

V1 is a player and local library.

## Thumbnails

Do not build a separate background video preview system.

Use placeholders for uncached items.

After playback starts successfully, a cached frame may be captured through the playback library if useful.

Never seek the active player just to create artwork.

## Home

Build:

```text
Recent videos
All videos
```

Both should render from cached/indexed data.

The home screen must not wait for a full saved-folder scan.

## Sidebar

Build:

```text
Home
All Videos

Folders
+ Add Folder
saved folder entries

Settings
```

## Player UI

Primary controls:

```text
seek slider
play/pause
seek backward
seek forward
speed
shuffle when relevant
volume/mute
overflow menu
fullscreen
```

Subtitles and speed have direct controls at wider widths and move into More
options below 600 logical pixels. Audio and video track selection stays in
More options when those tracks are available.

## Fullscreen interaction

The bottom controls may appear on general mouse movement.

The fullscreen top bar must **not** appear on general mouse movement.

It appears only when the pointer enters the top-edge activation zone.

Test this behavior.

## Theme

VPFL visual theme is the default.

All product colors must come from `ui/core/themes`.

Do not hard-code product colors in feature widgets.

Optional system theme integration may affect brightness/accent tokens only.

Do not introduce Yaru styling as the default design.

## Library

UI reads SQLite/indexed data.

Folder scanners update the database asynchronously.

Use bounded metadata concurrency.

Skip unchanged files.

Do not read every media file during startup.

## Command line

Support only:

```bash
vpfl
vpfl <file>
```

No CLI flags unless a later requirement explicitly adds them.

All file-open entry points should call the same internal action.

## Linux

Validate the existing Flatpak manifest and its runtime behavior before making
Flatpak support claims.

Use user-granted folder access.

Keep launcher/application identity consistent.

Do not rely on host development packages.

## Testing

Follow `06-testing.md`.

The executable pull-request checks and their observed status are documented
in [the CI guide](ci/README.md). Keep `ci/media-matrix.json`, the video file
policy, and advertised MIME formats aligned. Do not describe an unrun GitHub,
package, compositor, or hardware lane as passed.

Important rules:

* one behavior per test
* behavior-based names
* unit tests for logic
* widget tests for UI
* integration tests for real native behavior
* no arbitrary sleeps as normal synchronization
* add regression tests for important bugs

## Performance

Follow `04-performance.md`.

Especially:

```text
do not block UI on scans
do not poll player state
do not broadly watch position state
do not eagerly build the whole library
do not perform media I/O in build()
```

## Current milestone status

The initial playback baseline and native DEB, RPM, and Arch package checks are
documented in the [CI guide](ci/README.md). Flatpak remains a planned release
target; use the [release checklist](ci/release-checklist.md) for the validation
still needed before a release claim.
