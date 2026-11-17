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

/// Robert's call: ×10 is "up to 10 buys" when the wallet is short, and
/// CAMP MAX buys up to 99 levels per tap. Same per-buy prices as ×1.
Future<void> _close(WidgetTester tester, GameDirector director) async {
  await tester.pumpWidget(const SizedBox.shrink());
  director.dispose();
  await tester.pump();
}

Future<void> _pick(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(BuyQtyToggle), matching: find.text(label)),
  );
  await tester.pump();
}

Future<void> _host(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SizedBox(height: 700, width: 360, child: child)),
    ),
  );
}

void main() {
  testWidgets('FORGE ×10 on a short wallet buys what fits, not zero or ten', (
    tester,
  ) async {
    final seed = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 4)),
    ).copyWith(homeLayout: HomeLayout.home, highestFloorCleared: 2, gold: 0);
    // Wallet for exactly three AP buys at the ×1 price.
    var probe = seed;
    var wallet = 0;
    for (var i = 0; i < 3; i++) {
      final one = GameLogic.previewForgeGoldSpend(
        probe.copyWith(gold: 1 << 40),
        PartyUpgradeType.attack,
        ForgeGoldSpendMode.one,
      );
      wallet += one.spent;
      probe = GameLogic.upgradeWithSpendMode(
        probe.copyWith(gold: one.spent),
        type: PartyUpgradeType.attack,
        mode: ForgeGoldSpendMode.one,
      );
    }
    final start = seed.copyWith(gold: wallet);
    final preview = GameLogic.previewForgeGoldSpend(
      start,
      PartyUpgradeType.attack,
      ForgeGoldSpendMode.x10,
    );
    expect(preview.buys, 3);
    expect(preview.spent, wallet);

    final director = GameDirector.preview(initialState: start);
    await director.boot(deferCombatLoop: true);
    await _host(
      tester,
      ForgeOverlay(director: director, inlineUnderFight: true),
    );
    await tester.pump();
    await _pick(tester, '×10');
    final before = director.state;
    final chip = find.widgetWithText(
      PowerUpgradePriceChip,
      formatGold(preview.spent),
    );
    expect(chip, findsWidgets);
    await tester.tap(chip.first);
    await tester.pump();
    expect(
      GameLogic.forgeTrackTier(director.state, PartyUpgradeType.attack),
      GameLogic.forgeTrackTier(before, PartyUpgradeType.attack) + 3,
    );
    expect(director.state.gold, before.gold - wallet);
    await _close(tester, director);
  });

  Future<GameDirector> pumpCamp(WidgetTester tester, int essence) async {
    final director = GameDirector.preview(
      initialState: GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime(2026, 11, 4)),
      ).copyWith(essence: essence, ascensionLevel: 1, bossVictories: 1),
    );
    await director.boot(deferCombatLoop: true);
    await _host(
      tester,
      SanctuaryOverlay(director: director, inlineUnderFight: true),
    );
    await tester.pump();
    return director;
  }

  Future<void> buyGold(
    WidgetTester tester,
    GameDirector director,
    int expectLevels,
  ) async {
    final cost = GameLogic.sanctuaryBulkCost(
      director.state,
      'gold',
      expectLevels,
    );
    final logic = GameLogic.upgradeSanctuaryBulk(
      director.state,
      'gold',
      maxLevels: expectLevels,
    );
    final before = director.state.sanctuaryGoldLevel;
    final chip = find.widgetWithText(PowerUpgradePriceChip, '$cost essence');
    expect(chip, findsWidgets);
    await tester.tap(chip.first);
    await tester.pump();
    expect(director.state.sanctuaryGoldLevel, before + expectLevels);
    expect(director.state.essence, logic.essence);
  }

  testWidgets('CAMP MAX with a deep wallet buys 99 levels in one tap', (
    tester,
  ) async {
    final director = await pumpCamp(tester, 1 << 40);
    expect(
      GameLogic.sanctuaryBulkAffordableLevels(
        director.state,
        'gold',
        maxLevels: 200,
      ),
      greaterThan(99),
    );
    await _pick(tester, 'MAX');
    await buyGold(tester, director, 99);
    await _close(tester, director);
  });

  testWidgets('CAMP ×10 and MAX on a short wallet buy what fits', (
    tester,
  ) async {
    final seed = GameLogic.createInitialState(
      now: DateTime(2026, 11, 4),
    ).copyWith(ascensionLevel: 1, bossVictories: 1);
    final wallet = GameLogic.sanctuaryBulkCost(seed, 'gold', 4);
    final director = await pumpCamp(tester, wallet);
    expect(
      GameLogic.sanctuaryBulkAffordableLevels(
        director.state,
        'gold',
        maxLevels: 99,
      ),
      4,
    );
    await _pick(tester, '×10');
    await buyGold(tester, director, 4);
    await _close(tester, director);

    final again = await pumpCamp(tester, wallet);
    await _pick(tester, 'MAX');
    await buyGold(tester, again, 4);
    await _close(tester, again);
  });
}
