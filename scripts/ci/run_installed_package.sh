#!/usr/bin/env bash
set -euo pipefail

distro=${1:?usage: run_installed_package.sh ubuntu|fedora|arch PACKAGE FIXTURE}
package=$(realpath "${2:?package required}")
sample=$(realpath "${3:?fixture required}")
test -f "$package"
test -f "$sample"

case "$distro" in
  ubuntu)
    export DEBIAN_FRONTEND=noninteractive
    printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\n' \
      > /etc/apt/apt.conf.d/99-vpfl-ci
    apt-get update
    apt-get install -y --no-install-recommends xvfb xauth xdotool wmctrl \
      openbox desktop-file-utils appstream libgl1-mesa-dri ffmpeg
    apt-get install -y --no-install-recommends "$package"
    remove=(apt-get remove -y vpfl)
    ;;
  fedora)
    dnf install -y --setopt=install_weak_deps=False \
      xorg-x11-server-Xvfb xorg-x11-xauth xdotool wmctrl \
      openbox desktop-file-utils appstream mesa-dri-drivers ffmpeg-free
    dnf install -y --setopt=install_weak_deps=False "$package"
    remove=(dnf remove -y vpfl)
    ;;
  arch)
    if [[ -n "${VPFL_CI_ARCH_MIRROR:-}" ]]; then
      printf 'Server = %s/$repo/os/$arch\n' "$VPFL_CI_ARCH_MIRROR" \
        > /etc/pacman.d/mirrorlist
    fi
    pacman -Syu --noconfirm --needed xorg-server-xvfb xorg-xauth xdotool \
      wmctrl openbox desktop-file-utils appstream mesa ffmpeg python
    pacman -U --noconfirm "$package"
    remove=(pacman -R --noconfirm vpfl-bin)
    ;;
  *) echo "unknown distribution: $distro" >&2; exit 2 ;;
esac

test -x /usr/bin/vpfl
test -x /usr/lib/vpfl/vpfl
test -d /usr/lib/vpfl/lib
test -d /usr/lib/vpfl/data
desktop-file-validate /usr/share/applications/com.app.vpfl.desktop
appstreamcli validate --no-net /usr/share/metainfo/com.app.vpfl.metainfo.xml
for binary in /usr/lib/vpfl/vpfl /usr/lib/vpfl/lib/*.so; do
  # Flutter bundles an Android JNI asset that VPFL does not load on Linux.
  [[ "$binary" == */libdartjni.so ]] && continue
  if ldd "$binary" | grep 'not found'; then
    echo "Unresolved library: $binary" >&2
    exit 1
  fi
done
xdg=$(mktemp -d -t vpfl-installed-xdg.XXXXXXXX)
trap 'rm -rf "$xdg"' EXIT
VPFL_CI_XDG_ROOT="$xdg" ./scripts/ci/run_display.sh x11 \
  ./scripts/ci/installed_app_smoke.sh "$sample"
test -f "$xdg/data/vpfl/vpfl.sqlite"
"${remove[@]}"
test ! -e /usr/bin/vpfl
test ! -e /usr/share/applications/com.app.vpfl.desktop
test -f "$xdg/data/vpfl/vpfl.sqlite"
echo "PASS $distro installed package removal"
