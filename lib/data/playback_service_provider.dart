import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/playback_service.dart';
import 'services/media_source_identity.dart';
import 'persistence_providers.dart';

/// Provides the app's single playback service instance.
final Provider<PlaybackService> playbackServiceProvider =
    Provider<PlaybackService>((Ref ref) {
      final settings = ref.watch(settingsRepositoryProvider);
      final history = ref.watch(playbackHistoryRepositoryProvider);
      final PlaybackService service = PlaybackService(
        resumePositionForUri: (uri) async {
          if (!await settings.getBool('resumeEnabled', defaultValue: true)) {
            return null;
          }
          return history.resumePosition(canonicalMediaUri(uri));
        },
      );
      ref.onDispose(() => unawaited(service.dispose()));
      return service;
    });
