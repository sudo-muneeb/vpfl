import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/home/home_screen.dart';
import 'package:vpfl/ui/library/media_card.dart';

void main() {
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
          home: Scaffold(body: HomeScreen(onOpenMedia: (_) {})),
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
}
