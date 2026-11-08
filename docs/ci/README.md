# VPFL continuous integration

There are exactly two workflows: `ci.yml` automatically verifies pull requests
against `bootstrap-project` and `main`; `release-candidate.yml` manually
qualifies a selected candidate. The release workflow reuses `ci.yml` with
full verification enabled. There are no scheduled workflows or hosted
physical GPU jobs. See the [test inventory](test-inventory.md) for invocation,
environment, unique coverage, selection, and measured runtime boundaries,
and the [restructuring validation record](restructure-validation.md) for evidence.

## V1 media contract

VPFL V1 opens video files. `test/fixtures/media-matrix.json` lists 26 video
files across the advertised extensions, four external subtitle files used
with a video, and one video with an embedded subtitle. The video cases also
exercise their encoded audio streams. `.ts` is explicit-open only because the
suffix also names TypeScript files; declaration files such as `.d.mts` are
never indexed.

The fixture generator creates short synthetic files with fixed color patches.
`verify_fixtures.py` checks the manifest hash, each file hash and size,
container streams, codecs, pixel format, dimensions, duration, and FFmpeg
decode. The native integration test then opens every video through
`PlaybackService`, checks video and audio tracks, captures an mpv-decoded PNG,
checks the red, green, and blue patch positions, and exercises pause, seek,
resume, natural completion, and stop for each video. It checks subtitle track
discovery and a decoded frame for the embedded-subtitle video. **The current
test does not prove visible subtitle text or final Flutter composition.**

The [additional subtitle fixture suite](subtitle-fixtures.md) is generated
and verified in the same CI fixture job. Its 25 generated files cover cue
timing, language metadata, sidecar naming, ASS styles/effects, font attachment,
Unicode, malformed text, a source-switch pair, and controlled resize captions.
They are fixture checks, not new native playback assertions.
The [native subtitle comparison](native-subtitle-verification.md) checks
standalone mpv and pinned media_kit rendering before the required graphical
subtitle job checks VPFL's final X11 window.

## Pull request selection and preflight

`ci / changed files` compares base and head paths, including both sides of
renames and deleted paths. Only root Markdown, `.agents/` Markdown, `docs/`
Markdown, and `.github/PULL_REQUEST_TEMPLATE.md` qualify as documentation.
Empty diffs and unknown paths select full application verification. Commit
messages are validated independently using the existing main-PR convention.
Neither titles, headings, nor branch names select tests.

Changes to CI configuration or infrastructure also run policy tests, Bash syntax checks, and pinned
`actionlint` in preflight. Every application job depends on successful change
classification **and** commit validation; a known preflight failure blocks
expensive work. New commits cancel only older runs of this workflow for the
same PR. Manual release runs use distinct run IDs and are never canceled by
that policy.

The small classifier in `scripts/ci/ci_policy.py` is deliberately conservative:

- Documentation only: preflight and `ci / required-gate`.
- Home, library, folders, shell, themes, and widget tests: core verification.
  These paths retain all widget tests and Ubuntu application regressions.
- Shared title-bar/window widgets: core plus native desktop checks.
- Desktop plugin: core, native desktop, full distribution/display compatibility,
  and native package builds/install tests.
- Packaging: core, native desktop, full distribution/display compatibility,
  and package builds/install tests. Installed subtitle pixels remain checked.
- Subtitle integration tests and subtitle fixtures: core plus the full native
  and graphical subtitle lane.
- Playback, player UI, rendering, shared data/state, dependencies, other test
  infrastructure, CI configuration, and unknown paths: all PR lanes.
- Mixed component categories and unknown paths select full PR verification.
  Documentation alongside one known component does not expand its selection.

All non-documentation PRs run complete generated fixture integrity checks,
lockfile dependency resolution, Dart formatting, static analysis, unit/widget
and desktop plugin unit tests. Ubuntu runs the existing playback, error,
inspector, resume, queue, Repeat One, three-cycle lifecycle, default-manager,
and metadata regressions. This is the ordinary UI path; it needs no packages,
Fedora/Arch builds, repeated display matrices, or graphical subtitle job.

High-risk paths add the full video matrix on Ubuntu/Fedora/Arch, full matrices
under Wayland/XWayland/injected software fallback, all three package builds
and clean installs, and native plus graphical subtitles as selected above.
Keeping the existing full matrices in these high-risk lanes avoids a second,
reduced fixture manifest and its maintenance cost. Low-risk PRs use the
existing Ubuntu playback regression as their representative smoke check.

`ci / required-gate` retains its name and validates every boolean selection
and every expected job result. Selected jobs must succeed; intentionally
unselected jobs must be skipped. Failed/canceled prerequisites, missing or
malformed outputs, unexpected skips, and unexpectedly executed jobs fail the
gate. Release mode additionally requires every lane and lifecycle stress.
Matrix lanes use `fail-fast: false` so one failure preserves other diagnostics.
No branch protection, ruleset, or required-check configuration is changed.

