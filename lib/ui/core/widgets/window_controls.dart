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
          glyph: _WindowGlyph.minimize,
          onPressed: WindowCommands.minimize,
        ),
        _WindowButton(
          tooltip: maximized ? 'Restore window' : 'Maximize window',
          glyph: maximized ? _WindowGlyph.restore : _WindowGlyph.maximize,
          onPressed: _toggle,
        ),
        _WindowButton(
          tooltip: 'Close window',
          glyph: _WindowGlyph.close,
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
    required this.glyph,
    required this.onPressed,
    this.close = false,
  });

  final String tooltip;
  final _WindowGlyph glyph;
  final Future<void> Function() onPressed;
  final bool close;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(6),
            hoverColor: close
                ? scheme.errorContainer
                : scheme.surfaceContainerHigh,
            focusColor: close
                ? scheme.errorContainer
                : scheme.secondaryContainer,
            child: SizedBox.square(
              dimension: 40,
              child: Center(
                child: CustomPaint(
                  size: const Size.square(16),
                  painter: _WindowGlyphPainter(
                    glyph,
                    scheme.onSurfaceVariant,
                    View.of(context).devicePixelRatio,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _WindowGlyph { minimize, maximize, restore, close }

/// Stroke geometry is snapped to the display's pixel grid, including at
/// fractional desktop scale. This avoids font glyph and splash raster edges.
class _WindowGlyphPainter extends CustomPainter {
  const _WindowGlyphPainter(this.glyph, this.color, this.dpr);

  final _WindowGlyph glyph;
  final Color color;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    double snap(double value) => (value * dpr).round() / dpr;
    final stroke = (1.4 * dpr).round().clamp(1, 4) / dpr;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;
    void line(double x1, double y1, double x2, double y2) => canvas.drawLine(
      Offset(snap(x1), snap(y1)),
      Offset(snap(x2), snap(y2)),
      paint,
    );
    void rect(double left, double top, double right, double bottom) =>
        canvas.drawRect(
          Rect.fromLTRB(snap(left), snap(top), snap(right), snap(bottom)),
          paint,
        );
    switch (glyph) {
      case _WindowGlyph.minimize:
        line(2, 8, 14, 8);
      case _WindowGlyph.maximize:
        rect(2, 2, 14, 14);
      case _WindowGlyph.restore:
        rect(2, 4, 12, 14);
        line(4, 2, 14, 2);
        line(14, 2, 14, 12);
      case _WindowGlyph.close:
        line(2.5, 2.5, 13.5, 13.5);
        line(13.5, 2.5, 2.5, 13.5);
    }
  }

  @override
  bool shouldRepaint(covariant _WindowGlyphPainter oldDelegate) =>
      glyph != oldDelegate.glyph ||
      color != oldDelegate.color ||
      dpr != oldDelegate.dpr;
}
