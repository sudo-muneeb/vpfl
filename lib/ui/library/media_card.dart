import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/thumbnail_providers.dart';
import '../core/themes/vpfl_theme_extension.dart';

/// Consistent video card for recent, library, and folder browsing.
class MediaCard extends StatefulWidget {
  const MediaCard({
    required this.title,
    required this.status,
    required this.detail,
    required this.onTap,
    this.filePath,
    this.progress,
    this.watchedTime,
    super.key,
  });

  final String title;
  final String status;
  final String? detail;
  final double? progress;
  final String? watchedTime;
  final VoidCallback onTap;

  /// Local file whose artwork is shown; null keeps the placeholder.
  final String? filePath;

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<VpflThemeExtension>()!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final active = _hovered || _focused;
    final duration = MediaQuery.maybeOf(context)?.disableAnimations == true
        ? Duration.zero
        : const Duration(milliseconds: 150);
    final radius = BorderRadius.circular(12);

    return Semantics(
      button: true,
      label: [
        widget.title,
        widget.status,
        if (widget.watchedTime != null) '${widget.watchedTime} watched',
      ].join(', '),
      child: Tooltip(
        message: widget.title,
        waitDuration: const Duration(milliseconds: 900),
        child: AnimatedContainer(
          duration: duration,
          decoration: BoxDecoration(
            color: tokens.cardSurface,
            borderRadius: radius,
            border: Border.all(
              color: _focused
                  ? tokens.sidebarFocus
                  : _hovered
                  ? tokens.cardBorderActive
                  : tokens.cardBorder,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onHover: (value) => setState(() => _hovered = value),
              onFocusChange: (value) => setState(() => _focused = value),
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            tokens.cardArtworkTop,
                            tokens.cardArtworkBottom,
                          ],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _Artwork(
                            filePath: widget.filePath,
                            placeholderColor: scheme.onSurfaceVariant,
                          ),
                          if (widget.watchedTime case final String watched)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: active ? 1 : 0,
                                  duration: duration,
                                  child: ColoredBox(
                                    color: tokens.cardOverlay,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'WATCHED',
                                          style: textTheme.labelSmall?.copyWith(
                                            color:
                                                tokens.playerOverlayForeground,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          watched,
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                color: tokens
                                                    .playerOverlayForeground,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            right: 10,
                            bottom: widget.progress == null ? 10 : 12,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: tokens.cardOverlay,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 17,
                                  color: tokens.playerOverlayForeground,
                                ),
                              ),
                            ),
                          ),
                          if (widget.progress case final value?)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: LinearProgressIndicator(
                                value: value.clamp(0, 1),
                                minHeight: 3,
                                color: tokens.playbackProgress,
                                backgroundColor: tokens.cardBorder,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (widget.detail case final String detail) ...[
                          const SizedBox(height: 2),
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thumbnail artwork that fills the card, or a movie icon when none exists.
class _Artwork extends ConsumerWidget {
  const _Artwork({required this.filePath, required this.placeholderColor});

  final String? filePath;
  final Color placeholderColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? path = filePath;
    final placeholder = Center(
      child: Icon(Icons.movie_outlined, size: 40, color: placeholderColor),
    );
    final File? file = path == null
        ? null
        : ref.watch(thumbnailProvider(path)).asData?.value;
    return Positioned.fill(
      child: file == null
          ? placeholder
          : Image.file(
              file,
              fit: BoxFit.cover,
              // Thumbnails are decoded near card size, not at full frame size.
              cacheWidth: 480,
              errorBuilder: (context, error, stackTrace) => placeholder,
            ),
    );
  }
}
