import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/mission_board.dart';
import 'package:idle_party/core/wipe_advice.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  test('cinder wipe revive spends 15 and requires eligibility', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      inDungeon: true,
      metaDepth: state.metaDepth.copyWith(cinders: 14),
    );
    expect(GameLogic.canWipeReviveWithCinders(state), isFalse);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(cinders: 20),
    );
    expect(GameLogic.canWipeReviveWithCinders(state), isTrue);
    final next = GameLogic.spendCindersForWipeRevive(state);
    expect(next.metaDepth.cinders, 5);
  });

  test('quest reroll fields round-trip json', () {
    final raw = MetaDepthState(
      questRerollUtcDay: '2026-11-01',
      questRerollsToday: 1,
    );
    final json = raw.toJson();
    expect(json['questRerollUtcDay'], '2026-11-01');
    expect(json['questRerollsToday'], 1);
    final loaded = MetaDepthState.fromJson(json);
    expect(loaded.questRerollUtcDay, '2026-11-01');
    expect(loaded.questRerollsToday, 1);
    final legacy = MetaDepthState.fromJson(<String, dynamic>{});
    expect(legacy.questRerollsToday, 0);
  });

  test('quest reroll daily slot resets progress and caps at 2 per day', () {
    final now = DateTime.utc(2026, 11, 1, 12);
    var state = GameLogic.createInitialState(now: now);
    state = MissionBoard.ensureDailyQuest(state, now: now);
    expect(state.missions.length, MissionBoard.boardSize);
    final daily = state.missions[MissionBoard.dailySlot];
    state = state.copyWith(
      missions: [
        for (var i = 0; i < state.missions.length; i++)
          if (i == MissionBoard.dailySlot)
            daily.copyWith(progress: 5)
          else
            state.missions[i],
      ],
    );
    final r1 = MissionBoard.applyQuestReroll(
      state,
      MissionBoard.dailySlot,
      now: now,
    );
    expect(r1.metaDepth.questRerollsToday, 1);
    expect(r1.missions[MissionBoard.dailySlot].progress, 0);
    expect(
      r1.missions[MissionBoard.dailySlot].id,
      isNot(daily.id),
    );
    final r2 = MissionBoard.applyQuestReroll(
      r1,
      MissionBoard.dailySlot,
      now: now,
    );
    expect(r2.metaDepth.questRerollsToday, 2);
    final r3 = MissionBoard.applyQuestReroll(
      r2,
      MissionBoard.dailySlot,
      now: now,
    );
    expect(identical(r3, r2), isTrue);
  });

  test('what killed you breakdown in scan line', () {
    const fight = WipeFightSnapshot(
      waveHp: 1000,
      remainingHp: 0,
      damageDealt: 50,
      damageTaken: 100,
      partyMaxHp: 400,
      elapsedSec: 8,
      meleeTaken: 100,
      rangedOrSpellTaken: 0,
    );
    expect(
      WipeAdvice.scanLine(fight),
      'Pack 0% left · 50 dealt · Taken: 100% melee',
    );
  });
}
