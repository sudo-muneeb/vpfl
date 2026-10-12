#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/debug-isolated.sh [--reset-profile] [--trace] [video-file]

Launch VPFL as a normal desktop window with Flutter hot reload, using a
persistent test profile at .vpfl-debug-profile/ in this checkout.

  --reset-profile  Delete only this test profile before starting VPFL.
  --trace          Print VPFL lifecycle events while debugging.
  -h, --help       Show this help.

In the Flutter terminal: r = hot reload, R = hot restart, q = quit.
EOF
}

reset_profile=false
trace=false
media_file=''
while (($#)); do
  case "$1" in
    --reset-profile) reset_profile=true ;;
    --trace) trace=true ;;
    -h|--help) usage; exit 0 ;;
    --)
      shift
      if (($# > 1)); then usage >&2; exit 2; fi
      if (($# == 1)); then media_file=$1; fi
      break
      ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      if [[ -n "$media_file" ]]; then usage >&2; exit 2; fi
      media_file=$1
      ;;
  esac
  shift
done

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter is not installed or not on PATH.' >&2
  exit 1
fi
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
  echo 'Start this script from a graphical desktop session.' >&2
  exit 1
fi
if [[ -n "$media_file" ]]; then
  if [[ ! -f "$media_file" ]]; then
    echo "Video file not found: $media_file" >&2
    exit 2
  fi
  media_file=$(realpath -- "$media_file")
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$script_dir/.." && pwd)
profile_dir="$repo_dir/.vpfl-debug-profile"
if [[ -L "$profile_dir" ]]; then
  echo "Refusing to use a symlinked test profile: $profile_dir" >&2
  exit 1
fi
if [[ "$reset_profile" == true ]]; then
  rm -rf -- "$profile_dir"
fi
umask 077
mkdir -p "$profile_dir"/{config,data,cache,state}

# Keep the real desktop display, runtime directory, and session bus so the
# native GTK window and file chooser work normally. Redirect persistent app
# data and GSettings writes to the test profile.
export XDG_CONFIG_HOME="$profile_dir/config"
export XDG_DATA_HOME="$profile_dir/data"
export XDG_CACHE_HOME="$profile_dir/cache"
export XDG_STATE_HOME="$profile_dir/state"
export GSETTINGS_BACKEND=keyfile
if [[ "$trace" == true ]]; then
  export VPFL_LIFECYCLE_TRACE=1
fi

cd -- "$repo_dir"
flutter_args=(run -d linux)
if [[ -n "$media_file" ]]; then
  flutter_args+=("--dart-entrypoint-args=$media_file")
fi

echo "VPFL test profile: $profile_dir"
echo 'Launching on your desktop. Flutter: r = reload, R = restart, q = quit.'
exec flutter "${flutter_args[@]}"
