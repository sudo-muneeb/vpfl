import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../../data/services/media_metadata_service.dart';

typedef MetadataLoader = Future<MediaMetadata> Function(
  String filePath, {
  MetadataCancellation? cancellation,
});

/// Displays the result of one on-demand metadata inspection.
class VideoDetailsPanel extends StatefulWidget {
  const VideoDetailsPanel({
    required this.filePath,
    required this.load,
    required this.onClose,
    super.key,
  });

  final String filePath;
  final MetadataLoader load;
  final VoidCallback onClose;

  @override
  State<VideoDetailsPanel> createState() => _VideoDetailsPanelState();
}

class _VideoDetailsPanelState extends State<VideoDetailsPanel> {
  MetadataCancellation? _cancellation;
  late Future<MediaMetadata> _future = _load();

  Future<MediaMetadata> _load() {
    _cancellation?.cancel();
    final cancellation = MetadataCancellation();
    _cancellation = cancellation;
    return widget
        .load(widget.filePath, cancellation: cancellation)
        .then(
          (value) => value,
          onError: (Object error, StackTrace stack) {
            stderr.writeln('VPFL media details failed: $error');
            Error.throwWithStackTrace(error, stack);
          },
        );
  }

  @override
  void didUpdateWidget(covariant VideoDetailsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _future = _load();
    }
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {LogicalKeySet(LogicalKeyboardKey.escape): widget.onClose},
    child: Focus(
      autofocus: true,
      child: Material(
        elevation: 12,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Video details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close details',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Tooltip(
                message: widget.filePath,
                child: Text(
                  path.basename(widget.filePath),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: FutureBuilder<MediaMetadata>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Reading video details…'),
                          ],
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Could not read video details.'),
                            const SizedBox(height: 8),
                            Text(switch (snapshot.error) {
                              FileSystemException _ =>
                                'The video or its folder is unavailable.',
                              TimeoutException _ =>
                                'Reading this video took too long.',
                              _ => 'This video could not be inspected.',
                            }, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _future = _load();
                                });
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    return _MetadataList(metadata: snapshot.requireData);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MetadataList extends StatelessWidget {
  const _MetadataList({required this.metadata});

  final MediaMetadata metadata;

  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    children: [
      _section(context, 'File information'),
      _fact(context, 'Location', metadata.absolutePath),
      _fact(context, 'Size', _size(metadata.sizeBytes)),
      _fact(context, 'Modified', metadata.modified.toLocal().toString()),
      _fact(context, 'Duration', _duration(metadata.duration)),
      _section(context, 'Video information'),
      _fact(context, 'Format reported by mpv', metadata.container),
      _fact(context, 'Codec', metadata.video.firstOrNull?.codec),
      _fact(
        context,
        'Resolution',
        metadata.video.firstOrNull?.width != null &&
                metadata.video.firstOrNull?.height != null
            ? '${metadata.video.first.width} × ${metadata.video.first.height}'
            : null,
      ),
      _fact(
        context,
        'Reported frame rate',
        metadata.video.firstOrNull?.frameRate == null
            ? null
            : '${metadata.video.first.frameRate!.toStringAsFixed(2)} fps',
      ),
      if (metadata.video.length > 1)
        _fact(context, 'Video streams', '${metadata.video.length}'),
    ],
  );

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _fact(BuildContext context, String name, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        SelectableText(
          value == null || value.isEmpty ? 'Unavailable' : value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB';
  }

  String? _duration(Duration? value) {
    if (value == null) return null;
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return value.inHours > 0
        ? '${value.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}
