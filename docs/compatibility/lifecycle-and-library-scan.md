# Playback lifecycle and library scan checkup

Status: implementation and local Linux checks on 5 October 2026. These changes
are in the working tree; the original intermittent surviving-process incident
was not reproduced with a correctly addressed window close request.

## Findings

`PlaybackService` is the app's one foreground player owner. It creates one
media_kit `Player`, then lazily creates one `VideoController`. media_kit registers
the controller's native release callback on that player. The callback disposes
the Linux `VideoOutput`, unregisters its texture, and releases its mpv render
context when `Player.dispose()` runs. `PlayerScreen` subscribes to this root
service but does not own it.

Before this change, the Home action removed `PlayerScreen` without stopping the
root-scoped player. An async `_openMedia` operation could also finish after that
screen was removed. This explains playback continuing on Home. The app's custom
close action sent GTK `close` immediately; it did not await Dart resource
cleanup. Window-manager close requests took another path. Provider disposal
started asynchronous player, recorder, thumbnail, and database cleanup without
awaiting their order.

During the new shutdown integration test, closing Drift while live root-scoped
stream providers existed stalled and surfaced `ConcurrentModificationError` in
`StreamQueryStore.close`. Those providers now release streams when unobserved.
The app unmounts its UI before closing storage, and database close is
idempotent. This is a demonstrated shutdown flaw, but it does not prove it was
the cause of the user's earlier intermittent process survivor.

The scanner compared final extensions exactly and did not include `.d`. A
`video.mp4.d` file is likewise rejected. A `.d` entry already in the library
could be a stale database row; a complete rescan removes it. An incomplete
scan intentionally preserves old rows to avoid deleting media in inaccessible
folders. Separately, the permissive **Open file → All files** choice can add a
non-video path to playback history; Recent videos is distinct from the indexed
library. The scanner did explicitly include `.ts`, because it is also used for
MPEG transport streams. Source code named `code.ts` was therefore indexed.

## Current ownership and order

Leaving the player for Home invalidates pending opens, stops the one player,
and keeps that player and controller for the next foreground session. Opening
another item serializes media changes and drops queued superseded opens.
The player screen also abandons async media setup when its route generation
changes or it unmounts.

Both custom and window-manager close requests now enter the same Dart close
handler. It unmounts the UI, stops playback, awaits history subscriptions and
pending thumbnail work, disposes the player (which calls media_kit's controller
release callback), closes the thumbnail stream, and closes Drift. GTK then
closes the window. The native runner has a ten-second fallback if Dart cannot
respond. The shutdown object, player disposal, thumbnail close, and database
close are idempotent.

Set `VPFL_LIFECYCLE_TRACE=1` to print timestamped Dart session and native GTK
events. The native video plugin also prints renderer setup, resize, fallback,
and cleanup warnings. The event trace deliberately does not print every frame
or full file paths.

## Format policy

Automatic folder scanning accepts `3g2`, `3gp`, `asf`, `avi`, `flv`, `m2ts`,
`m4v`, `mkv`, `mov`, `mp4`, `mpeg`, `mpg`, `mts`, `mxf`, `ogv`, `vob`, `webm`, and
`wmv`. Matching is exact and case insensitive. `.d` and `.ts` are excluded.
Users can still explicitly open `.ts` as a transport stream. Supported
subtitle extensions remain `srt`, `ass`, `ssa`, and `vtt`.

## Local validation and limits

The scanner test covers source and video names, upper-case and multi-dot
extensions, hidden names, extensionless files, symlinks, a `.mp4` directory,
deleted files, and removal of an existing `.d` row. The native lifecycle test
ran 20 Home → player return cycles, including ten seconds on Home, and checked
that the one controller was reused. It also checks sequential and rapid media
replacement when B/C samples are supplied. The release close script exercises
the button and window-manager paths and checks that each launched PID exits.

On this host, 30 alternating close cycles passed across Home, playing, paused,
seeking, immediate-close, and injected software-fallback attempts. The script
sent pause and seek keys; it did not independently assert the resulting mpv
state. The original intermittent high-CPU survivor was not reproduced. The
native renderer sometimes still prints `Could not activate video context for
cleanup: 0x3002` while disposing. Process termination succeeded in the tested
cycles, but that warning merits a separate raster-thread EGL cleanup check.
No CPU trend, native output count, or visual frame comparison was measured.

Final local checks passed: `flutter analyze`, all 36 `flutter test` cases,
the 20-cycle Linux integration test, and a separate A → B → C → A plus rapid
replacement integration run. The release Linux build, DEB package validator,
and Arch archive validator passed. A clean Ubuntu 24.04 container installed
the final DEB, opened MP4, MKV, and WebM to 320 × 180 textures, and removed
the package. Two additional close checks passed on the final release build
with lifecycle tracing enabled. These results are local X11/Xvfb checks;
Wayland and other GPU drivers were not exercised.

Repeat the close check after a release build:

```bash
xvfb-run -a ./packaging/scripts/check-linux-close.sh \
  "$PWD/videos/default.mp4" 30
```
