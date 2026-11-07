#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
flutter build linux --release
flatpak-builder --user --install --force-clean \
  build/flatpak flatpak/io.github.sudo_muneeb.vpfl.yml
