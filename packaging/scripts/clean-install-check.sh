#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
kind=${1:-}
artifact=${2:-}
[[ "$kind" == deb || "$kind" == rpm ]] || {
  echo "Usage: $0 deb|rpm PACKAGE_FILE" >&2
  exit 2
}
[[ -f "$artifact" ]] || { echo "Package not found: $artifact" >&2; exit 1; }
artifact=$(realpath "$artifact")
command -v docker >/dev/null || { echo 'Docker is required' >&2; exit 1; }

# Generate a tiny local video; no user sample is copied into an image.
sample=$(mktemp -d -t vpfl-clean-install.XXXXXXXX)
trap 'rm -rf "$sample"' EXIT
ffmpeg -loglevel error -f lavfi -i 'testsrc2=size=320x180:rate=24' \
  -t 3 -c:v mpeg4 -q:v 5 "$sample/sample.mp4"
ffmpeg -loglevel error -i "$sample/sample.mp4" -c copy "$sample/sample.mkv"
ffmpeg -loglevel error -f lavfi -i 'testsrc2=size=320x180:rate=24' \
  -t 3 -c:v libvpx -deadline realtime -cpu-used 8 "$sample/sample.webm"

if [[ "$kind" == deb ]]; then
  image=ubuntu:24.04
  install_cmd='apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends /pkg/vpfl.deb xvfb libgl1-mesa-dri xauth'
  remove_cmd='apt-get remove -y vpfl'
else
  image=fedora:44
  install_cmd='dnf -y --disablerepo=updates --setopt=install_weak_deps=False install /pkg/vpfl.rpm xorg-x11-server-Xvfb mesa-dri-drivers'
  remove_cmd='dnf -y --disablerepo=updates remove vpfl'
fi

docker run --rm \
  -v "$artifact:/pkg/vpfl.$kind:ro" \
  -v "$sample:/samples:ro" \
  -e INSTALL_CMD="$install_cmd" -e REMOVE_CMD="$remove_cmd" \
  "$image" sh -ec '
    eval "$INSTALL_CMD"
    command -v vpfl >/dev/null
    test -x /usr/bin/vpfl
    test -x /usr/lib/vpfl/vpfl
    test -d /usr/lib/vpfl/lib && test -d /usr/lib/vpfl/data
    test -f /usr/share/applications/com.app.vpfl.desktop
    test -f /usr/share/metainfo/com.app.vpfl.metainfo.xml
    test -f /usr/share/icons/hicolor/256x256/apps/com.app.vpfl.png
    grep -q "^MimeType=.*video/mp4" /usr/share/applications/com.app.vpfl.desktop
    if command -v gio >/dev/null; then
      gio mime video/mp4 | grep -F com.app.vpfl.desktop
    fi
    set +e
    for media in /samples/sample.mp4 /samples/sample.mkv /samples/sample.webm; do
      timeout 20s xvfb-run -a vpfl "$media" >/tmp/vpfl.log 2>&1
      result=$?
      cat /tmp/vpfl.log
      test "$result" = 124 || { echo "VPFL exited early for $media: $result" >&2; exit 1; }
      grep "width: 320, height: 180" /tmp/vpfl.log >/dev/null || {
        echo "VPFL did not open $media to a sized video texture" >&2
        exit 1
      }
    done
    set -e
    eval "$REMOVE_CMD"
    test ! -e /usr/bin/vpfl
    test ! -e /usr/lib/vpfl
    test ! -e /usr/share/applications/com.app.vpfl.desktop
    test ! -e /usr/share/icons/hicolor/256x256/apps/com.app.vpfl.png
    test ! -e /usr/share/metainfo/com.app.vpfl.metainfo.xml
    echo "Clean install, headless launch, and removal passed"
  '
