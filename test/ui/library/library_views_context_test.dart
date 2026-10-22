import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/folders/folders_screen.dart';
import 'package:vpfl/ui/home/home_screen.dart';
import 'package:vpfl/ui/library/library_screen.dart';
import 'package:vpfl/ui/library/media_card.dart';

void main() {
  testWidgets('all video views route menu actions to the selected file', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(460, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026);
    const filePath = '/videos/second clip.mp4';
    final media = [
      for (final name in ['first.mp4', 'second clip.mp4'])
        LibraryMediaItem(
          uri: Uri.file('/videos/$name').toString(),
          folderId: 1,
          path: '/videos/$name',
          displayName: name,
          sizeBytes: 1,
          modifiedAt: now,
          indexedAt: now,
        ),
    ];
    final recent = [
      for (final item in media)
        PlaybackHistory(
          uri: item.uri,
          displayName: item.displayName,
          lastOpenedAt: now,
          positionMs: 0,
          durationMs: 1000,
          watchCount: 1,
          completed: false,
        ),
    ];
    final folder = SavedFolder(
      id: 1,
      path: '/videos',
      displayName: 'Videos',
      addedAt: now,
    );
    final opened = <String>[];
    final details = <String>[];
    final containingFolders = <String>[];
    Widget wrap(Widget child) => ProviderScope(
      overrides: [
        recentPlaybackProvider.overrideWith((ref) => Stream.value(recent)),
        libraryMediaProvider.overrideWith((ref) => Stream.value(media)),
        folderMediaProvider(1).overrideWith((ref) => Stream.value(media)),
      ],
      child: MaterialApp(
        theme: VpflTheme.light,
        home: Scaffold(body: child),
      ),
    );
    final views = <Widget>[
      HomeScreen(
        onOpenMedia: opened.add,
        onShowDetails: details.add,
        onShowContainingFolder: containingFolders.add,
      ),
      LibraryScreen(
        onOpenMedia: opened.add,
        onShowDetails: details.add,
        onShowContainingFolder: containingFolders.add,
      ),
      FoldersScreen(
        folder: folder,
        onAddFolder: () {},
        onOpenMedia: opened.add,
        onShowDetails: details.add,
        onShowContainingFolder: containingFolders.add,
        onRemoveFolder: (_) {},
        onRescan: () {},
      ),
    ];
    for (final view in views) {
      await tester.pumpWidget(wrap(view));
      await tester.pumpAndSettle();
      final card = find
          .byWidgetPredicate(
            (widget) => widget is MediaCard && widget.filePath == filePath,
          )
          .first;
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.down(tester.getCenter(card));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text('Show details'), findsOneWidget);
      expect(opened, isEmpty);
      await tester.tap(find.text('Show details'));
      await tester.pumpAndSettle();
      expect(details.last, filePath);

      await mouse.down(tester.getCenter(card));
      await mouse.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show containing folder'));
      await tester.pumpAndSettle();
      expect(containingFolders.last, filePath);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    }
    expect(details, hasLength(3));
    expect(containingFolders, hasLength(3));
    expect(opened, isEmpty);
  });
}
