import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/core/wipe_advice.dart';
import 'package:idle_party/models/dungeon_mode.dart';

void main() {
  test('canWipeReviveAd allows zone push and gauntlet once per run', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      inDungeon: true,
      dungeonId: 'sandy',
      bossVictories: 1,
    );
    expect(GameLogic.canWipeReviveAd(state), isTrue);

    state = state.copyWith(wipeReviveUsed: true);
    expect(GameLogic.canWipeReviveAd(state), isFalse);

    state = GameLogic.createInitialState().copyWith(
      inDungeon: true,
      inGauntlet: true,
      dungeonId: 'crystal',
    );
    expect(GameLogic.canWipeReviveAd(state), isTrue);
  });

  test('canWipeReviveAd excludes Ranked GR, rift, and daily echo', () {
    var state = GameLogic.createInitialState().copyWith(
      inDungeon: true,
      inGreaterRift: true,
      dungeonId: 'veil',
    );
    expect(GameLogic.canWipeReviveAd(state), isFalse);

    state = GameLogic.createInitialState().copyWith(
      inDungeon: true,
      inRift: true,
      dungeonId: 'storm',
    );
    expect(GameLogic.canWipeReviveAd(state), isFalse);

    final now = DateTime.utc(2026, 11, 1);
    final dayKey = MetaSystems.dailyDateKey(now);
    final day = MetaSystems.parseDailyDateKey(dayKey)!;
    state = GameLogic.createInitialState().copyWith(
      inDungeon: true,
      dungeonId: MetaSystems.dailyDungeonId(day),
      layoutSeed: MetaSystems.dailySeed(day),
      lastDailyDate: dayKey,
    );
    expect(MetaSystems.isActiveDailyRun(state, now: now), isTrue);
    expect(GameLogic.canWipeReviveAd(state), isFalse);
  });

  test('revertLiveWipeStreak undoes notePartyWipe bump', () {
    var state = GameLogic.createInitialState().copyWith(
      inDungeon: true,
      dungeonId: 'sandy',
      bossVictories: 1,
    );
    state = state.copyWith(
      currentRoom: state.currentRoom.copyWith(floorNumber: 4),
    );
    final fight = WipeFightSnapshot(
      waveHp: 1000,
      remainingHp: 800,
      damageDealt: 200,
      damageTaken: 500,
      partyMaxHp: 400,
      elapsedSec: 30,
    );
    state = GameLogic.notePartyWipe(state, fight);
    expect(state.wipeStreakCount, 1);

    state = GameLogic.revertLiveWipeStreak(state);
    expect(state.wipeStreakCount, 0);
    expect(state.wipeStreakKey, '');

    state = GameLogic.notePartyWipe(state, fight);
    state = GameLogic.notePartyWipe(state, fight);
    expect(state.wipeStreakCount, 2);
    state = GameLogic.revertLiveWipeStreak(state);
    expect(state.wipeStreakCount, 1);
  });

  test('leave dungeon clears wipeReviveUsed', () {
    var state = GameLogic.createInitialState().copyWith(
      inDungeon: true,
      dungeonId: 'sandy',
      wipeReviveUsed: true,
      dungeonMode: DungeonMode.push,
    );
    state = GameLogic.leaveDungeon(state);
    expect(state.inDungeon, isFalse);
    expect(state.wipeReviveUsed, isFalse);
  });

  test('wipeReviveUsed round-trips save json', () {
    final raw = GameLogic.createInitialState().copyWith(wipeReviveUsed: true);
    final json = raw.toJson();
    expect(json['wipeReviveUsed'], isTrue);
    final loaded = GameLogic.stateFromJson(json);
    expect(loaded.wipeReviveUsed, isTrue);

    json.remove('wipeReviveUsed');
    final legacy = GameLogic.stateFromJson(json);
    expect(legacy.wipeReviveUsed, isFalse);
  });
}
