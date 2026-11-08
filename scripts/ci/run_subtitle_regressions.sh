#!/usr/bin/env bash
set -euo pipefail
fixtures=$(realpath "${1:?usage: run_subtitle_regressions.sh FIXTURE_DIRECTORY}")
test -f "$fixtures/subtitle-suite/index.json"
# Separate invocations are required: Linux's test runner cannot reliably attach
# the second native app when several integration files share one invocation.
for suite in subtitle_integration_test subtitle_file_identity_linux_test \
             subtitle_lifecycle_linux_test subtitle_picker_linux_test \
             subtitle_delay_linux_test; do
  bash scripts/ci/run_display.sh x11 flutter test "integration_test/$suite.dart" \
    -d linux --dart-define=VPFL_SUBTITLE_FIXTURES="$fixtures" --reporter expanded
done
