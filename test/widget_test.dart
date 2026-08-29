import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/main.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/first_session_tips.dart';
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
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('IDLE PARTY'), findsOneWidget);
    expect(find.text('ENTER DUNGEON'), findsOneWidget);
    expect(find.textContaining('The Party · Boss on F'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Sandy Caverns')), findsWidgets);
    expect(find.textContaining('Boss on F'), findsWidgets);
    expect(find.textContaining('Boss:'), findsOneWidget);
    expect(find.text('GEAR'), findsOneWidget);
    expect(find.text('POWER'), findsOneWidget);
    expect(find.text('MORE'), findsOneWidget);
    expect(find.textContaining('Boss 0/1'), findsWidgets);
    // Fresh save: KEY jargon gated — no KEYSTONE strip under ENTER.
    expect(find.textContaining('KEYSTONE'), findsNothing);
  });

  testWidgets('short hub keeps pillars without early KEYSTONE', (WidgetTester tester) async {
    final director = GameDirector.preview();

    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(director: director, autoStartLoop: false, showIntro: false));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(GameTheme.isShortHeight(tester.element(find.text('ENTER DUNGEON'))), isTrue);
    expect(find.text('ENTER DUNGEON'), findsOneWidget);
    expect(find.textContaining('KEYSTONE'), findsNothing);
    expect(find.text('GEAR'), findsOneWidget);
    expect(find.text('POWER'), findsOneWidget);
    expect(find.text('MORE'), findsOneWidget);
    expect(find.textContaining('Bosses'), findsNothing);
  });

  testWidgets('hub shows KEYSTONE after party Lv60 unlock', (WidgetTester tester) async {
    final base = GameLogic.createInitialState().copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
      highestDungeonCleared: 14,
      hardmodeLevel: GameLogic.maxAscensionLevel,
      lastDailyDate: '2099-01-01',
      dailyClaimed: true,
      metaDepth: GameLogic.createInitialState().metaDepth.copyWith(
        dailyVaultClaimed: true,
        gauntletBestFloor: 100,
        claimedGauntletMilestones: const ['f25', 'f50', 'f100'],
        riftBestTier: 20,
        claimedRiftMilestones: const ['r5', 'r10', 'r20'],
      ),
      achievements: [
        for (var i = 0; i < 200; i++) 'ach_$i',
      ],
      lifetimeGoldEarned: 50_000_000,
    );
    final director = GameDirector.preview(
      initialState: base.copyWith(
        heroRoster: [
          for (final h in base.heroRoster)
            h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
        ],
      ),
    );

    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MyApp(director: director, autoStartLoop: false, showIntro: false));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(GameLogic.showKeystoneJargon(director.state), isTrue);
    expect(find.textContaining('KEY DIAL'), findsOneWidget);
    expect(find.textContaining('RIFT'), findsWidgets);
  });

  testWidgets('entering dungeon shows mobile shell chrome', (WidgetTester tester) async {
    // Cleared a zone: advanced GEAR panels (MERGE) are unlocked.
    final director = GameDirector.preview(
      initialState:
          GameLogic.createInitialState().copyWith(highestDungeonCleared: 0),
    );
    await director.boot();
    director.enterDungeon();

    await tester.pumpWidget(MyApp(director: director, autoStartLoop: false, showIntro: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Next'), findsWidgets);
    expect(find.text('GEAR'), findsWidgets);
    expect(find.text('POWER'), findsWidgets);
    expect(find.text('QUESTS'), findsWidgets);
    expect(find.text('LEAVE'), findsOneWidget);
    expect(find.textContaining('Shield'), findsWidgets);

    await tester.tap(find.text('GEAR').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('GEAR'), findsWidgets);
    expect(find.textContaining('DMG'), findsWidgets);
    expect(find.textContaining('iLvl'), findsWidgets);

    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GEAR').last);
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

    expect(GameTheme.isCompactWidth(tester.element(find.text('GEAR').last)), isTrue);

    await tester.tap(find.text('GEAR').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('GEAR'), findsWidgets);

    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GEAR').last);
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
      seenChangelogVersion: MetaSystems.currentVersion,
      seenTips: [
        for (final t in FirstSessionTips.tips) t.id,
        'discord_thanks',
      ],
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
    await tester.pump(const Duration(milliseconds: 500));

    final upgrades = MenuAlerts.bagUpgradeCount(director.state);
    expect(upgrades, greaterThan(0));
    final partyButton = find.widgetWithText(AppBottomBarItem, 'GEAR');
    expect(partyButton, findsOneWidget);
    expect(
      find.descendant(of: partyButton, matching: find.text('$upgrades')),
      findsOneWidget,
    );

    // Hub keeps ambient animations running, so settle by hand.
    await tester.tap(find.bySemanticsLabel('GEAR $upgrades waiting'));
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

    // Phone-only product: menus stay on the phone chrome even in a wide window.
    expect(GameTheme.isPhoneWidth(tester.element(find.text('GEAR').last)), isTrue);

    await tester.tap(find.text('GEAR').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BAG'));
    await tester.pumpAndSettle();
    expect(find.textContaining('BAG'), findsWidgets);
    // GEAR is doll + OPEN BAG — not a side-by-side bag pane.
    expect(find.text('OPEN BAG'), findsNothing); // BAG tab is open, not GEAR
  });

  testWidgets('POWER Shop opens listings without a dim crash', (tester) async {
    final director = GameDirector.preview();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MyApp(director: director, autoStartLoop: false, showIntro: false),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('POWER').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Shop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Buy flask'), findsWidgets);
    expect(find.text('ALL'), findsOneWidget);
  });
}
