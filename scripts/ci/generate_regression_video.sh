#!/usr/bin/env bash
set -euo pipefail

output=${1:?usage: generate_regression_video.sh OUTPUT.mp4}
mkdir -p "$(dirname "$output")"
ffmpeg -nostdin -hide_banner -loglevel error -y \
  -f lavfi -i 'testsrc2=size=320x180:rate=24:duration=30' \
  -f lavfi -i 'sine=frequency=880:sample_rate=48000:duration=30' \
  -map 0:v:0 -map 1:a:0 -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
  -c:a aac -t 30 "$output"
duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$output")
python3 - "$duration" <<'PY'
import sys
assert 29 < float(sys.argv[1]) < 31, f'wrong regression video duration: {sys.argv[1]}'
PY
ffmpeg -nostdin -v error -xerror -i "$output" -f null -
sha256sum "$output"
