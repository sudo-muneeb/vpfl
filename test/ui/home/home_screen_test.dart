import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/home/home_screen.dart';
import 'package:vpfl/ui/library/media_card.dart';

void main() {
  testWidgets('Home previews ten items and offers the full library', (
    tester,
  ) async {
    final media = List.generate(
      12,
      (index) => LibraryMediaItem(
        uri: 'file:///videos/video$index.mp4',
        folderId: 1,
        path: '/videos/video$index.mp4',
        displayName: 'video$index',
        sizeBytes: 100,
        modifiedAt: DateTime(2026),
        indexedAt: DateTime(2026),
      ),
    );
    var showAllCalls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentPlaybackProvider.overrideWith((ref) => Stream.value(const [])),
          libraryMediaProvider.overrideWith((ref) => Stream.value(media)),
        ],
        child: MaterialApp(
          theme: VpflTheme.light,
          home: Scaffold(
            body: HomeScreen(
              onOpenMedia: (_) {},
              onShowAllVideos: () => showAllCalls++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('View all videos'), 250);
    expect(find.text('From your library'), findsOneWidget);
    expect(find.byType(MediaCard), findsNWidgets(10));
    expect(find.text('video9.mp4'), findsOneWidget);
    expect(find.text('video10.mp4'), findsNothing);

    await tester.tap(find.text('View all videos'));
    expect(showAllCalls, 1);
  });

  testWidgets('completed recent videos keep progress without watched time', (
    tester,
  ) async {
    final entries = [
      PlaybackHistory(
        uri: 'memory:complete',
        displayName: 'complete.mp4',
        lastOpenedAt: DateTime(2026),
        positionMs: 0,
        durationMs: 22000,
        watchCount: 1,
        completed: true,
      ),
      PlaybackHistory(
        uri: 'memory:partial',
        displayName: 'partial.mp4',
        lastOpenedAt: DateTime(2026),
        positionMs: 7000,
        durationMs: 22000,
        watchCount: 1,
        completed: false,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentPlaybackProvider.overrideWith((ref) => Stream.value(entries)),
          libraryMediaProvider.overrideWith(
            (ref) => Stream.value(const <LibraryMediaItem>[]),
          ),
        ],
        child: MaterialApp(
          theme: VpflTheme.light,
          home: Scaffold(
            body: HomeScreen(onOpenMedia: (_) {}, onShowAllVideos: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cards = tester.widgetList<MediaCard>(find.byType(MediaCard)).toList();
    expect(cards, hasLength(2));
    expect(cards.first.title, 'complete.mp4');
    expect(cards.first.progress, 1);
    expect(cards.first.watchedTime, isNull);
    expect(cards.last.watchedTime, '00:07 / 00:22');
  });

  testWidgets('Recent cards show progress without a remove overlay', (
    tester,
  ) async {
    final entries = [
      PlaybackHistory(
        uri: 'file:///videos/first.mp4',
        displayName: 'first.mp4',
        lastOpenedAt: DateTime(2026),
        positionMs: 30000,
        durationMs: 120000,
        watchCount: 1,
        completed: false,
      ),
      PlaybackHistory(
        uri: 'file:///videos/second.mp4',
        displayName: 'second.mp4',
        lastOpenedAt: DateTime(2026),
        positionMs: 0,
        durationMs: 120000,
        watchCount: 1,
        completed: false,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentPlaybackProvider.overrideWith((ref) => Stream.value(entries)),
          libraryMediaProvider.overrideWith(
            (ref) => Stream.value(const <LibraryMediaItem>[]),
          ),
        ],
        child: MaterialApp(
          theme: VpflTheme.light,
          home: Scaffold(
            body: HomeScreen(onOpenMedia: (_) {}, onShowAllVideos: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MediaCard), findsNWidgets(2));
    expect(find.byTooltip('Remove first.mp4 from Recents'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
  });
}
