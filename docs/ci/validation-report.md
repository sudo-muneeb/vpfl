# CI implementation and validation report

**Date:** 10 October 2026. **Branch:** `ci/production-testing`. This report records
observed results for the checkout; it does not turn unrun GitHub jobs into
passes. The V1 format decision in this work is video-only. The handoff's eight
standalone audio fixtures were removed from the declared matrix. Two hosted
runs on PR #3 have occurred. Both failed before native compilation and
playback. The first dependency fix was exercised in the second run; the
second set of fixes has not yet run on GitHub.

## A. Original state

| Area | Before this work |
| --- | --- |
| GitHub Actions | No workflow files in `.github/workflows/`; no required check. |
| Unit/widget tests | 17 test files covering shell, controls, settings, library scanning, thumbnails, history, and format policy. |
| Native integration | Seven existing Linux test files; several require manual fixture paths or opt-in XDG environment. The package smoke looked for a video texture size, not decoded pixels. |
| Distribution packages | DEB and RPM packaging scripts, plus prebuilt-style Arch `vpfl-bin` packaging. Existing RPM packaging could reuse an Ubuntu-family Flutter bundle. |
| Displays | Local Xvfb scripts; no required Weston/native Wayland or XWayland lane. The runner selects X11 when `DISPLAY` exists unless `GDK_BACKEND` is set. |
| Media | No checked-in executable codec manifest. Existing native tests used a few manually supplied samples. |
| Persistence | On-disk history reopen test and settings tests, but no old-schema migration test. |

## B. Implemented changes

- `.github/workflows/ci.yml` defines fixture, quality, three target-native
  build/media, three clean package-install, three display/fallback, and
  aggregate-gate jobs. The gate rejects any failed, canceled, or skipped
  required job. The workflow uses read-only PR permissions.
- Nightly and manual release-candidate workflows rerun the required pipeline;
  nightly adds a 30-cycle lifecycle test. Neither publishes artifacts.
- `ci/media-matrix.json` declares **26 video/container cases**, four external
  subtitle cases, and one embedded-subtitle video. A separate 30-second video
  supports older playback/lifecycle regressions. No standalone audio format is
  added to V1's open or scan policy.
- The generator, verifier, XDG/display wrapper, package smoke, Arch package
  helper, and regression runner are in `scripts/ci/`.
- The native integration test opens every video through `PlaybackService`,
  checks stream codecs and a decoded PNG color-patch oracle, exercises pause,
  seek, resume, natural completion, and stop, and checks subtitle track
  discovery. GTK's actual backend is queried over the native window channel.
  A GPU-init fault lane requires software output.
- A manually dispatched physical-GPU workflow is defined for a provisioned
  self-hosted runner. It checks the GL renderer, records EGL diagnostics, and
  requires observed GPU output and H.264 hardware decoding. It has not run.
- A format-policy contract test checks that every advertised explicit-open
  video extension has a fixture and rejects standalone audio. An isolated
  SQLite test reconstructs the original schema 1 table set from commit
  `e390c16`, upgrades to schema 2, checks history/settings preservation and
  `PRAGMA integrity_check`, then reopens the file.
- The Arch package helper compiles the bundle in Arch before `makepkg`;
  package scripts now accept ImageMagick 6 (`convert`) or 7 (`magick`).

## C. Platform and display evidence

