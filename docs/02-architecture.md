# VPFL architecture

VPFL follows Flutter's recommended separation between UI and data layers, adapted for Riverpod and a desktop media application.

The domain layer is intentionally small. Flutter's architecture guide treats a domain layer as optional and most useful when complex shared business logic justifies it.

## Layer overview

```text
UI layer
  ↓
View model / Riverpod controller
  ↓
Repository
  ↓
Service
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
repository/service
```

## Playback architecture

Use exactly one foreground player session.

```text
Player widgets
    ↓
player providers
    ↓
PlaybackRepository
    ↓
PlaybackService
    ↓
media_kit
```

Widgets never call native playback properties directly.

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
LibraryService scans folder
    ↓
MediaRepository updates SQLite
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

Metadata extraction must be bounded.

Do not run an unlimited future for every media file in a large directory.

Start with a conservative worker pool such as:

```dart
final workerCount =
    (Platform.numberOfProcessors ~/ 2).clamp(1, 4);
```

Tune only after measuring.

## Thumbnails without a separate converter



VPFL does not add a separate conversion or thumbnail-generation executable in V1.

Initial thumbnail policy:

```text
never played media
→ placeholder / file artwork

media successfully starts playing
→ optionally capture one frame using media_kit screenshot support
→ resize/cache that image
→ use it for Recent and library cards
```

Do not seek the active player merely to generate a thumbnail.

For VPFL right now, I would use a 3 level thumbnail strategy and keep it simple.
First choice: reuse the Linux Freedesktop thumbnail cache. Linux desktops commonly store thumbnails under $XDG_CACHE_HOME/thumbnails or ~/.cache/thumbnails, with standard sizes such as 128, 256, 512, and 1024 pixels. The thumbnail filename is the MD5 of the canonical file URI, and validity is checked using metadata such as the original URI and modification time. Freedesktop Specifications
video file
   ↓
check Linux thumbnail cache
   ↓
found + valid?
   ├── yes → use it
   └── no
         ↓
check VPFL cache
         ↓
found?
   ├── yes → use it
   └── no → placeholder

For V1, I would not generate thumbnails for every video during folder scanning. That can make adding a large folder expensive.
Instead, when the user actually plays a video, media_kit already exposes Player.screenshot(), which captures the current video frame as encoded image bytes. Dart packages
So VPFL can do:
movie.mkv
   ↓
user starts playback
   ↓
wait until playback has reached a sensible frame
   ↓
player.screenshot()
   ↓
resize
   ↓
save in VPFL cache
   ↓
future Home/Library cards use it

I would avoid capturing frame 0 because intros frequently start black. Something around the first few seconds after playback starts is more useful, but do not seek just for the thumbnail. Capture once playback naturally reaches a suitable position.
Your V1 thumbnail resolver should therefore be:
ThumbnailService.getThumbnail(media)

1. check memory cache

2. check Freedesktop thumbnail cache
   ~/.cache/thumbnails/

3. check VPFL thumbnail cache
   ~/.cache/vpfl/thumbnails/

4. return placeholder

Then during successful playback:
if VPFL has no thumbnail
and Linux cache has no thumbnail
and playback position > suitable threshold:

    screenshot current frame
    resize it
    save it

I would keep VPFL's own cache separate rather than writing VPFL screenshots into the system Freedesktop cache at first. Reading the system cache is easy. Correctly writing compliant system thumbnails means also storing the required PNG metadata, canonical URI, modification time, using atomic writes, handling failures correctly, and respecting the Freedesktop specification.

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

Suggested records:

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

Create history only after playback successfully begins.

Save position:

* periodically while position advances
* on pause
* after a deliberate seek
* before source switch
* during controlled app shutdown

Do not seek repeatedly after opening.

Resume is a one-time initialization action for that media session.

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
