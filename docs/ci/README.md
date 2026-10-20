# VPFL continuous integration

This guide describes the checks in `.github/workflows/ci.yml` and their
observed status. The workflow runs for pull requests targeting
`bootstrap-project` or `main`; it also supports manual dispatch.

## V1 media contract

VPFL V1 opens video files. `ci/media-matrix.json` lists 26 video
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

The [additional subtitle fixture suite](subtitle-fixtures.md) is generated
and verified in the same CI fixture job. Its 25 generated files cover cue
timing, language metadata, sidecar naming, ASS styles/effects, font attachment,
Unicode, malformed text, a source-switch pair, and controlled resize captions.
They are fixture checks, not new native playback assertions.
The [native subtitle comparison](native-subtitle-verification.md) checks
standalone mpv and pinned media_kit rendering before the required graphical
subtitle job checks VPFL's final X11 window.

## Required pull request jobs

| Check | Action |
| --- | --- |
| `ci / fixtures` | Generate and verify the complete video/subtitle fixture set plus a longer regression video once; upload them for other jobs. |
| `ci / quality` | Enforce lockfile, Dart formatting, analyzer, unit and widget tests. |
| `ci / native-build (ubuntu)` | Compile and package a DEB in Ubuntu 24.04; play the matrix and existing playback, lifecycle, error, inspector, and GIO regression suites in Xvfb. |
| `ci / native-build (fedora)` | Compile and package an RPM in Fedora 44; play the matrix in Xvfb. |
| `ci / native-build (arch)` | Compile on Arch, build `vpfl-bin` with `makepkg`, and play the matrix in Xvfb. |
| `ci / package-install (ubuntu/fedora/arch)` | Install the generated package with the target package manager, check files and libraries, capture video color bars plus authored ASS and external SRT captions from the installed app's X11 window, close it, then remove it. |
| `ci / display (wayland/xwayland/x11-fallback)` | Run the matrix under headless Weston or injected GPU initialization failure; query the selected GTK backend and require software fallback state. |
| `ci / graphical-subtitles (ubuntu-x11)` | Compare standalone mpv/media_kit subtitle frames, then check paired CC On/Off pixels from VPFL's actual X11 window. |
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
python3 -m unittest discover -s test/ci -p 'test_*.py' -v
python3 scripts/ci/generate_fixtures.py --out build/ci-video-fixtures --subtitle-suite
python3 scripts/ci/verify_fixtures.py --dir build/ci-video-fixtures --subtitle-suite
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

The opt-in [Part 4 subtitle integration check](../compatibility/subtitle-integration-part4.md)
uses the generated subtitle suite with VPFL's actual `PlaybackService` and
Flutter video surface. Run its four Linux test files in separate Flutter
invocations after fixture verification; this host's Flutter runner could not
start the second app when multiple files were passed to one command.

The [Part 5 subtitle timing check](../compatibility/subtitle-settings-part5.md)
uses the same fixture suite to verify native delay readback, cue timing, and
libass pixels through VPFL's playback service.

The [Part 6 graphical subtitle check](subtitle-window-checks.md) captures
actual VPFL X11 window pixels and compares CC On/Off frames from the Flutter
video texture. A dedicated Ubuntu CI job runs it alongside the native
mpv/media_kit comparison; package-install jobs also check authored ASS and
automatically discovered SRT captions in installed VPFL windows.
The [Part 6 compatibility report](../compatibility/subtitle-rendering-part6.md)
records the executed results and remaining platform limits.

## Validation record

The [fifth hosted run](https://github.com/sudo-muneeb/vpfl/actions/runs/38117032738)
on PR #3 passed all 12 jobs, including the required gate. It covered the 31
video/subtitle cases in the native and display lanes and installed, launched,
and removed DEB, RPM, and Arch packages. This is the latest hosted run recorded
in the [detailed validation report](validation-report.md), which preserves the
failures and fixes from earlier runs.

The earlier `jq`, Git ownership, FFprobe parsing, Fedora codec setup, and
XWayland socket failures were corrected and exercised by later hosted runs.
Fedora and Arch playback stalls were addressed with a single startup open,
bounded operations, stage logs, and a null audio sink for headless tests. Two
local full-matrix runs on each distribution and the fifth hosted run passed;
the hosted result is one pass after the intermittent stalls. Decoder-selection
messages such as `Could not open codec` appeared in headless Ubuntu/display
logs, but the decoded-frame and completion checks passed. See the
[hardware-decoding fallback documentation](https://mpv.io/manual/stable/#options-hwdec).

On 12 October 2026, the local unit/widget suite passed 71 tests and
`flutter analyze` reported no issues. Native lanes were not rerun for this
local documentation audit.

## Known limits

- The 31-file integration test checks decoded mpv screenshots. The installed
  package smoke captures final compositor pixels for one 30-second video and
  authored ASS/external SRT fixtures; it does not repeat that capture for all
  31 fixtures or for Wayland/XWayland.
- The graphical subtitle lane checks both native subtitle pixels and final
  VPFL X11 window pixels. It does not establish glyph shaping semantics or
  Wayland compositor output.
- The suite covers pause, seek, resume, and natural completion for each video.
  The GPU initialization fault is injected in one X11 lane; other native
  renderer faults are not yet covered.
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

The active **Protect main** ruleset requires a pull request, resolved review
threads, and linear history. It blocks deletion and force-pushes to `main` and
allows squash or rebase merges. It currently requires zero approving reviews
and does not require a status check. Contributors should still fix failing CI
jobs before merging. See the [contributor guide](../../CONTRIBUTING.md).

For enforceable CI protection, add `ci / required-gate` as a required status
check in the `main` ruleset after it has reported on a pull request. Require
at least one independent approval if review by another person is part of the
merge policy. The pull request template and `AGENTS.md` ask for evidence, but
repository instructions alone cannot prevent an agent from committing or
merging; branch rules and the owner's review provide the separate gate.
