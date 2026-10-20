#!/usr/bin/env bash
set -euo pipefail

embedded=${1:?embedded ASS video required}
external=${2:?video with matching external SRT required}
test -f "$embedded"
test -f "$external"
test -f "${external%.*}.srt"
logdir=${VPFL_CI_LOG_DIR:-build/ci-logs}/installed-subtitles
mkdir -p "$logdir"
if command -v openbox >/dev/null; then
  openbox >"$logdir/window-manager.log" 2>&1 &
elif command -v metacity >/dev/null; then
  metacity --replace --no-composite >"$logdir/window-manager.log" 2>&1 &
else
  echo 'A window manager (Metacity or Openbox) is required' >&2
  exit 2
fi
wm=$!
app=''
frame=''
cleanup() {
  [[ -z "$app" ]] || kill "$app" 2>/dev/null || :
  kill "$wm" 2>/dev/null || :
  [[ -z "$frame" ]] || rm -f "$frame"
}
trap cleanup EXIT
for _ in {1..50}; do
  wmctrl -m >/dev/null 2>&1 && break
  kill -0 "$wm" 2>/dev/null || { cat "$logdir/window-manager.log"; exit 1; }
  sleep 0.1
done
wmctrl -m >/dev/null || { echo 'Window manager did not become ready' >&2; exit 1; }
read -r screen_width screen_height < <(xdotool getdisplaygeometry)
if ((screen_width < 1024 || screen_height < 768)); then
  echo 'Subtitle smoke requires an X11 screen of at least 1024x768; set VPFL_CI_X11_SCREEN_ARGS="-screen 0 1280x1024x24"' >&2
  exit 2
fi
xdotool mousemove "$((screen_width - 5))" "$((screen_height - 5))"

check_case() {
  local name=$1 sample=$2 kind=$3 window='' rendered=false
  vpfl "$sample" >"$logdir/$name-app.log" 2>&1 &
  app=$!
  for _ in {1..100}; do
    window=$(wmctrl -lxp 2>/dev/null | awk -v pid="$app" '$3 == pid {print $1; exit}' || :)
    [[ -n "$window" ]] && break
    kill -0 "$app" || { cat "$logdir/$name-app.log"; exit 1; }
    sleep 0.1
  done
  [[ -n "$window" ]] || { cat "$logdir/$name-app.log"; echo 'VPFL window missing' >&2; exit 1; }
  frame=$(mktemp -t vpfl-installed-subtitle.XXXXXXXX.rgb)
  for _ in {1..45}; do
    if ffmpeg -nostdin -v error -y -f x11grab -draw_mouse 0 \
        -video_size "${screen_width}x${screen_height}" -i "$DISPLAY" \
        -frames:v 1 -pix_fmt rgb24 -f rawvideo "$frame" \
        >"$logdir/$name-capture.log" 2>&1 && \
        python3 scripts/ci/check_installed_subtitle_frame.py "$frame" \
          "$screen_width" "$screen_height" "$kind" \
          >"$logdir/$name-check.log" 2>&1; then
      rendered=true
      break
    fi
    kill -0 "$app" || { cat "$logdir/$name-app.log"; exit 1; }
    sleep 0.1
  done
  if [[ "$rendered" != true ]]; then
    cp "$frame" "$logdir/$name-failed.rgb"
    cat "$logdir/$name-check.log" "$logdir/$name-capture.log" "$logdir/$name-app.log"
    echo "Installed VPFL did not render $kind subtitle pixels: $sample" >&2
    exit 1
  fi
  cp "$frame" "$logdir/$name.rgb"
  ffmpeg -nostdin -v error -y -f rawvideo -pixel_format rgb24 \
    -video_size "${screen_width}x${screen_height}" -i "$frame" \
    -frames:v 1 "$logdir/$name.png"
  cat "$logdir/$name-check.log"
  rm -f "$frame"
  frame=''
  wmctrl -ic "$window"
  for _ in {1..250}; do
    if ! kill -0 "$app" 2>/dev/null; then break; fi
    sleep 0.1
  done
  if kill -0 "$app" 2>/dev/null; then
    cat "$logdir/$name-app.log"
    echo 'Installed VPFL did not close after subtitle check' >&2
    exit 1
  fi
  wait "$app"
  app=''
  grep -q 'VPFL_DISPLAY_BACKEND=GdkX11Display' "$logdir/$name-app.log"
}

check_case embedded-ass "$embedded" ass
check_case external-srt "$external" srt
