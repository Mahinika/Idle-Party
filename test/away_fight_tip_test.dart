import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/away_fight_tip.dart';
import 'package:idle_party/core/game_guides.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  final now = DateTime.utc(2026, 10, 7, 12);

  test('new save does not show the away line', () {
    final state = GameLogic.createInitialState(now: now);
    expect(AwayFightTip.shouldShow(state, bossStairs: false), isFalse);
    expect(AwayFightTip.shouldShow(state, bossStairs: true), isTrue);
  });

  test('after the first boss the hub shows the line once', () {
    final fresh = GameLogic.createInitialState(now: now);
    final hub = fresh.copyWith(bossVictories: 1);
    expect(AwayFightTip.shouldShow(hub, bossStairs: false), isTrue);
    expect(AwayFightTip.line.toLowerCase(), contains('close the app'));
    expect(AwayFightTip.line.toLowerCase(), contains('keeps fighting'));

    final seen = AwayFightTip.markSeen(hub);
    expect(AwayFightTip.shouldShow(seen, bossStairs: false), isFalse);
    expect(AwayFightTip.shouldShow(seen, bossStairs: true), isFalse);

    final round = MetaDepthState.fromJson(seen.metaDepth.toJson());
    expect(round.awayFightTipSeen, isTrue);
    expect(MetaDepthState.fromJson(const {}).awayFightTipSeen, isFalse);
  });

  test('ascend keeps the away line as seen', () {
    final fresh = GameLogic.createInitialState(now: now);
    final seen = fresh.copyWith(
      bossVictories: 1,
      essence: 40,
      metaDepth: fresh.metaDepth.copyWith(awayFightTipSeen: true),
    );
    final ascended = GameLogic.ascend(seen, now: now.add(const Duration(days: 1)));
    expect(ascended.metaDepth.awayFightTipSeen, isTrue);
    expect(ascended.ascensionLevel, 1);
  });

  test('first hour guide says the party keeps fighting', () {
    final state = GameLogic.createInitialState(now: now);
    expect(GameGuides.firstHourTopicIds, contains('away'));
    final away = GameGuides.topicsFor(state).firstWhere((t) => t.id == 'away');
    expect(away.body.toLowerCase(), contains('close the app'));
    expect(away.body.toLowerCase(), contains('keep fighting'));
    expect(away.body.toLowerCase(), contains('gold'));
    expect(away.body.toUpperCase(), isNot(contains('ESSENCE')));
  });
}
