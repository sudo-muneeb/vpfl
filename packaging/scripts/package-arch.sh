#!/usr/bin/env bash
set -euo pipefail

# Builds the prebuilt release archive consumed by packaging/arch/PKGBUILD
# (vpfl-bin). The archive holds only the usr/ tree, so makepkg can install it
# into $pkgdir without running any build step.

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"
[[ $(uname -m) == x86_64 ]] || {
  echo 'Arch packaging currently supports x86_64 only' >&2
  exit 1
}
version=$(sed -nE 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)(\+[0-9]+)?$/\1/p' pubspec.yaml)
[[ -n "$version" ]] || { echo 'Invalid pubspec version' >&2; exit 1; }
commit=$(git rev-parse --short HEAD)
bundle="$root/build/linux/x64/release/bundle"
work=$(mktemp -d -t vpfl-arch.XXXXXXXX)
trap 'rm -rf "$work"' EXIT
stage="$work/stage"
mkdir -p "$stage/usr/lib/vpfl" "$stage/usr/bin" \
  "$stage/usr/share/applications" "$stage/usr/share/metainfo" \
  "$stage/usr/share/doc/vpfl"

flutter build linux --release
"$root/packaging/scripts/validate-package.sh" bundle "$bundle"
cp -a "$bundle/." "$stage/usr/lib/vpfl/"
install -m 644 LICENSE NOTICE AUTHORS THIRD_PARTY_NOTICES.md \
  "$stage/usr/share/doc/vpfl/"
install -m 644 third_party/media_kit_video/LICENSE \
  "$stage/usr/share/doc/vpfl/LICENSE.media_kit_video"
install -m 755 packaging/linux/vpfl-launcher "$stage/usr/bin/vpfl"
install -m 644 packaging/linux/com.app.vpfl.desktop "$stage/usr/share/applications/"
sed -E "s/(<release version=\")[^\"]+/\1$version/" \
  packaging/linux/com.app.vpfl.metainfo.xml \
  > "$stage/usr/share/metainfo/com.app.vpfl.metainfo.xml"
for size in 48 64 128 256; do
  icon_dir="$stage/usr/share/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$icon_dir"
  convert vpfl-logo.png -resize "${size}x${size}" "$icon_dir/com.app.vpfl.png"
done
{
  echo "Version: $version"
  echo 'Package revision: 1'
  echo "Git commit: $(git rev-parse HEAD)"
  echo "Architecture: $(uname -m)"
  echo "Build OS: $(. /etc/os-release; echo "$PRETTY_NAME")"
  echo "glibc: $(getconf GNU_LIBC_VERSION)"
  echo "GTK: $(pkg-config --modversion gtk+-3.0)"
  echo "Flutter: $(flutter --version | head -1)"
} > "$stage/usr/share/doc/vpfl/BUILD-INFO"

"$root/packaging/scripts/validate-package.sh" stage "$stage" "$version"

mkdir -p "$root/dist"
artifact="$root/dist/vpfl-linux-x86_64.tar.gz"
# Fixed owner and sorted names keep the archive stable for the same input.
tar -C "$stage" --owner=0 --group=0 --numeric-owner --sort=name \
  -czf "$artifact" usr
echo "Archive: $artifact"
echo "sha256sum: $(sha256sum "$artifact" | cut -d' ' -f1)"
