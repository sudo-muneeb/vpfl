import '../model/app_database.dart';
import 'lifecycle_trace.dart';
import 'playback_history_recorder.dart';
import 'playback_service.dart';
import 'thumbnail_service.dart';

/// One awaited, idempotent shutdown path for the app-owned resources.
class ApplicationShutdown {
  ApplicationShutdown({
    required this.playback,
    required this.history,
    required this.thumbnails,
    required this.database,
  });

  final PlaybackService playback;
  final PlaybackHistoryRecorder history;
  final ThumbnailService thumbnails;
  final AppDatabase database;
  Future<void>? _shutdownFuture;

  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  Future<void> _shutdown() async {
    LifecycleTrace.event('app.shutdown.stop');
    await playback.stop();
    LifecycleTrace.event('app.shutdown.history');
    await history.dispose();
    LifecycleTrace.event('app.shutdown.player');
    // media_kit owns the VideoController release callback and native texture.
    await playback.dispose();
    LifecycleTrace.event('app.shutdown.thumbnails');
    await thumbnails.close();
    LifecycleTrace.event('app.shutdown.database');
    await database.close();
    LifecycleTrace.event('app.shutdown.complete');
  }
}
