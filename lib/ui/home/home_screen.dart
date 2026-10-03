import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/persistence_providers.dart';
import '../../data/model/app_database.dart';

/// Home surface for recent media and the indexed video library.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentPlaybackProvider);
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
              : Column(
                  children: [
                    for (final PlaybackHistory entry in entries)
                      _RecentMediaCard(entry: entry),
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
        const _EmptyLibraryCard(
          icon: Icons.video_library_outlined,
          title: 'Your library is empty',
          message: 'Add a folder to start building your library.',
        ),
      ],
    );
  }
}

class _RecentMediaCard extends StatelessWidget {
  const _RecentMediaCard({required this.entry});

  final PlaybackHistory entry;

  @override
  Widget build(BuildContext context) {
    final String progress = entry.durationMs > 0
        ? '${Duration(milliseconds: entry.positionMs).inMinutes} min of '
              '${Duration(milliseconds: entry.durationMs).inMinutes} min'
        : 'Played ${entry.watchCount} ${entry.watchCount == 1 ? 'time' : 'times'}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.movie_outlined),
        title: Text(
          entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(progress),
      ),
    );
  }
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
