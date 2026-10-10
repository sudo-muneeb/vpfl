# VPFL continuous integration

This guide describes the checks in `.github/workflows/ci.yml` and their
observed status. The workflow runs for pull requests targeting
`bootstrap-project` or `main`; it also supports manual dispatch. The checkout
had no GitHub Actions workflows before this change.

## V1 media contract

VPFL V1 opens video files. Standalone audio files are outside its supported
format policy and are not CI fixtures. `ci/media-matrix.json` lists 26 video
files across the advertised extensions, four external subtitle files used
with a video, and one video with an embedded subtitle. The video cases also
exercise their encoded audio streams. `.ts` is explicit-open only because the
suffix also names TypeScript files; declaration files such as `.d.mts` are
never indexed.

The fixture generator creates short synthetic files with fixed color patches.
`verify_fixtures.py` checks the manifest hash, each file hash and size,
container streams, codecs, pixel format, dimensions, duration, and FFmpeg
decode. The native integration test then opens every video through
`PlaybackService`, checks video and audio tracks, captures an mpv-decoded PNG,
checks the red, green, and blue patch positions, and exercises pause, seek,
resume, natural completion, and stop for each video. It checks subtitle track
discovery and a decoded frame for the embedded-subtitle video. **The current
test does not prove visible subtitle text or final Flutter composition.**

## Required pull request jobs

| Check | Action |
| --- | --- |
| `ci / fixtures` | Generate and verify the complete video/subtitle fixture set plus a longer regression video once; upload them for other jobs. |
| `ci / quality` | Enforce lockfile, Dart formatting, analyzer, unit and widget tests. |
| `ci / native-build (ubuntu)` | Compile and package a DEB in Ubuntu 24.04; play the matrix and existing playback, lifecycle, error, inspector, and GIO regression suites in Xvfb. |
| `ci / native-build (fedora)` | Compile and package an RPM in Fedora 44; play the matrix in Xvfb. |
| `ci / native-build (arch)` | Compile on Arch, build `vpfl-bin` with `makepkg`, and play the matrix in Xvfb. |
| `ci / package-install (ubuntu/fedora/arch)` | Install the generated package with the target package manager, check files and libraries, capture six video color bars from the installed app's X11 window, close it, then remove it. |
| `ci / display (wayland/xwayland/x11-fallback)` | Run the matrix under headless Weston or injected GPU initialization failure; query the selected GTK backend and require software fallback state. |
| `ci / required-gate` | Fail if any required job fails, is canceled, or is skipped. |

The separate, manually dispatched `gpu / physical-hardware` workflow needs a
self-hosted Linux x64 runner labeled `vpfl-gpu` with Flutter 3.47.5, FFmpeg,
`glxinfo`, `eglinfo`, a working X11 `DISPLAY`, and an accessible DRM render
node. It rejects known software GL renderers, records GL/EGL diagnostics,
then requires VPFL's GPU output path and an observed H.264 hardware decoder
while playing the full video matrix. It has not run on a provisioned runner
and is not a required PR check.

The three native build lanes compile in their own distribution containers.
The Arch target is still the `vpfl-bin` packaging design, but its bundle is
compiled on Arch in CI. X11 uses Xvfb. The Wayland lane removes `DISPLAY` and
requires `GdkWaylandDisplay`; XWayland explicitly selects X11 and requires
`GdkX11Display`. The integration test queries GTK through the native window
channel; a backend mismatch fails the lane. The workflows use
read-only repository permissions and no repository secrets.
Fedora's native and clean-install lanes enable RPM Fusion Free and install its
full `ffmpeg` package. Fedora's default `ffmpeg-free` decoder cannot handle
the 10-bit H.264 fixture and stops matrix validation before VPFL's playback
test. The fixture verifier still checks pixel format and full decode.

## Run locally

From the repository root with Flutter 3.47.5, Linux build dependencies,
FFmpeg, FFprobe, and Xvfb installed:

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --reporter expanded
python3 scripts/ci/generate_fixtures.py --out build/ci-video-fixtures
python3 scripts/ci/verify_fixtures.py --dir build/ci-video-fixtures
./scripts/ci/run_display.sh x11 flutter test integration_test/media_matrix_test.dart \
  -d linux --dart-define=VPFL_CI_FIXTURES="$PWD/build/ci-video-fixtures"
