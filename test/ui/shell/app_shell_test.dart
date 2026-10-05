import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/ui/app.dart';

void main() {
  testWidgets('sidebar navigates between the main sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());

    expect(find.text('Recent videos'), findsOneWidget);

    await tester.tap(find.byTooltip('All Videos'));
    await tester.pumpAndSettle();
    expect(
      find.text('Videos from your saved folders will appear here.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('appearance setting changes between system and dark theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('top bar shows the logo, file action, and appearance menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());

    expect(find.byKey(const Key('open-file-button')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byKey(const Key('quick-appearance-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Dark appearance'), findsOneWidget);
    await tester.tap(find.text('Dark appearance'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('top-bar-settings-button')), findsNothing);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Playback history'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('only the selected saved folder is highlighted', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final folders = [
      SavedFolder(
        id: 1,
        path: '/missing/data',
        displayName: 'data',
        addedAt: DateTime(2026),
      ),
      SavedFolder(
        id: 2,
        path: '/missing/downloads',
        displayName: 'Downloads',
        addedAt: DateTime(2026),
      ),
      SavedFolder(
        id: 3,
        path: '/missing/minty',
        displayName: 'minty',
        addedAt: DateTime(2026),
      ),
    ];
    await tester.pumpWidget(_testApp(folders: folders));
    await tester.pumpAndSettle();

    expect(_selectedNavigationLabels(tester), ['Home']);
    await tester.tap(find.byTooltip('data'));
    await tester.pumpAndSettle();
    expect(_selectedNavigationLabels(tester), ['data']);

    await tester.tap(find.byTooltip('Downloads'));
    await tester.pumpAndSettle();
    expect(_selectedNavigationLabels(tester), ['Downloads']);

    await tester.tap(find.byTooltip('All Videos'));
    await tester.pumpAndSettle();
    expect(_selectedNavigationLabels(tester), ['All Videos']);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(_selectedNavigationLabels(tester), ['Settings']);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}

List<String> _selectedNavigationLabels(WidgetTester tester) {
  final selected = <String>[];
  for (final label in [
    'Home',
    'All Videos',
    'Add Folder',
    'data',
    'Downloads',
    'minty',
    'Settings',
  ]) {
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byTooltip(label),
            matching: find.byType(Material),
          )
          .first,
    );
    if (material.color != Colors.transparent) selected.add(label);
  }
  return selected;
}

Widget _testApp({List<SavedFolder> folders = const []}) => ProviderScope(
  overrides: [
    recentPlaybackProvider.overrideWith((ref) => Stream.value(const [])),
    if (folders.isNotEmpty)
      savedFoldersProvider.overrideWith((ref) => Stream.value(folders)),
    appDatabaseProvider.overrideWith((ref) {
      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      ref.onDispose(() => database.close());
      return database;
    }),
  ],
  child: const VpflApp(initialMediaUri: null, startupError: null),
);
