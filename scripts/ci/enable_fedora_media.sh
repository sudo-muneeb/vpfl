#!/usr/bin/env bash
set -euo pipefail

# Fedora's ffmpeg-free uses OpenH264 for H.264 and cannot verify our 10-bit
# fixture. Use the full decoder set in both native and installed-package lanes.
fedora_release=$(rpm -E '%fedora')
dnf install -y --setopt=install_weak_deps=False \
  "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_release}.noarch.rpm"