| Target | Implemented lane | Local result | Hosted result | Limit |
| --- | --- | --- | --- | --- |
| Linux Mint 22.3 / Ubuntu-family X11 | Native test and local DEB build | 31-case normal and software-fallback playback passed; DEB built and validated | Ubuntu native job passed fixture verification, then Git rejected the mounted Flutter SDK during `pub get` | Xvfb/Mesa llvmpipe, not Ubuntu-native build or physical GPU |
| Ubuntu 24.04 clean install | `apt` install, launch, remove | Passed install, desktop metadata, required libraries, six compositor color bars, X11 launch/close, removal, and user-data preservation | Package job skipped after native failure | Package was built on Mint; the headless log also contains codec and missing audio-device warnings despite visible video |
| Fedora 44 | Fedora-native build/media and `dnf` install jobs | Native toolchain dependencies installed; mounted host Flutter SDK stalled at `pub get` and the local validation container was stopped after 12 hours. A separate container with RPM Fusion full FFmpeg verified the hosted 31-fixture artifact. | Native job stopped on fixture-verifier JSON parse; package job skipped | No Fedora-native VPFL build or playback result |
| Arch | Arch-native build/media and `pacman -U` jobs | Native toolchain dependencies installed from the official geo mirror; mounted host Flutter SDK stalled at `pub get` and the local validation container was stopped after 12 hours | Native job passed fixture verification, then Git rejected the mounted Flutter SDK during `pub get`; package job skipped | No Arch-native VPFL build or install result |
| X11/Xvfb | Full matrix and existing regressions | Matrix passed; GTK reported `GdkX11Display` through native channel | Ubuntu/Arch native and fallback jobs stopped at SDK ownership; Fedora at fixture verification | GL renderer is Mesa llvmpipe |
| Native Wayland/Weston | Full matrix | Not run locally; Weston unavailable on host | Display job passed fixture verification, then stopped at SDK ownership | No presentation result |
| Weston XWayland | Full matrix | Not run locally; Weston unavailable on host | Display job passed fixture verification, then stopped at SDK ownership | No presentation result |
| GNOME/KWin nested | No job | Not implemented | Not run | Requires separate reliable compositor setup |
| Physical GPU | Optional self-hosted manual workflow | Not executed | Not run | No provisioned runner or hardware GPU/decoder claim |

## D. Media evidence

The verifier passed all 31 generated entries and their SHA-256, stream,
container, pixel-format, dimension, duration, and decode checks. A deliberately
corrupted H.264 fixture made the verifier fail. The X11 native suite then
passed all 26 video entries through VPFL's actual playback service and decoded
color-patch assertion, plus four external subtitle track cases and the
embedded-subtitle video. The same suite passed with GPU initialization
failure injected and software output required.

The installed Ubuntu DEB also displayed the 30-second regression video in
Xvfb: a capture of the final X11 window contained six broad color bars in the
expected order. The same checker rejected an all-black capture. This proves
one installed-package compositor frame, not playback on a physical GPU.
The local capture is `build/ci-logs/ubuntu-installed-compositor.png`; it is
ignored by Git along with the other generated CI evidence.

| Video IDs | Local native X11 result |
| --- | --- |
| `h264_mp4`, `h264_mkv`, `h264_mov`, `h264_10bit_mkv`, `h264_mts`, `h264_m4v` | Passed in the 31-entry integration run |
| `hevc_8bit_mp4`, `hevc_10bit_mkv` | Passed |
| `vp8_webm`, `vp9_webm`, `av1_webm` | Passed |
| `mpeg2_mpg`, `mpeg2_mpeg`, `mpeg2_ts`, `mpeg2_m2ts`, `mpeg2_vob`, `mpeg2_mxf` | Passed |
| `mpeg4_avi`, `mpeg4_3gp`, `mpeg4_3g2`, `theora_ogv`, `mjpeg_avi`, `prores_mov` | Passed |
| `flv_flv`, `wmv_asf`, `wmv_asf_ext` | Passed |
| `sub_srt`, `sub_vtt`, `sub_ass`, `sub_ssa` | Track discovery passed; cue presentation not asserted |
| `embed_srt_mkv` | Subtitle track discovery and video patch screenshot passed; cue presentation not asserted |

This table reports one successful aggregate test that iterated every ID.
It is not a matrix result for Fedora, Arch, Wayland, or a physical GPU.
VPFL's video output can say `gpu` while GL itself is software rendered:
`glxinfo -B` in local Xvfb reported Mesa llvmpipe and `Accelerated: no`.

