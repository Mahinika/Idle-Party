import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/first_session_tips.dart';

void main() {
  final now = DateTime.utc(2026, 8, 8, 12);

  test('fresh hub tip is one line on ENTER, not a menu dictionary', () {
    final state = GameLogic.createInitialState(now: now);
    expect(
      FirstSessionTips.nextTipId(state, inDungeon: false),
      'first_run',
    );
    final tip = FirstSessionTips.tips.first;
    expect(tip.id, 'first_run');
    expect(tip.title, 'NEXT JOB');
    expect(tip.body, 'They fight on their own.');
    expect(tip.body.toUpperCase(), isNot(contains('TODAY')));
    expect(
      FirstSessionTips.lineFor(state, CoachTarget.enter, inDungeon: false),
      'They fight on their own.',
    );
  });

  test('only six button-anchor tips — no multi-system cards', () {
    final ids = FirstSessionTips.tips.map((t) => t.id).toSet();
    expect(
      ids,
      {'first_run', 'godhand', 'farm_push', 'bag', 'forge', 'sanctuary'},
    );
    expect(ids, isNot(contains('lore_descent')));
    expect(ids, isNot(contains('three_dailies')));
    expect(ids, isNot(contains('al20_endgame')));
    expect(ids, isNot(contains('market')));
    expect(ids, isNot(contains('apex')));
  });

  test('GOLD and ESSENCE lines are one short sentence each', () {
    final gold = FirstSessionTips.tips.firstWhere((t) => t.id == 'forge');
    expect(gold.body, 'Power for this run.');
    final essence =
        FirstSessionTips.tips.firstWhere((t) => t.id == 'sanctuary');
    expect(essence.body, 'Power that stays.');
  });

  test('porch hub does not queue GOLD or ESSENCE before the first floor', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      seenTips: const ['first_run'],
    );
    expect(FirstSessionTips.leftPorch(state), isFalse);
    expect(FirstSessionTips.nextTipId(state, inDungeon: false), isNull);
  });

  test('dungeon first tip is tap the fight, not Repeat/Next', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      inDungeon: true,
      seenTips: const ['first_run'],
    );
    expect(
      FirstSessionTips.nextTipId(state, inDungeon: true),
      'godhand',
    );
    expect(
      FirstSessionTips.lineFor(state, CoachTarget.godhand, inDungeon: true),
      'Tap to smash.',
    );
  });

  test('multi-system tip ids never queue as coach cards', () {
    final base = GameLogic.createInitialState(now: now);
    final state = base.copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
      bossVictories: 99,
      highestFloorCleared: 50,
      lifetimeGoldEarned: 100,
      essence: 5,
      seenTips: const ['first_run', 'godhand', 'farm_push', 'bag', 'forge'],
      heroRoster: [
        for (final h in base.heroRoster) h.copyWith(level: 88, xp: 0),
      ],
    );
    expect(MenuTabs.showCamp(state), isTrue);
    expect(
      FirstSessionTips.nextTipId(state, inDungeon: false),
      'sanctuary',
    );
  });

  test('after a floor, hub does not dump lore cards', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      highestFloorCleared: 1,
      lifetimeGoldEarned: 12,
      seenTips: const ['first_run', 'godhand', 'farm_push'],
    );
    expect(FirstSessionTips.leftPorch(state), isTrue);
    // GOLD unlocks with first reward — one line on the tab, not lore.
    expect(
      FirstSessionTips.nextTipId(state, inDungeon: false),
      'forge',
    );
  });

  test('first-run coach is at most two beats before first reward', () {
    final fresh = GameLogic.createInitialState(now: now);
    expect(FirstSessionTips.earnedFirstReward(fresh), isFalse);
    expect(
      FirstSessionTips.nextTipId(fresh, inDungeon: false),
      'first_run',
    );
    final afterHub = fresh.copyWith(seenTips: const ['first_run']);
    expect(FirstSessionTips.nextTipId(afterHub, inDungeon: false), isNull);
    expect(
      FirstSessionTips.nextTipId(afterHub, inDungeon: true),
      'godhand',
    );
    final both = afterHub.copyWith(seenTips: const ['first_run', 'godhand']);
    expect(FirstSessionTips.nextTipId(both, inDungeon: true), isNull);
    expect(FirstSessionTips.nextTipId(both, inDungeon: false), isNull);
  });

  test('GOLD / ESSENCE wait until after first reward; GEAR needs bag upgrades',
      () {
    final gold = GameLogic.createInitialState(now: now).copyWith(
      lifetimeGoldEarned: 0,
      seenTips: const ['first_run', 'godhand'],
    );
    expect(FirstSessionTips.earnedFirstReward(gold), isFalse);
    for (final id in ['sanctuary', 'forge', 'bag']) {
      expect(
        FirstSessionTips.nextTipId(gold, inDungeon: false),
        isNot(equals(id)),
        reason: '$id must not coach before first reward / upgrades',
      );
    }
    final afterFloor = gold.copyWith(
      highestFloorCleared: 1,
      lifetimeGoldEarned: 20,
      seenTips: const ['first_run', 'godhand', 'farm_push', 'bag'],
    );
    expect(FirstSessionTips.earnedFirstReward(afterFloor), isTrue);
    expect(MenuTabs.showGold(afterFloor), isTrue);
    expect(
      FirstSessionTips.nextTipId(afterFloor, inDungeon: false),
      'forge',
    );
  });

  test('GEAR coach waits for a better bag item', () {
    final base = GameLogic.createInitialState(now: now).copyWith(
      highestFloorCleared: 1,
      lifetimeGoldEarned: 20,
      seenTips: const ['first_run', 'godhand', 'farm_push'],
    );
    expect(FirstSessionTips.nextTipId(base, inDungeon: false), 'forge');
    final withBag = base.copyWith(
      gearStash: [
        EquipmentItem(
          id: 'up_1',
          name: 'Test Blade',
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.epic,
          attackBonus: 40,
          strengthBonus: 30,
          itemLevel: 90,
        ),
      ],
    );
    expect(MenuAlerts.bagUpgradeCount(withBag), greaterThan(0));
    expect(FirstSessionTips.nextTipId(withBag, inDungeon: false), 'bag');
    expect(
      FirstSessionTips.lineFor(withBag, CoachTarget.gear, inDungeon: false),
      'Better gear waiting.',
    );
  });

  test('enter dungeon dismisses the hub job tip', () async {
    final director = GameDirector.preview();
    await director.boot();
    await director.startNewGame(HeroSpecs.starterUnlocked);
    expect(director.state.seenTips, isNot(contains('first_run')));
    director.enterDungeon(dungeonId: 'sandy');
    expect(director.state.seenTips, contains('first_run'));
    expect(
      FirstSessionTips.nextTipId(director.state, inDungeon: true),
      'godhand',
    );
    director.dispose();
  });

  test('Repeat/Next coach after first floor clear', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      inDungeon: true,
      highestFloorCleared: 1,
      seenTips: const ['first_run', 'godhand'],
    );
    expect(
      FirstSessionTips.nextTipId(state, inDungeon: true),
      'farm_push',
    );
    expect(
      FirstSessionTips.lineFor(state, CoachTarget.farmPush, inDungeon: true),
      'Repeat loots. Next goes deeper.',
    );
  });
}
