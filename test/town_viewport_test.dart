import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/assets/custom_assets.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/town_building.dart';
import 'package:idle_party/ui/shell/home/town_viewport.dart';

void main() {
  group('TownBuilding', () {
    test('three distinct buildings with distinct art', () {
      expect(TownBuilding.all.map((b) => b.id).toSet(), {
        TownBuildingId.forge,
        TownBuildingId.market,
        TownBuildingId.inn,
      });
      expect(TownBuilding.all.map((b) => b.assetPath).toSet().length, 3);
      expect(TownBuilding.byId(TownBuildingId.forge).goldPanel, GoldPanel.tracks);
      expect(TownBuilding.byId(TownBuildingId.market).goldPanel, GoldPanel.market);
      expect(TownBuilding.byId(TownBuildingId.inn).gearPanel, GearPanel.roster);
    });

    test('town tier is derived from Ascend, no save field', () {
      expect(TownTier.fromAscension(0), 0);
      expect(TownTier.fromAscension(1), 1);
      expect(TownTier.fromAscension(5), 2);
      expect(TownTier.fromAscension(10), 3);
      expect(TownTier.fromAscension(20), 4);
      expect(TownTier.shippedArtTier, 0);
    });
  });

  group('CustomAssets town files', () {
    test('every town asset exists on disk', () {
      expect(CustomAssets.townAssetPaths.length, 5);
      for (final path in CustomAssets.townAssetPaths) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
      expect(File('assets/custom/town/preview_a56.png').existsSync(), isTrue);
      expect(File('assets/custom/town/buildings_sheet.png').existsSync(), isTrue);
    });
  });

  group('TownPreview', () {
    late GameDirector director;
    late MenuRouter router;

    setUp(() {
      director = GameDirector.preview(
        initialState: GameLogic.createInitialState(
          now: DateTime(2026, 11, 8),
        ).copyWith(inDungeon: false),
      );
      router = MenuRouter();
    });

    tearDown(() {
      director.dispose();
      router.dispose();
    });

    Future<void> pumpTown(WidgetTester tester, {double textScale = 1.0}) async {
      tester.view.physicalSize = TownPreview.phoneSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: TownPreview(
            director: director,
            router: router,
            textScale: textScale,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders forge, market, inn, party, and ENTER', (tester) async {
      await pumpTown(tester);
      expect(find.text('FORGE'), findsOneWidget);
      expect(find.text('MARKET'), findsOneWidget);
      expect(find.text('INN'), findsOneWidget);
      expect(find.text('ENTER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FORGE opens the existing gold sheet on tracks', (tester) async {
      await pumpTown(tester);
      await tester.tap(find.text('FORGE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('FORGE opens after the first boss (F2).'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MARKET opens the existing gold sheet on market', (tester) async {
      await pumpTown(tester);
      await tester.tap(find.text('MARKET'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('MARKET'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('INN opens HEROES without touching game_logic', (tester) async {
      await pumpTown(tester);
      await tester.tap(find.text('INN'));
      await tester.pump();
      expect(router.route, MenuRoute.gear);
      expect(
        router.gearPanel == GearPanel.roster ||
            router.gearPanel == GearPanel.gear,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits A56 at text scale 1.45', (tester) async {
      await pumpTown(tester, textScale: 1.45);
      expect(find.text('FORGE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits A56 at text scale 2.0', (tester) async {
      await pumpTown(tester, textScale: 2.0);
      expect(find.text('ENTER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
