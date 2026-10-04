#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
mode=${1:-}
target=${2:-}
version=${3:-}
app_id=com.app.vpfl
fail() { echo "Package validation failed: $*" >&2; exit 1; }

case "$mode" in
  bundle)
    [[ -x "$target/vpfl" ]] || fail 'release executable missing'
    [[ -d "$target/lib" && -d "$target/data" ]] || fail 'incomplete Flutter bundle'
    [[ -f "$target/lib/libflutter_linux_gtk.so" ]] || fail 'Flutter engine missing'
    [[ -f "$target/lib/libmedia_kit_video_plugin.so" ]] || fail 'video plugin missing'
    [[ -f "$target/lib/libdefault_manager_linux_plugin.so" ]] || fail 'default-app plugin missing'
    if readelf -d "$target/vpfl" "$target"/lib/*.so 2>/dev/null \
      | grep 'Library runpath: \[/' >/dev/null; then
      fail 'absolute build path in ELF RUNPATH'
    fi
    ;;
  stage)
    "$0" bundle "$target/usr/lib/vpfl"
    [[ -x "$target/usr/bin/vpfl" ]] || fail 'launcher missing'
    [[ $(cat "$target/usr/bin/vpfl") == $'#!/bin/sh\nexec /usr/lib/vpfl/vpfl "$@"' ]] \
      || fail 'launcher command changed'
    desktop="$target/usr/share/applications/$app_id.desktop"
    meta="$target/usr/share/metainfo/$app_id.metainfo.xml"
    [[ -f "$desktop" && -f "$meta" ]] || fail 'desktop metadata missing'
    desktop-file-validate "$desktop"
    appstreamcli validate --pedantic --no-net "$meta"
    grep -qx 'Exec=vpfl %f' "$desktop" || fail 'desktop Exec mismatch'
    grep -qx 'TryExec=vpfl' "$desktop" || fail 'desktop TryExec mismatch'
    grep -qx "Icon=$app_id" "$desktop" || fail 'desktop icon mismatch'
    grep -qx 'MimeType=video/mp4;video/x-matroska;video/webm;video/quicktime;video/vnd.avi;video/mpeg;video/mp2t;video/x-flv;video/x-ms-wmv;video/3gpp;video/3gpp2;video/ogg;application/mxf;' "$desktop" \
      || fail 'desktop MIME types mismatch'
    grep -q "<id>$app_id</id>" "$meta" || fail 'AppStream ID mismatch'
    grep -q "<release version=\"$version\"" "$meta" || fail 'AppStream version mismatch'
    for size in 48 64 128 256; do
      [[ -s "$target/usr/share/icons/hicolor/${size}x${size}/apps/$app_id.png" ]] \
        || fail "${size}px icon missing"
    done
    if find "$target" \( -name videos -o -name test -o -name .dart_tool \
      -o -name .pub-cache -o -name flutter_sdk -o -name CMakeFiles \) \
      -print -quit | grep -q .; then
      fail 'source, cache, or sample media found in stage'
    fi
    ;;
  deb)
    [[ -f "$target" ]] || fail 'DEB artifact missing'
    [[ $(dpkg-deb -f "$target" Version) == "$version-1" ]] || fail 'DEB version mismatch'
    dpkg-deb -f "$target" Depends | grep -q libmpv2 || fail 'DEB lacks libmpv2 dependency'
    dpkg-deb -f "$target" Depends | grep -q libgles2 || fail 'DEB lacks GLES dependency'
    dpkg-deb -f "$target" Depends | grep -q desktop-file-utils || fail 'DEB lacks desktop database tool'
    dpkg-deb -c "$target" | grep './usr/bin/vpfl$' >/dev/null || fail 'DEB launcher missing'
    ;;
  rpm)
    [[ -f "$target" ]] || fail 'RPM artifact missing'
    if command -v rpm >/dev/null; then
      [[ $(rpm -qp --qf '%{VERSION}' "$target") == "$version" ]] || fail 'RPM version mismatch'
      rpm -qpl "$target" | grep -x /usr/bin/vpfl >/dev/null || fail 'RPM launcher missing'
      rpm -qpR "$target" | grep 'libmpv.so.2' >/dev/null || fail 'RPM lacks libmpv dependency'
      rpm -qpR "$target" | grep -x libglvnd-gles >/dev/null || fail 'RPM lacks GLES dependency'
      rpm -qpR "$target" | grep -x desktop-file-utils >/dev/null || fail 'RPM lacks desktop database tool'
    elif command -v docker >/dev/null; then
      docker run --rm -v "$(realpath "$target"):/vpfl.rpm:ro" fedora:44 sh -ec '
        test "$(rpm -qp --qf "%{VERSION}" /vpfl.rpm)" = "$1"
        rpm -qpl /vpfl.rpm | grep -x /usr/bin/vpfl >/dev/null
        rpm -qpR /vpfl.rpm | grep "libmpv.so.2" >/dev/null
        rpm -qpR /vpfl.rpm | grep -x libglvnd-gles >/dev/null
        rpm -qpR /vpfl.rpm | grep -x desktop-file-utils >/dev/null
      ' sh "$version" || fail 'RPM metadata invalid'
    else
      fail 'RPM verification requires rpm or Docker'
    fi
    ;;
  *) fail 'Usage: validate-package.sh bundle|stage|deb|rpm PATH [VERSION]' ;;
esac
