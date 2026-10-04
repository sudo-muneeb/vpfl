import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/thumbnail_service.dart';

final Provider<ThumbnailService> thumbnailServiceProvider =
    Provider<ThumbnailService>((Ref ref) {
      final ThumbnailService service = ThumbnailService();
      ref.onDispose(() => unawaited(service.close()));
      return service;
    });

/// Artwork for one media file, or null when no valid thumbnail exists.
/// Rebuilds when VPFL stores a new frame for that same file.
final thumbnailProvider = FutureProvider.family<File?, String>((
  Ref ref,
  String path,
) {
  final ThumbnailService service = ref.watch(thumbnailServiceProvider);
  final String key = ThumbnailService.keyFor(path);
  final StreamSubscription<String> subscription = service.savedFrames.listen((
    String saved,
  ) {
    if (saved == key) ref.invalidateSelf();
  });
  ref.onDispose(() => unawaited(subscription.cancel()));
  return service.resolve(path);
});
