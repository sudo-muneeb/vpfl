import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/playback_service.dart';

/// Provides the app's single playback service instance.
final Provider<PlaybackService> playbackServiceProvider =
    Provider<PlaybackService>((Ref ref) {
      final PlaybackService service = PlaybackService();
      ref.onDispose(() => unawaited(service.dispose()));
      return service;
    });
