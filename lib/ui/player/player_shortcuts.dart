import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The shared keyboard contract for windowed and fullscreen playback.
Map<ShortcutActivator, VoidCallback> playerShortcutBindings({
  required VoidCallback onPlayPause,
  required VoidCallback onSeekBackward,
  required VoidCallback onSeekForward,
  required VoidCallback onVolumeUp,
  required VoidCallback onVolumeDown,
  required VoidCallback onMute,
  required VoidCallback onFullscreen,
  required VoidCallback onEscape,
  required VoidCallback onOpenFile,
}) => {
  const SingleActivator(LogicalKeyboardKey.space, includeRepeats: false):
      onPlayPause,
  const SingleActivator(LogicalKeyboardKey.arrowLeft): onSeekBackward,
  const SingleActivator(LogicalKeyboardKey.arrowRight): onSeekForward,
  const SingleActivator(LogicalKeyboardKey.arrowUp): onVolumeUp,
  const SingleActivator(LogicalKeyboardKey.arrowDown): onVolumeDown,
  const SingleActivator(LogicalKeyboardKey.keyM, includeRepeats: false): onMute,
  const SingleActivator(LogicalKeyboardKey.keyF, includeRepeats: false):
      onFullscreen,
  const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false):
      onEscape,
  const SingleActivator(
    LogicalKeyboardKey.keyO,
    control: true,
    includeRepeats: false,
  ): onOpenFile,
};

/// Runs the first binding that accepts [event].
///
/// Repeats of bindings that do not include repeats are consumed without running
/// them. Letting them bubble could activate a focused control through the
/// application's default Space binding. [beforeAction] runs only when an action
/// is about to execute.
KeyEventResult dispatchPlayerShortcut(
  Map<ShortcutActivator, VoidCallback> bindings,
  KeyEvent event, {
  VoidCallback? beforeAction,
}) {
  for (final entry in bindings.entries) {
    final activator = entry.key;
    final suppressRepeat =
        event is KeyRepeatEvent &&
        activator is SingleActivator &&
        !activator.includeRepeats;
    // Match suppressed repeats using the original press's key and current
    // modifiers, then consume them.
    final matchingEvent = suppressRepeat
        ? KeyDownEvent(
            physicalKey: event.physicalKey,
            logicalKey: event.logicalKey,
            timeStamp: event.timeStamp,
          )
        : event;
    if (activator.accepts(matchingEvent, HardwareKeyboard.instance)) {
      if (!suppressRepeat && !event.synthesized) {
        beforeAction?.call();
        entry.value();
      }
      return KeyEventResult.handled;
    }
  }
  return KeyEventResult.ignored;
}

/// Whether [route] is a popup menu (as opposed to a dialog or other popup).
///
/// Material menus label their barrier with the localized menu dismissal text.
bool isPopupMenuRoute(Route<dynamic> route, String menuDismissLabel) =>
    route is PopupRoute && route.barrierLabel == menuDismissLabel;

/// Identifies dialogs opened by player controls for source-change cleanup.
const playerControlDialogRouteName = 'vpfl-player-control-dialog';

bool isPlayerControlTransientRoute(
  Route<dynamic> route,
  String menuDismissLabel,
) =>
    isPopupMenuRoute(route, menuDismissLabel) ||
    route.settings.name == playerControlDialogRouteName;

/// Tracks the bindings of the mounted player so keys pressed inside transient
/// menus, which live in their own routes, can still reach the player.
class PlayerShortcutRegistry {
  final List<(Object, Map<ShortcutActivator, VoidCallback>)> _entries = [];

  /// Bindings of the most recently attached player surface, if any.
  Map<ShortcutActivator, VoidCallback>? get bindings =>
      _entries.isEmpty ? null : _entries.last.$2;

  void attach(Object owner, Map<ShortcutActivator, VoidCallback> bindings) {
    detach(owner);
    _entries.add((owner, bindings));
  }

  void detach(Object owner) =>
      _entries.removeWhere((entry) => identical(entry.$1, owner));
}

class _RegistryScope extends InheritedWidget {
  const _RegistryScope({required this.registry, required super.child});

  final PlayerShortcutRegistry registry;

  @override
  bool updateShouldNotify(_RegistryScope oldWidget) =>
      registry != oldWidget.registry;
}

/// Dispatches player shortcuts without consuming text input or leaking repeats.
class PlayerShortcuts extends StatefulWidget {
  const PlayerShortcuts({
    required this.bindings,
    required this.child,
    super.key,
  });

  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;

  @override
  State<PlayerShortcuts> createState() => _PlayerShortcutsState();
}

class _PlayerShortcutsState extends State<PlayerShortcuts> {
  PlayerShortcutRegistry? _registry;

  @override
  void initState() {
    super.initState();
    _registry = context
        .getInheritedWidgetOfExactType<_RegistryScope>()
        ?.registry;
    _registry?.attach(this, widget.bindings);
  }

  @override
  void didUpdateWidget(covariant PlayerShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    _registry?.attach(this, widget.bindings);
  }

  @override
  void dispose() {
    _registry?.detach(this);
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.space &&
        focusedContext != null) {
      var controlOwnsSpace = false;
      focusedContext.visitAncestorElements((element) {
        final widget = element.widget;
        if (widget is ButtonStyleButton ||
            widget is IconButton ||
            widget is MenuItemButton) {
          controlOwnsSpace = true;
          return false;
        }
        return true;
      });
      if (controlOwnsSpace) return KeyEventResult.ignored;
    }
    return dispatchPlayerShortcut(widget.bindings, event);
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: _handleKeyEvent,
    child: widget.child,
  );
}

/// Lets player shortcuts work while a popup menu is open.
///
/// Menus are routes above the player, so their focus subtree never reaches the
/// player's key handler. Install this above the [Navigator], for example from
/// [MaterialApp.builder]. A shortcut pressed with a menu open dismisses the menu
/// and runs once. Arrow keys, Escape, Enter, and Tab stay with the menu, and
/// Space activates a menu item that has keyboard focus.
class PlayerMenuShortcuts extends StatefulWidget {
  const PlayerMenuShortcuts({required this.child, super.key});

  final Widget child;

  @override
  State<PlayerMenuShortcuts> createState() => _PlayerMenuShortcutsState();
}

class _PlayerMenuShortcutsState extends State<PlayerMenuShortcuts> {
  final PlayerShortcutRegistry _registry = PlayerShortcutRegistry();

  static final Set<LogicalKeyboardKey> _menuKeys = {
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.escape,
  };

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final bindings = _registry.bindings;
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (bindings == null || focusContext == null || !focusContext.mounted) {
      return KeyEventResult.ignored;
    }
    final route = ModalRoute.of(focusContext);
    if (route == null ||
        !isPopupMenuRoute(
          route,
          MaterialLocalizations.of(focusContext).menuDismissLabel,
        )) {
      return KeyEventResult.ignored;
    }
    final itemFocused = focus is! FocusScopeNode;
    if (route.isCurrent &&
        itemFocused &&
        event.logicalKey == LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    final menuBindings = {
      for (final entry in bindings.entries)
        if (entry.key is! SingleActivator ||
            !_menuKeys.contains((entry.key as SingleActivator).trigger))
          entry.key: entry.value,
    };
    // A menu that is already animating out is not current; later presses still
    // belong to the player.
    return dispatchPlayerShortcut(
      menuBindings,
      event,
      beforeAction: route.isCurrent ? () => route.navigator?.pop() : null,
    );
  }

  @override
  Widget build(BuildContext context) => _RegistryScope(
    registry: _registry,
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    ),
  );
}
