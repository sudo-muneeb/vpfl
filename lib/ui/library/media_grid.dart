import 'package:flutter/material.dart';

import '../../data/model/app_database.dart';
import 'media_card.dart';

/// Lazy video grid shared by the library and saved-folder screens.
class MediaGrid extends StatelessWidget {
  const MediaGrid({required this.items, required this.onOpenMedia, super.key});

  final List<LibraryMediaItem> items;
  final ValueChanged<String> onOpenMedia;

  @override
  Widget build(BuildContext context) => SliverGrid(
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 290,
      mainAxisExtent: 248,
      crossAxisSpacing: 16,
      mainAxisSpacing: 20,
    ),
    delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
      final item = items[index];
      return MediaCard(
        title: item.displayName,
        status: 'Ready to play',
        detail: item.path,
        onTap: () => onOpenMedia(item.uri),
      );
    }, childCount: items.length),
  );
}
