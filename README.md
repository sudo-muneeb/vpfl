# VPFL

VPFL is a Flutter desktop video player for local media on Linux. It has a
responsive navigation shell and one `media_kit` playback session. Home shows
recent media, while All Videos and saved folders browse the local library.

## Run

Launch the main app shell:

```bash
flutter run -d linux
```

Open one local media file:

```bash
flutter run -d linux --dart-entrypoint-args=/path/to/video.mkv
```

The built executable follows the same contract: `vpfl` or `vpfl <file>`.
Relative paths, spaces, Unicode filenames, and a quoted `~/...` path are supported.
The player title bar reports whether the Linux video output selected GPU or
software rendering. This is the rendering path, not the video decoder mode.
Use the CC control over the video to select a subtitle track or load an
external SRT, ASS, SSA, or WebVTT file.

After three successful plays, an installed VPFL may invite you to make it the
default for its supported video formats. **Maybe later** delays another
invitation for 21 days. You can also inspect and change defaults in Settings.
See [Linux default-application integration](docs/linux/default-applications.md).

## Build DEB and RPM packages

Builds currently target x86_64 Linux. From the repository root, use a host
with a working Flutter Linux toolchain and the `mpv` and `epoxy` development
libraries. On Ubuntu or Linux Mint, install the packaging tools with:

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev \
  libmpv-dev libepoxy-dev dpkg-dev binutils imagemagick \
  desktop-file-utils appstream
```

The RPM build also needs `rpmbuild` or Docker. When `rpmbuild` is unavailable,
the script uses Docker to build the RPM in a Fedora 44 container. Run either
command, or both, from the repository root:

```bash
flutter pub get
./packaging/scripts/package-linux.sh deb
./packaging/scripts/package-linux.sh rpm
```

Each command runs `flutter build linux --release` and validates its package.
The installable files are written to `dist/`:

```text
dist/vpfl_<version>-1_amd64.deb
dist/vpfl-<version>-1.fc44.x86_64.rpm
dist/symbols/<version>-1-x86_64-<commit>/
```

For the current `1.0.0` build, the files are
`dist/vpfl_1.0.0-1_amd64.deb` and
`dist/vpfl-1.0.0-1.fc44.x86_64.rpm`. The `symbols/` directory contains
separate debug symbols and `BUILD-INFO`; it is not an installer. The Flutter
release bundle used to create each package is at
`build/linux/x64/release/bundle/`. Both `build/` and `dist/` are generated
locally and are not committed to Git.

Install on Ubuntu 24.04 or Linux Mint 22.x with
`sudo apt install ./dist/vpfl_1.0.0-1_amd64.deb`, or on Fedora 44 with
`sudo dnf install ./dist/vpfl-1.0.0-1.fc44.x86_64.rpm`.
See [native package targets and installation checks](docs/compatibility/native-packages.md)
for supported targets, clean-install checks, and remaining limitations.

## Development checks

```bash
dart format lib test integration_test
flutter analyze
flutter test
flutter build linux --release
```

See [the Phase 0 Linux compatibility report](docs/compatibility/phase-0.md)
for verified results and remaining compatibility work. To refresh the patched
video dependency after an upstream release, run
`./tool/update_media_kit_video.sh <version>`. The implementation tracker and
remaining product goals are in
[GOALS.md](GOALS.md).
