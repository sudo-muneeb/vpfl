import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pointer-aware playback overlay used on the video surface.
class VideoControlsOverlay extends StatefulWidget {
  const VideoControlsOverlay({
    required this.title,
    required this.fullscreen,
    required this.controls,
    required this.onExit,
    required this.bindings,
    super.key,
  });

  final String title;
  final bool fullscreen;
  final Widget controls;
  final Future<void> Function() onExit;
  final Map<ShortcutActivator, VoidCallback> bindings;

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay> {
  static const Duration _hideDelay = Duration(seconds: 3);
  Timer? _hideTimer;
  bool _bottomVisible = true;
  bool _topVisible = false;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onHover(PointerHoverEvent event) {
    setState(() {
      _bottomVisible = true;
      if (event.localPosition.dy <= 16) _topVisible = true;
    });
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (!mounted) return;
      setState(() {
        _bottomVisible = false;
        _topVisible = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: widget.bindings,
    child: MouseRegion(
      cursor: !widget.fullscreen || _bottomVisible || _topVisible
          ? MouseCursor.defer
          : SystemMouseCursors.none,
      onHover: _onHover,
      onExit: (_) => _scheduleHide(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.fullscreen && _topVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.78),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Exit fullscreen',
                        onPressed: widget.onExit,
                        color: Colors.white,
                        icon: const Icon(Icons.fullscreen_exit),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_bottomVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: widget.controls,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
