# VPFL performance rules

## Non-negotiable rules

```text
THE UI MUST NOT WAIT FOR A FULL FILESYSTEM SCAN.

THE UI MUST NOT READ VIDEO FILES DURING build().

THE ACTIVE PLAYER MUST NOT BE SEEKED FOR LIBRARY PREVIEWS.

PLAYER STATE MUST BE EVENT-DRIVEN.

POSITION UPDATES MUST NOT REBUILD THE WHOLE APP.
```

## Startup

Preferred sequence:

```text
process starts
  ↓
initialize required Flutter/native pieces
  ↓
open SQLite/settings
  ↓
render cached home data
  ↓
start folder refresh after UI is usable
```

Do not rescan every saved folder before displaying the window.

## Library indexing

Use SQLite for rendering the library.

Folder scanning should:

1. enumerate candidate files
2. compare lightweight identity
3. skip unchanged files
4. read metadata only for new/changed items
5. batch database writes
6. remove missing records carefully
7. notify UI after useful batches rather than every file

## Bounded work

Do not create unlimited concurrent metadata requests.

Start conservatively:

```dart
final workerCount =
    (Platform.numberOfProcessors ~/ 2).clamp(1, 4);
```

Measure before increasing.

## Thumbnails

No separate background video thumbnail engine in V1.

Policy:

```text
no cached image
→ placeholder

video begins successfully
→ optional media_kit screenshot
→ resize and cache
→ reuse later
```

Never seek the current playback session for a card preview.

### Image decoding

If a cached image is much larger than its display size, decode it near the required resolution with `cacheWidth` and `cacheHeight`.

Do not decode a giant image merely to display a small card.

## Lazy UI

Use:

```text
ListView.builder
GridView.builder
slivers where useful
incremental database queries
```

Avoid building the full library at once.

## Riverpod rebuild scope

High-frequency state:

```text
position
buffer amount
temporary mouse/control visibility
```

must be isolated from low-frequency state:

```text
library
settings
saved folders
theme
navigation
```

Use `select`, separate providers, or equivalent granular subscriptions.

## Playback events

Prefer `media_kit` streams for:

* playing
* position
* duration
* buffering
* tracks
* volume
* rate
* errors
* completion

Do not create polling timers for data already available as events.

## Async deduplication

Do not launch duplicate work for the same resource.

Use in-flight request maps for:

* metadata
* folder refresh
* cached image lookup

## Idle behavior

When VPFL is idle:

* no permanent filesystem scanning
* no unnecessary timers
* no continuously running animations
* no repeated diagnostics polling
* no hidden loading loops

Target idle CPU should be near zero after initialization settles.

## Fullscreen player

While video plays:

* keep overlay tree lightweight
* hide controls when inactive
* pause nonessential animation
* do not rebuild library pages
* avoid large full-window blur or opacity effects unless measured

## GPU and decode layers

Treat these as separate:

```text
Flutter renders UI

media_kit_video presents video frames

native backend selects available decode path
```

Requested hardware decoding is not proof that hardware decoding is actually active.

Diagnostics should report the observed decoder/render state where the backend exposes it.

## Memory

Measure separately where possible:

* Dart heap
* Flutter image cache
* process RSS
* native playback buffers
* GPU memory
* open file descriptors
* threads

Repeated open/close cycles must settle rather than grow forever.

## Allocator changes

Do not adopt a different native allocator by default.

Only evaluate an allocator such as mimalloc if profiling demonstrates a native allocation or fragmentation problem.

Require before/after release measurements.

## Performance test matrix

At minimum:

```text
idle home
large library scrolling
folder scan
1080p playback
4K playback when available
maximized window
fullscreen
repeated seek
rapid media switching
scan while playing
100 open/close cycles
X11
Wayland when available
```

## Initial engineering targets

These are targets, not achieved claims.

| Measurement | Initial target |
| --- | --- |
| Warm launch to cached home | <= 1 second |
| Cold launch to cached home | <= 2 seconds |
| First local 1080p frame | <= 1.5 seconds |
| Typical local seek | around 300 ms on reference fixture |
| Idle CPU | < 1% of one CPU core after settling |
| Idle process RSS | <= 180 MiB initial target |
| 1080p process RSS | <= 350 MiB initial target |
| Indexed library | 10,000 items without blocked UI |
| Repeated use | no continuing resource growth after warmup |

Benchmark against the same media in a mature native player when useful.

The current [pull-request CI](ci/README.md) uses short functional fixtures
and does not measure these performance targets. Startup, RSS, CPU,
large-library, and resource-growth results require release/profile
measurements on a named machine. A green media lane is not a performance pass.

## Build mode

Do not judge production performance from debug mode.

Use profile/release builds for performance work.
