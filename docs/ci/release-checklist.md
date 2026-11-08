# Release validation checklist

Manually dispatch `.github/workflows/release-candidate.yml` before publishing.
Select the workflow revision containing the qualification infrastructure and
enter a candidate ref (or leave it blank to test the selected workflow SHA).
Record the resolved candidate SHA from `release-candidate-commit`; branch/tag
movement afterward must not change the tested source. Require
`release / required-gate` to succeed. A PR gate alone can intentionally omit
unaffected lanes and is not comprehensive release evidence.

The reusable CI pipeline always performs static analysis, unit/widget/plugin
tests, complete generated fixture checks, Ubuntu/Fedora/Arch codec matrices,
DEB/RPM/Arch builds and clean install/launch/playback/removal, package contents,
dependencies, desktop/AppStream validation, X11/Wayland/XWayland/software
fallback, native subtitle suites and mpv/media_kit comparisons, graphical
subtitle pixels/sharpness/resize/fullscreen, native desktop bridge/window
state, and 30-cycle lifecycle stress. Any required failure, cancellation,
or unexpected skip fails qualification. Inspect the diagnostic artifacts.
The workflow does not publish, tag, update AUR metadata, or upload public assets.

The following additional manual sign-offs remain. Record version, commit,
distribution, desktop session, GPU/driver, command, result, and artifact.

- [ ] Release qualification passed at the exact publishing commit; review all
      required lanes and artifacts. Also exercise PR gating from a fork.
- [ ] Verify a deliberately broken fixture, UI assertion, package dependency,
      native renderer, and Wayland launch each make the correct check fail.
- [ ] Install, launch, play, and remove DEB on Ubuntu 24.04, RPM on Fedora 44,
      and `vpfl-bin` on Arch; inspect desktop menu, MIME registration, icons,
      AppStream, and clean removal.
- [ ] Confirm video and subtitle presentation on X11, native Wayland, and
      XWayland; inspect GNOME and KDE sessions separately.
- [ ] Test package upgrade from the previous published release with a copied
      profile; verify database migration and that user data survives removal.
- [ ] Test real GPU rendering and supported hardware decode on each claimed
      vendor; run `bash scripts/testing/test_gpu.sh --decode` on an
      actual desktop and record the GL/EGL renderer and selected decoder.
      Use `--require-decode` only when that H.264 capability is required.
      Repeat on each vendor before making vendor-specific claims.
- [ ] Run startup, idle, library scan, playback, and repeated open/close
      benchmarks on a reference machine. Record baselines and variance.
- [ ] Review dependency licenses, notices, checksums, package provenance,
      and the format claims against `test/fixtures/media-matrix.json`.
- [ ] Update the compatibility report with executed results and unresolved
      limitations before publishing.

The CI workflow does not publish a release or change repository rules.

Flatpak has no operational release lane. Do not advertise Flatpak validation
without implementing and executing its build and sandbox tests. There are no
scheduled or self-hosted-runner workflows. Historical investigations retain
their original observations; they are not current support claims.
