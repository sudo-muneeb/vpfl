# VPFL architecture

VPFL follows Flutter's recommended separation between UI and data layers, adapted for Riverpod and a desktop media application.

VPFL does not currently have a domain layer. Add one only if complex shared
business rules justify it.
The diagrams describe dependency direction; consult the current `lib/` tree
before adding a layer or class shown here.

## Layer overview

```text
UI layer
  ↓
View model / Riverpod controller
  ↓
Repository or service
  ↓
SQLite / filesystem / media_kit / Linux desktop APIs
```

Use unidirectional data flow.

```text
data changes
  ↓
repository
  ↓
provider/view model
  ↓
UI

user action
  ↓
provider/view model command
  ↓
repository or service
```

## Playback architecture

Use exactly one foreground player session.

```text
Player widgets
    ↓
playbackServiceProvider
    ↓
PlaybackService
    ↓
media_kit
```

The current player screen obtains the single `PlaybackService` from Riverpod.
`PlaybackService` owns the player and coordinates source changes; persistence
uses separate repositories. Do not add a playback repository only to match an
older diagram. Widgets never call native playback properties directly.

### Player state by update frequency

Do not put all playback fields into one broadly watched object.

Prefer separate providers/selectors for:

```text
current media
playing
position
duration
buffering
volume
speed
playlist
selected subtitle
selected audio track
available tracks
diagnostics
```

The seek bar watches position.

The play button watches playing.

The home screen watches neither.

A position update must never rebuild the entire application shell.

## Session generation

Every media session receives a generation or request ID.

Example race:

```text
open A
metadata for A begins

open B
metadata for B begins

A completes late
```

The late result for A must be ignored.

Use:

* generation numbers
* request tokens
* URI equality checks
* explicit cancellation when possible

## Library architecture

The UI does not browse the filesystem directly.

```text
user adds folder
    ↓
LibraryScanner scans folder
    ↓
LibraryRepository updates SQLite
    ↓
library providers expose indexed data
    ↓
UI renders database results
```

The home screen and All Videos section read SQLite.

A folder refresh runs asynchronously and updates the database incrementally.

## Startup architecture

Do not block launch on folder scanning.

```text
launch
  ↓
initialize Flutter and media_kit
  ↓
open settings/database
  ↓
load cached home data
  ↓
show main window
  ↓
refresh saved folders asynchronously
```

Independent initialization may run concurrently after required prerequisites are ready.

## Media metadata

The current scanner records file size and modification time without decoding
video or extracting stream metadata. If metadata extraction is added later,
bound concurrent requests and measure scan impact before increasing the limit.

## Thumbnails without a separate converter

`ThumbnailService.resolve` checks valid Freedesktop thumbnails, then VPFL's
cached frame, then returns no image so the card shows a placeholder. It
checks the system thumbnail's modification time and its URI when present.
Folder scanning does not generate artwork or decode video.

After a file starts playing and its position reaches ten seconds, the history
recorder may capture one PNG frame if no thumbnail exists and history is
enabled. VPFL stores that frame in its own cache. It never seeks the active
player for artwork and does not write to the Freedesktop thumbnail cache.

## In-flight work deduplication

If several widgets request the same metadata or cached image, share the same pending operation.

Conceptually:

```text
key → Future<Result>
```

Examples:

```text
media id → metadata request
media id → cached thumbnail lookup
folder id → refresh request
```

Remove completed in-flight entries.

## Persistence

Use SQLite as the source of truth for local application records.
VPFL uses Drift with a versioned schema. The Linux database is stored at
`$XDG_DATA_HOME/vpfl/vpfl.sqlite`, falling back to
`~/.local/share/vpfl/vpfl.sqlite` when `XDG_DATA_HOME` is unset. Keep migration
steps in `AppDatabase.migration` and increase `schemaVersion` for every schema
change.

The implemented tables and migrations are in
`lib/data/model/app_database.dart`. The records below are design examples for
future needs, not a list of tables to create for an unrelated change.

### MediaEntry

```text
id
saved_folder_id
accessible_uri
relative_path
display_name
file_size
modified_at
duration
width
height
container
thumbnail_key
```

