# CI troubleshooting

Start with the first failed job in the pull request's **Checks** tab. The
`ci / required-gate` result summarizes failure, but the source job contains
the useful log. `ci / fixtures` uploads the exact generated fixture set and
`index.json`; native build jobs upload packages and `BUILD-INFO` when their
build reaches artifact creation. Package-install jobs upload the installed
app log and X11 compositor capture when those files are available.

| Symptom | Inspect | Local reproduction |
| --- | --- | --- |
| Flutter action reports `jq not found` in a distro container | Dependency installation before `subosito/flutter-action`; all native and display lanes need `jq` | Run `scripts/ci/install_dependencies.sh <distro>` in a disposable target container, then `jq --version` |
| Package artifact missing after native build failure | First failing `ci / native-build` job; the package job depends on its artifact | Fix the native failure, then rerun the PR workflow; the required gate also rejects skipped jobs |
| Missing encoder, codec, or pixel format | `ci / fixtures` generator and verifier output, FFmpeg version in `index.json` | `python3 scripts/ci/generate_fixtures.py --out build/ci-video-fixtures` |
| Video patch or track mismatch | First failing fixture ID in `ci / native-build` or `ci / display`; its FFprobe metadata and VPFL log | `./scripts/ci/run_display.sh x11 flutter test integration_test/media_matrix_test.dart -d linux --dart-define=VPFL_CI_FIXTURES="$PWD/build/ci-video-fixtures"` |
| Wrong display backend | Native method-channel assertion, `DISPLAY`, `WAYLAND_DISPLAY`, Weston log | Run `scripts/ci/run_display.sh` with `x11`, `wayland`, or `xwayland` |
| Package cannot install or launch | Package-manager resolver output, `ldd`, desktop metadata, native stdout | `bash scripts/ci/run_installed_package.sh <distro> <package> build/ci-video-fixtures/h264_mp4.mp4` in a disposable target container |
| `ldd` reports `libjvm.so` for `libdartjni.so` | This bundled Android JNI asset is unused by VPFL on Linux and is excluded from package dependency resolution | Check the remaining libraries and the installed VPFL launch result; do not add Java solely for this asset |
| Distribution setup stalls or times out | Package-manager download errors, mirror reachability, Flutter `pub get` process and cache | Retry with the configured APT retries or set `VPFL_CI_ARCH_MIRROR` to a reachable Arch mirror; use a fresh Flutter SDK inside the target container |
| Analyzer or widget failure | `ci / quality` first failing test | `flutter analyze` or `flutter test --reporter expanded` |

Do not turn a failing mode into a skipped or nonblocking check. Distinguish a
generator defect, VPFL playback defect, dependency failure, and missing
infrastructure in the PR description. Do not report an mpv screenshot as a
compositor screenshot, or Mesa llvmpipe as hardware GPU rendering.
