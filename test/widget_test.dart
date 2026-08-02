import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/main.dart';
import 'package:idle_party/ui/game_theme.dart';

void main() {
  testWidgets('renders the idle party hub', (WidgetTester tester) async {
    final director = GameDirector.preview();

    // Tall phone: short-height collapse is off so ascend progress stays visible.
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(director: director, autoStartLoop: false, showIntro: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('IDLE PARTY'), findsOneWidget);
    expect(find.textContaining('ENTER DUNGEON'), findsOneWidget);
    expect(find.textContaining("Hero's Keep"), findsOneWidget);
    expect(find.textContaining('Sandy Caverns'), findsWidgets);
    expect(find.textContaining('Boss F'), findsWidgets);
    expect(find.textContaining('Boss:'), findsOneWidget);
    expect(find.textContaining('MORE'), findsOneWidget);
    expect(find.textContaining('Bosses'), findsWidgets);
  });

  testWidgets('short hub height hides secondary chrome', (WidgetTester tester) async {
    final director = GameDirector.preview();

    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(director: director, autoStartLoop: false, showIntro: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(GameTheme.isShortHeight(tester.element(find.textContaining('ENTER DUNGEON'))), isTrue);
    expect(find.textContaining('ENTER DUNGEON'), findsOneWidget);
    expect(find.textContaining('MORE'), findsOneWidget);
    expect(find.textContaining('Bosses'), findsNothing);
  });

  testWidgets('entering dungeon shows mobile shell chrome', (WidgetTester tester) async {
    final director = GameDirector.preview();
    await director.boot();
    director.enterDungeon();

    await tester.pumpWidget(MyApp(director: director, autoStartLoop: false, showIntro: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('PUSH'), findsWidgets);
    expect(find.textContaining('BAG'), findsWidgets);
    expect(find.text('GEAR'), findsOneWidget);
    expect(find.text('MORE'), findsWidgets);
    expect(find.textContaining('PROT'), findsWidgets);

    await tester.tap(find.text('GEAR'));
    await tester.pumpAndSettle();
    expect(find.textContaining('GEAR'), findsWidgets);
    expect(find.textContaining('DMG'), findsWidgets);
    expect(find.textContaining('iLvl'), findsWidgets);

    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('BAG').first);
    await tester.pumpAndSettle();
    expect(find.text('BAG'), findsWidgets);
    expect(find.text('TOOLS'), findsOneWidget);

    await tester.tap(find.text('TOOLS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('COMBINATOR'), findsOneWidget);
  });

  testWidgets('compact phone viewport keeps bottom nav usable', (WidgetTester tester) async {
    final director = GameDirector.preview();
    await director.boot();
    director.enterDungeon();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(director: director, autoStartLoop: false, showIntro: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(GameTheme.isCompactWidth(tester.element(find.text('GEAR'))), isTrue);

    await tester.tap(find.text('GEAR'));
    await tester.pumpAndSettle();
    expect(find.textContaining('GEAR'), findsWidgets);

    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('BAG').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('BAG'), findsWidgets);
  });

  testWidgets('wide desktop viewport still opens overlays', (WidgetTester tester) async {
    final director = GameDirector.preview();
    await director.boot();
    director.enterDungeon();

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(director: director, autoStartLoop: false, showIntro: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(GameTheme.isCompactWidth(tester.element(find.text('GEAR'))), isFalse);

    await tester.tap(find.textContaining('BAG').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('BAG'), findsWidgets);
  });
}
