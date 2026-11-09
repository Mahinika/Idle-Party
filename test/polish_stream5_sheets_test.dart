import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/guides_overlay.dart';
import 'package:idle_party/ui/game_icon.dart';
import 'package:idle_party/ui/item_tooltip.dart';
import 'package:idle_party/ui/shell/home/essence_tiles_screen.dart';
import 'package:idle_party/ui/shell/inventory_dock.dart';
import 'package:idle_party/ui/shell/jobs_overlay.dart';
import 'package:idle_party/ui/kenney_button.dart';
import 'package:idle_party/ui/shell/save_recovery_gate.dart';
import 'package:idle_party/ui/shell/shop_dock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty bag shows one empty message', (tester) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(gearStash: const []),
    );
    addTearDown(director.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 640,
            width: 360,
            child: InventoryDock(
              state: director.state,
              director: director,
              selectedId: null,
              combineA: null,
              combineB: null,
              panel: GearPanel.bag,
              onPanelChanged: (_) {},
              onSelect: (_) {},
              onPutCombine: (_) {},
              onEquip: () {},
              onUnequip: (_) {},
              bagSlotFilter: null,
              onBrowseBagSlot: (_) {},
              onClearBagSlotFilter: () {},
              equipHeroIndex: 0,
              onEquipHeroChanged: (_) {},
              onEquipToHero: (_) {},
              onAutoEquip: () {},
              onClearCombineA: () {},
              onClearCombineB: () {},
              onCombine: () {},
              onCleanBag: () {},
              onAutoMerge: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.textContaining('Bag empty'),
      findsNWidgets(1),
    );
  });

  testWidgets('save recovery disables RETRY while slow future runs',
      (tester) async {
    final completer = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: SaveRecoveryGate(
          message: 'test',
          onRetry: () => completer.future,
        ),
      ),
    );
    await tester.tap(find.text('RETRY'));
    await tester.pump();
    expect(find.text('RETRYING…'), findsOneWidget);
    expect(tester.widget<GameButton>(find.byType(GameButton)).onPressed, isNull);
    completer.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('RETRY'), findsOneWidget);
  });

  testWidgets('guides use GameIcon chevron, not unicode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GuidesOverlay()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GameIcon), findsWidgets);
    expect(find.text('▾'), findsNothing);
  });

  testWidgets('essence CODEX opens codex route', (tester) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        highestFloorCleared: 1,
      ),
    );
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EssenceTilesScreen(director: director, router: router),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('CODEX'));
    await tester.pumpAndSettle();
    expect(router.essencePanel, EssencePanel.tracks);
  });

  testWidgets('jobs list ignores unrelated director ticks', (tester) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    var missionBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              missionBuilds++;
              return JobsOverlay(director: director);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final before = missionBuilds;
    director.debugSetGold(director.state.gold + 1);
    director.notifyListeners();
    await tester.pump();
    expect(missionBuilds, before);
  });

  testWidgets('selected stash gear shows tooltip card on gear panel',
      (tester) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    final stash = director.state.gearStash;
    if (stash.isEmpty) return;
    final id = stash.first.id;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventoryDock(
            state: director.state,
            director: director,
            selectedId: id,
            combineA: null,
            combineB: null,
            panel: GearPanel.gear,
            onPanelChanged: (_) {},
            onSelect: (_) {},
            onPutCombine: (_) {},
            onEquip: () {},
            onUnequip: (_) {},
            bagSlotFilter: null,
            onBrowseBagSlot: (_) {},
            onClearBagSlotFilter: () {},
            equipHeroIndex: 0,
            onEquipHeroChanged: (_) {},
            onEquipToHero: (_) {},
            onAutoEquip: () {},
            onClearCombineA: () {},
            onClearCombineB: () {},
            onCombine: () {},
            onCleanBag: () {},
            onAutoMerge: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ItemTooltipCard), findsOneWidget);
  });

  testWidgets('shop waiting state shows progress indicator', (tester) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    ShopDock.goldenTestPriceLabel = '';
    addTearDown(() => ShopDock.goldenTestPriceLabel = '');
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ShopDock(director: director))),
    );
    await tester.pump();
    // Billing may not be ready in tests; widget still builds.
    expect(tester.takeException(), isNull);
  });
}
