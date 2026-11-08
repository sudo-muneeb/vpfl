# VPFL v1.0.1 release procedure and validation

This page is for maintainers. End-user installation belongs in the
[native package guide](../compatibility/native-packages.md#installing-a-release-package).
This checklist prepares the first public release; it does not authorize publication.

## Current publication setup

Checked against `origin/main` (`7df302d`) and GitHub on 9 November 2026:

- The release preparation branch sets Flutter to `1.0.1+2`, AppStream and native
  packaging to `1.0.1`, and the planned AppStream release date to 2026-11-09.
- No `v1.0.1` tag or public GitHub Release exists yet. Actions artifacts are
  temporary qualification outputs, not public installer downloads.
- The existing manual release-candidate workflow validates without publishing.
- The Arch source recipe retains `sha256sums=('SKIP')` until the exact published
  archive can be hashed. It is not a finalized, checksum verified source recipe.

Recheck publication state before advertising a download channel. If the planned
AppStream date changes, include that edit in the exact source commit qualified
by the release-candidate workflow.

## Release sequence

- [ ] Finalize and review the v1.0.1 preparation PR, including the AppStream
      date, version consistency, package metadata, and draft release notes.
- [ ] Merge the PR into `main` and record the full final commit SHA.
- [ ] Manually dispatch `.github/workflows/release-candidate.yml` with that SHA
      as `candidate`; record `release-candidate-commit` and require a successful
      `release / required-gate` for the same SHA.
- [ ] Download the workflow artifacts and extract the native files from the
      GitHub Actions ZIP wrappers. Inspect the DEB, RPM, Arch package, and
      `vpfl-linux-x86_64.tar.gz`, including version, dependencies, licenses,
      desktop entry, AppStream, icons, application ID, and `BUILD-INFO` commit.
- [ ] Verify native installation and playback on the maintainer's actual Linux
      desktop. Record distribution, desktop session, GPU, package file, result,
      and limitations. Confirm package version consistency with `1.0.1`.
- [ ] Generate `SHA256SUMS` from the exact four final release files and verify
      it with `sha256sum -c SHA256SUMS`. Never substitute rebuilt assets.
- [ ] Tag the exact qualified commit `v1.0.1` and create GitHub Release
      **VPFL v1.0.1: First Public Release**. Upload only the four verified
      native files and `SHA256SUMS`, without GitHub Actions ZIP wrappers.
- [ ] Publish accurate release notes and known limitations.
- [ ] After publication, hash the exact published Arch archive, replace `SKIP`
      in `packaging/arch/PKGBUILD`, regenerate `.SRCINFO`, and update the source
      recipe in a separate commit. No separate AUR repository or AUR submission
      is required. Flatpak and Flathub remain future work.

## Qualification coverage

The reusable CI pipeline performs static analysis, unit/widget/plugin tests,
complete generated fixture checks, Ubuntu/Fedora/Arch codec matrices, DEB/RPM/Arch
builds and clean install/launch/playback/removal, package contents, dependencies,
desktop/AppStream validation, X11/Wayland/XWayland/software fallback, native
subtitle suites and mpv/media_kit comparisons, graphical subtitle checks,
native desktop bridge/window state, and 30-cycle lifecycle stress. Any required
failure, cancellation, or unexpected skip fails qualification. A PR gate can
omit unaffected lanes and is not comprehensive release evidence. Inspect the
diagnostic artifacts. The workflow does not publish, tag, or upload public assets.

The following additional manual sign-offs remain. Record version, commit,
distribution, desktop session, GPU/driver, command, result, and artifact.

- [ ] Review all required lanes and artifacts. Also exercise PR gating from a fork.
- [ ] Verify a deliberately broken fixture, UI assertion, package dependency,
      native renderer, and Wayland launch each make the correct check fail.
- [ ] Install, launch, play, and remove DEB on Ubuntu 24.04, RPM on Fedora 44,
      and `vpfl-bin` on Arch; inspect desktop menu, MIME registration, icons,
      AppStream, and clean removal.
- [ ] Confirm video and subtitle presentation on X11, native Wayland, and
      XWayland; inspect GNOME and KDE sessions separately.
- [ ] Preserve a copied user profile through package removal. There is no
      previous public release to upgrade from for v1.0.1.
- [ ] Test real GPU rendering and supported hardware decode on each claimed
      vendor; run `bash scripts/testing/test_gpu.sh --decode` on an actual
      desktop and record the GL/EGL renderer and selected decoder. Use
      `--require-decode` only when that H.264 capability is required.
- [ ] Run startup, idle, library scan, playback, and repeated open/close
      benchmarks on a reference machine. Record baselines and variance.
- [ ] Review dependency licenses, notices, checksums, package provenance,
      and format claims against `test/fixtures/media-matrix.json`.
- [ ] Update the compatibility report with executed results and unresolved
      limitations before publishing.

Flatpak and Flathub have no operational release lane. Do not advertise their
validation without implementing and executing build and sandbox tests.
Historical investigations retain their original observations; they are not
current support claims.
