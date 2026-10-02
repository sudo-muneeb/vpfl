# VPFL project structure

This structure intentionally follows the official Flutter architecture case-study style:

* UI organized by feature
* data organized by type
* shared domain models in `domain`
* routing separated
* shared widgets and themes under `ui/core`

Riverpod can be used for view-model/state responsibilities without changing this layer structure.

## Recommended structure

```text
lib/
  main.dart

  ui/
    core/
      widgets/
        app_dialog.dart
        loading_indicator.dart
        error_view.dart
        empty_state.dart

      themes/
        vpfl_theme.dart
        vpfl_color_tokens.dart
        vpfl_typography.dart
        vpfl_spacing.dart
        vpfl_radius.dart
        vpfl_theme_extension.dart
        system_theme_adapter.dart

    shell/
      view_models/
        shell_view_model.dart
      widgets/
        app_shell.dart
        sidebar.dart
        title_bar.dart

    home/
      view_models/
        home_view_model.dart
      widgets/
        home_screen.dart
        recent_media_section.dart
        recent_media_card.dart
        all_videos_section.dart
        media_card.dart

    player/
      view_models/
        player_view_model.dart
      widgets/
        player_screen.dart
        video_surface.dart
        player_controls.dart
        seek_bar.dart
        seek_back_button.dart
        seek_forward_button.dart
        play_pause_button.dart
        volume_control.dart
        speed_button.dart
        shuffle_button.dart
        player_overflow_menu.dart
        fullscreen_top_bar.dart

    library/
      view_models/
        library_view_model.dart
      widgets/
        library_screen.dart
        media_grid.dart
        media_list.dart
        library_toolbar.dart

    folders/
      view_models/
        folders_view_model.dart
      widgets/
        folders_screen.dart
        folder_browser.dart
        folder_tile.dart
        folder_breadcrumbs.dart
        add_folder_button.dart

    settings/
      view_models/
        settings_view_model.dart
      widgets/
        settings_screen.dart
        appearance_settings.dart
        playback_settings.dart
        subtitle_settings.dart
        hardware_settings.dart
        privacy_settings.dart

  data/
    repositories/
      playback_repository.dart
      media_repository.dart
      playback_history_repository.dart
      saved_folder_repository.dart
      playlist_repository.dart
      settings_repository.dart

    services/
      playback_service.dart
      media_library_service.dart
      media_metadata_service.dart
      database_service.dart
      desktop_file_access_service.dart
      window_service.dart
      shortcut_service.dart
      single_instance_service.dart
      system_theme_service.dart

    model/
      database_models.dart

  domain/
    models/
      media_entry.dart
      playback_history.dart
      saved_folder.dart
      playlist.dart
      playlist_item.dart
      media_preferences.dart
      playback_diagnostics.dart

  routing/
    app_router.dart
    routes.dart
```

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
* models are reused across UI and data layers

## Domain layer policy

Do not create a large use-case layer immediately.

For V1, `domain/` primarily contains shared models.

Add domain use-cases only if business logic becomes:

* complex
* reused by multiple view models
* too large for repositories/view models

## Widget placement rule

```text
tiny widget used by one parent only
→ private widget in the same file

widget used by one feature
→ ui/<feature>/widgets/

widget used by unrelated features
→ ui/core/widgets/
```

Do not create one giant global `widgets/` folder.

## View-model rule

Each important screen should have one primary view model.

Examples:

```text
HomeScreen
↔ HomeViewModel

PlayerScreen
↔ PlayerViewModel

FoldersScreen
↔ FoldersViewModel
```

Riverpod providers/notifiers can implement the view-model role.

## Dependency direction

```text
ui
 ↓
repositories
 ↓
services
```

Domain models may be shared across layers.

Services must never import feature UI.

Repositories must not depend on Flutter widgets.

Widgets must not know:

* SQL
* portal calls
* raw mpv property names
* Linux runner implementation details

## Tests should mirror the source tree

```text
test/
  ui/
    home/
    player/
    library/
    folders/
    settings/

  data/
    repositories/
    services/

  domain/
    models/

  routing/
```

Keep shared test fakes separately if useful:

```text
testing/
  fakes/
  models/
```
