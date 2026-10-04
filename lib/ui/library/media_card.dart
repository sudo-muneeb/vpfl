import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/thumbnail_providers.dart';

/// Consistent video card for recent, library, and folder browsing.
class MediaCard extends StatelessWidget {
  const MediaCard({
    required this.title,
    required this.status,
    required this.detail,
    required this.onTap,
    this.filePath,
    this.progress,
    super.key,
  });

  final String title;
  final String status;
  final String detail;
  final double? progress;
  final VoidCallback onTap;

  /// Local file whose artwork is shown; null keeps the placeholder.
  final String? filePath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.surfaceContainerHighest,
                      scheme.secondaryContainer,
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _Artwork(
                      filePath: filePath,
                      placeholderColor: scheme.onSurfaceVariant,
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        size: 28,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (progress case final value?)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: value.clamp(0, 1),
                          minHeight: 4,
                          backgroundColor: scheme.surfaceContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
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
      child: Icon(Icons.movie_outlined, size: 44, color: placeholderColor),
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
