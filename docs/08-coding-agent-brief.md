# VPFL coding agent brief

Use the repository documentation as the implementation specification.

## Architecture

Follow the project structure in `03-project-structure.md`.

Use:

```text
ui/
data/
domain/
routing/
```

Organize UI by feature.

Organize data by repositories/services.

Keep shared application models in `domain/models`.

Use Riverpod for view-model/state responsibilities.

Do not create a single global widgets folder.

## Playback

Use one foreground `media_kit` player.

Keep:

```text
widgets
→ view model/providers
→ PlaybackRepository
→ PlaybackService
→ media_kit
```

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

Overflow menu owns secondary actions such as subtitles and audio tracks.

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

Build a working Flatpak early.

Use user-granted folder access.

Keep launcher/application identity consistent.

Do not rely on host development packages.

## Testing

Follow `06-testing.md`.

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

## First implementation task

Complete Phase 0 from `07-roadmap.md`.

Produce:

* minimal player
* release Linux build
* thin Flatpak
* compatibility report
* native playback tests
* exact dependency versions

Do not implement the full product UI until the selected playback stack is proven.
