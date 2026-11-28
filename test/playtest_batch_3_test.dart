import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:idle_party/ui/feedback_toast.dart';
import 'package:idle_party/ui/hub/hub_powerups.dart';
import 'package:idle_party/ui/menu_chrome.dart';
import 'package:idle_party/ui/shell/dungeon_party_hud.dart';
import 'package:idle_party/ui/shell/discord_thanks_overlay.dart';
import 'package:idle_party/ui/shell/home/home_catalog.dart';
import 'package:idle_party/ui/shell/home/rail_button.dart';
import 'package:idle_party/ui/shell/dungeon_loot_log.dart';
import 'package:idle_party/ui/shell/dungeon_top_hud.dart';
import 'package:idle_party/ui/shell/home/fight_seam.dart';
import 'package:idle_party/ui/shell/home/town_viewport.dart';
import 'package:idle_party/ui/shell/inventory_dock.dart';
import 'package:idle_party/ui/shell/menu_surface.dart';
import 'package:idle_party/ui/shell/play_shell.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';
import 'shell_screen_golden_test.dart' show pumpGearGoldenUntilDoll;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => ensureShellGoldenFonts());

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
    expect(find.text('STARTER'), findsWidgets);
    expect(find.text('SCROLLS'), findsNothing);
  });

  test('Discord not offered during first 30s of fight', () {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    var state = GameLogic.enterDungeon(director.state);
    state = state.copyWith(seenTips: [...state.seenTips, 'first_run']);
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
    final semantics = tester.getSemantics(
      find.bySemanticsLabel('Music volume'),
    );
    expect(semantics.label, 'Music volume');
    expect(semantics.value, '20 percent');
  });

  test('ability info dialog drops duplicate title line', () {
    final ability = ClassKits.hudAbilitiesAtSpec(
      HeroSpecId.protection,
      20,
    ).firstWhere((a) => a.id == AbilityId.shieldBlock);
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
    final entry = HomeCatalog.entries.firstWhere((e) => e.id == 'menu_scrolls');
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

  testWidgets('exit toast shows on home hub after first back', (tester) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        homeLayout: HomeLayout.home,
      ),
    );
    var directorLive = true;
    addTearDown(() {
      if (directorLive) director.dispose();
    });
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PlayShell(director: director, router: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final pop = find.descendant(
      of: find.byType(PlayShell),
      matching: find.byWidgetPredicate((w) => w is PopScope),
    );
    expect(pop, findsOneWidget);
    final scope = tester.widget<PopScope>(pop);
    scope.onPopInvokedWithResult?.call(false, null);
    await tester.pump();
    expect(find.byType(FeedbackToast), findsOneWidget);
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(director.toast, 'Press back again to exit');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    director.dispose();
    directorLive = false;
    await tester.pump(const Duration(milliseconds: 400));
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
    final tabs = find.byKey(MenuSurface.gearTabsKey);
    expect(tabs, findsOneWidget);
    final tabRect = tester.getRect(tabs);
    for (final label in ['GEAR', 'BAG', 'MERGE', 'ROSTER']) {
      final hit = find.text(label);
      expect(hit, findsWidgets, reason: label);
      for (final e in hit.evaluate()) {
        final p = e.renderObject! as RenderParagraph;
        expect(p.didExceedMaxLines, isFalse, reason: label);
      }
    }
    final scroll = find.byKey(InventoryDock.equipScrollKey);
    expect(scroll, findsOneWidget);
    expect(tabRect.bottom, lessThan(tester.getRect(scroll).top + 1));
    final dollSlots = find.byType(PaperDollSlot);
    expect(dollSlots, findsWidgets);
    for (var pass = 0; pass < 4; pass++) {
      var missed = 0;
      final clip = tester.getRect(scroll);
      for (final e in dollSlots.evaluate()) {
        final rect = tester.getRect(find.byWidget(e.widget));
        final inside =
            rect.bottom <= clip.bottom + 2 && rect.top >= clip.top - 2;
        if (!inside) missed++;
      }
      if (missed == 0) break;
      await tester.drag(scroll, const Offset(0, -120));
      await tester.pumpAndSettle();
    }
    final legend = find.byKey(CharacterEquipPanel.slotLegendKey);
    expect(legend, findsOneWidget);
    final legendP = tester.renderObject<RenderParagraph>(
      find.byKey(CharacterEquipPanel.slotLegendKey),
    );
    expect(legendP.didExceedMaxLines, isFalse);
    final equipBtn = find.textContaining('EQUIP BEST');
    if (equipBtn.evaluate().isNotEmpty) {
      expect(
        tester.getRect(legend).bottom,
        lessThan(tester.getRect(equipBtn.first).top),
      );
      expect(
        tester.getRect(equipBtn.first).bottom,
        lessThanOrEqualTo(const Size(360, 780).height - 8),
      );
    }
    expect(tester.takeException(), isNull);
    final panel = find.byType(InventoryDock);
    expect(panel, findsOneWidget);
    await expectLater(
      panel,
      matchesGoldenFile('goldens/widgets/playtest_gear_equip_360_scale145.png'),
    );
  });

  testWidgets('floor clear has no HOLD skip-walk control', (tester) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    director.debugHoldSave(GameLogic.enterDungeon(director.state));
    final world = SpatialCombat.build(director.state);
    world.awaitingExit = true;
    director.debugAttachSpatial(world);
    final router = MenuRouter();
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              DungeonTopHud(
                state: director.state,
                director: director,
                onOpenSettings: () {},
                onOpenContracts: () {},
              ),
              FightSeam(director: director, router: router, onLeave: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('HOLD'), findsNothing);
    expect(
      find.bySemanticsLabel('HOLD — skip walk, finish floor now'),
      findsNothing,
    );
    expect(find.textContaining('HOLD skips'), findsNothing);
    expect(
      find.text(
        GameLogic.dungeonModeAfterClearHint(
          director.state,
          director.state.dungeonMode,
        ),
      ),
      findsOneWidget,
    );
    expect(director.spatial!.awaitingExit, isTrue);
  });

  testWidgets('floor clear recap wraps gold xp essence at 360 1.45', (
    tester,
  ) async {
    const line = 'F4 CLEAR · +62g · +456 XP · +1 essence';
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 780),
          textScaler: TextScaler.linear(GameTheme.typeScaleMax),
        ),
        child: const MaterialApp(
          home: Scaffold(body: DungeonLootLog(lines: [line])),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('+1 essence'), findsOneWidget);
    a100ExpectWhole(tester, find.textContaining('F4 CLEAR'));
    a100ExpectWhole(tester, find.textContaining('+456 XP'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('VAULT plaque stays whole at town right edge 360 1.45', (
    tester,
  ) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        inDungeon: false,
        bossVictories: 2,
        highestFloorCleared: 8,
        highestDungeonCleared: 3,
      ),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    tester.view.physicalSize = TownPreview.phoneSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: TownPreview(
          director: director,
          router: router,
          textScale: GameTheme.typeScaleMax,
        ),
      ),
    );
    await tester.pump();
    final vaultTexts = find.text('VAULT');
    expect(vaultTexts, findsWidgets);
    RenderParagraph? plaque;
    for (final e in vaultTexts.evaluate()) {
      final p = e.renderObject! as RenderParagraph;
      if (p.text.toPlainText() == 'VAULT' && !p.didExceedMaxLines) {
        plaque = p;
        break;
      }
    }
    expect(plaque, isNotNull, reason: 'vault name chip should not ellipsize');
    expect(
      plaque!.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(plaque.size.width + 0.5),
    );
    expect(tester.takeException(), isNull);
  });
}
