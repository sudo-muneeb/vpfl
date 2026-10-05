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

The first scanner correction excluded plain `.d` and ambiguous `.ts` by final
extension. It missed TypeScript declarations ending `.d.mts`: their final
extension is `.mts`, which the scanner admitted as video, while the card title
removed only that final suffix and displayed `vitesse-light.d`. The follow-up
below measures and fixes that actual cause.

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
and cleanup warnings. Scanner trace events include the file path, extension,
decision, and database operation when this opt-in trace is enabled; they can
be very verbose for large source trees.

## Format policy

Automatic folder scanning accepts `3g2`, `3gp`, `asf`, `avi`, `flv`, `m2ts`,
`m4v`, `mkv`, `mov`, `mp4`, `mpeg`, `mpg`, `mts`, `mxf`, `ogv`, `vob`, `webm`, and
`wmv`. Matching is exact and case insensitive. `.d` and `.ts` are excluded.
Users can still explicitly open `.ts` as a transport stream. Supported
subtitle extensions remain `srt`, `ass`, `ssa`, and `vtt`.

## Follow-up: declaration files and queue failure, 5 October 2026

The active database is `/home/minty/.local/share/vpfl/vpfl.sqlite` because
`XDG_DATA_HOME` is unset. Debug builds now print that absolute path when Drift
opens. Before the follow-up rescan it contained 1,078 indexed rows. A read-only
SQL inspection found **zero** plain `.d` paths, **1,031** `.d.mts` paths, zero
`.ts` paths, and no duplicate exact `uri` or `path` values. Saved roots were
`~/Videos`, `~/data`, and `~/Downloads`; the `~/data` root included source
projects and `node_modules`. The records had been accepted by the current
scanner, not left behind in a different database. For example, a visible
`vitesse-light.d` card mapped to a `vitesse-light.d.mts` declaration under
`vpfl-website/node_modules`. Similar titles appeared twice because distinct
packages (`@shikijs/themes` and `shiki`, for example) contained files with the
same basename. The URI primary key prevented identical path duplicates.

The scanner now checks declaration suffixes `.d.ts`, `.d.mts`, and `.d.cts`
before extracting the final extension. It excludes `.ts` from automatic
indexing, still permits explicit `.ts`, rejects non-files and links, and checks
accepted final extensions exactly without substring matching. For `.mts`, an
additional short MPEG transport stream packet-signature check distinguishes a
recording from a TypeScript module named `index-browser.mts`. This is a
conservative discovery check: an unusual or damaged transport stream can be
opened explicitly even if it does not pass automatic indexing. A real
`recording.mts` fixture with transport stream sync bytes remains indexed in
the regression test.

Each scan removes already stored rows rejected by the policy, then walks the
root. A complete scan also deletes rows no longer found. Incomplete walks keep
unseen rows so an inaccessible subtree does not erase its library entries.
The repository filters known invalid paths immediately while a scan runs.
Saved roots are canonicalized when added; a parent root leaves a nested saved
root to the inner folder. The `uri` primary key and overlapping-root test
ensure one row for each canonical path. A new AppShell scan guard avoids
starting the same folder scan repeatedly from folder stream updates; the
Rescan button still forces a scan.

The previous directory-open path handed mpv a playlist containing all sibling
files. A selected declaration could therefore fail to decode while mpv moved
to later entries; `PlaybackOpenCoordinator` only serializes/cancels opens and
does not call `next()`. The new path validates the selected local format and
regular file, filters nearby items with the automatic policy, and gives mpv
only the selected item. VPFL retains the directory list for explicit
Next/Previous navigation. Explicit queues use the same one-item-at-a-time
approach. An asynchronous media error stops playback and displays `VPFL could
not open this file.`; failed opens log `media.open.failed` with the reason
`unsupported-or-invalid` when lifecycle tracing is enabled. Successful normal
end does not auto-advance through a directory; the user can press Next.

Before modifying the populated database, a SQLite backup was saved at
`/tmp/vpfl-before-declaration-fix.sqlite`. The first full rescan reduced the
library from 1,078 rows to 47: `~/data` went from 1,040 to 9; the other
roots retained 4 and 34. Direct SQL then counted zero `.d`, `.d.ts`, `.d.mts`,
`.d.cts`, or `.ts` paths and zero duplicate URIs or paths. One remaining `.mts`
was a TypeScript module in `node_modules`, which prompted the transport stream
signature check and a second rescan. That rescan reduced the library to **46**
rows (4 Videos, 8 data, 34 Downloads). A second direct SQL check counted zero
`.d`, `.d.ts`, `.d.mts`, `.d.cts`, `.ts`, or `.mts` paths and no duplicate URI
or path. There was no genuine `.mts` recording in the three saved roots, so
continued `.mts` support is demonstrated by the regression fixture rather
than by a row in the populated library.

The regression directory covers real MP4/MKV/WebM names, a packet-signature
`.mts`, invalid `.d`, `.ts`, compound declarations, deceptive suffixes,
source files in `node_modules`, links, and directories with a video suffix.
It seeds invalid and missing database rows and verifies complete-rescan
removal. A separate test checks overlapping saved roots. Native Linux
playback testing selects an invalid declaration, opens a corrupt `.mp4`, checks
the controlled error and absence of an automatic jump, then opens a valid
video and verifies playback. The active-library rescan runs only with
`--dart-define=VPFL_RESCAN_ACTIVE_DB=true` and prints folder counts.

The test cannot prove every one of the populated library's playable files
decodes successfully: the full file set was not played. For items that fail
decoding, the controlled error path is exercised by the corrupt MP4 test.
The media_kit driver still prints its existing `integration_test plugin was
not detected` warning after the test body despite reporting all tests passed.
After the final code changes, `flutter analyze` reported no issues, all 38
`flutter test` cases passed, the native invalid/corrupt/valid playback test
passed, the active-database rescan test passed, and `flutter build linux
--release` produced `build/linux/x64/release/bundle/vpfl`. The native test
again printed the known renderer teardown warning `0x3002`; it did not fail
or leave playback running.

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

The earlier lifecycle checks passed: `flutter analyze`, all 36 `flutter test` cases,
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
