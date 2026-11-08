# CI restructuring validation record

This change starts from fetched `origin/main` c0442ea on
`ci/restructure-testing-pipeline`. The original checkout was clean on
`docs/improve-project-documentation`; that branch and its commit are preserved.
This record captures local verification before owner-authorized PR publication.
No GitHub settings, rulesets, required
checks, tags, releases, AUR metadata, or public assets were changed.

## Root cause and resulting architecture

The old docs-only classifier selected the entire expensive pipeline for every
other path. Fixture/quality jobs depended only on classification, allowing
full verification to proceed after an already failed commit check. Nightly
repeated the pipeline, with only its 30-cycle lifecycle invocation providing
additional coverage. The optional physical GPU workflow required an
unprovisioned runner and coupled rendering and decoding requirements.

The two-workflow design retains all existing test implementations and format
assertions. `ci.yml` selects lanes by changed paths, blocks application jobs
behind classification/commit/workflow validation, and cancels superseded
same-PR runs. The name `ci / required-gate` is unchanged. It validates all
classification flags and requires the exact expected result of each lane.
`release-candidate.yml` resolves one immutable SHA and invokes the same CI
jobs in full mode, including the preserved 30-cycle stress invocation; its
own final gate requires the complete reusable workflow to succeed.

`scripts/testing/test_gpu.sh` supplies opt-in physical rendering checks and
separate H.264 decoding assessment using the existing media matrix. It uses
synthetic media and isolated persistent XDG directories. No contributor data
is uploaded. Active-library rescanning remains an explicit manual operation.
See [the inventory](test-inventory.md) for every suite's invocation,
environment/dependencies, unique coverage, previous omission and new lane.

## Actual hosted baseline

Read GitHub Actions run collections, attempt-specific job lists/timestamps,
and the failed Fedora package job log through the GitHub connector on
8 November 2026. Sampled attempts:

