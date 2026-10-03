# Linux video renderer checkup

Status: implementation and local X11 checks completed on 3 October 2026.
The renderer changes described here are in the working tree; this report does
not claim a commit or a release artifact.

## Scope and test machine

This checkup investigated VPFL's Linux video texture path after a run of
`flutter run -d linux --dart-entrypoint-args=videos/default.mp4` reported
`Lost connection to device` shortly after a 1280 × 720 video resize. The user
also reported that the video had appeared on screen in an earlier run. The
immediate goals were to understand whether the isolated EGL context was at
fault, apply the proposed shared-context approach, make unavailable graphics
capabilities recover cleanly, and exercise GPU and software paths.

The available machine was Linux Mint 22.3 on X11, with AMD Radeon graphics,
Mesa 25.2.8, Flutter 3.47.5, Dart 3.13.4, and `media_kit_video` 2.0.1 as a
locally patched package. The test file was the ignored local file
`videos/default.mp4` (1280 × 720). The `videos/` directory is not part of the
repository. Other desktop sessions, GPUs, and Flatpak runtimes were not
available for this checkup.

## Journey and findings

### 1. Original package and first local correction

The unpatched Linux plugin tried to obtain Flutter's current EGL context in a
GTK callback. On this Flutter version the relevant EGL context was current on
the raster thread, so that lookup could fail. The earlier Phase 0 work used a
separate EGL context with a 1 × 1 pbuffer. It changed the observed startup from
`EGL display or context is invalid` and software output to a log saying
`H/W rendering with isolated EGL context`. Playback, seek, and pause worked on
the X11 machine. See [the Phase 0 report](phase-0.md) for that original result.

That result established that the isolated GL renderer could initialize on this
machine. It did not prove that Flutter could safely consume frames from that
context in every run, that decoding used the GPU, or that other Linux graphics
stacks would behave the same way.

### 2. Reported disconnect and baseline reproduction

The reported `flutter run` log reached `VideoOutput.Resize` at 1280 × 720 and
then said `Lost connection to device`. That message alone does not identify a
native crash or its cause. A separate baseline run under GDB survived its
30-second observation window, so the original disconnect was **not reproduced
reliably** before changing the renderer. The isolated-context path was still a
reasonable target: the Flutter texture callback runs with Flutter's EGL context
current, while the old plugin had built its video context independently.

The AMD machine also printed `Cannot load libcuda.so.1`. CUDA is an optional
NVIDIA decoder backend. Successful playback runs printed the same warning, so
it was not the blocker observed here. The warning does not tell us which video
decoder was actually selected.

### 3. Shared-context implementation

The Linux plugin now registers a GL texture, waits for Flutter to invoke
`FlTextureGL.populate` on the raster thread, and obtains the current EGL display
and context there. It inspects Flutter's EGL configuration and GLES version,
checks pbuffer support, creates a context shared with Flutter, and gives that
context to libmpv's OpenGL renderer. Frames are rendered into a GL texture and
framebuffer shared with Flutter. The code restores Flutter's context before
returning from the texture callback.

Initialization and rendering check for missing contexts or configurations,
failed context or pbuffer creation, texture-size limits, incomplete framebuffers,
GL errors, and libmpv render failures. If GPU output fails, a GTK-thread task
releases the GPU texture and starts software output. Frame notifications are
coalesced before delivery. Teardown marks the output stopped so queued work
does not continue using it. Software dimensions are scaled as a pair, including
portrait video, and failed software setup is reported as unavailable.

The Dart texture widget mounts the initial 1 × 1 texture before media size is
known. Without that bootstrap texture, Flutter never calls the raster callback
that creates the mpv render context. A request for the first frame starts the
process. Native resize messages now carry `initializing`, `gpu`, `software`, or
`unavailable`; VPFL displays that mode and waits for a usable renderer before
opening media. The first-frame completion signal requires a size greater than
the 1 × 1 bootstrap placeholder.

Main implementation files: [video output](../../third_party/media_kit_video/linux/video_output.cc),
[GL texture](../../third_party/media_kit_video/linux/texture_gl.cc),
[native controller](../../third_party/media_kit_video/lib/src/video_controller/native_video_controller/real.dart),
[texture widget](../../third_party/media_kit_video/lib/src/video/video_texture.dart),
and [player screen](../../lib/ui/player/player_screen.dart).

### 4. Failures encountered during development

