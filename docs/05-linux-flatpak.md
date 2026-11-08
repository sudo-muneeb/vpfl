# Linux integration and Flatpak status

VPFL's implemented distribution path is native x86_64 DEB, RPM, and Arch
packaging. See [native packages](compatibility/native-packages.md) for build
and installation procedures and [CONTRIBUTING](../CONTRIBUTING.md) for setup.

## Desktop integration

The native runner and package metadata use `io.github.sudo_muneeb.vpfl`; executable/package
names remain `vpfl` (Arch binary package: `vpfl-bin`). The desktop entry,
icons, AppStream metadata, and GTK application ID must agree. The
[packaged desktop entry](../packaging/linux/io.github.sudo_muneeb.vpfl.desktop) is the
source of truth for launcher and MIME registration. Installation registers
Open With support without changing per-user defaults. The
[default-application guide](linux/default-applications.md) explains consent,
reminder policy, and isolated GIO tests.

`vpfl` launches the UI; `vpfl "/path/to/video.mkv"` opens one local file.
`MediaOpenRequest` resolves relative and home-relative paths to file URIs;
the command line accepts a filesystem path, not a URL argument. CLI,
file picker, library cards, and recents enter the application playback route.
Opening a file builds a navigation queue from eligible siblings when readable;
it does not add its parent folder to the indexed library. Saved roots are
explicitly added by the user. Drag-and-drop, forwarding to an existing
instance, and MPRIS are not implemented.

The GTK runner supplies frameless window controls, native resize regions,
maximize-state notifications, and coordinated close. When `DISPLAY` is present
and `GDK_BACKEND` is unset it selects X11, including XWayland in a Wayland
session. Explicit backend overrides and pure-Wayland launches take their own
path. Headless CI backend checks do not establish GNOME/KDE desktop behavior;
see [CI limits](ci/README.md#known-limits).

## Flatpak prototype

[`flatpak/io.github.sudo_muneeb.vpfl.yml`](../flatpak/io.github.sudo_muneeb.vpfl.yml) and
[`flatpak/build.sh`](../flatpak/build.sh) are an unverified prototype,
not a published Flatpak or Flathub installation route. The manifest selects
Freedesktop Platform/SDK 26.08 and copies a locally built Flutter bundle.
It grants IPC, X11, Wayland, DRI, and PulseAudio access; it does not grant
blanket home/host access or network access.

The manifest does not build/bundle a complete libmpv/libepoxy dependency
closure. Native packages rely on system playback libraries, which does not
establish that the copied bundle can run inside this sandbox. Saved roots
currently store paths, not persistent portal document grants. Native GIO
association behavior also needs separate sandbox validation.

Before distributing Flatpak:

- Build and verify the native dependency closure without host development
  libraries; pin sources/checksums and eliminate hidden build-time downloads.
- Verify file/folder picker access and persistent grants across restart/update,
  including unavailable roots and explicit recovery without deleting history.
- Test menu launch, identity, Open With, fonts/subtitles, GPU/software output,
  audio, resizing/fullscreen, and database migration in the sandbox.
- Record the exact runtime, desktop, driver, commands, and observed results.

These are release requirements, not implemented guarantees. No Flatpak lane
exists in current CI; native package results cannot substitute for it.
