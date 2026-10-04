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

## Build and install on Arch Linux

Arch uses the prebuilt `vpfl-bin` package in `packaging/arch/`. It installs
the same Flutter release bundle as the DEB and RPM packages, with Arch
dependencies. On an x86_64 Arch host with the Flutter SDK on `PATH`, install
the build tools first:

```bash
sudo pacman -S --needed base-devel clang cmake ninja pkgconf gtk3 mpv \
  libepoxy imagemagick desktop-file-utils appstream
```

Create the release archive from the repository root:

```bash
./packaging/scripts/package-arch.sh
```

The archive is `dist/vpfl-linux-x86_64.tar.gz`, and the script prints its
sha256. Build the package from a copy of `packaging/arch/` that points at that
archive, so the committed PKGBUILD keeps the upstream release URL. Replace the
`sha256sums` value with the printed checksum, then run:

```bash
makepkg -si
```

Install an existing package with `sudo pacman -U dist/vpfl-bin-<version>-1-x86_64.pkg.tar.zst`.
Launch with `vpfl` or `vpfl /path/to/video.mkv`. Then open **Settings** and
choose **Make VPFL default**; the button is enabled only after the desktop
entry is installed. See [Arch packaging](docs/compatibility/native-packages.md#arch-linux-vpfl-bin)
for the checks and known limits.

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

## License

VPFL is free and open-source software licensed under the
[Apache License 2.0](LICENSE). Original VPFL work is Copyright © 2026
Sheikh Muneeb Ahmed, creator and primary developer.

Individuals, universities, companies, and other organizations may use VPFL
personally, academically, internally, commercially, and as part of another
product. They may modify and redistribute it under Apache-2.0 and applicable
third-party licenses. Preserve the notices and attribution required by those
licenses when redistributing. The warranty and liability terms are those in
Apache-2.0. See [NOTICE](NOTICE) and
[third-party notices](THIRD_PARTY_NOTICES.md).

## Commercial use

Commercial use is free and permitted under Apache-2.0. Companies do not need
to buy a separate license or obtain author permission. Sheikh Muneeb Ahmed
would appreciate hearing from organizations that use VPFL at
**muneebahmed2250@gmail.com**. Contact is completely optional and is not a
condition of the license.

Publicly naming an organization or displaying its logo requires separate,
explicit permission. See the [optional notification and consent template](COMMERCIAL_USE.md)
and the [public adopters page](ADOPTERS.md).