### PlaybackHistory

```text
media_id
last_opened_at
position_ms
completed
watch_count
```

### SavedFolder

```text
id
accessible_uri
display_name
portal_document_id when available
recursive
last_scan_at
availability
```

### Playlist

```text
id
name
created_at
updated_at
```

### PlaylistItem

```text
playlist_id
media_id
position
missing_state
```

### MediaPreferences

```text
media_id
audio_language
subtitle_language
subtitle_source
subtitle_delay
audio_delay
speed
```

### Settings

```text
theme_mode
use_system_accent
volume
resume_policy
history_enabled
scan_preferences
render_preferences
```

## Relative media identity

For media beneath a saved folder, preserve the saved root plus relative path.

Do not use filename alone as identity.

Do not hash an entire large video merely to create a record.

## Resume policy

The history recorder creates a row after playback enters the playing state.
It uses a normalized absolute file URI as the key, so a local path supplied by
media_kit's directory queue and a `file://` URI refer to the same record.
Renaming or moving a file gives it a new key; VPFL does not identify files by
content. A missing file's history remains until the user removes it.

Save position:

* each time position advances at least five seconds since the last checkpoint
* on pause
* after a seek that moves position by at least five seconds
* before source switch
* during controlled app shutdown

The playback service reads the resume setting and saved point for every source
open, including queue navigation. A saved point is eligible after ten seconds,
unless the record is completed. It waits for the new media's duration, seeks
once, and checks the resulting position. The recorder withholds new progress
writes while the source is opening or a seek is unverified, preserving the last
known point if loading or restoration fails. A superseded source generation
cannot apply a late seek to the next file. Progress writes also wait for their
own session's history-start write, so a slow database insert cannot drop the
first checkpoint or a final save.

Completion requires both at least 90% watched and no more than 15 seconds
remaining. A completed row stays visible with full progress, but its resume
position is cleared so a new play starts at the beginning. History disabled
stops new history and thumbnail writes while retaining existing records;
resume can still read those records. Resume disabled starts at the beginning
while history recording remains independent.

Home displays eight Recent cards from a query of at most twenty rows. These
limits do not delete stored rows. VPFL has no automatic age or count expiry:
resume points remain until a user removes a Recent card or confirms Clear
playback history in Settings. This favors reliable long-term resume with small
SQLite rows and makes deletion explicit. No schema migration is needed; rows
from older database versions remain readable. A position already cleared by
the earlier completion rule cannot be reconstructed. For comparison,
[MPC-HC 2.8.0](https://github.com/clsid2/mpc-hc/releases/tag/2.8.0) added
optional age pruning (365 days by default),
[mpv](https://mpv.io/manual/stable/#resuming-playback) uses per-file Watch Later
records, [Kodi](https://kodi.wiki/view/HOW-TO:Modify_automatic_watch_and_resume_points)
distinguishes watched status from a resume point, and
[VLC for Android](https://docs.videolan.me/vlc-android-user/more/settings/extra_video.html)
offers Never, Ask, and Always resume choices. These are design references, not
claims that the players have identical retention rules.

## Native resource ownership

Services own:

* media_kit player lifecycle
* stream subscriptions
* database handles
* filesystem watchers if later added
* Linux desktop channels

Every resource owner needs explicit cleanup.

## Theme architecture

VPFL has its own visual identity.

```text
VPFL theme tokens
  ├── light
  └── dark
```

Optional Linux integration may provide:

* system brightness
* system accent
* selected color hint

The adapter maps those values into VPFL tokens.

The desktop theme must not replace VPFL's spacing, shapes, typography, animations, or component layout.

## Single instance

The architecture must allow a future single-instance implementation.

All media opening should route through one application command:

```text
OpenMedia(path)
```

The same command should be usable by:

* command line
* Open With
* file picker
* drag and drop
* recent item
* library item

## Media compatibility checks

`PlaybackService` is the application-owned path for native playback tests.
The [CI guide](ci/README.md) records the video fixture manifest and current
decoded-frame assertions. An mpv screenshot checks decoded pixels; a separate
compositor capture is still needed to prove final Flutter presentation.
