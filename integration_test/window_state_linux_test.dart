import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vpfl/ui/core/widgets/app_top_bar.dart';
import 'package:vpfl/ui/core/widgets/window_controls.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['VPFL_TEST_EXTERNAL_MAXIMIZE'] == '1';

  testWidgets('external window-manager maximize and restore update title bar', (
    tester,
  ) async {
    WindowCommands.installCloseHandler();
    await tester.pumpWidget(
      MaterialApp(
        theme: VpflTheme.dark,
        home: Scaffold(
          body: AppTopBar(
            title: '',
            themeMode: ThemeMode.dark,
            onOpenFile: () {},
            onThemeModeChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('window-maximize-button')), findsOneWidget);

    final windows = await Process.run('wmctrl', ['-lp']);
    expect(windows.exitCode, 0, reason: '${windows.stderr}');
    final ownWindow = (windows.stdout as String)
        .split('\n')
        .firstWhere(
          (line) => RegExp('^0x[0-9a-fA-F]+\\s+\\S+\\s+$pid\\s').hasMatch(line),
          orElse: () => '',
        );
    expect(ownWindow, isNotEmpty, reason: '${windows.stdout}');
    final windowId = ownWindow.split(RegExp(r'\s+')).first;

    Future<void> setMaximized(bool value) async {
      final result = await Process.run('wmctrl', [
        '-i',
        '-r',
        windowId,
        '-b',
        '${value ? 'add' : 'remove'},maximized_vert,maximized_horz',
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final glyph = value
          ? WindowControlGlyph.restore
          : WindowControlGlyph.maximize;
      for (var attempt = 0; attempt < 40; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (tester
                .widget<WindowControlIcon>(find.byType(WindowControlIcon).at(1))
                .glyph ==
            glyph) {
          break;
        }
      }
      expect(
        tester
            .widget<WindowControlIcon>(find.byType(WindowControlIcon).at(1))
            .glyph,
        glyph,
      );
      expect(
        await const MethodChannel('com.app.vpfl/window')
            .invokeMethod<bool>('isMaximized'),
        value,
      );
    }

    await setMaximized(true);
    await setMaximized(false);
  }, skip: !enabled);
}
