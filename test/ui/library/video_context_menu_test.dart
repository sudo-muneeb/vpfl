import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/ui/library/video_context_menu.dart';

void main() {
  testWidgets(
    'right-click offers exactly three actions without opening video',
    (tester) async {
      var opened = 0;
      var details = 0;
      var folders = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VideoContextMenu(
                onOpen: () => opened += 1,
                onShowDetails: () => details += 1,
                onShowContainingFolder: () => folders += 1,
                child: InkWell(
                  onTap: () => opened += 1,
                  child: const SizedBox(width: 200, height: 120),
                ),
              ),
            ),
          ),
        ),
      );

      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.down(tester.getCenter(find.byType(VideoContextMenu)));
      await mouse.up();
      await tester.pumpAndSettle();

      expect(opened, 0);
      expect(find.byType(MenuItemButton), findsNWidgets(3));
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Show details'), findsOneWidget);
      expect(find.text('Show containing folder'), findsOneWidget);

      await tester.tap(find.text('Show details'));
      await tester.pumpAndSettle();
      expect(details, 1);
      expect(opened, 0);
      expect(folders, 0);
      expect(find.byType(MenuItemButton), findsNothing);
    },
  );

  testWidgets('Escape closes a menu and edge opening stays on screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: VideoContextMenu(
              onOpen: () {},
              onShowDetails: () {},
              onShowContainingFolder: () {},
              child: const SizedBox(width: 120, height: 80),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    final card = tester.getRect(find.byType(VideoContextMenu));
    await mouse.down(card.bottomRight - const Offset(4, 4));
    await mouse.up();
    await tester.pumpAndSettle();

    for (final menuItem in tester.widgetList<MenuItemButton>(
      find.byType(MenuItemButton),
    )) {
      final rect = tester.getRect(find.byWidget(menuItem));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(tester.view.physicalSize.width));
      expect(rect.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testWidgets(
    'rapid secondary clicks keep one menu and keyboard activates once',
    (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VideoContextMenu(
                onOpen: () => opened += 1,
                onShowDetails: () {},
                onShowContainingFolder: () {},
                child: const SizedBox(width: 200, height: 120),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      final center = tester.getCenter(find.byType(VideoContextMenu));
      for (var i = 0; i < 3; i++) {
        await mouse.down(center + Offset(i.toDouble(), 0));
        await mouse.up();
        await tester.pump();
        expect(find.byType(MenuItemButton), findsNWidgets(3));
      }
      expect(opened, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.byType(MenuItemButton), findsNothing);
    },
  );

  testWidgets('outside click and disposal remove the menu overlay', (
    tester,
  ) async {
    var backgroundTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            onTap: () => backgroundTaps += 1,
            child: Center(
              child: VideoContextMenu(
                onOpen: () {},
                onShowDetails: () {},
                onShowContainingFolder: () {},
                child: const SizedBox(width: 200, height: 120),
              ),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.down(tester.getCenter(find.byType(VideoContextMenu)));
    await mouse.up();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(backgroundTaps, 0);

    await mouse.down(tester.getCenter(find.byType(VideoContextMenu)));
    await mouse.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(find.byType(MenuItemButton), findsNothing);
  });
}
