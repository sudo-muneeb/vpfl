#!/usr/bin/env bash
# Opt-in desktop checks: never installs packages or touches the normal profile.
set -euo pipefail
require_gpu=true
decode=false
require_decode=false
for arg in "$@"; do
  case "$arg" in
    --allow-software) require_gpu=false ;;
    --decode) decode=true ;;
    --require-decode) decode=true; require_decode=true ;;
    --help|-h)
      echo 'usage: bash scripts/testing/test_gpu.sh [--allow-software] [--decode|--require-decode]'
      echo 'Uses the current X11 display (including an existing XWayland session).'
      echo 'Default: require physical GPU rendering; decoding is reported separately.'
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"
mkdir -p build/gpu-results
out=$(mktemp -d "$root/build/gpu-results/run.XXXXXXXX")
profile=$(mktemp -d -t vpfl-gpu.XXXXXXXX)
result=0
report="$out/report.txt"
record() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" | tee -a "$report"; }
# shellcheck disable=SC2317 # Invoked indirectly by the EXIT trap.
cleanup() {
  rm -rf "$profile"
  # Paths can occur in Flutter/tool diagnostics; remove the home prefix from
  # text logs. Contributors must still review all files before sharing.
  python3 - "$out" <<'PY'
from pathlib import Path
import sys
home = str(Path.home())
for path in Path(sys.argv[1]).glob('*.log'):
    path.write_text(path.read_text(errors='replace').replace(home, '~'))
PY
  printf 'Report: %s\n' "$report"
}
trap cleanup EXIT
printf 'VPFL commit: %s\n' "$(git rev-parse HEAD)" > "$report"
if [[ -n "$(git status --porcelain)" ]]; then
  printf 'Checkout state: modified or untracked files present\n' >> "$report"
else
  printf 'Checkout state: clean\n' >> "$report"
fi
printf 'Kernel: %s %s\n' "$(uname -s)" "$(uname -r)" >> "$report"
if [[ -r /etc/os-release ]]; then
  sed -n '/^PRETTY_NAME=/p' /etc/os-release >> "$report"
fi
for tool in flutter ffmpeg ffprobe python3 glxinfo; do
  if ! command -v "$tool" >/dev/null; then
    record FAIL prerequisites "Missing $tool"; exit 1
  fi
done
if [[ -z "${DISPLAY:-}" ]]; then
  record UNSUPPORTED display 'An active X11 or XWayland DISPLAY is required'
  exit 1
fi
if command -v lspci >/dev/null; then
  lspci -nnk | sed -nE '/VGA compatible controller|3D controller|Display controller/,+3p' >> "$report"
else
  record SKIP hardware-inventory 'lspci unavailable; renderer diagnostics still required'
fi
if ! glxinfo -B > "$out/glx.log" 2>&1; then
  record FAIL renderer-probe 'glxinfo failed; see glx.log'; exit 1
fi
# GLX identifies the renderer actually attached to this X11 display. EGL is
# supplementary: its device list alone does not prove the active renderer.
grep -E 'OpenGL (vendor|renderer|core profile version|version) string|direct rendering:' "$out/glx.log" >> "$report" || true
if command -v eglinfo >/dev/null; then
  if eglinfo -B > "$out/egl.log" 2>&1; then
    record PASS egl-diagnostics 'Recorded egl.log'
  else
    record UNSUPPORTED egl-diagnostics 'Some EGL platforms failed; see egl.log'
  fi
else
  record SKIP egl-diagnostics 'eglinfo unavailable'
fi
renderer=$(sed -n 's/.*OpenGL renderer string: //p' "$out/glx.log")
if [[ -z "$renderer" ]]; then
  record FAIL renderer-probe 'No active OpenGL renderer'; exit 1
