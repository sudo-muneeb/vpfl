# default_manager_linux

Internal Flutter Linux plugin for querying and setting desktop MIME defaults
with GIO. Version 0.1.0 is kept in the VPFL repository while its API and
desktop behavior are validated. It is not published to pub.dev.

```dart
const manager = DefaultManagerLinux();
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
```

`DefaultAppResult.results` reports verified status for each requested type;
`errors` contains per-type diagnostics. The desktop entry must be installed
and discoverable in XDG application paths before setting defaults. The caller
is responsible for obtaining the user's consent and choosing MIME types.

The package uses a Flutter method channel and GIO's `GDesktopAppInfo` and
`GAppInfo` APIs. It currently supports Linux only.

Original plugin code is Copyright © 2026 Sheikh Muneeb Ahmed and licensed
under [Apache License 2.0](LICENSE).

Tests from the VPFL repository root:

```bash
flutter test packages/default_manager_linux/test/default_manager_linux_test.dart
./packaging/scripts/check-default-manager-linux.sh
```
