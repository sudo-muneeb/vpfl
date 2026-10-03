import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../data/model/app_database.dart';

/// Lazy video grid shared by the library and saved-folder screens.
class MediaGrid extends StatelessWidget {
  const MediaGrid({required this.items, required this.onOpenMedia, super.key});

  final List<LibraryMediaItem> items;
  final ValueChanged<String> onOpenMedia;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (BuildContext context, SliverConstraints constraints) {
      final int columns = (constraints.crossAxisExtent / 210).floor().clamp(
        1,
        8,
      );
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 1.45,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          final LibraryMediaItem item = items[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onOpenMedia(item.uri),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Center(
                        child: Icon(
                          Icons.movie_outlined,
                          size: 42,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        }, childCount: items.length),
      );
    },
  );
}
