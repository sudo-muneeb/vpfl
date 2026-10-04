#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
kind=${1:-}
if [[ "$kind" != deb && "$kind" != rpm ]]; then
  echo "Usage: $0 deb|rpm" >&2
  exit 2
fi

cd "$root"
[[ $(uname -m) == x86_64 ]] || {
  echo 'Native packaging currently supports x86_64 only' >&2
  exit 1
}
version=$(sed -nE 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)(\+[0-9]+)?$/\1/p' pubspec.yaml)
[[ -n "$version" ]] || { echo 'Invalid pubspec version' >&2; exit 1; }
commit=$(git rev-parse --short HEAD)
bundle="$root/build/linux/x64/release/bundle"
work=$(mktemp -d -t vpfl-package.XXXXXXXX)
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

mkdir -p "$root/dist/symbols"
symbols="$root/dist/symbols/${version}-1-x86_64-${commit}"
mkdir -p "$symbols"
while IFS= read -r -d '' binary; do
  if readelf -h "$binary" >/dev/null 2>&1; then
    relative=${binary#"$stage"/}
    mkdir -p "$symbols/$(dirname "$relative")"
    objcopy --only-keep-debug "$binary" "$symbols/$relative.debug"
    objcopy --strip-debug "$binary"
  fi
done < <(find "$stage/usr/lib/vpfl" -type f -print0)

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
cp "$stage/usr/share/doc/vpfl/BUILD-INFO" "$symbols/BUILD-INFO"

"$root/packaging/scripts/validate-package.sh" stage "$stage" "$version"
mkdir -p "$root/dist"

if [[ "$kind" == deb ]]; then
  command -v dpkg-shlibdeps >/dev/null
  mkdir -p "$work/debian" "$stage/DEBIAN"
  cat > "$work/debian/control" <<'EOF'
Source: vpfl
Section: video
Priority: optional
Maintainer: Sheikh Muneeb Ahmed <muneebahmed2250@gmail.com>
Standards-Version: 4.6.2

Package: vpfl
Architecture: amd64
Description: Local video player for Linux
EOF
  mapfile -d '' binaries < <(find "$stage/usr/lib/vpfl" -type f -print0)
  shlib_args=()
  for binary in "${binaries[@]}"; do
    # libdartjni is an unused Android transitive asset, not a Linux runtime.
    [[ "$binary" == */libdartjni.so ]] && continue
    readelf -h "$binary" >/dev/null 2>&1 && shlib_args+=("-e$binary")
  done
  (
    cd "$work"
    dpkg-shlibdeps -O "-l$stage/usr/lib/vpfl/lib" "${shlib_args[@]}" \
      2> "$work/dpkg-shlibdeps.log"
  ) > "$work/dependencies"
  depends=$(sed -n 's/^shlibs:Depends=//p' "$work/dependencies")
  [[ -n "$depends" ]] || { echo 'Could not determine DEB dependencies' >&2; exit 1; }
  cat > "$stage/DEBIAN/control" <<EOF
Package: vpfl
Version: $version-1
Architecture: amd64
Maintainer: Sheikh Muneeb Ahmed <muneebahmed2250@gmail.com>
Section: video
Priority: optional
Homepage: https://github.com/sudo-muneeb/vpfl
Depends: $depends, libegl1, libgles2, desktop-file-utils
Description: Local video player for Linux
 VPFL plays local video files and remembers playback progress.
EOF
  install -m 755 packaging/deb/postinst "$stage/DEBIAN/postinst"
  install -m 755 packaging/deb/postrm "$stage/DEBIAN/postrm"
  artifact="$root/dist/vpfl_${version}-1_amd64.deb"
  dpkg-deb --build --root-owner-group "$stage" "$artifact"
else
  mkdir -p "$work/rpmbuild"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
  tar -C "$stage" -czf "$work/rpmbuild/SOURCES/vpfl-stage.tar.gz" usr
  sed "s/@VERSION@/$version/g" packaging/rpm/vpfl.spec.in \
    > "$work/rpmbuild/SPECS/vpfl.spec"
  if command -v rpmbuild >/dev/null; then
    rpmbuild -bb --define "_topdir $work/rpmbuild" "$work/rpmbuild/SPECS/vpfl.spec"
  elif command -v docker >/dev/null; then
    docker build -q -t vpfl-rpm-build:fedora44 -f packaging/rpm/Dockerfile packaging/rpm
    docker run --rm -v "$work/rpmbuild:/work" vpfl-rpm-build:fedora44 sh -ec \
      'trap "chmod -R a+rwX /work" EXIT; rpmbuild -bb --define "_topdir /work" /work/SPECS/vpfl.spec'
  else
    echo 'RPM build needs rpmbuild or Docker with Fedora 44 access' >&2
    exit 1
  fi
  artifact=$(find "$work/rpmbuild/RPMS" -name 'vpfl-*.rpm' -print -quit)
  [[ -n "$artifact" ]] || { echo 'RPM artifact missing' >&2; exit 1; }
  cp "$artifact" "$root/dist/"
  artifact="$root/dist/$(basename "$artifact")"
fi

"$root/packaging/scripts/validate-package.sh" "$kind" "$artifact" "$version"
echo "Package: $artifact"
echo "Debug symbols: $symbols"
