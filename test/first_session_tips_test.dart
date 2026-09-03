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

  test('GOLD and APEX tips name live POWER tabs', () {
    final gold = FirstSessionTips.tips.firstWhere((t) => t.id == 'forge');
    expect(gold.body, contains('POWER → Gold'));
    expect(gold.body, contains('their own POWER tabs'));
    expect(gold.body.toLowerCase(), isNot(contains('relics for party')));
    final apex = FirstSessionTips.tips.firstWhere((t) => t.id == 'apex');
    expect(apex.title, 'APEX');
    expect(apex.body, contains('POWER → Craft'));
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
