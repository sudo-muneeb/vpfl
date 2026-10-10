# Linux development and Flatpak

## Development setup

On Ubuntu or Linux Mint, install Flutter's Linux build toolchain and the native packages required by the chosen media_kit setup.

Then verify:

```bash
flutter doctor -v
flutter devices
flutter run -d linux
```

Keep the project's Flutter SDK revision and `pubspec.lock` reproducible.

## Initial dependencies

Core application dependencies should stay small.

Expected categories:

```text
media_kit
media_kit_video
media_kit_libs_video

flutter_riverpod

SQLite package / database layer

file_selector
path
path_provider

window management
desktop drag and drop
D-Bus only when needed
```

Do not add a media conversion package in V1.

## Command line

Initial command contract:

```bash
vpfl
```

Launch normal UI.

```bash
vpfl <file>
```

Open one local media file.

Resolve relative paths safely.

Support quoted paths with spaces.

Do not add command flags until there is a real use case.

## External opening

All of these should eventually feed one internal open action:

```text
vpfl <file>
Open With
double-click association
file picker
drag and drop
recent item
library item
```

The application should later support forwarding these requests to an existing instance.

## Desktop identity

Choose one application ID and keep it consistent across:

* executable/launcher
* Linux runner identity
* desktop file
* icon names
* AppStream metadata
* Flatpak manifest

Example placeholder:

```text
io.github.yourname.VPFL
```

Replace it before public release.

## Desktop entry

Example:

```ini
[Desktop Entry]
Type=Application
Name=VPFL
Comment=Play videos and browse saved folders
Exec=vpfl %U
Icon=io.github.yourname.VPFL
Terminal=false
Categories=AudioVideo;Player;Video;
MimeType=video/mp4;video/x-matroska;video/webm;video/quicktime;video/x-msvideo;
Keywords=video;movie;media;player;
```

Only advertise formats that have actually been tested.

## Flatpak design

Create a working Flatpak early.

The sandbox must contain the native libraries required by the packaged playback stack.

Do not depend on development libraries installed on the host.

## Folder access

Prefer user-granted access.

Use portals where appropriate.

Do not request blanket home or host filesystem access merely because it is convenient.

Persist stable grant/document information where possible.

If access is no longer valid:

```text
mark folder unavailable
show clear UI
offer reselect/relink
```

Do not silently delete history for temporarily unavailable folders.

## Saved folders

A selected folder should store:

* display label
* accessible URI/path
* portal/document identity when available
* recursive preference
* last scan timestamp
* availability

Opening one isolated video must not be treated as permission to index its entire parent folder.

## GPU and audio permissions

Flatpak permissions should be as narrow as possible.

Typical requirements may include:

```text
DRI device access for graphics/video
audio socket
Wayland
X11 fallback when required
portal access
```

Add network permission only if direct network playback ships.

## MPRIS

MPRIS is a later desktop integration milestone.

Keep it outside playback UI code.

Expose only required D-Bus interfaces.

## Window behavior

Initial requirements:

* sensible minimum window size
* maximize/restore
* fullscreen
* remember window size later if desired
* correct taskbar/dock identity

Always-on-top mini-player behavior is a later feature and compositor dependent.

## Launcher files

Package:

```text
desktop entry
scalable application icon
raster icons as needed
AppStream metadata
complete Flutter Linux bundle
```

A Flutter asset alone does not install an application icon into the desktop environment.

## Offline/reproducible packaging

Before Flathub submission:

* pin sources
* keep checksums
* keep `pubspec.lock`
* avoid hidden build-time downloads
* verify native dependency closure
* build from a clean environment
* test on a machine without development playback packages

## Release checks

Verify:

```text
menu launch
dock/taskbar grouping
vpfl
vpfl <file>
Open With
spaces in file names
Unicode paths
fullscreen
subtitles
saved folders
restart persistence
Flatpak update
database migration
```

The [current CI workflow](ci/README.md) builds native DEB, RPM, and Arch
packages only. Flatpak build, sandbox permissions, update, and migration
checks remain release work; native package jobs provide no Flatpak result.
