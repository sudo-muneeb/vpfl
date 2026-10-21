![VPFL logo and wordmark](vpfl-banner.png)

[![OpenRepos](https://img.shields.io/endpoint?url=https://openrepos.org/status/vpfl.openrepos.org.json&style=flat-square)](https://vpfl.openrepos.org/)

VPFL (Video Player in Flutter for Linux) is a free, open-source desktop video
player built with Flutter and powered by `media_kit` and mpv. It brings
together local video playback, subtitles, and a personal video library.

## Features

- **Playback controls**: Play, pause, seek, adjust volume and speed, manage
  subtitles, and enter fullscreen.
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
targets and installation checks.

**Public installer releases are not yet available.** Once published, verified
packages will be listed on the [GitHub Releases page](https://github.com/sudo-muneeb/vpfl/releases).
For now, developers can build and run VPFL from source.

## Run from source

You will need a Linux desktop environment, the Flutter SDK with Linux desktop
support, a working C/C++ build toolchain, and GTK 3, mpv, and libepoxy
development dependencies. CI uses **Flutter 3.47.5**; use that version for the
closest match. On Ubuntu or Linux Mint, install the native dependencies with:

```bash
sudo apt install clang cmake ninja-build pkg-config \
  libgtk-3-dev libmpv-dev libepoxy-dev
```

Clone and run the application:

```bash
git clone https://github.com/sudo-muneeb/vpfl.git
cd vpfl
flutter pub get
flutter run -d linux
```

Open a specific video while developing:

```bash
flutter run -d linux --dart-entrypoint-args=/path/to/video.mkv
```

An installed VPFL executable can be launched with `vpfl` or
`vpfl /path/to/video.mkv`. For local testing with a separate app profile, use
`./scripts/debug-isolated.sh [video-file]`; see the
[script](scripts/debug-isolated.sh) for its options.

## Building Linux packages

The repository provides scripts for generating native Linux packages. They
have distribution-specific prerequisites; consult the
[packaging guide](docs/compatibility/native-packages.md) before building or
installing generated artifacts.

**Debian / Ubuntu**

```bash
./packaging/scripts/package-linux.sh deb
```

**Fedora**

```bash
./packaging/scripts/package-linux.sh rpm
```

**Arch Linux**

```bash
./packaging/scripts/package-arch.sh
```

The Arch script generates the release archive used by the `vpfl-bin` package
build; it does not install the package itself.

## Under the hood

VPFL uses Flutter for its desktop interface and `media_kit` for playback,
backed by mpv. Its Linux integration covers rendering, a local media library,
desktop file associations, and subtitle controls. The project also has
automated playback and packaging checks.

For implementation details, compatibility work, and planned improvements, see
the [project documentation](docs/02-architecture.md),
[CI guide](docs/ci/README.md), and [development goals](GOALS.md).

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
