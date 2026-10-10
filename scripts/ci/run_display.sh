#!/usr/bin/env bash
set -euo pipefail

mode=${1:?usage: run_display.sh x11|wayland|xwayland command...}
shift
runtime=${VPFL_CI_XDG_ROOT:-}
owns_runtime=false
if [[ -z "$runtime" ]]; then
  runtime=$(mktemp -d -t vpfl-display.XXXXXXXX)
  owns_runtime=true
else
  mkdir -p "$runtime"
fi
chmod 700 "$runtime"
export XDG_RUNTIME_DIR="$runtime"
export XDG_CONFIG_HOME="$runtime/config"
export XDG_DATA_HOME="$runtime/data"
export XDG_CACHE_HOME="$runtime/cache"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
logdir=${VPFL_CI_LOG_DIR:-build/ci-logs}
mkdir -p "$logdir"
compositor=''
cleanup() {
  if [[ -n "$compositor" ]]; then
    kill "$compositor" 2>/dev/null || :
    wait "$compositor" 2>/dev/null || :
  fi
  if [[ -f "$runtime/weston.log" ]]; then
    cp "$runtime/weston.log" "$logdir/${mode}-weston.log"
  fi
  if [[ "$owns_runtime" == true ]]; then rm -rf "$runtime"; fi
}
trap cleanup EXIT

case "$mode" in
  x11)
    unset WAYLAND_DISPLAY
    export GDK_BACKEND=x11
    export VPFL_CI_DISPLAY_BACKEND=GdkX11Display
    exec_cmd=(xvfb-run -a "$@")
    ;;
  wayland|xwayland)
    unset DISPLAY
    export WAYLAND_DISPLAY=wayland-ci
    export GDK_BACKEND=wayland
    export VPFL_CI_DISPLAY_BACKEND=GdkWaylandDisplay
    weston_args=(--backend=headless-backend.so --socket="$WAYLAND_DISPLAY" --idle-time=0)
    if [[ "$mode" == xwayland ]]; then
      # Fresh containers do not always have the X11 socket directory.
      install -d -m 1777 /tmp/.X11-unix
      weston_args+=(--xwayland)
    fi
    weston "${weston_args[@]}" >"$runtime/weston.log" 2>&1 &
    compositor=$!
    for _ in {1..100}; do
      [[ -S "$runtime/$WAYLAND_DISPLAY" ]] && break
      if ! kill -0 "$compositor" 2>/dev/null; then
        cat "$runtime/weston.log"
        echo 'Weston exited before the Wayland socket was ready' >&2
        exit 1
      fi
      sleep 0.1
    done
    [[ -S "$runtime/$WAYLAND_DISPLAY" ]] || { cat "$runtime/weston.log"; exit 1; }
    if [[ "$mode" == xwayland ]]; then
      export GDK_BACKEND=x11
      export VPFL_CI_DISPLAY_BACKEND=GdkX11Display
      # Weston allocates an X display dynamically; read its own announcement.
      for _ in {1..100}; do
        display=$(sed -nE 's/.*(display|listening on) (:[0-9]+).*/\2/p' "$runtime/weston.log" | tail -1)
        [[ -n "$display" ]] && break
        sleep 0.1
      done
      [[ -n "${display:-}" ]] || { cat "$runtime/weston.log"; echo 'No XWayland display' >&2; exit 1; }
      export DISPLAY="$display"
      xdpyinfo >/dev/null
    fi
    exec_cmd=("$@")
    ;;
  *) echo "unknown display mode: $mode" >&2; exit 2 ;;
esac

log="$logdir/${mode}-$(date +%s).log"
set +e
"${exec_cmd[@]}" 2>&1 | tee "$log"
result=${PIPESTATUS[0]}
set -e
if [[ -f "$runtime/weston.log" ]]; then
  cat "$runtime/weston.log"
fi
[[ "$result" == 0 ]] || exit "$result"
