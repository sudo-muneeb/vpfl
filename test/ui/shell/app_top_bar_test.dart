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
  var maximized = false;

  setUp(() {
    calls.clear();
    maximized = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'isMaximized' || call.method == 'toggleMaximize'
              ? maximized
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

    await tester.tap(find.byKey(const Key('window-minimize-button')));
    await tester.tap(find.byKey(const Key('window-maximize-button')));
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
      for (final key in [
        'window-minimize-button',
        'window-maximize-button',
        'window-close-button',
      ]) {
        expect(tester.getSize(find.byKey(Key(key))), const Size(32, 32));
      }
    }
  });

  testWidgets('compact top bar keeps the logo and 40 px height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: VpflTheme.dark,
        home: Scaffold(
          body: AppTopBar(
            title: 'movie.mp4',
            themeMode: ThemeMode.dark,
            onOpenFile: () {},
            onThemeModeChanged: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('app-top-bar-surface'))).height,
      40,
    );
    expect(find.text('VPFL'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).semanticLabel, 'VPFL logo');
    expect(find.byTooltip('Open file'), findsOneWidget);
    for (final key in [
      'window-minimize-button',
      'window-maximize-button',
      'window-close-button',
    ]) {
      expect(tester.getSize(find.byKey(Key(key))), const Size(32, 32));
    }
  });

  testWidgets('window glyphs follow actual maximize state and actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: VpflTheme.dark,
        home: const Scaffold(body: WindowControlButtons()),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<WindowControlIcon>(find.byType(WindowControlIcon).at(0))
          .glyph,
      WindowControlGlyph.minimize,
    );
    expect(
      tester
          .widget<WindowControlIcon>(find.byType(WindowControlIcon).at(1))
          .glyph,
      WindowControlGlyph.maximize,
    );
    expect(
      tester
          .widget<WindowControlIcon>(find.byType(WindowControlIcon).at(2))
          .glyph,
      WindowControlGlyph.close,
    );

    await tester.tap(find.byKey(const Key('window-minimize-button')));
    expect(calls, contains('minimize'));
    maximized = true;
    await WindowCommands.isMaximized();
    await tester.pump();
    expect(
      tester
          .widget<WindowControlIcon>(find.byType(WindowControlIcon).at(1))
          .glyph,
      WindowControlGlyph.restore,
    );
    await tester.tap(find.byKey(const Key('window-maximize-button')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, contains('toggleMaximize'));
    await tester.tap(find.byKey(const Key('window-close-button')));
    await tester.pump();
    expect(calls, contains('close'));
  });

  testWidgets('native maximize events update the icon without a resize', (
    tester,
  ) async {
    WindowCommands.installCloseHandler();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WindowControlButtons())),
    );
    await tester.pump();
    expect(find.byKey(const Key('window-maximize-button')), findsOneWidget);

    Future<void> sendState(bool value) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('maximizedChanged', value),
            ),
            null,
          );
      await tester.pump();
    }

    await sendState(true);
    expect(
      tester
          .widget<WindowControlIcon>(find.byType(WindowControlIcon).at(1))
          .glyph,
      WindowControlGlyph.restore,
    );
    await sendState(false);
    expect(
      tester
          .widget<WindowControlIcon>(find.byType(WindowControlIcon).at(1))
          .glyph,
      WindowControlGlyph.maximize,
    );
  });

  testWidgets(
    'all window controls use circular hover targets and compact glyphs',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WindowControlButtons())),
      );
      await tester.pump();
      for (final maximizedState in [false, true]) {
        WindowCommands.maximized.value = maximizedState;
        await tester.pump();
        for (final key in [
          'window-minimize-button',
          'window-maximize-button',
          'window-close-button',
        ]) {
          final target = find.byKey(Key(key));
          expect(
            tester.widget<InkWell>(target).borderRadius,
            BorderRadius.circular(16),
          );
          expect(tester.getSize(target), const Size.square(32));
        }
        for (final label in [
          'Minimize window',
          maximizedState ? 'Restore window' : 'Maximize window',
          'Close window',
        ]) {
          expect(find.bySemanticsLabel(label), findsOneWidget);
        }
        for (var index = 0; index < 3; index++) {
          expect(
            tester.getSize(find.byType(WindowControlIcon).at(index)),
            const Size.square(14),
          );
        }
      }
      for (final label in [
        'Minimize window',
        'Maximize window',
        'Restore window',
        'Close window',
      ]) {
        expect(find.byTooltip(label), findsNothing);
      }
      WindowCommands.maximized.value = false;
      semantics.dispose();
    },
  );
}