bash scripts/ci/generate_regression_video.sh build/ci-video-fixtures/regression.mp4
bash scripts/ci/run_regressions.sh build/ci-video-fixtures
```

The fixture directory is generated and ignored by Git. The Python verifier
must pass before the integration test. The test uses an in-memory Drift
database; the display wrapper gives the app isolated XDG directories.
For distribution-specific runs, use the same scripts as the workflow inside
the named target container. Avoid using a real VPFL user profile.

## Validation record

As of 10 October 2026, the revised generator produced **31/31** fixtures on
Linux Mint 22.3 with FFmpeg 6.1.1, and the separate verifier passed **31/31**.
The native X11 integration run opened all 31 cases through VPFL, checked video
decoding and subtitle track discovery, and passed again with GPU initialization
failure injected. The full unit/widget suite passed **65 tests**; Dart format
and analysis passed. Six existing native Linux regression suites also passed.
The local Mint release DEB built and passed its package validator. It also
passed a clean Ubuntu 24.04 install, X11 compositor color-bar capture,
launch/close, and removal smoke. A prior Xvfb
run with the handoff's 38 cases preceded the V1 video-only correction; it is
superseded and is not evidence for the final manifest. See the
[validation report](validation-report.md) for exact platform results and
limits. On PR #3, the first hosted run passed fixtures and quality, then the
container lanes stopped because `jq` was missing. The second run passed
fixtures and quality again and got through dependency setup. Five native and
display lanes then stopped at Git's ownership check on the mounted Flutter SDK;
Fedora stopped earlier when FFprobe's diagnostic output was mixed with JSON.
Local reproduction then confirmed Fedora's default decoder cannot decode the
10-bit H.264 fixture, so its lanes now install full FFmpeg from RPM Fusion Free.
The revised verifier passed all 31 fixtures from the second hosted artifact
inside a Fedora 44 container with that package set.
The package jobs were skipped because their native builds failed. The
[third hosted run](https://github.com/sudo-muneeb/vpfl/actions/runs/38073659777)
exercised those fixes: fixtures, quality, all three native builds, Wayland,
X11 software fallback, and all three clean package installs passed. XWayland
failed before Flutter started because Weston could not bind its X socket in a
fresh container without `/tmp/.X11-unix`. The local display-wrapper fix for
that startup failure needs a hosted rerun.

## Known limits

- The 31-file integration test checks decoded mpv screenshots. The installed
  package smoke captures final compositor pixels for one 30-second video; it
  does not repeat that capture for all 31 fixtures or for Wayland/XWayland.
- Subtitle tests check track discovery; they do not yet assert rendered cue
  text, timing, or style.
- The suite covers pause, seek, resume, and natural completion for each video.
  The GPU initialization fault is injected in one X11 lane; other native
  renderer faults are not yet covered.
- XWayland success requires a completed hosted run after the local socket
  directory fix. The third run reached build and playback assertions for
  Ubuntu, Fedora, Arch, native Wayland, and X11 software fallback; it did not
  reach VPFL playback under XWayland.
- A headless Mesa renderer is not a physical GPU or hardware decode result.
  The optional self-hosted GPU workflow and GNOME/KWin nested validation are
  unexecuted; there is no required physical-GPU PR lane yet.
- Flatpak packaging, upgrade from an old release package, old database schema
  snapshots, and long performance benchmarks are not part of this PR gate.
- Images and external actions are pinned to release tags, not immutable image
  digests or action commits. A reproducibility and supply-chain follow-up is
  needed before calling this pipeline production-grade.

See [troubleshooting](troubleshooting.md) and the
[release checklist](release-checklist.md).

The nightly workflow calls the same required CI and then runs 30 lifecycle
cycles on Ubuntu/Xvfb. The manual release-candidate workflow reruns required
CI without publishing. Neither workflow substitutes for the manual hardware,
desktop, upgrade, and Flatpak checks in the release checklist.

## Merge protection

After a successful hosted run on a pull request, configure branch rules for
both `bootstrap-project` and `main` to require **`ci / required-gate`** from
GitHub Actions, require pull-request review, and prevent direct and force
pushes. Do not make a path-based exception for `linux/`, `packaging/`, or
`third_party/`. This repository change does not modify branch rules.
