#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
profile=$(mktemp -d -t vpfl-default-manager.XXXXXXXX)
trap 'rm -rf "$profile"' EXIT

cd "$root"
VPFL_TEST_XDG_DEFAULTS=1 \
XDG_DATA_HOME="$profile/data" \
XDG_CONFIG_HOME="$profile/config" \
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/default_manager_linux_test.dart -d linux
