import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/ui/app.dart';

void main() {
  testWidgets('sidebar navigates between the main sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const VpflApp(initialMediaUri: null, startupError: null),
    );

    expect(find.text('Recent videos'), findsOneWidget);

    await tester.tap(find.byTooltip('All Videos'));
    await tester.pumpAndSettle();
    expect(
      find.text('Videos from your saved folders will appear here.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Folders'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Folder access and video indexing are coming in the library phase.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('appearance setting changes between system and dark theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const VpflApp(initialMediaUri: null, startupError: null),
    );
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
  });
}
