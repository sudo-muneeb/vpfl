# Updating the local `media_kit_video` patch

This VPFL `media_kit_video` Linux compatibility patch contains modifications
by Sheikh Muneeb Ahmed (Copyright © 2026 Sheikh Muneeb Ahmed). It is based on
the upstream `media_kit_video` project, which is licensed under the MIT
License and retains the upstream authors' copyright and license notices. This
attribution applies to the VPFL modifications, not to the original project.

VPFL uses the published package source with a checked-in patch for Linux
rendering and renderer status. Dart Pub does not apply source patches to hosted
dependencies, so the patched package is kept at `third_party/media_kit_video`.
The Linux patch initializes an EGL context shared with Flutter inside the
texture's raster callback, renders mpv frames into a shared GL texture, and
falls back to software output when GPU setup or rendering fails. The Dart part
mounts the initial texture and exposes `initializing`, `gpu`, `software`, or
`unavailable` renderer status.

To try an upstream version:

```bash
./tool/update_media_kit_video.sh 2.0.2
```

The script downloads that published version into the Dart package cache,
applies `vpfl-rendering.patch`, refreshes the local source and dependency pin,
then runs `flutter pub get`. If upstream changes conflict with the patch,
`git apply --check` stops before replacing the current copy. Update the patch
against the new upstream source, review it, then rebuild and run the Linux
playback checks before committing the version bump.

For a local Linux check with a video in the ignored `videos/` folder:

```bash
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/linux_playback_test.dart -d linux \
  --dart-define=VPFL_TEST_VIDEO="$PWD/videos/default.mp4"
VPFL_TEST_FAIL_GPU_INIT=1 flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/linux_playback_test.dart -d linux \
  --dart-define=VPFL_TEST_VIDEO="$PWD/videos/default.mp4"
```

The second command injects an EGL initialization failure to exercise software
fallback. It is a development check, not a runtime setting for users.

The patch is currently based on `media_kit_video` 2.0.1. Keep the package
license and upstream attribution with the refreshed source.
