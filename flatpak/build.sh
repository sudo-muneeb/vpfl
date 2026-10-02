#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
flutter build linux --release
flatpak-builder --user --install --force-clean \
  build/flatpak flatpak/com.app.vpfl.yml
