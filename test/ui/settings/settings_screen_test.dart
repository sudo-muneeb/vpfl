import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vpfl/data/default_app_prompt_provider.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/repositories/playback_history_repository.dart';
import 'package:vpfl/data/services/default_app_prompt_service.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/settings/settings_screen.dart';

void main() {
  late AppDatabase database;
  late DefaultAppPromptService service;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    service = DefaultAppPromptService(settings: SettingsRepository(database))
      ..loading = false;
  });

  tearDown(() async {
    service.dispose();
    await database.close();
  });

  testWidgets('settings groups are ordered and controls remain bounded', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_harness(service));
    await tester.pumpAndSettle();

    final headings = ['Appearance', 'Playback', 'System integration', 'About'];
    final positions = headings.map(
      (title) => tester.getTopLeft(find.text(title)).dy,
    );
    expect(positions.toList(), orderedEquals(positions.toList()..sort()));
    expect(
      tester.getSize(find.byKey(const Key('theme-mode-selector'))).width,
      inInclusiveRange(360, 420),
    );
    final history = tester.getRect(
      find.byKey(const Key('history-enabled-setting')),
    );
    expect(history.width, lessThanOrEqualTo(680));
  });

  testWidgets('playback switches call their matching preference actions', (
    tester,
  ) async {
    bool? history;
    bool? resume;
    await tester.pumpWidget(
      _harness(
        service,
        onHistory: (value) => history = value,
        onResume: (value) => resume = value,
      ),
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('history-enabled-setting')))
          .label,
      contains('Playback history'),
    );
    await tester.tap(find.byKey(const Key('history-enabled-setting')));
    await tester.pump();
    expect(history, isFalse);
    await tester.tap(find.byKey(const Key('resume-enabled-setting')));
    await tester.pump();
    expect(resume, isFalse);
  });

  testWidgets('default-player state shows exact partial count and success', (
    tester,
  ) async {
    service.available = true;
    service.defaultCount = 4;
    await tester.pumpWidget(_harness(service));
    await tester.pumpAndSettle();
    expect(
      find.text('4 of 13 supported video formats use VPFL.'),
      findsOneWidget,
    );
    expect(find.text('Make VPFL default'), findsOneWidget);

    service.defaultCount = vpflVideoMimeTypes.length;
    await tester.pumpWidget(_harness(service));
    await tester.pumpAndSettle();
    expect(
      find.text('VPFL is the default for supported video formats.'),
      findsOneWidget,
    );
    expect(find.text('Make VPFL default'), findsNothing);
  });

  testWidgets('About uses package metadata and opens the real repository', (
    tester,
  ) async {
    Uri? opened;
    await tester.pumpWidget(
      _harness(
        service,
        openExternal: (uri) async {
          opened = uri;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Version 1.2.3  ·  Build 7'), findsOneWidget);
    expect(find.text('Created by Sheikh Muneeb Ahmed'), findsOneWidget);
    await tester.ensureVisible(find.text('View on GitHub'));
    await tester.tap(find.text('View on GitHub'));
    await tester.pump();
    expect(opened.toString(), 'https://github.com/sudo-muneeb/vpfl');
  });

  testWidgets('third-party notices open in a local scrollable reader', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(service));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Third-party notices'));
    await tester.tap(find.text('Third-party notices'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.textContaining('Dependencies retain their'), findsOneWidget);
    await tester.tap(find.byTooltip('Close document'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    await tester.ensureVisible(find.text('Apache License 2.0'));
    await tester.tap(find.text('Apache License 2.0'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.textContaining('Apache License'), findsWidgets);
  });

  testWidgets('GitHub launch failure is explained without leaving Settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(service, openExternal: (_) async => false),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View on GitHub'));
    await tester.tap(find.text('View on GitHub'));
    await tester.pump();
    expect(find.text('Could not open GitHub.'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets(
    'keyboard focus visits theme, playback, integration, then About',
    (tester) async {
      service.available = true;
      await tester.pumpWidget(
        _harness(service, onHistory: (_) {}, onResume: (_) {}),
      );
      await tester.pumpAndSettle();
      final visited = <String>[];
      for (var i = 0; i < 16; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final context = FocusManager.instance.primaryFocus?.context;
        if (context == null) continue;
        final outlined = context
            .findAncestorWidgetOfExactType<OutlinedButton>();
        final category =
            context
                    .findAncestorWidgetOfExactType<
                      SegmentedButton<ThemeMode>
                    >() !=
                null
            ? 'theme'
            : context.findAncestorWidgetOfExactType<SwitchListTile>() != null
            ? 'playback'
            : outlined?.key == const Key('make-default-button')
            ? 'integration'
            : outlined?.key == const Key('github-button')
            ? 'about'
            : null;
        if (category != null && (visited.isEmpty || visited.last != category)) {
          visited.add(category);
        }
      }
      expect(
        visited,
        containsAllInOrder(['theme', 'playback', 'integration', 'about']),
      );
    },
  );

  testWidgets('narrow Settings stays scrollable with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    await tester.pumpWidget(_harness(service));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('View on GitHub'), findsOneWidget);
  });
}

Widget _harness(
  DefaultAppPromptService service, {
  ValueChanged<bool>? onHistory,
  ValueChanged<bool>? onResume,
  Future<bool> Function(Uri)? openExternal,
}) => ProviderScope(
  overrides: [defaultAppPromptProvider.overrideWithValue(service)],
  child: MaterialApp(
    theme: VpflTheme.light,
    home: Scaffold(
      body: SettingsScreen(
        themeMode: ThemeMode.system,
        onThemeModeChanged: (_) {},
        onHistoryEnabledChanged: onHistory,
        onResumeEnabledChanged: onResume,
        loadPackageInfo: () async => PackageInfo(
          appName: 'VPFL',
          packageName: 'vpfl',
          version: '1.2.3',
          buildNumber: '7',
        ),
        openExternal: openExternal,
      ),
    ),
  ),
);
