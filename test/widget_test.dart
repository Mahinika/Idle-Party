import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/core/shop_catalog.dart';
import 'package:idle_party/main.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/first_session_tips.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/app_bottom_bar.dart';

/// Floor lights and coach pulses never go idle, so dungeon menus cannot
/// use [WidgetTester.pumpAndSettle].
Future<void> pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Hub cards (thanks / reminders / what's new) sit on a scrim. Dismiss so
/// the bottom bar can be tapped.
Future<void> dismissHubPrompts(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    Finder? target;
    for (final label in ['MAYBE LATER', 'NOT NOW', 'GOT IT']) {
      final found = find.text(label);
      if (found.evaluate().isNotEmpty) {
        target = found;
        break;
      }
    }
    if (target == null) return;
    await tester.tap(target.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

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

    expect(find.text('ENTER DUNGEON'), findsOneWidget);
    expect(find.textContaining('+'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp(r'Sandy Caverns')), findsWidgets);
    expect(find.text('Sandy Caverns'), findsOneWidget);
    expect(find.text('GEAR'), findsOneWidget);
    expect(find.text('GOLD'), findsNothing);
    expect(find.text('SHOP'), findsNothing);
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
    expect(find.text('GOLD'), findsNothing);
    expect(find.text('SHOP'), findsNothing);
    expect(find.text('MORE'), findsOneWidget);
    expect(find.textContaining('Bosses'), findsNothing);
  });

  testWidgets('hub shows ENDGAME tab map after party max unlock', (WidgetTester tester) async {
    final base = GameLogic.createInitialState().copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
      highestDungeonCleared: 14,
      hardmodeLevel: GameLogic.maxAscensionLevel,
      lastDailyDate: '2099-01-01',
      dailyClaimed: true,
      metaDepth: GameLogic.createInitialState().metaDepth.copyWith(
        reviewPrompted: true,
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
    expect(find.text('PATH'), findsOneWidget);
    expect(find.text('ENDGAME'), findsWidgets);

    await dismissHubPrompts(tester);
    await tester.tap(find.text('ENDGAME').first);
    await tester.pump();
    expect(find.textContaining('GR1'), findsWidgets);
    expect(find.textContaining('FARM R'), findsWidgets);
    expect(find.textContaining('GAUNTLET'), findsWidgets);

    await tester.tap(find.text('PATH').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel(RegExp(r'Mothveil Hollow')), findsWidgets);
  });

  testWidgets('entering dungeon shows mobile shell chrome', (WidgetTester tester) async {
    // Cleared a zone: advanced GEAR panels (MERGE) are unlocked.
    final director = GameDirector.preview(
      initialState:
          GameLogic.createInitialState().copyWith(
            highestDungeonCleared: 0,
            highestFloorCleared: 1,
            lifetimeGoldEarned: 100,
            essence: 1,
          ),
    );
    await director.boot();
    director.enterDungeon();

    await tester.pumpWidget(MyApp(director: director, autoStartLoop: false, showIntro: false));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    // Floor art stays on "Loading floor…" in widget tests. The bar is the chrome.
    // Gold and essence stay hidden until the first boss, even after a clear.
    expect(find.text('GEAR'), findsWidgets);
    expect(find.text('MORE'), findsWidgets);
    expect(find.text('GOLD'), findsNothing);
    expect(find.text('ESSENCE'), findsNothing);
    expect(find.text('LEAVE'), findsOneWidget);

    await tester.tap(find.text('GEAR').last);
    await pumpSheet(tester);
    expect(find.textContaining('GEAR'), findsWidgets);
    expect(find.text('HERO STATS'), findsOneWidget);
    expect(find.textContaining('iLvl'), findsWidgets);

    await tester.tap(find.text('CLOSE'));
    await pumpSheet(tester);

    await tester.tap(find.text('GEAR').last);
    await pumpSheet(tester);
    await tester.tap(find.text('BAG'));
    await pumpSheet(tester);
    expect(find.text('BAG'), findsWidgets);
    expect(find.text('MERGE'), findsOneWidget);

    await tester.tap(find.text('MERGE'));
    await pumpSheet(tester);
    expect(find.textContaining('MERGE'), findsWidgets);
  });

  testWidgets('system back closes open menu instead of leaving play', (
    WidgetTester tester,
  ) async {
    final director = GameDirector.preview(
      initialState:
          GameLogic.createInitialState().copyWith(
            highestDungeonCleared: 0,
            highestFloorCleared: 1,
            lifetimeGoldEarned: 100,
            essence: 1,
          ),
    );
    await director.boot();
    director.enterDungeon();

    await tester.pumpWidget(
      MyApp(director: director, autoStartLoop: false, showIntro: false),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('GEAR').last);
    await pumpSheet(tester);
    expect(find.text('CLOSE'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await pumpSheet(tester);
    expect(find.text('CLOSE'), findsNothing);
    expect(find.text('LEAVE'), findsOneWidget);
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
    await pumpSheet(tester);
    expect(find.textContaining('GEAR'), findsWidgets);

    await tester.tap(find.text('CLOSE'));
    await pumpSheet(tester);

    await tester.tap(find.text('GEAR').last);
    await pumpSheet(tester);
    await tester.tap(find.text('BAG'));
    await pumpSheet(tester);
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
    await dismissHubPrompts(tester);

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
    await pumpSheet(tester);
    await tester.tap(find.text('BAG'));
    await pumpSheet(tester);
    expect(find.textContaining('BAG'), findsWidgets);
    // GEAR is doll + OPEN BAG — not a side-by-side bag pane.
    expect(find.text('OPEN BAG'), findsNothing); // BAG tab is open, not GEAR
  });

  testWidgets('GOLD → MARKET opens listings without a dim crash', (tester) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        highestFloorCleared: 1,
        lifetimeGoldEarned: 100,
        gold: 500,
        bossVictories: 1,
      ),
    );
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MyApp(director: director, autoStartLoop: false, showIntro: false),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await dismissHubPrompts(tester);

    await tester.tap(find.text('GOLD').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.textContaining('MARKET'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Flask'), findsWidgets);
    expect(find.textContaining('Upgrades'), findsWidgets);
  });

  testWidgets('SHOP catalog includes forever scrolls and a cheaper bundle', (
    tester,
  ) async {
    expect(
      ShopCatalog.offered.where((e) => e.kind == ShopOfferKind.permScroll).length,
      8,
    );
    expect(ShopCatalog.byId['perm_scrolls_all']!.priceLabel, '\$4.99');
    expect(ShopCatalog.byId['perm_scroll_atk']!.name, 'Forever Scroll of Damage');
  });

  testWidgets('GEAR pauses dungeon combat but not hub', (tester) async {
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

    await dismissHubPrompts(tester);
    await tester.tap(find.text('GEAR').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(director.uiPaused, isFalse);

    await tester.tap(find.text('CLOSE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    director.enterDungeon();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(director.uiPaused, isFalse);

    await tester.tap(find.text('GEAR').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(director.uiPaused, isTrue);

    await tester.tap(find.text('CLOSE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(director.uiPaused, isFalse);
  });
}