fi
software=false
if [[ "${renderer,,}" =~ llvmpipe|softpipe|swrast|virgl|software|swiftshader|lavapipe ]]; then software=true; fi
if [[ "$software" == true ]] || ! compgen -G '/dev/dri/renderD*' >/dev/null; then
  if [[ "$require_gpu" == true ]]; then
    record FAIL physical-renderer 'Physical renderer and DRM render node required'
    record SKIP native-playback 'Physical renderer prerequisite failed'
    record SKIP hardware-decode 'Physical renderer prerequisite failed'
    exit 1
  fi
  record SKIP physical-renderer 'Software GL allowed; native GPU output is not physical hardware evidence'
else
  record PASS physical-renderer 'Hardware GL renderer and DRM render node detected'
fi
record PASS renderer-probe "$renderer"
# Keep the session runtime and X authority for the existing display, but isolate
# every persistent XDG location. The tests only open generated synthetic media.
export XDG_CONFIG_HOME="$profile/config" XDG_DATA_HOME="$profile/data"
export XDG_CACHE_HOME="$profile/cache" XDG_STATE_HOME="$profile/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
export GDK_BACKEND=x11 VPFL_CI_DISPLAY_BACKEND=GdkX11Display
export VPFL_CI_LOG_DIR="$out"
unset VPFL_TEST_FAIL_GPU_INIT VPFL_CI_REQUIRE_HARDWARE
if ! flutter pub get --enforce-lockfile > "$out/dependencies.log" 2>&1; then
  record FAIL dependencies 'See dependencies.log'; exit 1
fi
if ! python3 scripts/ci/generate_fixtures.py --out "$profile/fixtures" > "$out/fixtures.log" 2>&1 ||
   ! python3 scripts/ci/verify_fixtures.py --dir "$profile/fixtures" >> "$out/fixtures.log" 2>&1; then
  record FAIL fixtures 'See fixtures.log'; exit 1
fi
if flutter test integration_test/media_matrix_test.dart -d linux \
    --dart-define=VPFL_CI_FIXTURES="$profile/fixtures" \
    --reporter expanded > "$out/playback.log" 2>&1; then
  record PASS native-playback 'Full synthetic codec matrix completed'
else
  record FAIL native-playback 'See playback.log'
  record SKIP native-gpu-output 'Playback did not complete'
  record SKIP hardware-decode 'Playback did not complete'
  exit 1
fi
# Native Flutter tests do not reliably forward raw Dart stdout. Consume the
# matrix's flushed stage log from this unique run, never stale build output.
evidence="$out/media-matrix-stages.log"
if [[ ! -s "$evidence" ]]; then
  record FAIL diagnostics 'Native matrix did not record capability evidence'
  exit 1
fi
if grep -q ' VPFL_RENDERING_MODE=gpu$' "$evidence"; then
  record PASS native-gpu-output 'VPFL GPU texture path observed; physical renderer status is separate'
elif grep -q ' VPFL_RENDERING_MODE=software$' "$evidence"; then
  if [[ "$require_gpu" == true ]]; then
    record FAIL native-gpu-output 'Native GPU output not observed'; result=1
  else
    record SKIP native-gpu-output 'Software output allowed explicitly'
  fi
else
  record FAIL native-gpu-output 'Missing native rendering evidence'; result=1
fi
if [[ "$decode" == true ]]; then
  decoder=$(sed -n 's/.* VPFL_HARDWARE_DECODER=//p' "$evidence")
  case "$decoder" in
    '') record FAIL hardware-decode 'Missing decoder diagnostic'; result=1 ;;
    no|null)
      record UNSUPPORTED hardware-decode 'No H.264 hardware decoder observed; rendering result is independent'
      if [[ "$require_decode" == true ]]; then
        record FAIL required-decode 'Requested decoder capability was not demonstrated'; result=1
      fi ;;
    *) record PASS hardware-decode "Observed H.264 decoder: $decoder (no claim for other codecs)" ;;
  esac
else
  record SKIP hardware-decode 'Use --decode to assess H.264, or --require-decode to require it'
fi
exit "$result"
