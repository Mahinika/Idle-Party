import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/main.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/app_bottom_bar.dart';

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
    expect(find.text('ENTER DUNGEON'), findsOneWidget);
    expect(find.textContaining("Hero's Keep"), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Sandy Caverns')), findsWidgets);
    expect(find.textContaining('Boss F'), findsWidgets);
    expect(find.textContaining('Boss:'), findsOneWidget);
    expect(find.text('PARTY'), findsOneWidget);
    expect(find.text('POWER'), findsOneWidget);
    expect(find.textContaining('META'), findsOneWidget);
    expect(find.textContaining('Ascend'), findsWidgets);
    expect(find.textContaining('KEYSTONE'), findsWidgets);
  });

  testWidgets('short hub keeps KEYSTONE and pillars', (WidgetTester tester) async {
    final director = GameDirector.preview();

    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(director: director, autoStartLoop: false, showIntro: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(GameTheme.isShortHeight(tester.element(find.text('ENTER DUNGEON'))), isTrue);
    expect(find.text('ENTER DUNGEON'), findsOneWidget);
    expect(find.textContaining('KEYSTONE'), findsWidgets);
    expect(find.text('PARTY'), findsOneWidget);
    expect(find.text('POWER'), findsOneWidget);
    expect(find.textContaining('META'), findsOneWidget);
    expect(find.textContaining('Bosses'), findsNothing);
  });

  testWidgets('entering dungeon shows mobile shell chrome', (WidgetTester tester) async {
    // Cleared a zone: advanced PARTY tabs (MERGE) are unlocked.
    final director = GameDirector.preview(
      initialState:
          GameLogic.createInitialState().copyWith(highestDungeonCleared: 0),
    );
    await director.boot();
    director.enterDungeon();

    await tester.pumpWidget(MyApp(director: director, autoStartLoop: false, showIntro: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('PUSH'), findsWidgets);
    expect(find.text('PARTY'), findsWidgets);
    expect(find.text('POWER'), findsWidgets);
    expect(find.text('META'), findsWidgets);
    expect(find.text('HUB'), findsOneWidget);
    expect(find.textContaining('PROT'), findsWidgets);

    await tester.tap(find.text('PARTY').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('GEAR'), findsWidgets);
    expect(find.textContaining('DMG'), findsWidgets);
    expect(find.textContaining('iLvl'), findsWidgets);

    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PARTY').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BAG'));
    await tester.pumpAndSettle();
    expect(find.text('BAG'), findsWidgets);
    expect(find.text('MERGE'), findsOneWidget);

    await tester.tap(find.text('MERGE'));
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

    expect(GameTheme.isCompactWidth(tester.element(find.text('PARTY').last)), isTrue);

    await tester.tap(find.text('PARTY').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('GEAR'), findsWidgets);

    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PARTY').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BAG'));
    await tester.pumpAndSettle();
    expect(find.textContaining('BAG'), findsWidgets);
    // First hour: only GEAR / BAG — advanced tabs unlock later.
    expect(find.text('MERGE'), findsNothing);
    expect(find.text('ROSTER'), findsNothing);
  });

  testWidgets('menu badge points at bag upgrades', (WidgetTester tester) async {
    final seeded = GameLogic.createInitialState().copyWith(
      gearStash: const [
        EquipmentItem(
          id: 'badge_up',
          name: 'Test Blade',
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.epic,
          attackBonus: 40,
          strengthBonus: 30,
          itemLevel: 90,
        ),
      ],
    );
    final director = GameDirector.preview(initialState: seeded);
    await director.boot();

    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MyApp(director: director, autoStartLoop: false, showIntro: false),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final upgrades = MenuAlerts.bagUpgradeCount(director.state);
    expect(upgrades, greaterThan(0));
    final partyButton = find.widgetWithText(AppBottomBarItem, 'PARTY');
    expect(partyButton, findsOneWidget);
    expect(
      find.descendant(of: partyButton, matching: find.text('$upgrades')),
      findsOneWidget,
    );

    // Hub keeps ambient animations running, so settle by hand.
    await tester.tap(find.text('PARTY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('EQUIP $upgrades'), findsWidgets);
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

    expect(GameTheme.isCompactWidth(tester.element(find.text('PARTY').last)), isFalse);

    await tester.tap(find.text('PARTY').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BAG'));
    await tester.pumpAndSettle();
    expect(find.textContaining('BAG'), findsWidgets);
  });
}
