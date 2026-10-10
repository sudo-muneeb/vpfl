#!/usr/bin/env bash
set -euo pipefail

case "${1:?usage: install_dependencies.sh ubuntu|fedora|arch}" in
  ubuntu)
    export DEBIAN_FRONTEND=noninteractive
    printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\n' \
      > /etc/apt/apt.conf.d/99-vpfl-ci
    apt-get update
    apt-get install -y --no-install-recommends git curl jq unzip xz-utils zip python3 \
      clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libmpv-dev \
      libepoxy-dev libsqlite3-dev libegl1-mesa-dev libgles2-mesa-dev \
      dpkg-dev desktop-file-utils appstream imagemagick ffmpeg xvfb xauth \
      xdotool wmctrl openbox weston xwayland x11-utils mesa-utils \
      libgl1-mesa-dri
    ;;
  fedora)
    bash scripts/ci/enable_fedora_media.sh
    dnf install -y --setopt=install_weak_deps=False \
      git curl jq tar gzip unzip xz zip python3 which findutils \
      clang cmake ninja-build pkgconf-pkg-config gtk3-devel xz-devel \
      mpv-devel libepoxy-devel sqlite-devel mesa-libEGL-devel \
      libglvnd-devel rpm-build desktop-file-utils appstream ImageMagick \
      ffmpeg xorg-x11-server-Xvfb xorg-x11-xauth xdotool wmctrl \
      openbox mesa-dri-drivers
    ;;
  arch)
    # Public mirrors can throttle concurrent large downloads on shared CI.
    sed -i 's/^ParallelDownloads = .*/ParallelDownloads = 2/' /etc/pacman.conf
    grep -q '^DisableDownloadTimeout$' /etc/pacman.conf || \
      printf '\nDisableDownloadTimeout\n' >> /etc/pacman.conf
    if [[ -n "${VPFL_CI_ARCH_MIRROR:-}" ]]; then
      printf 'Server = %s/$repo/os/$arch\n' "$VPFL_CI_ARCH_MIRROR" \
        > /etc/pacman.d/mirrorlist
    fi
    pacman -Syu --noconfirm --needed git curl jq tar gzip unzip xz zip python \
      base-devel clang cmake ninja pkgconf gtk3 mpv libepoxy sqlite \
      libglvnd desktop-file-utils appstream imagemagick ffmpeg \
      xorg-server-xvfb xorg-xauth xorg-xdpyinfo xdotool wmctrl openbox \
      mesa namcap
    ;;
  *) echo "unknown distribution: $1" >&2; exit 2 ;;
esac
