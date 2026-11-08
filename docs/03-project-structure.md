# VPFL source map

UI is grouped by feature; data code is grouped by responsibility. The
[architecture guide](02-architecture.md) explains ownership and interactions.

```text
lib/
  main.dart                Flutter/media_kit initialization and CLI parsing
  routing/                 local media-open request parsing
  ui/
    app.dart               app navigation, preferences, coordinated close
    core/                  shared themes, typography, window controls
    shell/                 library navigation, scan and Details coordination
    home/ library/ folders/ settings/ player/  feature widgets
  data/
    model/                 Drift schema/generated queries and track models
    repositories/          history, settings, saved roots, indexed media
    services/              playback, queues, scans, thumbnails, metadata, shutdown
    *_provider.dart        shared service wiring
    persistence_providers.dart  repositories and reactive query providers

packages/vpfl_desktop_linux/  internal GIO and FileManager1 plugin
linux/                       GTK runner and window method channel
third_party/media_kit_video/  upstream video package with VPFL patch
patches/media_kit_video/      maintained patch and refresh instructions
tool/                        dependency refresh helper
packaging/                   desktop metadata, native package scripts/templates
flatpak/                     unverified sandbox package prototype
ci/                          video fixture contract
scripts/ci/                  fixture, display, pixel, and package harnesses
test/                        unit/widget tests, Python CI tests, fixture sources
integration_test/            tests requiring the real Linux/media/window stack
test_driver/                 Flutter integration driver
.github/workflows/           hosted checks; see the CI guide
```

Keep a widget private to its file when only one parent needs it, in its feature
when shared there, and under `ui/core/` when unrelated features share it. Keep
screen-local interaction state with its screen. Use the existing service and
provider boundaries rather than adding a view-model class for symmetry.
There is no `lib/domain/` or `PlaybackRepository` in this implementation.

Data services must not import feature UI; repositories must not depend on
Flutter widgets. SQL, raw mpv properties, and Linux channels belong behind
their owning boundary. Test placement and native requirements are in the
[testing guide](06-testing.md).