## E. Application coverage

The unit/widget suite exercises navigation, controls, themes, settings,
library scanning, thumbnails, history, and format policy. Existing native
regressions cover playback interactions, invalid-source recovery, the media
inspector, recoverable codec warnings, Home/reopen lifecycle, and isolated
GIO defaults. The new database test covers a representative schema upgrade
and real settings persistence. The PR pipeline currently lacks final
compositor-pixel checks for the full fixture matrix, subtitle cue rendering
assertions, package upgrades, and automated performance thresholds.

## F. Local command evidence

| Command | Observed result |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Passed. |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Passed; 66 files checked, 0 changed. |
| `flutter analyze` | Passed; no issues. |
| `flutter test --reporter expanded` | Passed; 65 tests. |
| `flutter test test/data/repositories/database_migration_test.dart --reporter expanded` | 1 passed. |
| `python3 scripts/ci/generate_fixtures.py --out build/ci-video-fixtures` | 31 fixtures, 7,347,671 total bytes. |
| `python3 scripts/ci/verify_fixtures.py --dir build/ci-video-fixtures` | 31/31 passed. |
| `bash scripts/ci/run_display.sh x11 flutter test integration_test/media_matrix_test.dart -d linux --dart-define=VPFL_CI_FIXTURES="$PWD/build/ci-video-fixtures"` | 1 aggregate test passed, all 31 cases iterated with video pause/seek/resume/natural completion/stop; 90-second test output on the final run. |
| Same command with `VPFL_TEST_FAIL_GPU_INIT=1` | 1 aggregate test passed with video pause/seek/resume/natural completion/stop, software mode observed; 78-second test output on the final run. |
| `bash scripts/ci/run_regressions.sh build/ci-video-fixtures` | Passed all six suites end to end: playback, library-open failure, inspector, recoverable codec error, three-cycle lifecycle with rapid source switching, and isolated GIO default-app behavior. |
| `bash packaging/scripts/package-linux.sh deb` | Release bundle and DEB package validator passed; `dist/vpfl_1.0.0-1_amd64.deb` created. |
| `bash scripts/ci/run_installed_package.sh ubuntu dist/vpfl_1.0.0-1_amd64.deb build/ci-video-fixtures/regression.mp4` in Ubuntu 24.04 container | Passed install, desktop/AppStream metadata, required libraries, six ordered color bars from an X11 compositor capture, launch/close, removal, and database preservation. The DEB was built on Mint. |
| `bash -n scripts/ci/*.sh`, Python compile, workflow YAML parse | Passed. |
| `go run github.com/rhysd/actionlint/cmd/actionlint@latest .github/workflows/*.yml` | Passed with actionlint v1.7.12; no workflow findings. |
| Disposable Ubuntu 24.04, Fedora 44, and Arch containers: install `jq`, then `jq --version` | All passed (`jq` 1.7, 1.8.1, and 1.8.2 respectively). This verifies package availability, not a rerun of Flutter setup. |
| Fedora 44 container: RPM Fusion Free full `ffmpeg`, then `python3 scripts/ci/verify_fixtures.py --dir` against the downloaded second-run artifact | 31/31 passed, including 10-bit H.264 and HEVC; `mpv-devel` also installed successfully with full FFmpeg. The same fixture under Fedora `ffmpeg-free` emitted `DecodeFrame failed` and reported `yuv420p` instead of `yuv420p10le`. This is dependency and fixture-verifier evidence, not VPFL playback. |

