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

    await tester.tap(find.byKey(const Key('top-bar-settings-button')));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('appearance setting changes between system and dark theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.tap(find.byKey(const Key('top-bar-settings-button')));
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

    await tester.tap(find.byKey(const Key('top-bar-settings-button')));
    await tester.pumpAndSettle();
    expect(find.text('Playback history'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}

Widget _testApp() => ProviderScope(
  overrides: [
    recentPlaybackProvider.overrideWith((ref) => Stream.value(const [])),
    appDatabaseProvider.overrideWith((ref) {
      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      ref.onDispose(() => database.close());
      return database;
    }),
  ],
  child: const VpflApp(initialMediaUri: null, startupError: null),
);
