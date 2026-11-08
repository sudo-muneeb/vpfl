# VPFL documentation

Start with the [README](../README.md) to run VPFL and
[CONTRIBUTING](../CONTRIBUTING.md) to work on it. The pages below separate
current implementation, maintenance procedures, and recorded investigations.

## Implementation and maintenance

- [Architecture](02-architecture.md): ownership, playback/source changes,
  rendering, subtitles, persistence, indexing, metadata, and shutdown.
- [Source map](03-project-structure.md): where each responsibility lives.
- [UI design](UI_DESIGN.md): current interactions and explicitly marked proposals.
- [Performance](04-performance.md): engineering constraints and measurement
  targets, not benchmark claims.
- [Testing](06-testing.md): existing suites, test placement, and local checks.
- [CI](ci/README.md): PR classification, native/display coverage, manual jobs,
  and operational status.
- [Native packaging](compatibility/native-packages.md): build prerequisites,
  package contents, installation, and distribution limits.
- [Release procedure](ci/release-checklist.md): source tags, artifact provenance,
  manual validation, and separate AUR maintenance.
- [Linux/Flatpak status](05-linux-flatpak.md): desktop integration and the
  unverified sandbox packaging prototype.
- [Default applications](linux/default-applications.md): GIO behavior and consent.
- [Native patch maintenance](../patches/media_kit_video/README.md): refreshing
  the vendored video plugin without losing VPFL changes or upstream notices.
  The refresh script copies that guide into `third_party/media_kit_video/VPFL_PATCHES.md`;
  the package-local copy is a generated mirror, not a separate procedure.

[GOALS](../GOALS.md) records milestones and remaining work.
[Product scope](01-product-scope-fixed.md) is a delivery backlog, including
unimplemented targets; it is not a supported-feature list.
[AGENTS](../AGENTS.md) owns coding-agent rules.

## Reproduction guides

- [Subtitle fixtures](ci/subtitle-fixtures.md): generation and validation.
- [Native subtitle comparison](ci/native-subtitle-verification.md): mpv versus
  media_kit frames, track state, font provenance, and artifacts.
- [Subtitle window checks](ci/subtitle-window-checks.md): final X11 pixels,
  sharpness, resize recovery, and installed-app smoke checks.
- [CI troubleshooting](ci/troubleshooting.md): failure signatures and diagnostics.

## Historical evidence

These reports preserve the tested revision/environment, failures, measurements,
and limits. Their descriptions of earlier behavior do not override current
code or the implementation guides above. Paths beneath `build/` are ignored,
generated artifacts; regenerate them with the linked guides on a new checkout.

- [Phase 0](compatibility/phase-0.md) and
  [Linux renderer checkup](compatibility/linux-renderer-checkup.md): initial
  EGL failure, isolated-context experiment, shared-context correction, fallback.
- [Lifecycle and library scan](compatibility/lifecycle-and-library-scan.md):
  Home/shutdown ownership, declaration-file indexing, and decoder recovery.
- [CI validation report](ci/validation-report.md): hosted runs through
  11 October 2026, including failed runs and corrections.
- Subtitle investigation sequence:
  [baseline (Part 1)](compatibility/subtitle-baseline.md),
  [native verification (Part 3)](compatibility/native-subtitle-verification.md),
  [service integration (Part 4)](compatibility/subtitle-integration-part4.md),
  [timing (Part 5)](compatibility/subtitle-settings-part5.md),
  [window rendering (Part 6)](compatibility/subtitle-rendering-part6.md), and
  [resize recovery](compatibility/subtitle-resize-recovery.md).

Licensing and attribution remain in [LICENSE](../LICENSE), [NOTICE](../NOTICE),
[third-party notices](../THIRD_PARTY_NOTICES.md), and
[commercial use](../COMMERCIAL_USE.md).
