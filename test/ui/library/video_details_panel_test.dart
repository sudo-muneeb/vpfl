import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/services/media_metadata_service.dart';
import 'package:vpfl/ui/library/video_details_panel.dart';

void main() {
  final metadata = MediaMetadata(
    fileName: 'movie.mkv',
    absolutePath: '/videos/movie.mkv',
    sizeBytes: 4096,
    modified: DateTime(2026),
    duration: const Duration(minutes: 2),
    container: null,
    video: const [
      VideoStreamMetadata(
        codec: 'H.264',
        width: 1920,
        height: 1080,
        frameRate: 30000 / 1001,
      ),
    ],
  );

  testWidgets('shows each available and unavailable field in two sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 600,
            child: VideoDetailsPanel(
              filePath: '/videos/movie.mkv',
              load: (path, {cancellation}) async => metadata,
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('movie.mkv'), findsOneWidget);
    expect(find.text('File information'), findsOneWidget);
    expect(find.text('Video information'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('1920 × 1080'), findsOneWidget);
    expect(find.text('29.97 fps'), findsOneWidget);
    expect(find.text('Audio'), findsNothing);
  });

  testWidgets('Escape closes immediately and cancels an in-flight read', (
    tester,
  ) async {
    final pending = Completer<MediaMetadata>();
    MetadataCancellation? request;
    var closeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 600,
            child: VideoDetailsPanel(
              filePath: '/videos/movie.mkv',
              load: (path, {cancellation}) {
                request = cancellation;
                return pending.future;
              },
              onClose: () => closeCount += 1,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Reading video details…'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closeCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(request?.isCanceled, true);
    pending.complete(metadata);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an inspection error stays user friendly and can be retried', (
    tester,
  ) async {
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 600,
            child: VideoDetailsPanel(
              filePath: '/videos/movie.mkv',
              load: (path, {cancellation}) async {
                reads += 1;
                if (reads == 1) throw StateError('internal diagnostic secret');
                return metadata;
              },
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This video could not be inspected.'), findsOneWidget);
    expect(find.textContaining('internal diagnostic secret'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('movie.mkv'), findsOneWidget);
  });
}
