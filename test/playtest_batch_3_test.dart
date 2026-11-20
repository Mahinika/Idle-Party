import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/reinstall_pouch.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/character_equip_panel.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/hub/hub_powerups.dart';
import 'package:idle_party/ui/menu_chrome.dart';
import 'package:idle_party/ui/shell/dungeon_party_hud.dart';
import 'package:idle_party/ui/shell/discord_thanks_overlay.dart';
import 'package:idle_party/ui/shell/home/home_catalog.dart';
import 'package:idle_party/ui/shell/home/rail_button.dart';
import 'package:idle_party/ui/shell/inventory_dock.dart';

import 'package:idle_party/ui/hero_doll_sprite.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';
import 'shell_screen_golden_test.dart' show pumpGearGoldenUntilDoll;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fold header meets min touch height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuChrome.fold(
            title: 'How sound works',
            children: const [Text('body')],
          ),
        ),
      ),
    );
    await tester.pump();
    final box = tester.getSize(find.byKey(MenuChrome.foldHeaderKey));
    expect(box.height, greaterThanOrEqualTo(GameTheme.minTouch));
  });

  testWidgets('POUCH focus shows pouch header in SCROLLS', (tester) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    director.debugHoldSave(ReinstallPouch.markDue(director.state));
    await tester.pumpWidget(
      MaterialApp(
        home: scrollsSheetForTest(
          director: director,
          focus: PowerupsFocus.pouch,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ScrollsSheet.pouchTitleKey), findsOneWidget);
    expect(find.text('POUCH'), findsOneWidget);
  });

  test('Discord not offered during first 30s of fight', () {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    var state = GameLogic.enterDungeon(director.state);
    state = state.copyWith(
      seenTips: [...state.seenTips, 'first_run'],
    );
    director.debugHoldSave(state);
    final world = SpatialCombat.build(state);
    world.combatElapsed = 5;
    world.awaitingExit = true;
    director.debugAttachSpatial(world);
    expect(DiscordThanksOverlay.shouldOffer(director), isFalse);
    world.combatElapsed = 35;
    final after = DiscordThanksOverlay.shouldOffer(director);
    expect(after, isA<bool>());
  });

  testWidgets('menu slider semantics use label and percent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuChrome.slider(
            label: 'Music volume',
            value: 0.2,
            min: 0,
            max: 1,
            divisions: 10,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Music volume'), findsOneWidget);
    final semantics = tester.getSemantics(find.bySemanticsLabel('Music volume'));
    expect(semantics.label, 'Music volume');
    expect(semantics.value, '20 percent');
  });

  test('ability info dialog drops duplicate title line', () {
    final ability = ClassKits.hudAbilitiesAtSpec(HeroSpecId.protection, 20)
        .firstWhere((a) => a.id == AbilityId.shieldBlock);
    final body = abilityInfoDialogBody(ability);
    expect(body.startsWith('Shield Block'), isFalse);
    expect(body, contains('DR window'));
  });

  testWidgets('MENU SCROLLS uses count pip not glued label', (tester) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    director.debugHoldSave(
      director.state.copyWith(
        bossVictories: 1,
        metaDepth: director.state.metaDepth.copyWith(adTickets: 1),
      ),
    );
    final entry =
        HomeCatalog.entries.firstWhere((e) => e.id == 'menu_scrolls');
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(GameTheme.typeScaleMax),
          ),
          child: Scaffold(
            body: RailButton(
              entry: entry,
              state: director.state,
              director: director,
              router: router,
              compact: true,
              listCard: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(RailButton.countKey), findsOneWidget);
    expect(find.text('SCROLLS 1'), findsNothing);
    expect(find.text('SCROLLS'), findsOneWidget);
  });

  test('PopScope double-back sets exit toast on home hub root', () {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        homeLayout: HomeLayout.home,
      ),
    );
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    final atRoot = !router.isOpen && router.homeDepth == 0;
    final homeDoubleBackExit = director.state.homeLayout == HomeLayout.home &&
        !director.state.inDungeon &&
        atRoot;
    expect(homeDoubleBackExit, isTrue);
    expect(atRoot && !homeDoubleBackExit, isFalse);
    director.showToast('Press back again to exit', life: 2);
    expect(director.toast, 'Press back again to exit');
  });

  a100TestHome('gear doll 360 scale 1.45 slot legend above EQUIP row', (
    tester,
  ) async {
    final (director, router) = await a100Pump(
      tester,
      const Size(360, 780),
      GameTheme.typeScaleMax,
    );
    a100Live = (director, router);
    router.open(MenuRoute.gear, gear: GearPanel.gear);
    await a100Settle(tester);
    await pumpGearGoldenUntilDoll(tester);
    final legend = find.byKey(CharacterEquipPanel.slotLegendKey);
    expect(legend, findsOneWidget);
    final equipBtn = find.textContaining('EQUIP BEST');
    if (equipBtn.evaluate().isNotEmpty) {
      expect(
        tester.getRect(legend).bottom,
        lessThan(tester.getRect(equipBtn.first).top),
      );
    }
    expect(tester.takeException(), isNull);
    final panel = find.byType(InventoryDock);
    expect(panel, findsOneWidget);
    await expectLater(
      panel,
      matchesGoldenFile(
        'goldens/widgets/playtest_gear_equip_360_scale145.png',
      ),
    );
  });
}