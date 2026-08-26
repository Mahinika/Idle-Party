import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/market_listings_service.dart';
import 'package:idle_party/core/wipe_advice.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/loot.dart';

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

  test('FORGE tip after two wipes; floor gap on first wipe', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      highestFloorCleared: 2,
      currentRoom: state.currentRoom.copyWith(floorNumber: 6),
    );
    const farFight = WipeFightSnapshot(
      waveHp: 5000,
      remainingHp: 3000,
      damageDealt: 800,
      damageTaken: 400,
      partyMaxHp: 400,
      elapsedSec: 12,
    );
    state = GameLogic.notePartyWipe(state, farFight);
    expect(state.wipeStreakCount, 1);
    expect(state.wipeAdviceLine, 'This floor is too far — retry a lower floor');

    state = GameLogic.createInitialState(now: now);
    state = GameLogic.notePartyWipe(state, atkLack());
    expect(state.wipeStreakCount, 1);
    expect(state.wipeAdviceLine, '');
    state = GameLogic.notePartyWipe(state, atkLack());
    expect(state.wipeStreakCount, 2);
    expect(state.wipeAdviceLine, 'Upgrade ATK in FORGE');
  });

  test('melted pack points at DEF on first wipe', () {
    const fight = WipeFightSnapshot(
      waveHp: 8000,
      remainingHp: 6000,
      damageDealt: 400,
      damageTaken: 900,
      partyMaxHp: 400,
      elapsedSec: 4,
    );
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.notePartyWipe(state, fight);
    expect(state.wipeAdviceLine, 'Upgrade DEF in FORGE');
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
    state = state.copyWith(highestFloorCleared: 8);
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

  test('clearing a lower floor after push retreat keeps the wall streak', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      highestFloorCleared: 4,
      currentRoom: state.currentRoom.copyWith(floorNumber: 5),
      dungeonMode: DungeonMode.push,
    );
    state = GameLogic.notePartyWipe(state, atkLack());
    expect(state.wipeStreakKey, 'sandy:5');
    expect(state.wipeStreakCount, 1);

    // Simulate clearing F4 after retreat — meta progress uses pre-clear floor.
    final beforeClear = state.copyWith(
      currentRoom: state.currentRoom.copyWith(floorNumber: 4),
    );
    final afterClear = beforeClear.copyWith(
      highestFloorCleared: 4,
      wipeStreakKey: beforeClear.wipeStreakKey,
      wipeStreakCount: beforeClear.wipeStreakCount,
    );
    // Same rule as _applyMetaProgress: only clear when streak key matches.
    final kept = beforeClear.wipeStreakKey.isEmpty ||
            beforeClear.wipeStreakKey == GameLogic.wipeFloorKey(beforeClear)
        ? GameLogic.clearWipeStreak(afterClear)
        : afterClear;
    expect(kept.wipeStreakKey, 'sandy:5');
    expect(kept.wipeStreakCount, 1);

    kept.copyWith(
      currentRoom: kept.currentRoom.copyWith(floorNumber: 5),
    );
    var again = GameLogic.notePartyWipe(
      kept.copyWith(currentRoom: kept.currentRoom.copyWith(floorNumber: 5)),
      atkLack(),
    );
    expect(again.wipeStreakCount, 2);
  });

  test('bag upgrades beat forge tips', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      gearStash: [
        EquipmentItem(
          id: 'up_atk',
          name: 'Test Blade',
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.epic,
          attackBonus: 40,
          strengthBonus: 30,
          itemLevel: 90,
        ),
      ],
    );
    expect(
      WipeAdvice.lineFor(state: state, fight: atkLack()),
      contains('Equip better'),
    );
    expect(
      WipeAdvice.lineFor(state: state, fight: atkLack()),
      contains('PARTY'),
    );
  });

  test('PARTY tabs for AL20 veteran include ROSTER not dead loadouts', () {
    final veteran = GameLogic.createInitialState(now: now).copyWith(
      ascensionLevel: 20,
      highestDungeonCleared: 14,
    );
    expect(MenuTabs.showMerge(veteran), isTrue);
    expect(MenuTabs.showRoster(veteran), isTrue);
    final tabs = MenuRouter.visiblePartyTabs(veteran);
    expect(tabs, contains(PartyTab.roster));
    expect(tabs, contains(PartyTab.merge));
    expect(tabs.length, 4);
  });

  test('forge gap prefers MARKET when listing is affordable', () {
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.enterDungeon(state, dungeonId: 'brass');
    state = GameLogic.ensureMarketListings(
      state.copyWith(
        ascensionLevel: 20,
        gold: 500_000,
        hardmodeLevel: 12,
      ),
      nowMs: 1_750_000_000_000,
    );
    expect(MarketListingsService.hasAffordableUpgradeListing(state), isTrue);
    state = GameLogic.notePartyWipe(state, atkLack());
    state = GameLogic.notePartyWipe(state, atkLack());
    expect(state.wipeAdviceLine, startsWith('MARKET:'));
    expect(state.wipeAdviceLine, contains('g'));
  });

  test('hub hint nudges HUB for gear fixes', () {
    expect(
      WipeAdvice.hubHintFor('POWER → MARKET has an upgrade'),
      contains('HUB'),
    );
    expect(
      WipeAdvice.hubHintFor('Equip the better item in PARTY'),
      contains('HUB'),
    );
  });

  test('God Hand hint after two wipes on same floor', () {
    var state = GameLogic.createInitialState(now: now);
    expect(WipeAdvice.godHandHintFor(state), isNull);
    state = GameLogic.notePartyWipe(state, atkLack());
    state = GameLogic.notePartyWipe(state, atkLack());
    expect(
      WipeAdvice.godHandHintFor(state),
      contains('God Hand'),
    );
  });
}
