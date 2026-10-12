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
      if (call.method == 'maximizedChanged' && call.arguments is bool) {
        maximized.value = call.arguments as bool;
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
          controlKey: const Key('window-minimize-button'),
          label: 'Minimize window',
          glyph: WindowControlGlyph.minimize,
          onPressed: WindowCommands.minimize,
        ),
        _WindowButton(
          controlKey: const Key('window-maximize-button'),
          label: maximized ? 'Restore window' : 'Maximize window',
          glyph: maximized
              ? WindowControlGlyph.restore
              : WindowControlGlyph.maximize,
          onPressed: _toggle,
        ),
        _WindowButton(
          controlKey: const Key('window-close-button'),
          label: 'Close window',
          glyph: WindowControlGlyph.close,
          onPressed: WindowCommands.close,
          close: true,
        ),
      ],
    ),
  );
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.controlKey,
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.close = false,
  });

  final Key controlKey;
  final String label;
  final WindowControlGlyph glyph;
  final Future<void> Function() onPressed;
  final bool close;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Semantics(
        label: label,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: controlKey,
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            hoverColor: close
                ? scheme.errorContainer
                : scheme.surfaceContainerHigh,
            focusColor: close
                ? scheme.errorContainer
                : scheme.secondaryContainer,
            child: SizedBox.square(
              dimension: 32,
              child: Center(
                child: WindowControlIcon(
                  glyph: glyph,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum WindowControlGlyph { minimize, maximize, restore, close }

/// Chromium's 24-unit window-control silhouettes rendered as scalable paths.
class WindowControlIcon extends StatelessWidget {
  const WindowControlIcon({
    required this.glyph,
    required this.color,
    super.key,
  });

  final WindowControlGlyph glyph;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(14),
    painter: _WindowGlyphPainter(glyph, color),
  );
}

/// Geometry adapted from Chromium's window_control_*.icon files.
/// Copyright 2016 The Chromium Authors. BSD-style license; see
/// third_party/chromium_window_icons/LICENSE.
class _WindowGlyphPainter extends CustomPainter {
  const _WindowGlyphPainter(this.glyph, this.color);

  final WindowControlGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final path = Path()..fillType = PathFillType.evenOdd;
    switch (glyph) {
      case WindowControlGlyph.minimize:
        path.addRect(const Rect.fromLTRB(1, 19, 23, 23));
      case WindowControlGlyph.maximize:
        path.addRect(const Rect.fromLTRB(1, 1, 23, 23));
        path.addRect(const Rect.fromLTRB(5, 5, 19, 19));
      case WindowControlGlyph.restore:
        path.addRect(const Rect.fromLTRB(8, 1, 23, 16));
        path.addRect(const Rect.fromLTRB(12, 5, 19, 12));
        path.moveTo(5, 8);
        path.lineTo(1, 8);
        path.lineTo(1, 23);
        path.lineTo(16, 23);
        path.lineTo(16, 19);
        path.lineTo(5, 19);
        path.close();
      case WindowControlGlyph.close:
        path.moveTo(23, 3.22);
        path.lineTo(20.78, 1);
        path.lineTo(12, 9.78);
        path.lineTo(3.22, 1);
        path.lineTo(1, 3.22);
        path.lineTo(9.78, 12);
        path.lineTo(1, 20.78);
        path.lineTo(3.22, 23);
        path.lineTo(12, 14.22);
        path.lineTo(20.78, 23);
        path.lineTo(23, 20.78);
        path.lineTo(14.22, 12);
        path.close();
    }
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WindowGlyphPainter oldDelegate) =>
      glyph != oldDelegate.glyph || color != oldDelegate.color;
}
