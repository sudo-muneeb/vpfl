import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistence_providers.dart';
import 'services/playback_history_recorder.dart';
import 'playback_service_provider.dart';

final Provider<PlaybackHistoryRecorder> playbackHistoryRecorderProvider =
    Provider<PlaybackHistoryRecorder>((Ref ref) {
      final PlaybackHistoryRecorder recorder = PlaybackHistoryRecorder(
        playback: ref.watch(playbackServiceProvider),
        history: ref.watch(playbackHistoryRepositoryProvider),
        settings: ref.watch(settingsRepositoryProvider),
      );
      ref.onDispose(() => unawaited(recorder.dispose()));
      return recorder;
    });
