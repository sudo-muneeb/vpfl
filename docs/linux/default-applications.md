# Default video application on Linux

VPFL uses the Freedesktop desktop-entry and MIME applications system. The
installed `com.app.vpfl.desktop` advertises the video formats it can open. The
user's desktop chooses the default application for each MIME type. Installing
VPFL makes it available in Open With; installation does not set it as default.

`packages/default_manager_linux` is an internal Flutter Linux plugin, version
0.1.0. Its Dart API accepts a desktop-file ID and MIME types; its C++ Linux
side uses `GDesktopAppInfo` and `GAppInfo` through GIO. It queries
`g_app_info_get_default_for_type`, changes a default with
`g_app_info_set_as_default_for_type`, and queries again to verify every result.
It does not invoke `xdg-mime`, write `mimeapps.list` itself, or require root.
The plugin has no VPFL UI or reminder policy and is not published yet.

VPFL supplies `com.app.vpfl.desktop` and the 13 concrete MIME types listed in
`lib/data/services/default_app_prompt_service.dart`. These match the package's
desktop entry. Settings shows how many types currently use VPFL. The button
asks for confirmation, then reports success or per-type errors. Development
runs without an installed desktop entry show that the action is unavailable.

The player invitation appears below the top bar after three media items reach
the playing state. It has **Make default** and **Maybe later** actions. The
play count, prompt count, and last prompt date are saved in VPFL's SQLite
settings independently of playback history. A deferred invitation cannot
reappear until 21 days later and another video plays. At most five invitations
are shown. Once VPFL handles every listed type by default, the invitation
stops. The Settings action remains available whenever the desktop entry is
installed, even after the invitation limit.

## Check locally

```bash
flutter test test/data/services/default_app_prompt_service_test.dart
cd packages/default_manager_linux
flutter test test/default_manager_linux_test.dart
cd ../..
./packaging/scripts/check-default-manager-linux.sh
```

The last command builds a Linux integration target, creates temporary XDG
data and config directories, registers a test-only desktop entry, sets a
test-only MIME default, verifies it, and removes those directories. It does
not alter the user's video associations. For an installed VPFL package, use
`gio mime video/mp4` to inspect the current default. The app's Settings
button is the supported way to change it.

The GIO integration check passed locally on Linux Mint/X11. It does not prove
the Settings appearance or association behavior in GNOME, KDE, Wayland,
Flatpak, or other distributions. Flatpak's sandbox rules may need a separate
integration path; the native DEB/RPM flow is the current target.

References: [Freedesktop MIME Applications specification](https://specifications.freedesktop.org/mime-apps/latest-single/),
[GIO AppInfo API](https://docs.gtk.org/gio/iface.AppInfo.html), and
[GIO DesktopAppInfo API](https://docs.gtk.org/gio-unix/class.DesktopAppInfo.html).
