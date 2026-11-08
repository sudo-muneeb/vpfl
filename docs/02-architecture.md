# VPFL architecture

VPFL is a Flutter Linux application with one foreground playback session.
Riverpod wires shared services and reactive database queries; screen-local
interaction state stays in widgets. The application has no domain/use-case
layer or playback repository. See the [source map](03-project-structure.md)
for directory responsibilities.

## Ownership and data flow

- `VpflApp` owns navigation between the library and player, appearance, and
  the coordinated shutdown path.
- `AppShell` presents Home, All Videos, saved folders, and Settings. It starts
  saved-folder scans without making cached library display wait for them.
- `playbackServiceProvider` supplies the shared `PlaybackService`.
  `PlayerScreen` subscribes to it and sends commands; removing that screen
  does not dispose the service.
- `persistence_providers.dart` supplies one Drift database, repositories,
  scanner, and auto-disposed query streams. Widgets consume repository data
  through providers rather than running SQL.
- `media_kit` owns live playback state. Controls subscribe to its position,
  duration, playing, track, and other streams at the relevant widget boundary,
  keeping position changes out of the application shell.

## Playback and source changes

[`PlaybackService`](../lib/data/services/playback_service.dart) owns one
`media_kit.Player` and lazily creates its `VideoController`. It exposes
commands, streams, subtitle operations, and diagnostic queries. The service
keeps a logical directory or explicit queue while opening only the selected
item in mpv. `QueueProgression` owns repeat/shuffle traversal. Natural
completion advances the queue according to its repeat mode; a failed source
remains selected with Previous/Next available rather than being skipped.

`PlaybackOpenCoordinator` serializes opens and drops superseded requests.
Source generations prevent late resume, subtitle, and completion operations
from applying to a replacement source. A successful open request alone is not
proof of playback: readiness, duration, restored position, and native output
are checked at the relevant boundaries. Recoverable decoder errors are logged;
the player checks for output/progress before replacing playback with an error.

Returning from the player stops playback and invalidates pending opens, but
retains the service/controller for reuse. The
[lifecycle investigation](compatibility/lifecycle-and-library-scan.md)
records the original ownership defects and reproduction evidence.

## Video output and subtitles

`media_kit` calls the distribution's libmpv. The Linux video plugin comes
from VPFL's path override of `media_kit_video`, based on upstream 2.0.1.
The Pub lockfile pins Dart packages, not system mpv, libass, codecs, or fonts.

The patched plugin mounts a bootstrap texture so Flutter invokes the raster
callback. It obtains Flutter's current EGL context there and creates a shared
context for mpv GL output. GPU setup/render failures can switch to a software
pixel buffer. Renderer state is reported as `initializing`, `gpu`, `software`,
or `unavailable`. GPU presentation and hardware video decoding are separate:
`gpu` does not establish that a hardware decoder is active. The inspector
queries `hwdec-current` only while Diagnostics is visible.

`PlayerScreen` sizes native output for the displayed physical surface and
snaps the contained video's final origin to physical pixels. This avoids
scaling or fractional placement of already rasterized captions. Fit, crop,
and Stretch retain their distinct presentation behavior. The
[resize investigation](compatibility/subtitle-resize-recovery.md) preserves
the controlled experiments, rejected hypotheses, and measured results.

Text subtitles are rendered by mpv/libass into native video frames using
`PlayerConfiguration(libass: true)`. Flutter displays those frames and the
controls; it does not parse or restyle subtitle text. Embedded tracks and
mpv-discovered sidecars appear in the CC menu. Explicit SRT, ASS, SSA, and VTT
loads are serialized, reconcile native track identity, reuse existing tracks,
and verify selection. Invalid loads preserve the previous selection where
possible. Subtitle delay uses native readback, 100 ms steps, a ±5 second
range, and resets on source changes; selections and delay are not persisted.

Subtitle fonts come from embedded attachments and the system font provider.
Bundled Noto Sans Display is the Flutter **interface** font; it does not ensure
that libass can find that font on the host. Font installation and substitution
therefore affect subtitle output. See the [native comparison guide](ci/native-subtitle-verification.md)
and [X11 window checks](ci/subtitle-window-checks.md) for distinct native-frame,
final-presentation, and manual shaping checks. Patch maintenance lives in
[patches/media_kit_video/README.md](../patches/media_kit_video/README.md).

