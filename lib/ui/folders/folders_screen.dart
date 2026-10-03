import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/model/app_database.dart';
import '../../data/persistence_providers.dart';
import '../library/media_grid.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({
    required this.folder,
    required this.onAddFolder,
    required this.onOpenMedia,
    required this.onRemoveFolder,
    required this.onRescan,
    super.key,
  });

  final SavedFolder? folder;
  final VoidCallback onAddFolder;
  final ValueChanged<String> onOpenMedia;
  final ValueChanged<SavedFolder> onRemoveFolder;
  final VoidCallback? onRescan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (folder == null) {
      final AsyncValue<List<SavedFolder>> folders = ref.watch(
        savedFoldersProvider,
      );
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Folders',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: onAddFolder,
                icon: const Icon(Icons.add),
                label: const Text('Add folder'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          folders.when(
            data: (List<SavedFolder> values) => values.isEmpty
                ? const _FolderEmptyState()
                : Column(
                    children: [
                      for (final SavedFolder value in values)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(value.displayName),
                            subtitle: Text(
                              value.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove folder',
                              onPressed: () => onRemoveFolder(value),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ),
                        ),
                    ],
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace stack) =>
                Text('Could not load folders: $error'),
          ),
        ],
      );
    }

    final AsyncValue<List<LibraryMediaItem>> media = ref.watch(
      folderMediaProvider(folder!.id),
    );
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder!.displayName,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        folder!.path,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Rescan folder',
                  onPressed: onRescan,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Remove folder',
                  onPressed: () => onRemoveFolder(folder!),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
        media.when(
          data: (List<LibraryMediaItem> items) => items.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FolderEmptyState(
                    message: folder!.lastScannedAt == null
                        ? 'Scanning this folder…'
                        : 'No videos found in this folder yet.',
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  sliver: MediaGrid(items: items, onOpenMedia: onOpenMedia),
                ),
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace stack) => SliverFillRemaining(
            child: Center(child: Text('Could not load videos: $error')),
          ),
        ),
      ],
    );
  }
}

class _FolderEmptyState extends StatelessWidget {
  const _FolderEmptyState({
    this.message = 'Add a folder to build your video library.',
  });
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.folder_open_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
}
