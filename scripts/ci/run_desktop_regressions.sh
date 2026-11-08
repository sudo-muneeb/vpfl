#!/usr/bin/env bash
set -euo pipefail
# Never send requests to a contributor's actual FileManager1 service.
VPFL_TEST_FAKE_FILE_MANAGER1=1 bash scripts/ci/run_display.sh x11 \
  dbus-run-session -- flutter test integration_test/file_manager1_linux_test.dart \
  -d linux --reporter expanded
VPFL_TEST_EXTERNAL_MAXIMIZE=1 bash scripts/ci/run_display.sh x11 \
  bash scripts/ci/run_subtitle_window.sh flutter test \
  integration_test/window_state_linux_test.dart -d linux --reporter expanded
