#!/usr/bin/env bash
set -euo pipefail

./packaging/scripts/package-arch.sh
archive=$(realpath dist/vpfl-linux-x86_64.tar.gz)
work=$(mktemp -d -t vpfl-arch-ci.XXXXXXXX)
trap 'rm -rf "$work"' EXIT
cp packaging/arch/PKGBUILD packaging/arch/vpfl-bin.install "$work/"
cp "$archive" "$work/vpfl-linux-x86_64.tar.gz"
sed -i "s|^source=.*|source=('vpfl-linux-x86_64.tar.gz')|" "$work/PKGBUILD"
checksum=$(sha256sum "$archive" | cut -d' ' -f1)
sed -i "s|^sha256sums=.*|sha256sums=('$checksum')|" "$work/PKGBUILD"
useradd -m vpfl-ci-builder
chown -R vpfl-ci-builder:vpfl-ci-builder "$work"
runuser -u vpfl-ci-builder -- bash -c 'cd "$1" && makepkg --noconfirm --nodeps' _ "$work"
package=$(find "$work" -maxdepth 1 -name 'vpfl-bin-*.pkg.tar.zst' -print -quit)
test -n "$package"
namcap "$package"
cp "$package" dist/
echo "ARCH_PACKAGE=dist/$(basename "$package")"
