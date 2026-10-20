#!/usr/bin/env bash
set -euo pipefail

[[ -n "${DISPLAY:-}" ]] || { echo 'X11 DISPLAY is required' >&2; exit 2; }
[[ $# -gt 0 ]] || { echo 'usage: run_subtitle_window.sh COMMAND...' >&2; exit 2; }
logdir=${VPFL_CI_LOG_DIR:-build/ci-logs}
mkdir -p "$logdir/subtitle-window"
if command -v openbox >/dev/null; then
  openbox >"$logdir/subtitle-window/window-manager.log" 2>&1 &
elif command -v metacity >/dev/null; then
  metacity --replace --no-composite >"$logdir/subtitle-window/window-manager.log" 2>&1 &
else
  echo 'A window manager (Metacity or Openbox) is required for fullscreen checks' >&2
  exit 2
fi
wm=$!
cleanup() {
  kill "$wm" 2>/dev/null || :
  wait "$wm" 2>/dev/null || :
}
trap cleanup EXIT
for _ in {1..50}; do
  if wmctrl -m >/dev/null 2>&1; then break; fi
  if ! kill -0 "$wm" 2>/dev/null; then
    cat "$logdir/subtitle-window/window-manager.log" >&2
    echo 'Window manager exited before taking control of X11' >&2
    exit 1
  fi
  sleep 0.1
done
wmctrl -m >/dev/null || { echo 'Window manager did not become ready' >&2; exit 1; }
"$@"