## What the native lanes prove

Ubuntu 24.04, Fedora 44, and Arch compile against their own native libraries.
Package lanes use fresh containers, validate contents/dependencies, desktop
entries and AppStream, capture installed video/subtitle pixels, remove the
package, and verify profile retention. Fedora enables RPM Fusion Free for
full codec support; distro-default codec availability is a different contract.

X11 uses Xvfb; Wayland and XWayland use headless Weston with explicit GTK
backend assertions. Injected GPU initialization failure must select software
output. Native matrices check decoded frames, tracks and playback transitions;
X11 graphical subtitles and installed packages additionally check final
compositor pixels. **Mesa/headless execution proves neither physical GPU
rendering nor hardware decoding.**

Fixtures are generated once per run and uploaded for one day. Packages and
failure diagnostics are retained for seven days; candidate provenance for
30 days. Retry the whole workflow if its one-day fixture artifact has expired.
Flutter SDK caching is preserved. No new shared build or dependency
cache is introduced; every lane still enforces `pubspec.lock`.

## Release candidate validation

Manually dispatch `release-candidate.yml`, optionally entering a candidate
commit, tag, or branch. The workflow resolves that ref once to a SHA, records
it and the workflow revision, and passes the immutable SHA to the reusable
CI workflow. Every checkout uses that SHA. The candidate must contain these
CI scripts; validating an older incompatible revision fails explicitly.

Release mode ignores documentation classification. It requires all quality,
fixtures, distribution, package, display, native desktop and subtitle checks,
including graphical pixels, sharpness, resize/fullscreen, and **30 lifecycle
cycles** using the existing test implementation. `release / required-gate`
fails unless the candidate resolves and the complete qualification succeeds.
No publishing, tags, AUR metadata, or public release uploads occur.

Physical GPU, real desktop/compositor sessions, upgrades from prior releases,
and Flatpak remain separate manual concerns in the
[release checklist](release-checklist.md). Flatpak release verification is
not implemented here.

## Local and community hardware testing

Use [the local GPU command](../../scripts/testing/test_gpu.sh) on an existing
X11/XWayland desktop; no self-hosted runner is needed:

```bash
bash scripts/testing/test_gpu.sh
bash scripts/testing/test_gpu.sh --decode
bash scripts/testing/test_gpu.sh --require-decode
# Explicitly permit a software renderer for diagnostic playback:
bash scripts/testing/test_gpu.sh --allow-software --decode
```

Install Flutter 3.47.5, the Linux build dependencies, FFmpeg/FFprobe, Python,
`glxinfo`, and optionally `eglinfo` and `lspci` beforehand. The command does
not install system packages. It records OS/kernel, graphics controllers,
GL driver/renderer and supplementary EGL information. Default mode rejects
known software renderers and requires a DRM render node. Native playback
reuses the complete synthetic media matrix and requires VPFL's GPU output
evidence independently of decoding. The matrix writes a flushed stage log
into the command's unique result directory; raw Dart stdout is not reliably
forwarded by Flutter's Linux test runner. `--decode` reports the observed H.264
hardware decoder or UNSUPPORTED; `--require-decode` additionally fails when
that capability is not demonstrated. Neither mode claims all codecs decode
in hardware. Decode failure does not relabel a successful rendering check.

