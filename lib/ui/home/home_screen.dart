import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/persistence_providers.dart';
import '../../data/model/app_database.dart';
import '../library/media_card.dart';

/// Home surface for recent media and the indexed video library.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({required this.onOpenMedia, super.key});
  final ValueChanged<String> onOpenMedia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentPlaybackProvider);
    final library = ref.watch(libraryMediaProvider);
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text('Home', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Your local videos, ready when you are.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        _SectionHeading(
          title: 'Recent videos',
          subtitle: 'Pick up where you left off.',
        ),
        const SizedBox(height: 12),
        recent.when(
          data: (List<PlaybackHistory> entries) => entries.isEmpty
              ? const _EmptyLibraryCard(
                  icon: Icons.history,
                  title: 'Nothing played yet',
                  message: 'Videos you play will appear here.',
                )
              : _HomeCardGrid(
                  cards: [
                    for (final entry in entries.take(8))
                      _RecentMediaCard(
                        entry: entry,
                        onTap: () => onOpenMedia(entry.uri),
                      ),
                  ],
                ),
          loading: () => const LinearProgressIndicator(),
          error: (Object error, StackTrace stack) => _EmptyLibraryCard(
            icon: Icons.error_outline,
            title: 'History is unavailable',
            message: error.toString(),
          ),
        ),
        const SizedBox(height: 32),
        _SectionHeading(
          title: 'All videos',
          subtitle: 'Your indexed video library.',
        ),
        const SizedBox(height: 12),
        library.when(
          data: (items) => items.isEmpty
              ? const _EmptyLibraryCard(
                  icon: Icons.video_library_outlined,
                  title: 'Your library is empty',
                  message: 'Add a folder to start building your library.',
                )
              : _HomeCardGrid(
                  cards: [
                    for (final item in items.take(8))
                      MediaCard(
                        title: item.displayName,
                        status: 'Ready to play',
                        detail: item.path,
                        filePath: item.path,
                        onTap: () => onOpenMedia(item.uri),
                      ),
                  ],
                ),
          loading: () => const LinearProgressIndicator(),
          error: (Object error, StackTrace stack) => _EmptyLibraryCard(
            icon: Icons.error_outline,
            title: 'Library is unavailable',
            message: error.toString(),
          ),
        ),
      ],
    );
  }
}

class _RecentMediaCard extends StatelessWidget {
  const _RecentMediaCard({required this.entry, required this.onTap});

  final PlaybackHistory entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasDuration = entry.durationMs > 0;
    return MediaCard(
      title: entry.displayName,
      status: hasDuration
          ? '${_time(entry.positionMs)} / ${_time(entry.durationMs)} watched'
          : 'Played ${entry.watchCount} ${entry.watchCount == 1 ? 'time' : 'times'}',
      detail: entry.completed ? 'Completed' : 'Recent playback',
      progress: hasDuration ? entry.positionMs / entry.durationMs : null,
      filePath: _localPath(entry.uri),
      onTap: onTap,
    );
  }

  static String? _localPath(String uri) {
    final Uri? parsed = Uri.tryParse(uri);
    return parsed?.scheme == 'file' ? parsed!.toFilePath() : null;
  }

  String _time(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _HomeCardGrid extends StatelessWidget {
  const _HomeCardGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 16.0;
      final columns = ((constraints.maxWidth + gap) / 250).floor().clamp(1, 5);
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: 20,
        children: [
          for (final card in cards) SizedBox(width: width, child: card),
        ],
      );
    },
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _EmptyLibraryCard extends StatelessWidget {
  const _EmptyLibraryCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
