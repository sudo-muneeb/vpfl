import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/model/app_database.dart';
import '../../data/persistence_providers.dart';
import 'media_grid.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({
    required this.onOpenMedia,
    this.onShowDetails,
    this.onShowContainingFolder,
    super.key,
  });
  final ValueChanged<String> onOpenMedia;
  final ValueChanged<String>? onShowDetails;
  final ValueChanged<String>? onShowContainingFolder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<LibraryMediaItem>> media = ref.watch(
      libraryMediaProvider,
    );
    return media.when(
      data: (List<LibraryMediaItem> items) => items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'All Videos',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Videos from your saved folders will appear here.',
                    ),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'All Videos',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  sliver: MediaGrid(
                    items: items,
                    onOpenMedia: onOpenMedia,
                    onShowDetails: onShowDetails,
                    onShowContainingFolder: onShowContainingFolder,
                  ),
                ),
              ],
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stack) =>
          Center(child: Text('Could not load library: $error')),
    );
  }
}
