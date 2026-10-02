# VPFL

VPFL is a Flutter desktop video player for local media on Linux. The current
build is the playback compatibility baseline: one `media_kit` session with a
minimal video surface and controls. The home library, saved folders, and
persistence are planned goals; they are not implemented yet.

## Run

Launch the empty player window:

```bash
flutter run -d linux
```

Open one local media file:

```bash
flutter run -d linux --dart-entrypoint-args=/path/to/video.mkv
```

The built executable follows the same contract: `vpfl` or `vpfl <file>`.
Relative paths, spaces, and a quoted `~/...` path are supported.
The player title bar reports whether the Linux video output selected GPU or
software rendering. This is the rendering path, not the video decoder mode.

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
