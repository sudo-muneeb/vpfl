#!/usr/bin/env bash
set -euo pipefail

sample=${1:?sample video required}
test -f "$sample"
logdir=${VPFL_CI_LOG_DIR:-build/ci-logs}
mkdir -p "$logdir"
openbox >/tmp/vpfl-openbox.log 2>&1 &
wm=$!
app=''
frame=''
cleanup() {
  [[ ! -f /tmp/vpfl-installed.log ]] || cp /tmp/vpfl-installed.log "$logdir/installed-app.log"
  [[ -z "$app" ]] || kill "$app" 2>/dev/null || :
  kill "$wm" 2>/dev/null || :
  [[ -z "$frame" ]] || rm -f "$frame"
}
trap cleanup EXIT
vpfl "$sample" >/tmp/vpfl-installed.log 2>&1 &
app=$!
window=''
for _ in {1..100}; do
  window=$(wmctrl -lxp 2>/dev/null | awk -v pid="$app" '$3 == pid {print $1; exit}' || :)
  [[ -n "$window" ]] && break
  kill -0 "$app"
  sleep 0.1
done
[[ -n "$window" ]] || { cat /tmp/vpfl-installed.log; echo 'VPFL window missing' >&2; exit 1; }
read -r screen_width screen_height < <(xdotool getdisplaygeometry)
frame=$(mktemp -t vpfl-installed-frame.XXXXXXXX.rgb)
rendered=false
for _ in {1..30}; do
  if ffmpeg -nostdin -v error -y -f x11grab -draw_mouse 0 \
      -video_size "${screen_width}x${screen_height}" -i "$DISPLAY" \
      -frames:v 1 -pix_fmt rgb24 -f rawvideo "$frame" \
      > /tmp/vpfl-frame-capture.log 2>&1 && \
      python3 scripts/ci/check_installed_frame.py "$frame" \
        "$screen_width" "$screen_height" > /tmp/vpfl-frame-check.log 2>&1; then
    rendered=true
    break
  fi
  kill -0 "$app"
  sleep 0.5
done
if [[ "$rendered" != true ]]; then
  cp "$frame" /tmp/vpfl-failed-frame.rgb
  cat /tmp/vpfl-frame-capture.log /tmp/vpfl-frame-check.log /tmp/vpfl-installed.log
  echo 'Installed VPFL did not render the regression video color bars' >&2
  exit 1
fi
cat /tmp/vpfl-frame-check.log
ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 \
  -video_size "${screen_width}x${screen_height}" -i "$frame" \
  -frames:v 1 "$logdir/installed-compositor.png"
wmctrl -ic "$window"
# The native runner allows ten seconds for awaited Dart shutdown before its
# fallback close, so give the process time to exit after that deadline.
for _ in {1..250}; do
  if ! kill -0 "$app" 2>/dev/null; then break; fi
  sleep 0.1
done
if kill -0 "$app" 2>/dev/null; then
  cat /tmp/vpfl-installed.log
  echo 'Installed VPFL did not exit after window close' >&2
  exit 1
fi
wait "$app"
app=''
cat /tmp/vpfl-installed.log
grep -q 'VPFL_DISPLAY_BACKEND=GdkX11Display' /tmp/vpfl-installed.log
