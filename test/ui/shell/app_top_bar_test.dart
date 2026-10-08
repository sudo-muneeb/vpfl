import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/core/widgets/app_top_bar.dart';
import 'package:vpfl/ui/core/widgets/window_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.app.vpfl/window');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'isMaximized' || call.method == 'toggleMaximize'
              ? false
              : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('empty title bar regions drag while buttons stay clickable', (
    tester,
  ) async {
    var openCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: VpflTheme.light,
        home: Scaffold(
          body: AppTopBar(
            title: 'movie.mp4',
            themeMode: ThemeMode.system,
            onOpenFile: () => openCount++,
            onThemeModeChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final dragRect = tester.getRect(find.byType(WindowDragHandle));
    for (final fraction in [0.15, 0.55, 0.95]) {
      final position = Offset(
        dragRect.left + dragRect.width * fraction,
        dragRect.top + 8,
      );
      await tester.tapAt(position);
      await tester.pump();
    }
    expect(calls.where((method) => method == 'startDrag'), hasLength(3));

    calls.clear();
    await tester.tap(find.byKey(const Key('open-file-button')));
    await tester.pump();
    expect(openCount, 1);
    expect(calls, isNot(contains('startDrag')));

    await tester.tap(find.byTooltip('Minimize window'));
    await tester.tap(find.byTooltip('Maximize window'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, containsAll(['minimize', 'toggleMaximize']));
    expect(calls, isNot(contains('startDrag')));
  });

  testWidgets('player filename exposes path and known facts on focus', (
    tester,
  ) async {
    const details = '/deep/folder/movie.mp4\nH.264 · 1920 × 1080 · 30 fps';
    await tester.pumpWidget(
      MaterialApp(
        theme: VpflTheme.light,
        home: Scaffold(
          body: AppTopBar(
            title: 'movie.mp4',
            titleTooltip: details,
            themeMode: ThemeMode.system,
            onOpenFile: () {},
            onThemeModeChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('movie.mp4'), findsOneWidget);
    expect(find.text(details), findsNothing);
    Focus.of(tester.element(find.text('movie.mp4'))).requestFocus();
    await tester.pumpAndSettle();
    expect(find.text(details), findsOneWidget);
  });

  testWidgets('window controls keep matching targets at common scale factors', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    for (final dpr in [1.0, 1.25, 1.5, 2.0]) {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = Size(1280 * dpr, 800 * dpr);
      await tester.pumpWidget(
        MaterialApp(
          theme: VpflTheme.light,
          home: Scaffold(
            body: AppTopBar(
              title: 'movie.mp4',
              themeMode: ThemeMode.system,
              onOpenFile: () {},
              onThemeModeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      for (final label in [
        'Minimize window',
        'Maximize window',
        'Close window',
      ]) {
        expect(tester.getSize(find.byTooltip(label)), const Size(40, 40));
      }
    }
  });
}