The command isolates persistent XDG config/data/cache/state, generates only
test media, removes temporary profiles, and leaves a concise report with
PASS/FAIL/SKIP/UNSUPPORTED rows and diagnostic logs in `build/gpu-results/`.
It preserves the current display session's runtime and X authority. It never
opens the normal library/settings or uploads anything. Review the report and
logs before voluntarily sharing them through a
[GitHub compatibility issue](https://github.com/sudo-muneeb/vpfl/issues/new).
Include the tested commit, GPU/driver, session, mode, capability results,
and reproducible symptoms. Remove personal paths and other sensitive details;
home prefixes are redacted from text logs, but review is still necessary.

## Run locally

From the repository root with Flutter 3.47.5, Linux build dependencies,
FFmpeg, FFprobe, and Xvfb installed:

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --reporter expanded
python3 -m unittest discover -s test/ci -p 'test_*.py' -v
python3 scripts/ci/generate_fixtures.py --out build/ci-video-fixtures --subtitle-suite
python3 scripts/ci/verify_fixtures.py --dir build/ci-video-fixtures --subtitle-suite
./scripts/ci/run_display.sh x11 flutter test integration_test/media_matrix_test.dart \
  -d linux --dart-define=VPFL_CI_FIXTURES="$PWD/build/ci-video-fixtures"
bash scripts/ci/generate_regression_video.sh build/ci-video-fixtures/regression.mp4
bash scripts/ci/run_regressions.sh build/ci-video-fixtures
```

The fixture directory is generated and ignored by Git. The Python verifier
must pass before the integration test. The test uses an in-memory Drift
database; the display wrapper gives the app isolated XDG directories.
The regression fixture generator also makes a 45-second Matroska video beside
the 30-second MP4.
The regression script runs the resume suite with both formats. It uses a
temporary SQLite database to test Home, Recents, restart, and queue source
changes without touching the user's profile.
For distribution-specific runs, use the same scripts as the workflow inside
the named target container. Avoid using a real VPFL user profile.

The [Part 4 subtitle integration check](../compatibility/subtitle-integration-part4.md)
uses the generated subtitle suite with VPFL's actual `PlaybackService` and
Flutter video surface. Run its four Linux test files in separate Flutter
invocations after fixture verification; this host's Flutter runner could not
start the second app when multiple files were passed to one command.

The [Part 5 subtitle timing check](../compatibility/subtitle-settings-part5.md)
uses the same fixture suite to verify native delay readback, cue timing, and
libass pixels through VPFL's playback service.

The [Part 6 graphical subtitle check](subtitle-window-checks.md) captures
actual VPFL X11 window pixels and compares CC On/Off frames from the Flutter
video texture. A dedicated Ubuntu CI job runs it alongside the native
mpv/media_kit comparison; package-install jobs also check authored ASS and
automatically discovered SRT captions in installed VPFL windows.
The [Part 6 compatibility report](../compatibility/subtitle-rendering-part6.md)
records the executed results and remaining platform limits.

Additional native checks can be invoked with
`bash scripts/ci/run_subtitle_regressions.sh build/ci-video-fixtures` and
`bash scripts/ci/run_desktop_regressions.sh`; the subtitle command requires
fixtures generated/verified with `--subtitle-suite`. These commands are now
selected CI coverage as described above.

## Validation record

The [fifth hosted run](https://github.com/sudo-muneeb/vpfl/actions/runs/38117032738)
on PR #3 passed all 12 jobs, including the required gate. It covered the 31
video/subtitle cases in the native and display lanes and installed, launched,
and removed DEB, RPM, and Arch packages. This is the latest hosted run recorded
in the [detailed validation report](validation-report.md), which preserves the
failures and fixes from earlier runs.

The earlier `jq`, Git ownership, FFprobe parsing, Fedora codec setup, and
XWayland socket failures were corrected and exercised by later hosted runs.
Fedora and Arch playback stalls were addressed with a single startup open,
bounded operations, stage logs, and a null audio sink for headless tests. Two
local full-matrix runs on each distribution and the fifth hosted run passed;
the hosted result is one pass after the intermittent stalls. Decoder-selection
messages such as `Could not open codec` appeared in headless Ubuntu/display
logs, but the decoded-frame and completion checks passed. See the
[hardware-decoding fallback documentation](https://mpv.io/manual/stable/#options-hwdec).

On 12 October 2026, the local unit/widget suite passed 71 tests and
`flutter analyze` reported no issues. Native lanes were not rerun for this
local documentation audit.

## Known limits

- The 31-file integration test checks decoded mpv screenshots. The installed
  package smoke captures final compositor pixels for one 30-second video and
  authored ASS/external SRT fixtures; it does not repeat that capture for all
  31 fixtures or for Wayland/XWayland.
- The graphical subtitle lane checks both native subtitle pixels and final
  VPFL X11 window pixels. It does not establish glyph shaping semantics or
  Wayland compositor output.
- The suite covers pause, seek, resume, and natural completion for each video.
  The GPU initialization fault is injected in one X11 lane; other native
  renderer faults are not yet covered.
- A headless Mesa renderer is not a physical GPU or hardware decode result.
  Local physical GPU results and GNOME/KWin desktop checks remain separate
  from the hosted gate; no vendor-specific capability is inferred.
- Flatpak packaging, upgrade from an old release package, old database schema
  snapshots, and long performance benchmarks are not part of this PR gate.
- Images and external actions are pinned to release tags, not immutable image
  digests or action commits. A reproducibility and supply-chain follow-up is
  needed before calling this pipeline production-grade.

See [troubleshooting](troubleshooting.md) and the
[release checklist](release-checklist.md).

There is no nightly or other scheduled workflow. Thirty-cycle lifecycle
stress now runs only during manual release qualification. See the release
checklist for additional hardware, desktop, upgrade, and Flatpak limits.

## Merge protection

The active **Protect main** ruleset requires a pull request, resolved review
threads, and linear history. It blocks deletion and force-pushes to `main` and
allows squash or rebase merges. It currently requires zero approving reviews
and does not require a status check. Contributors should still fix failing CI
jobs before merging. See the [contributor guide](../../CONTRIBUTING.md).

For enforceable CI protection, add `ci / required-gate` as a required status
check in the `main` ruleset after it has reported on a pull request. Require
at least one independent approval if review by another person is part of the
merge policy. The pull request template and `AGENTS.md` ask for evidence, but
repository instructions alone cannot prevent an agent from committing or
merging; branch rules and the owner's review provide the separate gate.
