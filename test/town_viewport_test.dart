import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/assets/custom_assets.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/town_access.dart';
import 'package:idle_party/models/town_building.dart';
import 'package:idle_party/ui/shell/home/town_viewport.dart';

void main() {
  final now = DateTime(2026, 11, 8);

  GameState newTown() =>
      GameLogic.createInitialState(now: now).copyWith(inDungeon: false);

  GameState afterBoss() =>
      newTown().copyWith(bossVictories: 1, highestFloorCleared: 2);

  GameState afterAscend() => afterBoss().copyWith(ascensionLevel: 1);

  GameState vaultReady() {
    final stamp = DateTime.now().toUtc();
    var state = GameLogic.createInitialState(
      now: stamp,
    ).copyWith(inDungeon: false, bossVictories: 1, highestFloorCleared: 2);
    state = GameLogic.ensureWeeklyContract(state, now: stamp);
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
      ),
    );
  }

  group('Town paint token', () {
    test('a gold tick does not change what the square paints', () {
      final s = newTown();
      expect(
        TownPaintToken.of(s.copyWith(gold: s.gold + 40)),
        TownPaintToken.of(s),
      );
      expect(
        TownPaintToken.of(s.copyWith(ascensionLevel: 3)),
        isNot(TownPaintToken.of(s)),
      );
    });
  });

  group('TownBuilding catalog', () {
    test('five distinct jobs with distinct art', () {
      expect(TownBuilding.all.map((b) => b.id).toSet(), {
        TownBuildingId.guild,
        TownBuildingId.forge,
        TownBuildingId.market,
        TownBuildingId.inn,
        TownBuildingId.vault,
      });
      expect(TownBuilding.all.map((b) => b.assetPath(0)).toSet().length, 5);
    });

    test('painted tiers from Ascend, no save field', () {
      expect(TownTier.fromAscension(0), 0);
      expect(TownTier.fromAscension(1), 1);
      expect(TownTier.fromAscension(4), 1);
      expect(TownTier.fromAscension(5), 2);
      expect(TownTier.fromAscension(20), 2);
      expect(TownTier.showPennants(10), isTrue);
      expect(TownTier.showArcade(20), isTrue);
      expect(TownTier.progressLine(0), contains('first Ascend'));
    });
  });

  group('TownAccess', () {
    test('new game locks craft, market, roster, quests, vault claim', () {
      final s = newTown();
      expect(TownAccess.forgeOpen(s), isFalse);
      expect(TownAccess.marketOpen(s), isFalse);
      expect(TownAccess.innOpen(s), isFalse);
      expect(TownAccess.guildOpen(s), isFalse);
      expect(TownAccess.vaultClaimable(s), isFalse);
      expect(TownAccess.lockedCopy(TownBuildingId.forge, s), contains('CRAFT'));
      expect(TownAccess.lockedCopy(TownBuildingId.inn, s), contains('Ascend'));
    });

    test('first boss opens CRAFT, MARKET, QUESTS', () {
      final s = afterBoss();
      expect(TownAccess.forgeOpen(s), isTrue);
      expect(TownAccess.marketOpen(s), isTrue);
      expect(TownAccess.guildOpen(s), isTrue);
      expect(TownAccess.innOpen(s), isFalse);
    });

    test('first Ascend opens roster swaps', () {
      expect(TownAccess.innOpen(afterAscend()), isTrue);
    });
  });

  group('CustomAssets town files', () {
    test('every town asset exists on disk', () {
      expect(CustomAssets.townAssetPaths.length, 33);
      expect(CustomAssets.townAssetPaths, contains(CustomAssets.townPath));
      expect(CustomAssets.townAssetPaths, contains(CustomAssets.townFolk));
      expect(CustomAssets.townAssetPaths, contains(CustomAssets.townTreeRound));
      expect(CustomAssets.townAssetPaths, contains(CustomAssets.townTreeTall));
      expect(CustomAssets.townAssetPaths, contains(CustomAssets.townFlowers));
      expect(CustomAssets.townAssetPaths, contains(CustomAssets.townNameplate));
      expect(CustomAssets.townAssetPaths, contains(CustomAssets.townPennants));
      expect(CustomAssets.townAssetPaths, contains(CustomAssets.townLanterns));
      for (final path in CustomAssets.townAssetPaths) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
      expect(File('assets/custom/town/preview_a56.png').existsSync(), isTrue);
      expect(
        File('assets/custom/town/buildings_sheet.png').existsSync(),
        isTrue,
      );
    });
  });

  group('TownPreview', () {
    late GameDirector director;
    late MenuRouter router;
    var holdDirector = false;

    Future<void> pumpTown(
      WidgetTester tester, {
      double textScale = 1.0,
      Size size = TownPreview.phoneSize,
    }) async {
      holdDirector = true;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: TownPreview(
            director: director,
            router: router,
            textScale: textScale,
            size: size,
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> tapBuilding(WidgetTester tester, TownBuildingId id) async {
      await tester.tap(find.byKey(ValueKey('town-${id.name}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
    }

    tearDown(() {
      if (holdDirector) {
        director.dispose();
        holdDirector = false;
      }
      router.dispose();
    });

    testWidgets('renders guild, forge, market, inn, vault, party, ENTER', (
      tester,
    ) async {
      director = GameDirector.preview(initialState: newTown());
      router = MenuRouter();
      await pumpTown(tester);
      expect(find.text('GUILD'), findsOneWidget);
      expect(find.text('FORGE'), findsOneWidget);
      expect(find.text('MARKET'), findsOneWidget);
      expect(find.text('INN'), findsOneWidget);
      expect(find.text('VAULT'), findsOneWidget);
      expect(find.text('ENTER'), findsOneWidget);
      expect(find.bySemanticsLabel('Party resting in town'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('locked FORGE does not open gold tracks', (tester) async {
      director = GameDirector.preview(initialState: newTown());
      router = MenuRouter();
      await pumpTown(tester);
      await tapBuilding(tester, TownBuildingId.forge);
      expect(router.isOpen, isFalse);
      expect(find.text('CRAFT opens after the first boss.'), findsOneWidget);
      expect(find.text('FORGE opens after the first boss (F2).'), findsNothing);
      await tester.tap(find.text('CLOSE'));
      await tester.pump();
      expect(find.text('CRAFT opens after the first boss.'), findsNothing);
      await tapBuilding(tester, TownBuildingId.forge);
      expect(find.text('CRAFT opens after the first boss.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unlocked FORGE opens CRAFT Apex station', (tester) async {
      director = GameDirector.preview(initialState: afterBoss());
      router = MenuRouter();
      await pumpTown(tester);
      await tapBuilding(tester, TownBuildingId.forge);
      expect(router.route, MenuRoute.more);
      expect(router.moreSection, MoreSection.craft);
      expect(find.text('CRAFT'), findsWidgets);
      expect(find.textContaining('Tap a hero, pick a slot'), findsOneWidget);
      await tester.tap(find.text('CLOSE').first);
      await tester.pump();
      expect(router.isOpen, isFalse);
      await tapBuilding(tester, TownBuildingId.forge);
      expect(router.moreSection, MoreSection.craft);
      expect(tester.takeException(), isNull);
    });

    testWidgets('locked MARKET explains first boss', (tester) async {
      director = GameDirector.preview(initialState: newTown());
      router = MenuRouter();
      await pumpTown(tester);
      await tapBuilding(tester, TownBuildingId.market);
      expect(router.isOpen, isFalse);
      expect(find.text('MARKET opens after the first boss.'), findsOneWidget);
      await tester.tap(find.text('CLOSE'));
      await tester.pump();
      await tapBuilding(tester, TownBuildingId.market);
      expect(find.text('MARKET opens after the first boss.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unlocked MARKET opens listings', (tester) async {
      director = GameDirector.preview(initialState: afterBoss());
      router = MenuRouter();
      await pumpTown(tester);
      await tapBuilding(tester, TownBuildingId.market);
      expect(router.route, MenuRoute.gold);
      expect(router.goldPanel, GoldPanel.market);
      expect(find.text('MARKET'), findsWidgets);
      expect(
        find.text('UPGRADES').evaluate().isNotEmpty ||
            find.textContaining('FLASK').evaluate().isNotEmpty ||
            find.textContaining('listing').evaluate().isNotEmpty,
        isTrue,
      );
      await tester.tap(find.text('CLOSE').first);
      await tester.pump();
      expect(router.isOpen, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('locked INN does not pretend GEAR is composition', (
      tester,
    ) async {
      director = GameDirector.preview(initialState: newTown());
      router = MenuRouter();
      await pumpTown(tester);
      await tapBuilding(tester, TownBuildingId.inn);
      expect(router.isOpen, isFalse);
      expect(router.route, MenuRoute.none);
      expect(
        find.textContaining('Party swaps unlock at first Ascend'),
        findsOneWidget,
      );
      expect(find.text('GEAR'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unlocked INN opens ROSTER composition', (tester) async {
      director = GameDirector.preview(initialState: afterAscend());
      router = MenuRouter();
      await pumpTown(tester);
      await tapBuilding(tester, TownBuildingId.inn);
      expect(router.route, MenuRoute.gear);
      expect(router.gearPanel, GearPanel.roster);
      expect(find.text('ROSTER'), findsWidgets);
      expect(find.textContaining('Pick up to'), findsOneWidget);
      expect(find.text('ACTIVE'), findsWidgets);
      await tester.tap(find.text('CLOSE').first);
      await tester.pump();
      expect(router.isOpen, isFalse);
      await tapBuilding(tester, TownBuildingId.inn);
      expect(router.gearPanel, GearPanel.roster);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unlocked GUILD opens QUESTS board', (tester) async {
      director = GameDirector.preview(initialState: afterBoss());
      router = MenuRouter();
      await pumpTown(tester);
      await tapBuilding(tester, TownBuildingId.guild);
      expect(router.route, MenuRoute.more);
      expect(router.moreSection, MoreSection.quests);
      expect(find.text('QUESTS'), findsWidgets);
      expect(
        find.textContaining('Claim here or in the dungeon'),
        findsOneWidget,
      );
      await tester.tap(find.text('CLOSE').first);
      await tester.pump();
      expect(router.isOpen, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('VAULT claim uses existing daily vault command', (
      tester,
    ) async {
      director = GameDirector.preview(initialState: vaultReady());
      director.debugHoldSave(director.state);
      router = MenuRouter();
      expect(TownAccess.vaultClaimable(director.state), isTrue);
      final essenceBefore = director.state.essence;
      await pumpTown(tester);
      await tapBuilding(tester, TownBuildingId.vault);
      expect(director.state.metaDepth.dailyVaultClaimed, isTrue);
      expect(director.state.essence, greaterThanOrEqualTo(essenceBefore));
      expect(router.isOpen, isFalse);
      await tapBuilding(tester, TownBuildingId.vault);
      expect(find.text('Vault claimed today.'), findsOneWidget);
      director.dispose();
      holdDirector = false;
      expect(tester.takeException(), isNull);
    });

    testWidgets('party stands on the square', (tester) async {
      director = GameDirector.preview(initialState: newTown());
      router = MenuRouter();
      await pumpTown(tester);
      expect(find.bySemanticsLabel('Party resting in town'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits A56 at text scale 1.45', (tester) async {
      director = GameDirector.preview(initialState: afterAscend());
      router = MenuRouter();
      await pumpTown(tester, textScale: 1.45);
      expect(find.text('FORGE'), findsOneWidget);
      expect(find.text('ENTER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits A56 at text scale 2.0', (tester) async {
      director = GameDirector.preview(initialState: afterAscend());
      router = MenuRouter();
      await pumpTown(tester, textScale: 2.0);
      expect(find.text('ENTER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a gold tick keeps the town images', (tester) async {
      director = GameDirector.preview(initialState: newTown());
      router = MenuRouter();
      late void Function() rebuild;
      tester.view.physicalSize = TownPreview.phoneSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      holdDirector = true;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = () => setState(() {});
            return MaterialApp(
              home: TownPreview(director: director, router: router),
            );
          },
        ),
      );
      await tester.pump();
      final scope = find.byKey(const ValueKey('town-paint'));
      List<Element> images() => tester
          .elementList(find.descendant(of: scope, matching: find.byType(Image)))
          .toList();
      bool tier2(Element element) {
        final widget = element.widget;
        return widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.contains('_t2');
      }

      final before = images();
      expect(before, isNotEmpty);
      expect(before.any(tier2), isFalse);
      director.debugSetGold(director.state.gold + 50);
      rebuild();
      await tester.pump();
      final after = images();
      expect(after.length, before.length);
      for (var i = 0; i < before.length; i++) {
        expect(identical(before[i], after[i]), isTrue);
        expect(identical(before[i].widget, after[i].widget), isTrue);
      }
      director.debugHoldSave(director.state.copyWith(ascensionLevel: 5));
      rebuild();
      await tester.pump();
      expect(images().any(tier2), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits short 360x640', (tester) async {
      director = GameDirector.preview(initialState: afterAscend());
      router = MenuRouter();
      await pumpTown(tester, size: TownPreview.shortSize);
      expect(find.text('FORGE'), findsOneWidget);
      expect(find.text('GUILD'), findsOneWidget);
      expect(find.text('ENTER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
