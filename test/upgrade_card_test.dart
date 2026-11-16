import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/ui/chunky_face.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';
import 'package:idle_party/ui/shell/power_upgrade_row.dart';
import 'package:idle_party/ui/shell/sanctuary_overlay.dart';
import 'package:idle_party/ui/shell/shell_common.dart';

/// Brick-style upgrade cards: icon tile, "now › next" in green, a gold buy
/// face when the wallet covers it and grey when it does not, and a ×N badge.
void main() {
  GameState forgeState({required int gold}) => GameLogic.enterDungeon(
    GameLogic.createInitialState(now: DateTime(2026, 11, 4)),
  ).copyWith(
    homeLayout: HomeLayout.home,
    homePanelFull: false,
    gold: gold,
    highestFloorCleared: 2,
  );

  Future<GameDirector> pumpForge(WidgetTester tester, GameState state) async {
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            width: 360,
            child: ForgeOverlay(director: director, inlineUnderFight: true),
          ),
        ),
      ),
    );
    await tester.pump();
    return director;
  }

  test('forge gain line reads the sheet now and after the buys', () {
    final state = forgeState(gold: 0).copyWith(attackBonus: 10);
    final one = ForgeOverlay.forgeGainLine(state, PartyUpgradeType.attack);
    expect(one.$1, '+10 AP');
    expect(one.$2, '+${10 + GameLogic.forgeAttackGain}');
    expect(one.$3, isFalse);
    final ten = ForgeOverlay.forgeGainLine(
      state,
      PartyUpgradeType.attack,
      buys: 10,
    );
    expect(ten.$2, '+${10 + GameLogic.forgeAttackGain * 10}');
    final soft = ForgeOverlay.forgeGainLine(
      state.copyWith(critBonus: 30),
      PartyUpgradeType.crit,
    );
    expect(soft.$3, isTrue);
    expect(soft.$1, endsWith('%'));
  });

  testWidgets('an affordable forge row is a gold buy with a ×1 badge', (
    tester,
  ) async {
    final state = forgeState(gold: 5000);
    await pumpForge(tester, state);
    expect(find.byType(UpgradeIconTile), findsWidgets);
    final cost = GameLogic.upgradeCostFor(state, PartyUpgradeType.attack);
    final chip = find.widgetWithText(PowerUpgradePriceChip, formatGold(cost));
    expect(chip, findsWidgets);
    final face = tester.widget<ChunkyFace>(
      find.descendant(of: chip.first, matching: find.byType(ChunkyFace)),
    );
    expect(face.tone, ChunkyTone.gold);
    expect(find.text('×1'), findsWidgets);
    expect(find.textContaining('+0 AP › +2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short wallet paints the buy grey with no badge', (
    tester,
  ) async {
    await pumpForge(tester, forgeState(gold: 0));
    final faces = tester.widgetList<ChunkyFace>(find.byType(ChunkyFace));
    expect(faces, isNotEmpty);
    expect(faces.every((f) => f.tone == ChunkyTone.grey), isTrue);
    expect(find.text('×1'), findsNothing);
    expect(find.textContaining('Need'), findsWidgets);
  });

  testWidgets('the buy face keeps a 76x48 floor', (tester) async {
    await pumpForge(tester, forgeState(gold: 5000));
    final size = tester.getSize(find.byType(ChunkyFace).first);
    expect(size.width, greaterThanOrEqualTo(PowerUpgradePriceChip.minFaceWidth));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('a CAMP row shows level now and the next value in green', (
    tester,
  ) async {
    final director = GameDirector.preview(
      initialState: GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime(2026, 11, 4)),
      ).copyWith(essence: 500, ascensionLevel: 1, bossVictories: 1),
    );
    addTearDown(director.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            width: 360,
            child: SanctuaryOverlay(director: director, inlineUnderFight: true),
          ),
        ),
      ),
    );
    await tester.pump();
    final next = GameLogic.sanctuaryTrackBonusAt('gold', 1);
    expect(find.textContaining('Lv0 · +0% find › +$next%'), findsOneWidget);
    expect(find.text('15 essence'), findsWidgets);
    expect(find.text('×1'), findsWidgets);
  });
}
