import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/ui/first_session_tips.dart';

void main() {
  final now = DateTime.utc(2026, 8, 8, 12);

  test('fresh hub tip is TODAY chase, not a menu dictionary', () {
    final state = GameLogic.createInitialState(now: now);
    expect(
      FirstSessionTips.nextTipId(state, inDungeon: false),
      'first_run',
    );
    expect(FirstSessionTips.tips.first.title, 'TODAY');
    expect(FirstSessionTips.tips.first.body.toLowerCase(), contains('enter'));
  });

  test('GOLD and APEX tips name live GOLD / MORE paths', () {
    final gold = FirstSessionTips.tips.firstWhere((t) => t.id == 'forge');
    expect(gold.body, contains('GOLD tab'));
    expect(gold.body, contains('row inside MORE'));
    expect(gold.body, contains('ESSENCE → RELICS'));
    expect(gold.body.toLowerCase(), isNot(contains('relics for party')));
    final apex = FirstSessionTips.tips.firstWhere((t) => t.id == 'apex');
    expect(apex.title, 'APEX');
    expect(apex.body, contains('MORE → CRAFT'));
    expect(apex.body.toLowerCase(), isNot(contains('in forge')));
  });

  test('porch hub does not queue SANCTUARY or lore before the first floor', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      seenTips: const ['first_run'],
    );
    expect(FirstSessionTips.leftPorch(state), isFalse);
    expect(FirstSessionTips.nextTipId(state, inDungeon: false), isNull);
  });

  test('dungeon first tips are FARM/PUSH then God Hand', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      inDungeon: true,
      seenTips: const ['first_run'],
    );
    expect(
      FirstSessionTips.nextTipId(state, inDungeon: true),
      'farm_push',
    );
  });

  test('AL20 sub-max shows endgame gate tip before KEY jargon', () {
    final base = GameLogic.createInitialState(now: now);
    final state = base.copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
      bossVictories: 99,
      highestFloorCleared: 50,
      seenTips: [
        for (final t in FirstSessionTips.tips)
          if (t.id != 'al20_endgame') t.id,
      ],
      heroRoster: [
        for (final h in base.heroRoster) h.copyWith(level: 88, xp: 0),
      ],
    );
    expect(GameLogic.isMaxAscension(state), isTrue);
    expect(GameLogic.endgameUnlocked(state), isFalse);
    expect(
      FirstSessionTips.nextTipId(state, inDungeon: false),
      'al20_endgame',
    );
  });

  test('party max level queues ENDGAME ACT map tip', () {
    final base = GameLogic.createInitialState(now: now);
    final state = base.copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
      bossVictories: 99,
      highestFloorCleared: 50,
      seenTips: [
        for (final t in FirstSessionTips.tips)
          if (t.id != 'endgame_act') t.id,
      ],
      heroRoster: [
        for (final h in base.heroRoster) h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
    expect(GameLogic.endgameUnlocked(state), isTrue);
    expect(
      FirstSessionTips.nextTipId(state, inDungeon: false),
      'endgame_act',
    );
    expect(
      FirstSessionTips.tips.firstWhere((t) => t.id == 'endgame_act').body.toLowerCase(),
      contains('tab'),
    );
  });

  test('three dailies tip waits for showDailyChase', () {
    final early = GameLogic.createInitialState(now: now).copyWith(
      seenTips: [
        for (final t in FirstSessionTips.tips)
          if (t.id != 'three_dailies') t.id,
      ],
    );
    expect(GameLogic.showDailyChase(early), isFalse);
    expect(FirstSessionTips.nextTipId(early, inDungeon: false), isNull);

    final afterBoss = early.copyWith(
      bossVictories: 1,
      highestFloorCleared: 1,
    );
    expect(GameLogic.showDailyChase(afterBoss), isTrue);
    expect(
      FirstSessionTips.nextTipId(afterBoss, inDungeon: false),
      'three_dailies',
    );
  });

  test('after a floor, hub can show lore then power tips', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      highestFloorCleared: 1,
      seenTips: const ['first_run', 'godhand', 'farm_push'],
    );
    expect(FirstSessionTips.leftPorch(state), isTrue);
    expect(
      FirstSessionTips.nextTipId(state, inDungeon: false),
      'lore_descent',
    );
  });
}
