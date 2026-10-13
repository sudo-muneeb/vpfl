# VPFL project structure

The current source tree groups UI by feature and data code by responsibility.
Read the relevant files before adding a new layer or directory.

## Current structure

```text
lib/
  main.dart
  routing/                 local media-open request parsing
  ui/
    core/                  shared theme and window widgets
    shell/ home/ player/ library/ folders/ settings/
  data/
    model/                 Drift database and track models
    repositories/          library and playback history persistence
    services/              playback, scanning, thumbnails, shutdown, etc.
    *_provider.dart         Riverpod wiring for shared services and data

test/                      unit and widget tests by feature/layer
integration_test/          Linux playback, display, and package-related checks
```

There is no `lib/domain/` or `PlaybackRepository` today. Add a domain layer or
new repository only when a concrete shared rule needs one.

## Why this structure

Flutter's architecture case study recommends a hybrid organization:

```text
UI
→ organized by feature

data
→ organized by architecture type

domain
→ shared application models
```

That suits VPFL well because:

* Home owns Home widgets and Home state
* Player owns Player widgets and Player state
* repositories can be shared by multiple features
* services encapsulate filesystem, database, player, and Linux APIs
* shared models can be reused across UI and data layers

## Domain layer policy

Do not create a large use-case layer immediately.

There is no `domain/` directory in the current implementation. Keep a model
near its owner unless multiple layers need a shared domain type.

Add domain use-cases only if business logic becomes:

* complex
* reused by multiple view models
* too large for repositories/view models

## Widget placement rule

```text
tiny widget used by one parent only
→ private widget in the same file

widget used by one feature
→ ui/<feature>/

widget used by unrelated features
→ ui/core/widgets/
```

Do not create one giant global `widgets/` folder.

## View-model rule

Use Riverpod providers to expose shared services and data to screens. Keep
screen-local interaction state with its screen when appropriate. Do not add a
view-model class solely to match an example tree.

## Dependency direction

```text
ui
 ↓
providers / controllers
 ↓
repositories or services
```

Domain models may be shared across layers.

Services must never import feature UI.

Repositories must not depend on Flutter widgets.

Widgets must not know:

* SQL
* portal calls
* raw mpv property names
* Linux runner implementation details

## Tests

Place focused unit and widget tests near the matching feature or data layer
under `test/`. Put behavior that needs the real Linux runner, media backend,
window, or package under `integration_test/`; follow
[the testing guide](06-testing.md) for the applicable native checks. Keep test
fixtures isolated from personal media and user databases.
