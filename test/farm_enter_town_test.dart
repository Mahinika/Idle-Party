import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_dispatcher.dart';
import 'package:idle_party/core/farm_intensity.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/meta/farm_strength_picker.dart';
import 'package:idle_party/ui/shell/home/town_viewport.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// Town ENTER offers FARM strength before the run, so players without the
/// KEY tab (it opens at max party level) can pick 1× / 2× / 4× too.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  const a56 = Size(412, 915);

  ChasePlan planOf(GameDirector d) =>
      ChaseDispatcher.plan(HubChase.forState(d.state), state: d.state);

  /// Startup prompts (welcome back, quiet ping) can open on any state
  /// change; close them so taps reach the town card.
  Future<void> closePrompts(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      if (!nav.canPop()) break;
      nav.pop();
      await a100Settle(t);
    }
  }

  /// Clear the town's other jobs (vault, quests, bag) and startup prompts
  /// so the town button is the plain ENTER.
  Future<void> clearToEnter(WidgetTester t, GameDirector d) async {
    await a100Settle(t);
    d.dismissOfflineSummary();
    d.claimDailyVault();
    for (var k = 0; k < 6; k++) {
      for (final m in d.state.missions.where((m) => m.canClaim).toList()) {
        d.claimMission(m.id, silent: true);
      }
    }
    d.autoEquipBetterGear();
    d.clearToast();
    await a100Settle(t);
    await closePrompts(t);
  }

  Future<GameDirector> earlyTown(WidgetTester t, double scale) async {
    final (d, _) = await a100Pump(
      t,
      a56,
      scale,
      fresh: true,
      inDungeon: false,
      live: true,
      clearedFloors: 2,
    );
    await clearToEnter(t, d);
    expect(planOf(d).op, ChaseOp.enter);
    // Early player: no KEY tab yet, 4× still locked.
    expect(GameLogic.endgameUnlocked(d.state), isFalse);
    expect(FarmIntensity.canPick(d.state, 4), isFalse);
    return d;
  }

  group('showTownFarmPicker', () {
    final base = GameLogic.createInitialState(now: shellGoldenNow);
    const enter = ChasePlan(label: 'ENTER', op: ChaseOp.enter, zoneId: 'x');
    test('hidden before the first cleared floor (first run unchanged)', () {
      expect(base.highestFloorCleared, 0);
      expect(showTownFarmPicker(base, enter), isFalse);
    });
    test('shown on a normal ENTER once a floor is cleared', () {
      expect(
        showTownFarmPicker(base.copyWith(highestFloorCleared: 1), enter),
        isTrue,
      );
    });
    test('hidden for a KEY run (KEY sheet owns that flow)', () {
      final cleared = base.copyWith(highestFloorCleared: 3);
      expect(
        showTownFarmPicker(
          cleared,
          const ChasePlan(op: ChaseOp.enterKey, zoneId: 'x', keyLevel: 1),
        ),
        isFalse,
      );
      expect(
        showTownFarmPicker(cleared.copyWith(hardmodeLevel: 2), enter),
        isFalse,
      );
    });
    test('hidden when the town button does something else', () {
      final cleared = base.copyWith(highestFloorCleared: 3);
      for (final op in [
        ChaseOp.claimVault,
        ChaseOp.claimMissions,
        ChaseOp.navEquipBag,
        ChaseOp.confirmAscend,
      ]) {
        expect(showTownFarmPicker(cleared, ChasePlan(op: op)), isFalse);
      }
    });
  });

  for (final scale in [1.0, 1.45]) {
    a100TestHome('early town @$scale: picker sits right above ENTER', (
      t,
    ) async {
      final d = await earlyTown(t, scale);
      expect(t.takeException(), isNull);
      final picker = find.byKey(FarmStrengthPicker.pickerKey);
      expect(picker, findsOneWidget);
      final enter = find.widgetWithText(GameButton, 'ENTER');
      expect(enter, findsOneWidget);
      expect(t.getRect(picker).bottom, lessThanOrEqualTo(t.getRect(enter).top));
      // Every tier is a full touch target and reads whole.
      for (final m in FarmIntensity.allowed) {
        final tap = find.ancestor(
          of: find.byKey(FarmStrengthPicker.tierKey(m)),
          matching: find.byType(InkWell),
        );
        expect(
          t.getSize(tap.first).height,
          greaterThanOrEqualTo(GameTheme.minTouch - 0.01),
        );
        a100ExpectWhole(t, find.text('$m×'));
      }
      // Locked 4×: padlock on the tile and its unlock rule under the row.
      expect(
        find.descendant(
          of: find.byKey(FarmStrengthPicker.tierKey(4)),
          matching: find.byType(PixelPadlock),
        ),
        findsOneWidget,
      );
      // Short rule on one line under the row; the full rule is in the
      // tile's semantics and the toast.
      expect(
        find.text(FarmStrengthPicker.compactUnlockLine(d.state, 4)),
        findsOneWidget,
      );
      a100ExpectWhole(
        t,
        find.text(FarmStrengthPicker.compactUnlockLine(d.state, 4)),
      );
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(FarmStrengthPicker.unlockLine(d.state, 4))),
        ),
        findsWidgets,
      );
      a100ExpectWhole(t, find.text('ENTER'));
    });
  }

  a100TestHome('last pick is the default: one tap on ENTER keeps it', (
    t,
  ) async {
    final d = await earlyTown(t, 1);
    await t.tap(find.byKey(FarmStrengthPicker.tierKey(2)));
    await a100Settle(t);
    await closePrompts(t);
    expect(d.state.metaDepth.farmIntensity, 2);
    // A locked tier explains itself and changes nothing.
    await t.tap(find.byKey(FarmStrengthPicker.tierKey(4)));
    await a100Settle(t);
    await closePrompts(t);
    expect(d.state.metaDepth.farmIntensity, 2);
    expect(FarmStrengthPicker.pickedMult(d.state), 2);
    await t.tap(find.widgetWithText(GameButton, 'ENTER'));
    await a100Settle(t);
    expect(d.state.inDungeon, isTrue);
    expect(d.state.metaDepth.farmIntensity, 2);
  });

  a100TestHome('KEY tab unlocked with a KEY dialled: no town picker', (
    t,
  ) async {
    final (d, _) = await a100Pump(
      t,
      a56,
      1,
      maxed: true,
      inDungeon: false,
      live: true,
      clearedFloors: 4,
    );
    await clearToEnter(t, d);
    expect(GameLogic.endgameUnlocked(d.state), isTrue);
    expect(planOf(d).op, ChaseOp.enterKey);
    expect(find.byKey(FarmStrengthPicker.pickerKey), findsNothing);
  });
}