The fixture index is in `build/ci-video-fixtures/index.json`; display logs
are in `build/ci-logs/`. Generated media and packages are ignored by Git.
The [first hosted run](https://github.com/sudo-muneeb/vpfl/actions/runs/38057627045)
passed fixtures and quality. All three native builds and all three display
jobs failed in `subosito/flutter-action` with `jq not found`; their build and
media assertions did not run. The package jobs then failed to download
nonexistent artifacts, and `ci / required-gate` failed as designed.
Adding `jq` on each distribution and gating package jobs on native success
was exercised in the [second hosted run](https://github.com/sudo-muneeb/vpfl/actions/runs/38058196617).
Fixtures and quality passed again. Ubuntu and Arch native jobs and all three
display jobs verified all 31 fixtures, then `flutter pub get` stopped with
Git's `detected dubious ownership` error for the mounted Flutter SDK. Fedora
stopped in the verifier at `h264_10bit_mkv` with `JSONDecodeError`; the prior
verifier merged FFprobe stderr into its JSON stdout. Package jobs were skipped
because their native dependencies failed, and the required gate failed.
The current checkout adds exact-path Git trust entries and separates FFprobe
stdout from stderr. A local Fedora 44 `ffmpeg-free` reproduction confirmed
`DecodeFrame failed` on that 10-bit H.264 fixture and showed the wrong pixel
format. The native and clean-install Fedora lanes now enable RPM Fusion Free
and install full FFmpeg. These changes await a hosted run.

## G–J. Hosted status, gaps, docs, and merge gate

The first two hosted runs **failed before native compilation**. No branch rules
were changed. The exact status check to require on both `bootstrap-project`
and `main` is `ci / required-gate`. Require pull-request review and disallow
direct/force pushes. The gate's upstream jobs have no path filters, so a
Linux, packaging, or vendored-patch-only PR still schedules them.

The main limitations are the uncompleted Fedora/Arch and Weston lanes,
absence of physical GPU testing, missing full-matrix compositor and
subtitle-cue oracles, and unmeasured hosted stability/runtime. The workflow's
external actions and container images use release tags rather than immutable
SHAs/digests.
Production-grade acceptance still requires successful hosted runs, deliberate
fail-closed checks beyond fixture corruption, and the manual items in the
[release checklist](release-checklist.md).

Documentation changed: `README.md`, `CONTRIBUTING.md`, `docs/01-product-scope-fixed.md`, `docs/02-architecture.md`,
`docs/04-performance.md`, `docs/05-linux-flatpak.md`, `docs/06-testing.md`,
`docs/08-coding-agent-brief.md`, `docs/compatibility/native-packages.md`, and
the dedicated `docs/ci/` guide, troubleshooting, checklist, and this report.

| Area | Implemented | Local result | GitHub result | Limitation |
| --- | --- | --- | --- | --- |
| Fixture generation and verification | Yes | 31/31 pass; corruption rejected | Fixture job passed both runs; Fedora native verifier failed on FFprobe output in second run | FFmpeg version/image digest not pinned; current verifier fix unverified on Fedora CI |
| Unit/widget and database | Yes | Full 65-test suite passed, including migration and video-only policy contract | Quality job passed both runs | No true released database image snapshot |
| VPFL decoded video matrix on X11 | Yes | 31/31 pass in normal and software-fallback lanes | Blocked by SDK ownership or Fedora verifier; not executed | No per-fixture compositor pixel capture; one installed-package video was captured |
| Native DEB | Yes | Mint-family release package validator pass | Blocked by SDK ownership; not built | Ubuntu-native CI build unexecuted |
| Native RPM/Arch | Yes, workflow/scripts | Target dependency sets installed; mounted-SDK `pub get` did not finish, so no native package result | Fedora verifier and Arch SDK ownership blocked builds | Current fixes, including Fedora full FFmpeg, unverified on GitHub |
| Clean package install/removal | Yes, workflow/scripts | Ubuntu clean install, video color-bar capture, launch/close, and removal passed | Skipped after native failures in second run | Fedora/Arch install unrun; only one release-package video captured |
| Native Wayland/XWayland | Yes, workflow/scripts | Not executed | Blocked by SDK ownership; not executed | Weston unavailable locally |
| Real hardware GPU | Optional manual workflow | Not executed | Not run | Requires provisioned self-hosted runner; not a required PR gate |
