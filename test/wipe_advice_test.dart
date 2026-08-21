import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/wipe_advice.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/core/menu_router.dart';

void main() {
  final now = DateTime.utc(2026, 8, 21);

  WipeFightSnapshot atkLack() => const WipeFightSnapshot(
    waveHp: 10000,
    remainingHp: 7000,
    damageDealt: 3000,
    damageTaken: 400,
    partyMaxHp: 400,
    elapsedSec: 20,
  );

  test('no line until three wipes on the same floor', () {
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.notePartyWipe(state, atkLack());
    expect(state.wipeStreakCount, 1);
    expect(state.wipeAdviceLine, '');
    state = GameLogic.notePartyWipe(state, atkLack());
    expect(state.wipeStreakCount, 2);
    expect(state.wipeAdviceLine, '');
    state = GameLogic.notePartyWipe(state, atkLack());
    expect(state.wipeStreakCount, 3);
    expect(state.wipeAdviceLine, 'Upgrade ATK in FORGE');
  });

  test('melted pack points at DEF, not ATK', () {
    const fight = WipeFightSnapshot(
      waveHp: 8000,
      remainingHp: 6000,
      damageDealt: 400,
      damageTaken: 900,
      partyMaxHp: 400,
      elapsedSec: 4,
    );
    final state = GameLogic.createInitialState(now: now);
    expect(
      WipeAdvice.lineFor(state: state, fight: fight),
      'Upgrade DEF in FORGE',
    );
  });

  test('almost-cleared chip death points at STA', () {
    const fight = WipeFightSnapshot(
      waveHp: 1000,
      remainingHp: 180,
      damageDealt: 2000,
      damageTaken: 400,
      partyMaxHp: 400,
      elapsedSec: 20,
    );
    final state = GameLogic.createInitialState(now: now);
    expect(
      WipeAdvice.lineFor(state: state, fight: fight),
      'Upgrade STA in FORGE',
    );
  });

  test('push three floors past clear with leftover HP names a retreat', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      highestFloorCleared: 2,
      currentRoom: state.currentRoom.copyWith(floorNumber: 6),
    );
    const fight = WipeFightSnapshot(
      waveHp: 5000,
      remainingHp: 3000,
      damageDealt: 800,
      damageTaken: 400,
      partyMaxHp: 400,
      elapsedSec: 12,
    );
    expect(
      WipeAdvice.lineFor(state: state, fight: fight),
      'This floor is too far — retry a lower floor',
    );
  });

  test('too little fight data stays quiet', () {
    final state = GameLogic.createInitialState(now: now);
    const fight = WipeFightSnapshot(
      waveHp: 5000,
      remainingHp: 5000,
      damageDealt: 10,
      damageTaken: 10,
      partyMaxHp: 400,
      elapsedSec: 0.8,
    );
    expect(WipeAdvice.lineFor(state: state, fight: fight), isNull);
  });

  test('ambiguous ttk vs ttd stays quiet', () {
    final state = GameLogic.createInitialState(now: now);
    const fight = WipeFightSnapshot(
      waveHp: 1000,
      remainingHp: 400,
      damageDealt: 900,
      damageTaken: 450,
      partyMaxHp: 400,
      elapsedSec: 15,
    );
    expect(WipeAdvice.lineFor(state: state, fight: fight), isNull);
  });

  test('a different floor restarts the streak', () {
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.notePartyWipe(state, atkLack());
    state = GameLogic.notePartyWipe(state, atkLack());
    state = state.copyWith(
      currentRoom: state.currentRoom.copyWith(floorNumber: 3),
    );
    state = GameLogic.notePartyWipe(state, atkLack());
    expect(state.wipeStreakCount, 1);
    expect(state.wipeAdviceLine, '');
  });

  test('floor clear wipes the streak', () {
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.notePartyWipe(state, atkLack());
    state = GameLogic.notePartyWipe(state, atkLack());
    state = GameLogic.notePartyWipe(state, atkLack());
    expect(state.wipeAdviceLine, isNotEmpty);
    state = GameLogic.clearWipeStreak(state);
    expect(state.wipeStreakCount, 0);
    expect(state.wipeAdviceLine, '');
  });

  test('LOADOUTS tab stays off even after Ascend', () {
    final veteran = GameLogic.createInitialState(now: now).copyWith(
      ascensionLevel: 20,
      highestDungeonCleared: 14,
    );
    expect(MenuTabs.showLoadouts(veteran), isFalse);
    expect(
      MenuRouter.visiblePartyTabs(veteran),
      isNot(contains(PartyTab.loadouts)),
    );
  });
}
