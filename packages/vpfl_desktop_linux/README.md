# vpfl_desktop_linux

Internal Flutter Linux plugin for querying and setting desktop MIME defaults
with GIO and selecting files or opening folders through FileManager1. Version
0.1.0 is kept in the VPFL repository while its API and desktop behavior are
validated. It is not published to pub.dev.

```dart
const manager = VpflDesktopLinux();
final installed = await manager.isAvailable('com.app.vpfl.desktop');
final current = await manager.getDefaultApplication('video/mp4');
final status = await manager.getDefaultStatus(
  'com.app.vpfl.desktop',
  ['video/mp4', 'video/webm'],
);
final result = await manager.setDefaultForMimeTypes(
  'com.app.vpfl.desktop',
  ['video/mp4', 'video/webm'],
);
await manager.showFolder(Uri.directory('/home/me/Videos'));
await manager.showItem(Uri.file('/home/me/Videos/movie.mp4'));
```

`DefaultAppResult.results` reports verified status for each requested type;
`errors` contains per-type diagnostics. The desktop entry must be installed
and discoverable in XDG application paths before setting defaults. The caller
is responsible for obtaining the user's consent and choosing MIME types.

The package uses one Flutter method channel. The native default-app service
uses GIO's `GDesktopAppInfo` and `GAppInfo` APIs; the file-manager service
uses FileManager1 `ShowItems` and `ShowFolders`. It currently supports Linux
only. Selecting a file depends on the user's file manager implementing
`ShowItems`; callers can open its parent folder if selection is unavailable.

Original plugin code is Copyright © 2026 Sheikh Muneeb Ahmed and licensed
under [Apache License 2.0](LICENSE).

Tests from the VPFL repository root:

```bash
flutter test packages/vpfl_desktop_linux/test/vpfl_desktop_linux_test.dart
./packaging/scripts/check-default-manager-linux.sh
```