## Library, metadata, and thumbnails

`LibraryRepository` owns saved roots and indexed files. `LibraryScanner`
walks roots asynchronously without following symlinks, skips separately saved
nested roots, compares size/mtime, and writes batches of 100 changed rows.
Complete walks remove missing rows; incomplete walks retain unseen rows to
avoid deleting entries for inaccessible subtrees. `AppShell` guards duplicate
scans of the same folder. There is no permanent filesystem watcher.

Scanning records filesystem metadata, not codec/duration metadata, and does
not decode videos. `MediaFormatPolicy` excludes ambiguous `.ts` from automatic
indexing while allowing explicit opens, rejects TypeScript declarations, and
uses a short packet-signature probe for `.mts` candidates.

The Details action uses `MediaMetadataService` on demand. For the active file
it reads a coherent playback snapshot; otherwise it serializes temporary
output-free mpv inspection sessions. Requests can be canceled and results are
not cached. These inspection players are separate from the foreground session
and do not create a video texture or start playback.

`ThumbnailService.resolve` tries a valid Freedesktop thumbnail, then VPFL's
cache, then a placeholder. After ten seconds of natural playback, the history
recorder may capture one PNG if history is enabled and no thumbnail exists.
It never seeks the active player for artwork or writes to the Freedesktop
cache. VPFL caches live beneath `$XDG_CACHE_HOME/vpfl`, falling back to
`~/.cache/vpfl`.

## Persistence and resume

[`AppDatabase`](../lib/data/model/app_database.dart) uses Drift/SQLite,
currently schema version 2, with four tables: `PlaybackHistories`,
`AppSettings`, `SavedFolders`, and `LibraryMediaItems`. Version 2 adds the
folder/library tables. There are no persisted playlists, favorites, portal
identities, or per-media track preferences.

The database is `$XDG_DATA_HOME/vpfl/vpfl.sqlite`, or
`~/.local/share/vpfl/vpfl.sqlite` when `XDG_DATA_HOME` is empty/unset.
History keys are normalized absolute file URIs. Moving or renaming a file
creates a different key; VPFL does not hash media contents to identify files.

History starts when playback enters the playing state. Progress checkpoints
occur after at least five seconds of position change, on pause, before source
replacement, and during controlled shutdown. Writes wait for the session's
initial history row and are withheld while opening or restoring an unverified
seek, preserving the last good point on failure.

Resume reads the setting and saved point on each source open, including queue
navigation. A noncompleted point at or beyond ten seconds is eligible. The
service waits for duration, seeks once, and verifies the resulting position.
Completion requires at least 90% watched **and** at most 15 seconds remaining.
Completed entries retain full progress but clear the resume point.

History disabled stops new history/thumbnail writes without deleting records;
resume can still read them. Resume disabled starts at the beginning while
history remains independent. Home displays eight Recent cards from a query
limited to twenty; those display limits do not delete records. Retention has
no automatic age/count expiry. Removing a Recent card or clearing history in
Settings explicitly deletes records; unavailable files are not expired.

## Linux desktop and shutdown

The GTK runner owns the frameless window, resize regions, window-state events,
startup file arguments passed to Flutter, and the native window channel.
`WindowCommands` connects Flutter controls to those operations. The native
application identity is currently `io.github.sudo_muneeb.vpfl`.

The internal `vpfl_desktop_linux` plugin owns GIO default-application queries
and changes, plus FileManager1 folder/item requests. The default-app prompt
service owns consent/reminder policy; installation itself never sets defaults.
See [desktop integration](linux/default-applications.md). The application does
not currently forward new launches to an existing instance or implement MPRIS.

Both custom and window-manager close requests enter `VpflApp`'s Dart shutdown
handler. It unmounts UI subscriptions, then `ApplicationShutdown` awaits stop,
history flush/disposal, player disposal, thumbnail close, and database close.
media_kit releases the controller/native output through player disposal.
Cleanup is idempotent; GTK has a ten-second fallback if Dart cannot respond.

For native evidence and its limits, use the [testing guide](06-testing.md)
and [CI guide](ci/README.md). Decoded mpv screenshots, final compositor pixels,
physical GPU output, and hardware decoding establish different things.
