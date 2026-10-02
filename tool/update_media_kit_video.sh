#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: $0 <media_kit_video-version>" >&2
  exit 2
fi

version=$1
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cache_root=${PUB_CACHE:-"$HOME/.pub-cache"}
cached_package="$cache_root/hosted/pub.dev/media_kit_video-$version"
package_dir="$repo_root/third_party/media_kit_video"
patch_file="$repo_root/patches/media_kit_video/vpfl-rendering.patch"
notes_file="$repo_root/patches/media_kit_video/README.md"
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

dart pub cache add media_kit_video --version "$version"
if [[ ! -f "$cached_package/pubspec.yaml" ]]; then
  echo "Package source not found at: $cached_package" >&2
  exit 1
fi

staged_package="$temp_dir/media_kit_video"
mkdir -p "$staged_package"
cp -a "$cached_package/." "$staged_package/"
rm -f "$staged_package/pubspec.lock"

if ! (cd "$staged_package" && git apply --check "$patch_file"); then
  echo "The VPFL patch does not apply cleanly to media_kit_video $version." >&2
  echo "Current package copy and version pin are unchanged." >&2
  exit 1
fi
(cd "$staged_package" && git apply "$patch_file")
cp "$notes_file" "$staged_package/VPFL_PATCHES.md"

if ! grep -qE '^  media_kit_video: [0-9]+\.[0-9]+\.[0-9]+$' \
  "$repo_root/pubspec.yaml"; then
  echo "Could not find the pinned media_kit_video dependency in pubspec.yaml." >&2
  exit 1
fi

backup_dir="$temp_dir/media_kit_video_previous"
mv "$package_dir" "$backup_dir"
mv "$staged_package" "$package_dir"
if ! sed -i -E \
  "s/^(  media_kit_video: )[0-9]+\\.[0-9]+\\.[0-9]+$/\\1$version/" \
  "$repo_root/pubspec.yaml"; then
  rm -rf "$package_dir"
  mv "$backup_dir" "$package_dir"
  echo "Could not update the media_kit_video pin in pubspec.yaml." >&2
  exit 1
fi

if ! (cd "$repo_root" && flutter pub get); then
  echo "Source refreshed; run 'flutter pub get' after resolving dependency access." >&2
  exit 1
fi

echo "Updated media_kit_video to $version with the VPFL rendering patch."