- [42391780435](https://github.com/sudo-muneeb/vpfl/actions/runs/42391780435),
  attempt 1, successful: 40m30s from run creation to last update;
  40m27s from first job start to last job completion; 14 executed jobs;
  83m40s aggregate job duration. Graphical subtitles: 39m03s, including
  34m17s in window pixel checks. Ubuntu native: 10m26s, with 4m37s in the
  application regression step. Fixture job: 1m17s; quality: 1m13s.
- [42391521995](https://github.com/sudo-muneeb/vpfl/actions/runs/42391521995),
  attempt 1, failed commit validation: 49m00s creation-to-update;
  48m58s first-job-to-last-job; 14 jobs; 94m07s aggregate job duration.
  The commit check failed in a four-second job, but graphical subtitles
  still ran for 47m31s. This directly demonstrates wasted post-failure work.
- [42407385324](https://github.com/sudo-muneeb/vpfl/actions/runs/42407385324),
  attempt 1: 48m42s first-job-to-last-job; 15 jobs; 98m33s aggregate job
  duration. Graphical subtitles: 47m18s. Fedora package smoke failed with
  `VPFL window missing` (job 128511638336). A later retry succeeded; the
  run's latest start/update timestamps span only that retry and must not
  be used as the complete original-run duration. The initial failure's
  root cause remains unresolved; assertions/timeouts were not changed.
- [42354609041](https://github.com/sudo-muneeb/vpfl/actions/runs/42354609041),
  attempt 1, successful: 45m06s creation-to-update; 45m02s job span;
  13 jobs; 80m57s aggregate job duration. Graphical subtitles: 43m42s.

Thus approximately 40-minute normal runs and 39–47-minute graphical jobs
remain representative of the sampled recent runs. Job totals differ because
commit validation and changed-file preflight were added over this history.
The latest baseline workflow expands to 15 jobs for full application CI.
Aggregate durations sum reported job start/end intervals; they are **not**
billed runner minutes and do not include queued time. Elapsed spans measure
overlap and must not be added to aggregate duration.

## Work reduction and measurement limits

The new ordinary UI path executes six jobs: changed files, commit messages,
fixtures, quality, Ubuntu native regressions, and required gate. Documentation
executes three lightweight jobs. Full-risk PRs still expand to 15 jobs;
release qualification adds lifecycle stress and candidate/final result jobs
(18 total including the reused pipeline's commit-validation no-op).

The UI path omits two distribution builds, three package-install jobs, three
display matrices, and one graphical subtitle job: nine fewer jobs than the
current full baseline. It also omits Ubuntu packaging/full-matrix steps,
while adding native metadata and plugin unit coverage. Full fixture generation
remains once per application run. Early preflight failures prevent application
jobs entirely. Superseded same-PR runs are canceled instead of consuming the
remaining pipeline time. Fixture retention is one day, packages/diagnostics
seven days, provenance 30 days; SDK caching is preserved without new shared
build caches.

**At the initial local handoff, no hosted run of this design had been executed.** There is no
measured new hosted elapsed time, aggregate-runner saving, or percentage
speedup. Baseline lane durations identify the work removed, but are not
additive predictions of future wall time. Local test timings below are host
measurements, not a replacement for a paired Actions comparison.

Playback/shared state, player UI, dependencies, rendering, CI/infrastructure,
and unknown changes remain conservative full verification. Subtitle-specific
fixtures/tests select the full subtitle lane; packaging and desktop paths
retain their full distribution/package coverage. Graphical subtitles remain
slow when selected. Further optimization needs profiling of captures/builds
and repeated resize cases; reducing assertions or introducing a second
fixture-selection framework is not justified by the current evidence.

## Local verification

Executed with Flutter 3.47.5 / Dart 3.13.4 on Linux Mint 22.3. Commands and
results are recorded below; native command timings include local rebuilds.
The native suites use fresh `build/ci-restructure-fixtures`, not personal media.

- `flutter pub get --enforce-lockfile`: exit 0.
- `dart format --output=none --set-exit-if-changed lib test integration_test`:
  exit 0, 105 files, zero changes.
- `flutter analyze`: exit 0, no issues.
- `flutter test --reporter expanded`: exit 0, 162 tests passed
  (test reporter duration 1m47s).
- `flutter analyze packages/vpfl_desktop_linux`: exit 0, no issues.
- `flutter test packages/vpfl_desktop_linux/test --reporter expanded`:
  exit 0, four tests passed.
- `python3 -m unittest discover -s test/ci -p 'test_*.py' -v`:
  exit 0, 45 tests passed (29.939s on the final run).
- `python3 -m py_compile scripts/ci/ci_policy.py test/ci/test_ci_policy.py`:
  exit 0.
- `python3 scripts/ci/generate_fixtures.py --out build/ci-restructure-fixtures --subtitle-suite`:
  exit 0, 31 base cases and 25 subtitle files generated.
- `python3 scripts/ci/verify_fixtures.py --dir build/ci-restructure-fixtures --subtitle-suite`:
  exit 0, all base/subtitle cases verified, including decoded burned captions.
- `bash scripts/ci/generate_regression_video.sh build/ci-restructure-fixtures/regression.mp4`:
  exit 0, both duration/decode checks passed.
- `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.7 -color`:
  exit 0, both workflows valid including inline shell checks. Also ran the
  downloaded 1.7.7 binary locally for workflow validation. Full shell checking
  initially identified SC2016 on the two existing literal pacman mirror
  templates; narrow comments explain why `$repo/$arch` must remain literal.
  No shell checking is disabled globally in the final workflow.
- `docker run --rm -v "$PWD:/repo" -w /repo koalaman/shellcheck:v0.10.0 scripts/testing/test_gpu.sh scripts/ci/run_desktop_regressions.sh scripts/ci/run_subtitle_regressions.sh scripts/ci/run_regressions.sh`:
  exit 0. The new EXIT cleanup has an explained SC2317 suppression for
  indirect invocation. No runtime assertion is suppressed.
- `docker run --rm -v "$PWD:/repo" -w /repo koalaman/shellcheck:v0.10.0 --severity=warning scripts/ci/install_dependencies.sh`:
  exit 0. At info level, its existing literal pacman `$repo/$arch` mirror
  template triggers SC2016; that literal expansion contract is intentional.
- `for script in scripts/ci/*.sh scripts/testing/*.sh; do bash -n "$script"; done`:
  exit 0.
- Controlled fault injection in a temporary copy: replacing the gate's
  lane-result comparison with an unconditional false branch made the eight
  policy tests exit 1 with **63 assertion failures**. The normal policy suite
  passes. The real checkout's policy was not changed for this experiment.
- `xvfb-run -a bash scripts/testing/test_gpu.sh`: expected exit 1, rejected
  llvmpipe as a physical renderer; native playback/decoding recorded SKIP,
  unsupported EGL platforms recorded separately. The temporary profile was
  removed and the reviewable local report retained.

Additional native commands on the same local Mint host (all exit 0):

- `bash scripts/ci/run_desktop_regressions.sh`: 66s; real FileManager1 and
  external maximize/restore assertions passed with private D-Bus/X11.
- `bash scripts/ci/run_regressions.sh build/ci-restructure-fixtures`: 434s;
  all existing application suites and newly wired native metadata checks passed.
- `bash scripts/ci/run_subtitle_regressions.sh build/ci-restructure-fixtures`:
  196s; all five native subtitle files passed, including delay/pixel timing.
- `bash scripts/ci/run_display.sh x11 flutter test integration_test/media_matrix_test.dart -d linux --dart-define=VPFL_CI_FIXTURES="$PWD/build/ci-restructure-fixtures" --reporter expanded`:
  120s; full existing matrix and directory-queue EOF checks passed.
- `bash scripts/ci/run_display.sh x11 flutter test integration_test/linux_lifecycle_test.dart -d linux --dart-define=VPFL_TEST_VIDEO="$PWD/build/ci-restructure-fixtures/regression.mp4" --dart-define=VPFL_TEST_CYCLES=30 --reporter expanded`:
  68s; all 30 cycles completed and shutdown passed.
- `flutter build linux --release`: 34s; release bundle built successfully.

During matrix execution, raw Dart stdout/stderr capability markers were absent
from the Flutter console log even though the existing flushed stage log
recorded progress. The local tool therefore consumes capability markers from
that existing log in its unique result directory, selected with
`VPFL_CI_LOG_DIR`. Existing strict hardware assertions and all format
assertions remain intact. The final local GPU command exercises this durable
reporting path independently of GitHub Actions.

Not executed in this checkout: full native mpv/media_kit subtitle comparison,
all six long graphical subtitle invocations, fresh Ubuntu/Fedora/Arch container
build/install/removal, Wayland/XWayland/fault-injected display matrices,
physical GPU rendering/vendor compatibility validation, real desktop sessions, upgrades,
and Flatpak. Their existing invocations/assertions are preserved and selected
as documented, but earlier hosted results are not proof of this revised
workflow's execution. The local full media matrix uses Xvfb/Mesa, not physical
GPU evidence. Final local tool and review checks:

- `xvfb-run -a bash scripts/testing/test_gpu.sh --allow-software --decode`:
  exit 0, 129s, full synthetic native matrix passed with the final durable
  evidence path. The report separately records llvmpipe GL, SKIP for physical
  rendering, PASS for VPFL's native GPU texture path, and observed H.264
  `vaapi-copy` from mpv's `hwdec-current` property. That decoder observation
  comes from the native property, not from software GL, and makes no claim
  about other codecs or GPU vendors. Some EGL platforms report UNSUPPORTED
  without replacing the successful active GLX/native checks.
- Repeated the default physical-required command on Xvfb: expected exit 1;
  llvmpipe is rejected even though a physical AMD controller is listed.
- Final `dart format --output=none --set-exit-if-changed lib test integration_test`:
  exit 0, 105 files unchanged. Final `flutter analyze`: exit 0, no issues.
- Full Docker actionlint including inline ShellCheck: exit 0. ShellCheck for
  modified/new shell scripts and Bash syntax for every CI/local testing shell
  script: exit 0. Local documentation link/path review: no missing targets.
- `python3 scripts/ci/check_commit_messages.py --file build/ci-restructure-review/pr-title.txt`:
  exit 0 for the prepared PR title.
- Complete diff reviewed including all new files; `git diff --check`: exit 0.
  New-file whitespace checks: pass. `git diff --cached --quiet`: exit 0,
  confirming nothing staged. No diff in application/native/plugin source or lockfile. The media-format
  manifest was subsequently relocated byte-for-byte as documented below. Exactly the two requested workflows
  remain; no scheduled or self-hosted runner declaration remains.

The final local GPU report/logs are under
`build/gpu-results/run.C46OiwN4/`. Other local command logs, the complete
unstaged review diff, and PR title/body are retained in ignored
`build/ci-restructure-review/`; they are not uploaded. Actual positive physical
GPU rendering and the strict decoder-required failure case on an unsupported
codec/device remain unexecuted.

## Scenario review

Policy tests exercise documentation allowlist boundaries, empty/unknown paths,
UI, playback, subtitle fixtures/tests, renderer patches, packaging, mixed
changes, CI config, dependencies, and forced release mode. Gate tests exercise
all lane outcomes and both prerequisite failures, malformed/missing outputs,
release/PR mode disagreement, and a selected release check becoming skipped.

Workflow review plus actionlint confirms every application job depends on
both preflight jobs, uses the resolved checkout SHA, and is included in the
gate. Native matrix expansion follows the compatibility flag; package and
subtitle/display jobs use explicit flags. Concurrency is scoped by workflow
and PR number, with cancellation true only for PR events; release runs use
individual run IDs. Exactly `ci.yml` and `release-candidate.yml` remain,
with no `schedule` key and no self-hosted runner requirement.

Actual GitHub cancellation behavior, fork event integration, uploaded artifact
wiring, the dynamic hosted matrix, and full manual release orchestration
still need a run after owner-authorized publication of this branch. Policy
unit tests and actionlint validate contracts/syntax but cannot substitute for
that hosted evidence. This work is not declared merge-ready.

## Changed files and review preparation

Modified files:

- `.github/workflows/ci.yml`: path-based preflight/selection, exact checkouts,
  PR concurrency, gated application work, reused full release mode, missing
  native suites, retention, and fail-closed result validation.
- `.github/workflows/release-candidate.yml`: manual immutable-candidate
  resolution/provenance, reused full qualification, and overall result.
- `scripts/ci/install_dependencies.sh`: disposable Ubuntu native D-Bus/GI
  prerequisites for the previously omitted FileManager1 test.
- `scripts/ci/run_regressions.sh`: native metadata inspection added to the
  existing application regression command.
- `integration_test/media_matrix_test.dart`: report the observed H.264 decoder
  independently of strict hardware requirements; use the existing flushed
  stage log with a selectable output directory; preserve existing assertions.
- `docs/06-testing.md`, `docs/ci/README.md`, and
  `docs/ci/release-checklist.md`: current selection, release and local testing
  commands/capability boundaries. `docs/ci/validation-report.md` receives only
  a historical-status banner; earlier investigations/results remain intact.

Created files:

- `scripts/ci/ci_policy.py` and `test/ci/test_ci_policy.py`: extend the previous
  classifier/gate responsibilities in one small, directly tested policy module.
- `scripts/ci/run_desktop_regressions.sh` and
  `scripts/ci/run_subtitle_regressions.sh`: curated existing suites with their
  required isolation/defines; no directory-wide native test glob.
- `scripts/testing/test_gpu.sh`: optional local/community diagnostics without
  self-hosted infrastructure or access to normal application data.
- `docs/ci/test-inventory.md` and this record: coverage mapping, baseline,
  verification evidence, limits, and handoff.

Deleted files:

- `.github/workflows/nightly.yml`: eliminate automatic scheduled duplication;
  retain the existing stress test in release qualification.
- `.github/workflows/gpu-hardware.yml`: valuable checks now run locally.
- `.github/actionlint.yaml`: obsolete custom self-hosted runner label config.

Prepared PR title: `ci: streamline verification and release testing`.
A template-compatible local PR body is kept in ignored
`build/ci-restructure-review/pr-description.md`. After the initial local
handoff, the owner authorized creating a PR and checking its hosted CI.
The local evidence below predates that publication; hosted outcomes must be
recorded separately after actual execution.


## Root CI directory cleanup

At the owner's request, moved the sole root `ci/` file to
`test/fixtures/media-matrix.json`, alongside existing test fixtures, and removed
the empty root directory. The JSON content is byte-for-byte identical to
`c0442ea:ci/media-matrix.json`. Updated generator/verifier defaults, native and
unit test readers, guidance, documentation paths and links. The new fixture
path continues to select full compatibility verification through the policy's
conservative fallback. No formats or playback assertions changed.


Relocation validation: the two existing media-format contract tests passed;
fresh generation and verification passed for all 31 base fixtures using the
new default path. The Python CI suite passed all 45 tests. Dart formatting,
full actionlint, and `git diff --check` passed. No JSON content changed.
