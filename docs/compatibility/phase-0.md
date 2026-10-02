# Phase 0 Linux compatibility report

## Environment

- OS: Linux Mint 22.3, X11
- Flutter: 3.47.5 stable, revision `6a19cca564`
- Dart: 3.13.4
- Linux graphics: AMD Radeon Graphics (radeonsi), Mesa 25.2.8
- Packages resolved by `pubspec.lock`: `media_kit` 1.2.6,
  `media_kit_video` 2.0.1, `media_kit_libs_video` 1.0.7
- Final local samples: four H.264 MP4 files in the ignored `videos/` folder
  (two 2560×1440 files, one 3840×2160 file, and one 2160×3840 file).
- Initial upstream-only reproduction used
  `/usr/share/help/C/gnome-help/figures/display-dual-monitors.webm`.

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| Dart analysis | Pass | Final `flutter analyze` reports no issues. |
| Unit/widget tests | Pass | Six command-line routing and player-control tests pass. |
| Linux release build | Pass | `flutter build linux --release` produced `build/linux/x64/release/bundle/vpfl`. |
| Linux runner launch | Pass | The bundled app opened on X11 and registered the media video texture. |
| Hardware video rendering context | Pass on X11 | The patched plugin logged `H/W rendering with isolated EGL context` in both the Linux playback integration run and release launch for all four local H.264 samples. |
| Playback, seek, and pause | Pass on X11 | `flutter drive` confirmed the 1440p sample advances, seeks to 10 seconds, and pauses. |
| First decoded frame visibly presented | Not verified | Native texture setup and media dimensions are observed, but this smoke check did not capture a frame or use the controller's first-frame signal. |
| Hardware decoding | Not verified | No `hwdec-current` observation or decoder measurement was collected. |
| Dispose/reopen | Not verified | The integration test validates playback, seek, and pause, but not player disposal and reopen. |
| Flatpak build/run | Not available | `flatpak` is installed; `flatpak-builder` is not installed. |

## Interpretation

The original 2.0.1 plugin queried Flutter's thread-local EGL context from its
GTK callback, matching the cause described in the still-open
[media_kit Linux rendering issue](https://github.com/media-kit/media-kit/issues/1404).
VPFL carries a local patch in `third_party/media_kit_video`: Linux obtains an
EGL display from GDK and creates an isolated ES2 context backed by a 1×1 pbuffer.
The pbuffer matters on this Mesa driver: the first surfaceless context failed
with `EGL_BAD_ACCESS`; the pbuffer version succeeds. Debug integration and
release smoke runs report the hardware GL rendering context for all four local
videos. This confirms the video frame rendering path initializes; visible
first-frame presentation and hardware decoding remain separate checks.

The X11 renderer is verified. Hardware decoding and visible first-frame
presentation are not yet verified. The next compatibility step is to collect a
first-frame signal and decoder state, then test Wayland and dispose/reopen.

## Reproduction

```bash
flutter analyze
flutter test
flutter build linux --release
timeout 12s build/linux/x64/release/bundle/vpfl \
  videos/16638149_3840_2160_30fps.mp4
```

The timeout is expected for this smoke command because the desktop player stays
open. The original upstream output before the patch was:

```text
Using the Impeller rendering backend (OpenGLESSDF).
package:media_kit_libs_linux registered.
media_kit: VideoOutput: EGL display or context is invalid.
media_kit: VideoOutput: S/W rendering.
NativeVideoController: Texture ID: ...
```

After the patch, the renderer log included:

```text
media_kit: VideoOutput: H/W rendering with isolated EGL context.
VideoOutput.Resize ... width: 3840, height: 2160
```

The AMD system has no CUDA library, so `Cannot load libcuda.so.1` is also
reported while mpv probes available decoder backends. It does not establish
whether VAAPI or another hardware decoder is active.
