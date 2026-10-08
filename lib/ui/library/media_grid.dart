import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../data/model/app_database.dart';
import 'media_card.dart';

/// Lazy video grid shared by the library and saved-folder screens.
class MediaGrid extends StatelessWidget {
  const MediaGrid({required this.items, required this.onOpenMedia, super.key});

  final List<LibraryMediaItem> items;
  final ValueChanged<String> onOpenMedia;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      const gap = 16.0;
      final columns = ((constraints.crossAxisExtent + gap) / (290 + gap))
          .ceil()
          .clamp(1, 8);
      final cardWidth =
          (constraints.crossAxisExtent - gap * (columns - 1)) / columns;
      final metadataHeight = MediaQuery.textScalerOf(context).scale(64);
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: cardWidth * 9 / 16 + metadataHeight,
          crossAxisSpacing: gap,
          mainAxisSpacing: 20,
        ),
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          final item = items[index];
          return MediaCard(
            title: path.basename(item.path),
            filePath: item.path,
            onTap: () => onOpenMedia(item.uri),
          );
        }, childCount: items.length),
      );
    },
  );
}