- The first injected GPU initialization failure reached a `SIGSEGV` on Flutter's
  raster thread under GDB. At that point the texture callback returned failure
  without supplying a usable texture. The callback now returns a valid 1 × 1
  placeholder until the software texture replaces it. The same injected
  failure then completed the native playback integration test.
- An early software fallback notification had no useful video dimensions. The
  bootstrap notification now uses 1 × 1; a later notification reports the
  actual 1280 × 720 dimensions after media opens.
- The integration check initially raced the texture bootstrap and queue update.
  It now pumps frames until a real sized texture is reported and waits for the
  two-item playlist before calling `next()`.
- If GPU cleanup cannot activate its EGL context, the plugin no longer tries to
  create a second mpv render context on the same handle. It reports the output
  as unavailable. That exceptional cleanup failure has not been induced on the
  test machine.
- Later smoke runs wrapped `flutter run` in `timeout`. Those runs reached GPU
  mode and 1280 × 720; their final `Lost connection to device` occurred when
  `timeout` terminated the process. It is not evidence of the original failure
  recurring.

## Validation results

- `flutter analyze` passed with no issues after the final cleanup changes.
- `flutter build linux --debug` and `flutter build linux --release` passed. The
  release build was repeated after the final cleanup changes.
- The native integration test passed with the normal GPU path on X11/AMD/Mesa.
  It waited for a real sized texture, checked renderer mode, playback position,
  duration, recorded history and resume position, seeking, pause, rate, volume,
  and moving to the next queue item.
- The same native integration test passed with
  `VPFL_TEST_FAIL_GPU_INIT=1`. The log showed the injected failure, switch to
  `S/W rendering`, and a software texture resize to 1280 × 720. This validates
  the recovery path for an initialization failure; it does not exercise every
  possible GPU failure.
- A release-app smoke run logged `H/W rendering with shared Flutter EGL
  context` and a 1280 × 720 resize without a crash during its observation
  window. A `flutter run --no-enable-impeller` smoke run also reached GPU mode
  and the same size before intentional timeout termination.
- The checked-in [VPFL package patch](../../patches/media_kit_video/vpfl-rendering.patch)
  applied cleanly to a fresh cached copy of `media_kit_video` 2.0.1. Its
  [update instructions](../../patches/media_kit_video/README.md) explain how
  to try a later published version.

The Flutter driver emitted `integration_test plugin was not detected` after the
test body. Both native runs still ended with `All tests passed`. This warning
was not investigated as part of the renderer checkup.

## What is achieved, and what remains open

The current local implementation selects GPU output on the tested X11 machine,
reaches a real sized video texture, and recovers to software output under a
forced GPU initialization failure. The player reports the renderer mode.
Analysis, native integration, and debug and release builds passed.

The original `flutter run` disconnect has no proven root cause because it was
not reproduced under GDB before the change. The new path removes the isolated
context design suspected in that report, but a short successful run cannot
prove that all intermittent disconnects are gone.

The test checks texture dimensions and playback events; it does not capture or
compare presented pixels. It also does not measure frame rate, dropped frames,
power use, or whether the video **decoder** is hardware accelerated. `gpu`
means the video **rendering** path uses GL. Disposal followed by reopen was
not separately exercised. The full repository test suite was not rerun in
this checkup.

Wayland, Intel, NVIDIA, and Flatpak runtime behavior remain unverified. The
capability checks and software fallback are intended to improve portability,
but coverage on one X11/Mesa host cannot establish support for all Linux
distributions or drivers. Those environments need their own playback,
fallback, reopen, and visible-frame checks before a broad compatibility claim.

## Repeat the local checks

Run these commands from the repository root with an accessible local sample:

```bash
flutter analyze
flutter build linux --release
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/linux_playback_test.dart -d linux \
  --dart-define=VPFL_TEST_VIDEO="$PWD/videos/default.mp4"
VPFL_TEST_FAIL_GPU_INIT=1 flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/linux_playback_test.dart -d linux \
  --dart-define=VPFL_TEST_VIDEO="$PWD/videos/default.mp4"
flutter run -d linux --dart-entrypoint-args=videos/default.mp4
```

The environment variable is a development fault injection switch. In the
running app, the renderer indicator should change from `initializing` to
`gpu`, or to `software` when the injected failure is enabled. The optional
CUDA warning can appear on this AMD host in otherwise successful runs.
