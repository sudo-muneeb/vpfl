![VPFL logo and wordmark](assets/readme/vpfl-banner.png)

[![OpenRepos](https://img.shields.io/endpoint?url=https://openrepos.org/status/vpfl.openrepos.org.json&style=flat-square)](https://vpfl.openrepos.org/)

VPFL (Video Player in Flutter for Linux) is a free, open-source desktop video
player built with Flutter and powered by `media_kit` and mpv. It brings
together local video playback, subtitles, and a personal video library.

## Preview

![VPFL playing a local video on Linux](assets/readme/vpfl.gif)

## Features

- **Playback controls**: Play, pause, seek, adjust volume and speed, manage
  subtitles, repeat or shuffle the queue, and enter fullscreen.
- **Local video library**: Browse indexed videos and saved folders, and return
  to recently opened media.
- **Resume playback**: Pick up unfinished videos from their saved positions
  when resume is enabled.
- **Subtitle support**: Select embedded subtitle tracks or load external SRT,
  ASS, SSA, and WebVTT files.
- **Linux desktop integration**: Open local files from the desktop, launch a
  video from the command line, and choose VPFL as the default player for its
  registered video formats.
- **GPU rendering where available**: GPU-backed video presentation with a
  software rendering fallback. Rendering mode is separate from video decoding.
- **Open source**: Use, inspect, modify, and redistribute VPFL under the
  Apache License 2.0.

## Download and installation

VPFL targets x86_64 Linux. The repository can build native packages for
Ubuntu 24.04 / Linux Mint 22.x, Fedora 44, and Arch Linux. See the
[native package guide](docs/compatibility/native-packages.md) for supported
targets and installation checks. X11, headless Wayland, and XWayland have
automated coverage; real desktop/driver coverage remains limited. Fedora codec
availability depends on its installed multimedia packages.
The Linux desktop application ID is `io.github.sudo_muneeb.vpfl`; the package
and command names remain `vpfl`.

**Public installer releases are not yet available.** Once published, verified
packages will be listed on the [GitHub Releases page](https://github.com/sudo-muneeb/vpfl/releases).
The [release status](docs/ci/release-checklist.md#current-publication-setup)
records the availability of GitHub assets. No AUR submission is planned for
v1.0.1. Build from source for now; use the
[package installation guide](docs/compatibility/native-packages.md#installing-a-release-package)
for local packages or published assets when available.

## Run from source

Install Flutter **3.47.5** and the Linux native build dependencies listed in
[CONTRIBUTING](CONTRIBUTING.md#set-up-a-development-checkout), then run:

```bash
git clone https://github.com/sudo-muneeb/vpfl.git
cd vpfl
flutter pub get --enforce-lockfile
flutter run -d linux
```

To compile a release bundle, run `flutter build linux --release`. The executable
is `build/linux/x64/release/bundle/vpfl`; keep the entire bundle together.
For installable DEB, RPM, and Arch builds, use the
[native package guide](docs/compatibility/native-packages.md).

## Using VPFL

Choose **Open file** to play a local video, or **Add Folder** to index a folder
for browsing. Recent videos retain playback progress; history and resume can
be controlled independently in Settings. The player provides subtitle selection
and external loading, repeat/shuffle, video fit, screenshots, and an inspector.

An installed application launches with `vpfl` or `vpfl "/path/to/video.mkv"`.
During development, open a file with:

```bash
flutter run -d linux --dart-entrypoint-args=/path/to/video.mkv
```

Space toggles playback, Left/Right seek ten seconds, Up/Down change volume,
M toggles mute, F toggles fullscreen, and Ctrl+O opens a file. Escape exits
fullscreen or dismisses an overlay. Subtitles render through the host's
mpv/libass and fonts; bundled interface fonts do not replace system subtitle
fonts.

## Documentation

The [documentation index](docs/README.md) links architecture, testing, CI,
packaging/release procedures, compatibility investigations, and design work.
[Development goals](GOALS.md) distinguish completed milestones from remaining
work. Flatpak/Flathub distribution, MPRIS, and saved playlists are not current
features.

## Contributing

Contributions are welcome, including bug fixes, testing, documentation,
packaging, and Linux desktop improvements. Read [CONTRIBUTING.md](CONTRIBUTING.md)
to get started, or open an [issue](https://github.com/sudo-muneeb/vpfl/issues)
to discuss a problem or suggestion.

## License

VPFL is licensed under the [Apache License 2.0](LICENSE). Commercial use,
modification, and redistribution are permitted under its terms. See
[NOTICE](NOTICE), [third-party notices](THIRD_PARTY_NOTICES.md), and
[commercial use information](COMMERCIAL_USE.md) for details.

Created and maintained by Sheikh Muneeb Ahmed.

---

[Website](https://vpfl.pages.dev/) · [GitHub](https://github.com/sudo-muneeb/vpfl) · [Issues](https://github.com/sudo-muneeb/vpfl/issues)
