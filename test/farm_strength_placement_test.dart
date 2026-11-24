import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/farm_intensity.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/meta/challenge_toggles.dart';
import 'package:idle_party/ui/meta/farm_strength_picker.dart';
import 'package:idle_party/ui/shell/home/fight_seam.dart';
import 'package:idle_party/ui/shell/home/upgrade_panel.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// FARM strength (1× / 2× / 4×) moved out of the FORGE panel: picked with
/// the KEY dial before ENTER, shown as "FARM n×" at the fight seam.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  const a56 = Size(412, 915);

  Future<void> dropWelcome(WidgetTester t, GameDirector d) async {
    d.dismissOfflineSummary();
    final wb = find.text('WELCOME BACK');
    if (wb.evaluate().isNotEmpty) {
      Navigator.of(t.element(wb.first)).pop();
      await a100Settle(t);
    }
    // A hub fixture stamped months ago used to open the comeback card, which
    // held this slot. Catch-up now credits the offline cap, under three days,
    // so the one-time ping ask is the card on top of KEY.
    final later = find.text('LATER');
    if (later.evaluate().isNotEmpty) {
      await t.tap(later);
      await a100Settle(t);
    }
  }

  test('copy names the tiers, the payoff and the limits', () {
    expect(
      FarmStrengthPicker.copyLine,
      'FARM strength: 1× / 2× / 4× — stronger packs, more loot. '
      'Only on floors you\'ve cleared, in FARM mode.',
    );
    expect(FarmStrengthPicker.blurb, contains('cleared'));
    expect(FarmStrengthPicker.blurb, contains('FARM mode'));
  });

  // A first-day save with a few floors cleared: only 1× is open. No boot,
  // so away time cannot add floor clears.
  GameDirector lockedDirector() => GameDirector.preview(
    initialState: GameLogic.createInitialState(
      now: shellGoldenNow,
    ).copyWith(highestFloorCleared: 3),
  );

  testWidgets('locked tiers show a padlock and how they unlock', (t) async {
    final d = lockedDirector();
    expect(FarmIntensity.maxUnlocked(d.state), 1);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: d,
            builder: (_, _) => FarmStrengthPicker(director: d),
          ),
        ),
      ),
    );
    // Two locked tiles + two unlock lines.
    expect(find.byType(PixelPadlock), findsNWidgets(4));
    expect(
      find.text('2× unlocks with the daily chase (beat a boss).'),
      findsOneWidget,
    );
    expect(
      find.text(
        '4× unlocks after 20 floor clears '
        '(${d.state.metaDepth.lifetimeFloorClears}/20) or Ascension.',
      ),
      findsOneWidget,
    );
    // Before a run a locked tier does nothing.
    await t.tap(find.byKey(FarmStrengthPicker.tierKey(2)));
    await t.pump();
    expect(d.state.metaDepth.farmIntensity, isNot(2));
    await t.pumpWidget(const SizedBox.shrink());
    d.dispose();
  });

  for (final scale in [1.0, 1.45]) {
    a100TestHome('KEY sheet: FARM strength sits between the dial and ENTER '
        '@$scale', (t) async {
      final (d, r) = await a100Pump(
        t,
        a56,
        scale,
        maxed: true,
        inDungeon: false,
        live: true,
        clearedFloors: 4,
      );
      r.open(MenuRoute.key);
      await a100Settle(t);
      await dropWelcome(t, d);
      expect(t.takeException(), isNull);
      final picker = find.byKey(FarmStrengthPicker.pickerKey);
      expect(picker, findsOneWidget);
      expect(find.text(FarmStrengthPicker.title), findsOneWidget);
      expect(find.text(FarmStrengthPicker.blurb), findsOneWidget);
      final dial = t.getRect(find.byKey(ChallengeToggles.valueKey));
      final enter = t.getRect(find.byKey(ChallengeToggles.enterKey));
      final box = t.getRect(picker);
      expect(box.top, greaterThan(dial.bottom));
      expect(box.bottom, lessThanOrEqualTo(enter.top));
      for (final m in FarmIntensity.allowed) {
        final tier = find.ancestor(
          of: find.byKey(FarmStrengthPicker.tierKey(m)),
          matching: find.byType(InkWell),
        );
        expect(
          t.getSize(tier.first).height,
          greaterThanOrEqualTo(GameTheme.minTouch - 0.01),
        );
      }
      a100ExpectWhole(t, find.text('4×'));
      // Picking works before the run (AL 2 has every tier).
      await t.tap(find.byKey(FarmStrengthPicker.tierKey(4)));
      await a100Settle(t);
      expect(d.state.metaDepth.farmIntensity, 4);
    });
  }

  a100TestHome('FORGE panel no longer carries 1× / 2× / 4×', (t) async {
    final (d, _) = await a100Pump(
      t,
      a56,
      1,
      maxed: true,
      live: true,
      clearedFloors: 4,
    );
    d.setDungeonMode(DungeonMode.farm);
    await a100Settle(t);
    expect(FarmIntensity.applies(d.state), isTrue);
    expect(find.byType(UpgradePanel), findsOneWidget);
    for (final label in ['1×', '2×', '4×']) {
      expect(
        find.descendant(
          of: find.byType(UpgradePanel),
          matching: find.text(label),
        ),
        findsNothing,
      );
    }
    expect(find.byKey(FarmStrengthPicker.pickerKey), findsNothing);
  });

  a100TestHome('seam shows FARM n× in FARM and opens the picker', (t) async {
    final (d, _) = await a100Pump(
      t,
      a56,
      1,
      maxed: true,
      live: true,
      clearedFloors: 4,
    );
    expect(find.byKey(FightFieldControls.farmChipKey), findsNothing);
    d.setDungeonMode(DungeonMode.farm);
    d.setFarmIntensity(2);
    await a100Settle(t);
    final chip = find.byKey(FightFieldControls.farmChipKey);
    expect(chip, findsOneWidget);
    expect(find.text('FARM 2×'), findsOneWidget);
    final tap = find.ancestor(of: chip, matching: find.byType(InkWell));
    expect(
      t.getSize(tap.first).height,
      greaterThanOrEqualTo(GameTheme.minTouch - 0.01),
    );
    await t.tap(chip);
    await a100Settle(t);
    expect(find.byKey(FarmStrengthPicker.pickerKey), findsOneWidget);
    await t.tap(find.byKey(FarmStrengthPicker.tierKey(4)));
    await a100Settle(t);
    expect(d.state.metaDepth.farmIntensity, 4);
    expect(FarmIntensity.effectiveMult(d.state), 4);
    Navigator.of(t.element(find.byKey(FarmStrengthPicker.pickerKey))).pop();
    await a100Settle(t);
    expect(find.text('FARM 4×'), findsOneWidget);
    // PUSH: no FARM strength, no chip.
    d.setDungeonMode(DungeonMode.push);
    await a100Settle(t);
    expect(find.byKey(FightFieldControls.farmChipKey), findsNothing);
  });

  a100TestHome('seam chip fits at 1.45 on a 360 phone', (t) async {
    final (d, _) = await a100Pump(
      t,
      const Size(360, 640),
      1.45,
      maxed: true,
      live: true,
      clearedFloors: 4,
    );
    d.setDungeonMode(DungeonMode.farm);
    await a100Settle(t);
    expect(t.takeException(), isNull);
    a100ExpectWhole(t, find.text('FARM 1×'));
  });
}
