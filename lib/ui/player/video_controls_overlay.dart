import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import '../core/themes/vpfl_theme_extension.dart';

/// Pointer-aware playback overlay used on the video surface.
class VideoControlsOverlay extends StatefulWidget {
  const VideoControlsOverlay({
    required this.title,
    required this.fullscreen,
    required this.controls,
    required this.onExit,
    required this.bindings,
    this.playlist,
    this.playlistStream,
    this.onPrevious,
    this.onNext,
    super.key,
  });

  final String title;
  final bool fullscreen;
  final Widget controls;
  final Future<void> Function() onExit;
  final Map<ShortcutActivator, VoidCallback> bindings;
  final Playlist? playlist;
  final Stream<Playlist>? playlistStream;
  final Future<void> Function()? onPrevious;
  final Future<void> Function()? onNext;

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay> {
  static const Duration _hideDelay = Duration(seconds: 3);
  final FocusNode _shortcutFocus = FocusNode(debugLabel: 'Video shortcuts');
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
    _shortcutFocus.dispose();
    super.dispose();
  }

  void _restoreShortcutFocus() {
    // A pointer click on a control may focus that control. Restore the video
    // shortcut target once its gesture finishes, while leaving popup routes
    // and text entry in charge of their own keyboard input.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final focusedContext = FocusManager.instance.primaryFocus?.context;
      if (focusedContext?.findAncestorWidgetOfExactType<EditableText>() !=
          null) {
        return;
      }
      _shortcutFocus.requestFocus();
    });
  }

  void _onHover(PointerHoverEvent event) {
    final revealTop = event.localPosition.dy <= 16;
    if (!_bottomVisible || (revealTop && !_topVisible)) {
      setState(() {
        _bottomVisible = true;
        if (revealTop) _topVisible = true;
      });
    }
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VpflThemeExtension>()!;
    return CallbackShortcuts(
      bindings: widget.bindings,
      child: Focus(
        focusNode: _shortcutFocus,
        autofocus: true,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerUp: (_) => _restoreShortcutFocus(),
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
                        color: colors.playerOverlayTop,
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Exit fullscreen',
                              onPressed: widget.onExit,
                              color: colors.playerOverlayForeground,
                              icon: const Icon(Icons.fullscreen_exit),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colors.playerOverlayForeground,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: StreamBuilder<Playlist>(
                    stream: widget.playlistStream,
                    initialData: widget.playlist,
                    builder: (context, snapshot) {
                      final queue = snapshot.data ?? widget.playlist;
                      if (queue == null || queue.medias.length < 2) {
                        return const SizedBox.shrink();
                      }
                      return IgnorePointer(
                        ignoring: !_bottomVisible,
                        child: AnimatedOpacity(
                          opacity: _bottomVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _EdgeButton(
                                tooltip: 'Previous video',
                                icon: Icons.skip_previous_rounded,
                                onPressed: queue.index > 0
                                    ? widget.onPrevious
                                    : null,
                              ),
                              _EdgeButton(
                                tooltip: 'Next video',
                                icon: Icons.skip_next_rounded,
                                onPressed: queue.index < queue.medias.length - 1
                                    ? widget.onNext
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !_bottomVisible,
                    child: AnimatedOpacity(
                      opacity: _bottomVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: SafeArea(
                        top: false,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                colors.playerOverlayMiddle,
                                colors.playerOverlayBottom,
                              ],
                            ),
                          ),
                          child: IconTheme(
                            data: IconThemeData(
                              color: colors.playerOverlayForeground,
                            ),
                            child: DefaultTextStyle.merge(
                              style: TextStyle(
                                color: colors.playerOverlayForeground,
                              ),
                              child: widget.controls,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgeButton extends StatelessWidget {
  const _EdgeButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Material(
      color: Theme.of(context)
          .extension<VpflThemeExtension>()!
          .playerEdgeBackground,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Theme.of(context)
              .extension<VpflThemeExtension>()!
              .playerOverlayForeground,
        ),
      ),
    ),
  );
}
