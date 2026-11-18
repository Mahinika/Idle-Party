import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/ui/shell/buy_qty_toggle.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';
import 'package:idle_party/ui/shell/power_upgrade_row.dart';
import 'package:idle_party/ui/shell/sanctuary_overlay.dart';
import 'package:idle_party/ui/shell/shell_common.dart';

/// One ×1 / ×10 / MAX row drives FORGE and CAMP. MAX long-press keeps the
/// 5/25/50/100% wallet slices. The pick is not saved.
Future<void> _close(WidgetTester tester, GameDirector director) async {
  await tester.pumpWidget(const SizedBox.shrink());
  director.dispose();
  await tester.pump();
}

void main() {
  Future<GameDirector> pumpForge(
    WidgetTester tester, {
    int gold = 100000,
  }) async {
    final state =
        GameLogic.enterDungeon(
          GameLogic.createInitialState(now: DateTime(2026, 11, 4)),
        ).copyWith(
          homeLayout: HomeLayout.home,
          homePanelFull: false,
          gold: gold,
          highestFloorCleared: 2,
        );
    final director = GameDirector.preview(initialState: state);
    await director.boot(deferCombatLoop: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            width: 360,
            child: ForgeOverlay(director: director, inlineUnderFight: true),
          ),
        ),
      ),
    );
    await tester.pump();
    return director;
  }

  testWidgets('FORGE starts on ×1 and every button is at least 48x44', (
    tester,
  ) async {
    final director = await pumpForge(tester);
    expect(find.byType(BuyQtyToggle), findsOneWidget);
    final toggle = tester.widget<BuyQtyToggle>(find.byType(BuyQtyToggle));
    expect(toggle.value, BuyQty.one);
    for (final label in ['×1', '×10', 'MAX']) {
      final f = find.descendant(
        of: find.byType(BuyQtyToggle),
        matching: find.text(label),
      );
      expect(f, findsOneWidget, reason: label);
      final box = find.ancestor(of: f, matching: find.byType(InkWell));
      final size = tester.getSize(box.first);
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(44), reason: label);
    }
    await _close(tester, director);
  });

  testWidgets('FORGE ×10 buys ten AP at the ×1 price per buy', (tester) async {
    final director = await pumpForge(tester);
    final before = director.state;
    final preview = GameLogic.previewForgeGoldSpend(
      before,
      PartyUpgradeType.attack,
      ForgeGoldSpendMode.x10,
    );
    expect(preview.buys, 10);
    await tester.tap(
      find.descendant(
        of: find.byType(BuyQtyToggle),
        matching: find.text('×10'),
      ),
    );
    await tester.pump();
    expect(find.text('×10'), findsWidgets);
    final chip = find.widgetWithText(
      PowerUpgradePriceChip,
      formatGold(preview.spent),
    );
    expect(chip, findsWidgets);
    await tester.tap(chip.first);
    await tester.pump();
    expect(
      GameLogic.forgeTrackTier(director.state, PartyUpgradeType.attack),
      GameLogic.forgeTrackTier(before, PartyUpgradeType.attack) + 10,
    );
    expect(director.state.gold, before.gold - preview.spent);
    await _close(tester, director);
  });

  testWidgets('MAX long-press keeps the wallet slices', (tester) async {
    final director = await pumpForge(tester);
    final max = find.descendant(
      of: find.byType(BuyQtyToggle),
      matching: find.text('MAX'),
    );
    await tester.longPress(max);
    await tester.pumpAndSettle();
    // Each slice says what it is worth now: "25% · 3,000g" (audit F025).
    final gold = director.state.gold;
    for (final (slice, pct) in [
      ('5%', 5),
      ('25%', 25),
      ('50%', 50),
      ('100%', 100),
    ]) {
      expect(
        find.text('$slice · ${formatGold((gold * pct) ~/ 100)}'),
        findsOneWidget,
        reason: slice,
      );
    }
    await tester.tap(find.textContaining('25% ·'));
    await tester.pumpAndSettle();
    final toggle = tester.widget<BuyQtyToggle>(find.byType(BuyQtyToggle));
    expect(toggle.value, BuyQty.max);
    expect(toggle.maxLabel, '25%');
    expect(
      find.descendant(
        of: find.byType(BuyQtyToggle),
        matching: find.text('25%'),
      ),
      findsOneWidget,
    );
    await _close(tester, director);
  });

  testWidgets('a fresh FORGE forgets the last pick', (tester) async {
    final first = await pumpForge(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(BuyQtyToggle),
        matching: find.text('×10'),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<BuyQtyToggle>(find.byType(BuyQtyToggle)).value,
      BuyQty.ten,
    );
    await _close(tester, first);
    final second = await pumpForge(tester);
    expect(
      tester.widget<BuyQtyToggle>(find.byType(BuyQtyToggle)).value,
      BuyQty.one,
    );
    await _close(tester, second);
  });

  testWidgets('CAMP ×10 buys ten levels when the wallet covers them', (
    tester,
  ) async {
    final director = GameDirector.preview(
      initialState: GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime(2026, 11, 4)),
      ).copyWith(essence: 100000, ascensionLevel: 1, bossVictories: 1),
    );
    await director.boot(deferCombatLoop: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            width: 360,
            child: SanctuaryOverlay(director: director, inlineUnderFight: true),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(BuyQtyToggle), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(BuyQtyToggle),
        matching: find.text('×10'),
      ),
    );
    await tester.pump();
    final cost = GameLogic.sanctuaryBulkCost(director.state, 'gold', 10);
    expect(
      GameLogic.sanctuaryBulkAffordableLevels(
        director.state,
        'gold',
        maxLevels: 10,
      ),
      10,
    );
    final chip = find.widgetWithText(PowerUpgradePriceChip, '$cost essence');
    expect(chip, findsWidgets);
    final before = director.state.sanctuaryGoldLevel;
    final logic = GameLogic.upgradeSanctuaryBulk(
      director.state,
      'gold',
      maxLevels: 10,
    );
    await tester.tap(chip.first);
    await tester.pump();
    expect(director.state.sanctuaryGoldLevel, before + 10);
    expect(director.state.essence, logic.essence);
    await _close(tester, director);
  });
}
