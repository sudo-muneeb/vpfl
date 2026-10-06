import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../../data/services/lifecycle_trace.dart';

abstract final class WindowCommands {
  static const _channel = MethodChannel('com.app.vpfl/window');
  static final maximized = ValueNotifier<bool>(false);
  static Future<void> Function()? shutdownHandler;
  static bool _handlerInstalled = false;
  static Future<void>? _closeFuture;

  static void installCloseHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'requestClose') {
        await close();
        return null;
      }
      throw MissingPluginException('Unknown window method: ${call.method}');
    });
  }

  static Future<void> minimize() => _call('minimize');
  static Future<bool> toggleMaximize() async {
    if (!Platform.isLinux) return false;
    try {
      await _channel.invokeMethod<bool>('toggleMaximize');
      // The window manager applies maximize asynchronously.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return await _readState('isMaximized');
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> isMaximized() => _readState('isMaximized');
  static Future<void> close() => _closeFuture ??= _close();

  static Future<void> _close() async {
    LifecycleTrace.event('window.close.requested');
    try {
      await shutdownHandler?.call();
    } finally {
      await _call('close');
    }
  }

  static Future<void> startDrag(Offset position) async {
    if (!Platform.isLinux) return;
    LifecycleTrace.event('window.drag.requested');
    try {
      await _channel.invokeMethod<void>('startDrag', {
        'x': position.dx.round(),
        'y': position.dy.round(),
      });
    } on MissingPluginException {
      // Widget tests do not have the GTK runner.
    }
  }

  static Future<void> _call(String method) async {
    if (!Platform.isLinux) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Widget tests do not have the GTK runner.
    }
  }

  static Future<bool> _readState(String method) async {
    if (!Platform.isLinux) return false;
    try {
      final value = await _channel.invokeMethod<bool>(method) ?? false;
      maximized.value = value;
      return value;
    } on MissingPluginException {
      return false;
    }
  }
}

/// A draggable region inside VPFL's own title bar.
class WindowDragHandle extends StatelessWidget {
  const WindowDragHandle({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onDoubleTap: () => unawaited(WindowCommands.toggleMaximize()),
    child: Listener(
      // Empty portions of the row have no render object that wins a hit test.
      // The listener itself must cover the full drag region.
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (event.buttons == kPrimaryMouseButton) {
          unawaited(WindowCommands.startDrag(event.position));
        }
      },
      child: child,
    ),
  );
}

class WindowControlButtons extends StatefulWidget {
  const WindowControlButtons({super.key});

  @override
  State<WindowControlButtons> createState() => _WindowControlButtonsState();
}

class _WindowControlButtonsState extends State<WindowControlButtons> {
  @override
  void initState() {
    super.initState();
    unawaited(_readState());
  }

  Future<void> _readState() async {
    await WindowCommands.isMaximized();
  }

  Future<void> _toggle() async {
    await WindowCommands.toggleMaximize();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: WindowCommands.maximized,
    builder: (context, maximized, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          tooltip: 'Minimize window',
          icon: Icons.remove_rounded,
          onPressed: WindowCommands.minimize,
        ),
        _WindowButton(
          tooltip: maximized ? 'Restore window' : 'Maximize window',
          icon: maximized
              ? Icons.filter_none_rounded
              : Icons.crop_square_rounded,
          onPressed: _toggle,
        ),
        _WindowButton(
          tooltip: 'Close window',
          icon: Icons.close_rounded,
          onPressed: WindowCommands.close,
          close: true,
        ),
      ],
    ),
  );
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.close = false,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool close;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        hoverColor: close ? scheme.errorContainer : scheme.surfaceContainerHigh,
        highlightColor: close
            ? scheme.errorContainer
            : scheme.secondaryContainer,
        iconSize: 19,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: Icon(icon, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
