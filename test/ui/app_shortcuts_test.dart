import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/ui/core/widgets/app_shortcuts.dart';

void main() {
  for (final key in [
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
  ]) {
    testWidgets('focused controls activate once per $key press', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          shortcuts: appShortcutBindings(),
          home: Scaffold(
            body: TextButton(
              autofocus: true,
              onPressed: () => calls++,
              child: const Text('Toggle'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(key);
      expect(calls, 1);
      for (var repeat = 0; repeat < 5; repeat++) {
        await tester.sendKeyRepeatEvent(key);
      }
      await tester.sendKeyUpEvent(key);
      expect(calls, 1);
      await tester.sendKeyEvent(key);
      expect(calls, 2);
    });
  }
  testWidgets('Tab traversal and text editing still work', (tester) async {
    final first = FocusNode();
    final second = FocusNode();
    final controller = TextEditingController(text: 'abcd');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        shortcuts: appShortcutBindings(),
        home: Scaffold(
          body: Column(
            children: [
              TextButton(
                autofocus: true,
                focusNode: first,
                onPressed: () {},
                child: const Text('First'),
              ),
              TextField(focusNode: second, controller: controller),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(first.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(second.hasPrimaryFocus, isTrue);
    controller.selection = const TextSelection.collapsed(offset: 4);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    expect(controller.selection.baseOffset, 2);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(first.hasPrimaryFocus, isTrue);
  });

  testWidgets('held Escape dismisses only the top dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        shortcuts: appShortcutBindings(),
        home: const Scaffold(body: Text('Home')),
      ),
    );
    final context = tester.element(find.text('Home'));
    final lower = showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: Text('Lower')),
    );
    await tester.pumpAndSettle();
    final upper = showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: Text('Upper')),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await upper;
    for (var repeat = 0; repeat < 3; repeat++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    expect(find.text('Lower'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await lower;
    expect(find.byType(AlertDialog), findsNothing);
  });
}
