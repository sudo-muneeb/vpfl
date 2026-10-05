#!/usr/bin/env bash
set -euo pipefail

# Run under an X server, for example: xvfb-run -a ./packaging/scripts/check-linux-close.sh videos/default.mp4 30
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
sample=${1:-}
cycles=${2:-30}
bundle="$root/build/linux/x64/release/bundle/vpfl"
[[ -x "$bundle" && -f "$sample" ]] || {
  echo 'Build the release app and pass a local sample video path.' >&2
  exit 2
}
command -v xdotool >/dev/null
command -v wmctrl >/dev/null
logdir=$(mktemp -d -t vpfl-close.XXXXXXXX)
echo "Close-check logs: $logdir"
pid=''
wm_pid=''
trap '[[ -z "$pid" ]] || kill "$pid" 2>/dev/null || true; [[ -z "$wm_pid" ]] || kill "$wm_pid" 2>/dev/null || true' EXIT
if command -v metacity >/dev/null; then
  metacity --replace >"$logdir/window-manager.log" 2>&1 &
  wm_pid=$!
  sleep 1
fi

for ((i=1; i<=cycles; i++)); do
  case $(((i-1)%6)) in
    0) state=home ;;
    1) state=playing ;;
    2) state=paused ;;
    3) state=seeking ;;
    4) state=immediate ;;
    5) state=software ;;
  esac
  if [[ "$state" == home ]]; then
    "$bundle" >"$logdir/$i.log" 2>&1 &
  elif [[ "$state" == software ]]; then
    VPFL_TEST_FAIL_GPU_INIT=1 "$bundle" "$sample" >"$logdir/$i.log" 2>&1 &
  else
    "$bundle" "$sample" >"$logdir/$i.log" 2>&1 &
  fi
  pid=$!
  window=''
  for ((attempt=0; attempt<100; attempt++)); do
    window=$(wmctrl -lp | awk -v pid="$pid" '$3 == pid {print $1; exit}' || true)
    [[ -n "$window" ]] && break
    sleep 0.1
  done
  [[ -n "$window" ]] || { echo "No window for cycle $i ($state)" >&2; exit 1; }
  xdotool windowfocus "$window" 2>/dev/null || true
  if [[ "$state" != home && "$state" != immediate ]]; then
    sleep 1
  fi
  if [[ "$state" == paused ]]; then xdotool key --window "$window" space; fi
  if [[ "$state" == seeking ]]; then xdotool key --window "$window" Right; fi
  # Alternate the Flutter button and WM_DELETE_WINDOW paths.
  if [[ ${VPFL_CLOSE_METHOD:-} == custom || ( ${VPFL_CLOSE_METHOD:-} != wm && $((i%2)) -eq 0 ) ]]; then
    width=$(xdotool getwindowgeometry --shell "$window" | sed -n 's/^WIDTH=//p')
    xdotool mousemove --window "$window" "$((width-32))" 32 click 1
    method=button
  else
    wmctrl -ic "$window"
    method=window_manager
  fi
  closed=false
  for ((attempt=0; attempt<130; attempt++)); do
    if ! kill -0 "$pid" 2>/dev/null; then closed=true; break; fi
    sleep 0.1
  done
  if [[ "$closed" != true ]]; then
    echo "VPFL survived close: cycle $i ($state, $method), PID $pid" >&2
    ps -L -p "$pid" -o pid,tid,stat,pcpu,comm >&2 || true
    exit 1
  fi
  wait "$pid"
  pid=''
  echo "cycle $i/$cycles: $state/$method closed"
done
