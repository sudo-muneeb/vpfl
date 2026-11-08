import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps platform navigation and editing bindings while making activation and
/// dismissal execute once per physical press, including focused controls.
Map<ShortcutActivator, Intent> appShortcutBindings() => {
  for (final entry in WidgetsApp.defaultShortcuts.entries)
    if (entry.key case final SingleActivator activator
        when entry.value is ActivateIntent || entry.value is DismissIntent)
      PressShortcutActivator(
        activator.trigger,
        control: activator.control,
        shift: activator.shift,
        alt: activator.alt,
        meta: activator.meta,
        numLock: activator.numLock,
      ): entry.value
    else
      entry.key: entry.value,
};

/// Activates on real key-down events, excluding repeat and focus synchronization.
class PressShortcutActivator extends SingleActivator {
  const PressShortcutActivator(
    super.trigger, {
    super.control,
    super.shift,
    super.alt,
    super.meta,
    super.numLock,
  }) : super(includeRepeats: false);

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) =>
      !event.synthesized && super.accepts(event, state);
}
