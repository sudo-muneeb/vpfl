# Release validation checklist

This is a manual sign-off list beyond the pull-request gate. Record the
version, commit, distribution, desktop session, GPU/driver, command, result,
and artifact for each run.

- [ ] Required gate passed on a fresh pull request from a fork, twice on the
      same commit, with no skipped lane.
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
      vendor; run the optional `gpu / physical-hardware` workflow on a
      provisioned `vpfl-gpu` runner and record the GL/EGL renderer and selected
      decoder. Repeat on each vendor before making vendor-specific claims.
- [ ] Run startup, idle, library scan, playback, and repeated open/close
      benchmarks on a reference machine. Record baselines and variance.
- [ ] Review dependency licenses, notices, checksums, package provenance,
      and the format claims against `ci/media-matrix.json`.
- [ ] Update the compatibility report with executed results and unresolved
      limitations before publishing.

The CI workflow does not publish a release or change repository rules.
