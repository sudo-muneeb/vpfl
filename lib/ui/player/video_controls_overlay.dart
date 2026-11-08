import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';

import '../core/themes/vpfl_theme_extension.dart';
import 'player_inspector.dart';
import 'player_shortcuts.dart';

/// Pointer-aware playback overlay used on the video surface.
class VideoControlsOverlay extends StatefulWidget {
  const VideoControlsOverlay({
    required this.title,
    required this.fullscreen,
    required this.controls,
    required this.onExit,
    required this.bindings,
    required this.isPlaying,
    required this.playingStream,
    required this.onPlayPause,
    this.sourceGeneration = 0,
    this.playlist,
    this.playlistStream,
    this.onPrevious,
    this.onNext,
    this.canPrevious,
    this.canNext,
    this.inspectorMode,
    this.inspectorBuilder,
    super.key,
  });

  final String title;
  final bool fullscreen;
  final Widget controls;
  final Future<void> Function() onExit;
  final Map<ShortcutActivator, VoidCallback> bindings;
  final bool isPlaying;
  final Stream<bool> playingStream;
  final Future<void> Function() onPlayPause;
  final int sourceGeneration;
  final Playlist? playlist;
  final Stream<Playlist>? playlistStream;
  final Future<void> Function()? onPrevious;
  final Future<void> Function()? onNext;
  final bool Function()? canPrevious;
  final bool Function()? canNext;
  final ValueListenable<InspectorMode?>? inspectorMode;
  final Widget Function(InspectorMode mode, String? uri)? inspectorBuilder;

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay> {
  static const Duration _idleHideDelay = Duration(milliseconds: 1500);
  static const Duration _nearControlsHideDelay = Duration(seconds: 3);
  static const double _controlProximityHeight = 140;
  // One duration and curve for every overlay transition; reduced motion
  // removes the animation but keeps the same end states.
  static const Duration _motionDuration = Duration(milliseconds: 220);
  static const Curve _motionCurve = Curves.easeInOutCubic;
  final FocusNode _shortcutFocus = FocusNode(debugLabel: 'Video shortcuts');
  Timer? _hideTimer;
  late StreamSubscription<bool> _playingSubscription;
  late bool _playing;
  bool _bottomVisible = true;
  bool _topVisible = false;
  bool _edgeButtonsVisible = false;
  bool _routeCovered = false;
  bool _pointerNearControls = false;
  NavigatorState? _navigator;
  String? _menuDismissLabel;

  Duration get _duration =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : _motionDuration;

  @override
  void initState() {
    super.initState();
    _playing = widget.isPlaying;
    _playingSubscription = widget.playingStream.listen(_onPlayingChanged);
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant VideoControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceGeneration != widget.sourceGeneration) {
      _dismissOrphanedTransientRoutes();
    }
    if (oldWidget.playingStream != widget.playingStream) {
      _playingSubscription.cancel();
      _playingSubscription = widget.playingStream.listen(_onPlayingChanged);
    }
    if (oldWidget.isPlaying != widget.isPlaying) {
      _onPlayingChanged(widget.isPlaying);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.maybeOf(context);
    _menuDismissLabel = MaterialLocalizations.of(context).menuDismissLabel;
    final routeCovered = ModalRoute.isCurrentOf(context) == false;
    if (routeCovered == _routeCovered) return;
    _routeCovered = routeCovered;
    if (routeCovered) {
      _hideTimer?.cancel();
      _bottomVisible = true;
    } else {
      _scheduleHide();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playingSubscription.cancel();
    _shortcutFocus.dispose();
    _dismissOrphanedTransientRoutes();
    super.dispose();
  }

  /// Player menus and dialogs are routes and can outlive their controls.
  void _dismissOrphanedTransientRoutes() {
    final navigator = _navigator;
    final label = _menuDismissLabel;
    if (navigator == null || label == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      navigator.popUntil(
        (route) => !isPlayerControlTransientRoute(route, label),
      );
    });
  }

  void _revealControls() {
    if (!_bottomVisible) setState(() => _bottomVisible = true);
    _scheduleHide();
  }

  void _onPlayingChanged(bool playing) {
    if (!mounted || playing == _playing) return;
    setState(() {
      _playing = playing;
      _bottomVisible = true;
    });
    _scheduleHide();
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

  void _onPointerMovement(Offset position) {
    _pointerNearControls = _isNearControls(position);
    final revealTop = position.dy <= 16;
    final size = context.size ?? MediaQuery.sizeOf(context);
    final inEdgeBand = (position.dy - size.height / 2).abs() <= 96;
    final nearEdge =
        inEdgeBand && (position.dx <= 96 || position.dx >= size.width - 96);
    if (!_bottomVisible ||
        (revealTop && !_topVisible) ||
        nearEdge != _edgeButtonsVisible) {
      setState(() {
        _bottomVisible = true;
        if (revealTop) _topVisible = true;
        _edgeButtonsVisible = nearEdge;
      });
    }
    _scheduleHide();
  }

  void _onPointerExit() {
    _pointerNearControls = false;
    if (_edgeButtonsVisible) {
      setState(() => _edgeButtonsVisible = false);
    }
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_routeCovered) return;
    _hideTimer = Timer(
      _pointerNearControls ? _nearControlsHideDelay : _idleHideDelay,
      () {
        if (!mounted) return;
        // Tooltips live in the Overlay, so they would stay on the video after
        // the controls that own them fade out.
        if (_playing && _bottomVisible) Tooltip.dismissAllToolTips();
        setState(() {
          if (_playing) _bottomVisible = false;
          _topVisible = false;
          _edgeButtonsVisible = false;
        });
      },
    );
  }

  bool _isNearControls(Offset position) {
    final size = context.size ?? MediaQuery.sizeOf(context);
    return position.dy >= size.height - _controlProximityHeight;
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointerNearControls = _isNearControls(event.localPosition);
    if (!_bottomVisible) setState(() => _bottomVisible = true);
    _scheduleHide();
    _restoreShortcutFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VpflThemeExtension>()!;
    return PlayerShortcuts(
      bindings: widget.bindings,
      child: Focus(
        focusNode: _shortcutFocus,
        autofocus: true,
        onKeyEvent: (_, event) {
          // Hidden controls are not focusable; any key press brings them back
          // without moving focus.
          if (event is KeyDownEvent && !_routeCovered) _revealControls();
          return KeyEventResult.ignored;
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerUp: _onPointerUp,
          child: MouseRegion(
            cursor: !widget.fullscreen || _bottomVisible || _topVisible
                ? MouseCursor.defer
                : SystemMouseCursors.none,
            onHover: (event) => _onPointerMovement(event.localPosition),
            onEnter: (event) => _onPointerMovement(event.localPosition),
            onExit: (_) => _onPointerExit(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _shortcutFocus.requestFocus();
                      unawaited(widget.onPlayPause());
                    },
                  ),
                ),
                if (widget.inspectorMode != null &&
                    widget.inspectorBuilder != null)
                  ValueListenableBuilder<InspectorMode?>(
                    valueListenable: widget.inspectorMode!,
                    builder: (context, mode, _) {
                      if (mode == null) return const SizedBox.shrink();
                      return Positioned(
                        top: 12,
                        bottom: 100,
                        right: 12,
                        width: (MediaQuery.sizeOf(context).width - 24).clamp(
                          220,
                          360,
                        ),
                        child: StreamBuilder<Playlist>(
                          stream: widget.playlistStream,
                          initialData: widget.playlist,
                          builder: (context, snapshot) {
                            final queue = snapshot.data ?? widget.playlist;
                            final uri =
                                queue != null &&
                                    queue.index >= 0 &&
                                    queue.index < queue.medias.length
                                ? queue.medias[queue.index].uri
                                : null;
                            return widget.inspectorBuilder!(mode, uri);
                          },
                        ),
                      );
                    },
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ExcludeSemantics(
                    excluding: !_topVisible,
                    child: ExcludeFocus(
                      excluding: !_topVisible,
                      child: IgnorePointer(
                        ignoring: !_topVisible,
                        child: AnimatedSwitcher(
                          duration: _duration,
                          switchInCurve: _motionCurve,
                          switchOutCurve: _motionCurve,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, -0.35),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: widget.fullscreen && _topVisible
                              ? SafeArea(
                                  key: const ValueKey('fullscreen-top-bar'),
                                  bottom: false,
                                  child: Material(
                                    color: colors.playerOverlayTop,
                                    child: Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Exit fullscreen',
                                          onPressed: widget.onExit,
                                          color: colors.playerOverlayForeground,
                                          icon: const Icon(
                                            LucideIcons.minimize,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            widget.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: colors
                                                      .playerOverlayForeground,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
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
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _EdgeReveal(
                            visible: _edgeButtonsVisible,
                            child: _EdgeButton(
                              tooltip: 'Previous video',
                              icon: Icons.skip_previous_rounded,
                              onPressed:
                                  (widget.canPrevious?.call() ??
                                      queue.index > 0)
                                  ? widget.onPrevious
                                  : null,
                            ),
                          ),
                          _EdgeReveal(
                            visible: _edgeButtonsVisible,
                            child: _EdgeButton(
                              tooltip: 'Next video',
                              icon: Icons.skip_next_rounded,
                              onPressed:
                                  (widget.canNext?.call() ??
                                      queue.index < queue.medias.length - 1)
                                  ? widget.onNext
                                  : null,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  // Hidden controls must not take pointer, keyboard, or screen
                  // reader interaction.
                  child: ExcludeSemantics(
                    excluding: !_bottomVisible,
                    child: ExcludeFocus(
                      excluding: !_bottomVisible,
                      child: IgnorePointer(
                        ignoring: !_bottomVisible,
                        child: AnimatedSlide(
                          offset: _bottomVisible
                              ? Offset.zero
                              : const Offset(0, 0.35),
                          duration: _duration,
                          curve: _motionCurve,
                          child: AnimatedOpacity(
                            opacity: _bottomVisible ? 1 : 0,
                            duration: _duration,
                            curve: _motionCurve,
                            child: SafeArea(
                              top: false,
                              child: ColoredBox(
                                color: colors.playerEdgeBackground,
                                child: IconTheme(
                                  data: IconThemeData(
                                    color: colors.playerOverlayForeground,
                                  ),
                                  child: IconButtonTheme(
                                    data: IconButtonThemeData(
                                      style: ButtonStyle(
                                        foregroundColor: WidgetStatePropertyAll(
                                          colors.playerOverlayForeground,
                                        ),
                                      ),
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

class _EdgeReveal extends StatelessWidget {
  const _EdgeReveal({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    excluding: !visible,
    child: ExcludeFocus(
      excluding: !visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : _VideoControlsOverlayState._motionDuration,
          curve: _VideoControlsOverlayState._motionCurve,
          child: child,
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<VpflThemeExtension>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Semantics(
        container: true,
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        onTap: onPressed == null ? null : () => onPressed!(),
        child: ExcludeSemantics(
          child: OutlinedButton(
            onPressed: onPressed,
            style:
                OutlinedButton.styleFrom(
                  backgroundColor: colors.playerEdgeBackground,
                  foregroundColor: colors.playerOverlayForeground,
                  disabledForegroundColor: colors.playerOverlayForeground
                      .withValues(alpha: 0.45),
                  side: BorderSide.none,
                  fixedSize: const Size(72, 48),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ).copyWith(
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return colors.playerOverlayForeground.withValues(
                        alpha: 0.45,
                      );
                    }
                    return states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.pressed)
                        ? colors.playbackProgress
                        : colors.playerOverlayForeground;
                  }),
                ),
            child: Icon(icon, size: 36),
          ),
        ),
      ),
    );
  }
}
