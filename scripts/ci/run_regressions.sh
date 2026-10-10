#!/usr/bin/env bash
set -euo pipefail

fixtures=$(realpath "${1:?usage: run_regressions.sh FIXTURE_DIRECTORY}")
sample="$fixtures/regression.mp4"
test -f "$sample"
test -f "$fixtures/h264_mkv.mkv"
test -f "$fixtures/vp8_webm.webm"

for suite in linux_playback_test library_open_failure_test \
             player_inspector_linux_test recoverable_codec_error_test; do
  echo "Running $suite"
  bash scripts/ci/run_display.sh x11 flutter test "integration_test/$suite.dart" \
    -d linux --dart-define=VPFL_TEST_VIDEO="$sample" --reporter expanded
done

bash scripts/ci/run_display.sh x11 flutter test \
  integration_test/linux_lifecycle_test.dart -d linux \
  --dart-define=VPFL_TEST_VIDEO="$sample" \
  --dart-define=VPFL_TEST_VIDEO_B="$fixtures/h264_mkv.mkv" \
  --dart-define=VPFL_TEST_VIDEO_C="$fixtures/vp8_webm.webm" \
  --dart-define=VPFL_TEST_CYCLES=3 --reporter expanded

VPFL_TEST_XDG_DEFAULTS=1 bash scripts/ci/run_display.sh x11 flutter test \
  integration_test/default_manager_linux_test.dart -d linux --reporter expanded
