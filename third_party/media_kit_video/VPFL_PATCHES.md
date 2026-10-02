# Updating the local `media_kit_video` patch

VPFL uses the published package source with a small checked-in patch because
the Linux EGL correction and render-mode status have not yet been released
upstream. Dart Pub does not apply source patches to hosted dependencies, so the
patched package is kept at `third_party/media_kit_video`.

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

The patch is currently based on `media_kit_video` 2.0.1. Keep the package
license and upstream attribution with the refreshed source.
