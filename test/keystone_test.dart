import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/keystone.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  test('affixes stack by key level and week', () {
    final low = Keystone.affixesFor(
      key: 2,
      weeklyModifier: 'glass',
      weeklyKey: '2026-W32',
    );
    expect(low, contains('glass'));
    expect(low, isNot(contains('fortified')));
    expect(low, isNot(contains('tyrannical')));

    final mid = Keystone.affixesFor(
      key: 4,
      weeklyModifier: 'swarm',
      weeklyKey: '2026-W32',
    );
    expect(mid, contains('swarm'));
    expect(
      mid.any((a) => a == 'fortified' || a == 'tyrannical'),
      isTrue,
    );

    final high = Keystone.affixesFor(
      key: 12,
      weeklyModifier: 'elite',
      weeklyKey: '2026-W33',
      personalNoFlask: true,
    );
    expect(high, contains('no_flask'));
    expect(high, contains('boss_rush'));
  });

  test('KEY loot iLvl bonus is a visible jump, not a crumb', () {
    expect(Keystone.lootItemLevelBonus(0), 0);
    expect(Keystone.lootItemLevelBonus(1), 2);
    expect(Keystone.lootItemLevelBonus(10), 20);
    expect(Keystone.lootItemLevelBonus(20), 40);
  });

  test('enter dungeon locks keystone run; leave clears it', () {
    final base = GameLogic.createInitialState().copyWith(hardmodeLevel: 3);
    final entered = GameLogic.enterDungeon(base, dungeonId: 'sandy');
    expect(entered.keystoneRunActive, isTrue);
    expect(entered.keystoneRunLevel, 3);
    expect(entered.keystoneParMs, greaterThan(0));
    expect(entered.keystoneRunAffixes, isNotEmpty);

    final left = GameLogic.leaveDungeon(entered);
    expect(left.keystoneRunActive, isFalse);
    expect(left.keystoneRunLevel, 0);
    expect(left.hardmodeLevel, 3);
  });

  test('timed boss clear upgrades preferred key and vault score', () {
    var state = GameLogic.createInitialState().copyWith(
      hardmodeLevel: 2,
      dungeonMode: DungeonMode.push,
      metaDepth: const MetaDepthState(
        weeklyKey: '2026-W32',
        weeklyModifier: 'fortune',
        seasonKey: '2026-W32 · 2026-08',
      ),
    );
    state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
    final bossFloor = Keystone.bossFloorForAl(state.ascensionLevel);
    final bossRoom = DungeonRoom(
      floorNumber: bossFloor,
      roomIndex: 0,
      type: RoomType.boss,
      enemyLevel: bossFloor,
      enemyCount: 1,
    );
    state = state.copyWith(
      currentRoom: bossRoom,
      keystoneTimerMs: 1000,
      keystoneParMs: 60 * 1000,
      enemies: const [],
    );
    final beforePref = state.hardmodeLevel;
    final after = GameLogic.completeCurrentRoom(
      state,
      goldGain: 10,
      skipLootRoll: true,
    );
    expect(after.metaDepth.dailyBestTimedKey, greaterThanOrEqualTo(2));
    expect(after.hardmodeLevel, greaterThan(beforePref));
    expect(after.essence, greaterThanOrEqualTo(Keystone.timedClearBonus(2)));
  });

  test('daily vault claim accepts timed key without a clear', () {
    final day = MetaSystems.dailyDateKey(DateTime(2026, 8, 9, 12));
    final state = GameLogic.createInitialState(
      now: DateTime(2026, 8, 9, 12),
    ).copyWith(
      metaDepth: MetaDepthState(
        weeklyKey: '2026-W32',
        weeklyModifier: 'iron',
        seasonKey: '2026-W32 · 2026-08',
        dailyVaultDate: day,
        dailyVaultClears: 0,
        dailyBestTimedKey: 5,
        dailyVaultClaimed: false,
      ),
    );
    expect(GameLogic.canClaimDailyVault(state), isTrue);
    final claimed = GameLogic.claimDailyVault(
      state,
      now: DateTime(2026, 8, 9, 12),
    );
    expect(claimed.metaDepth.dailyVaultClaimed, isTrue);
    expect(
      claimed.essence,
      greaterThanOrEqualTo(Keystone.dailyVaultEssence(5)),
    );
  });

  test('challenge essence uses run level, not hub dial alone', () {
    final hubOnly = GameLogic.createInitialState().copyWith(hardmodeLevel: 5);
    expect(MetaSystems.challengeClearEssenceBonus(hubOnly), 0);

    final inRun = hubOnly.copyWith(
      keystoneRunActive: true,
      keystoneRunLevel: 3, // AL0 cap is KEY +3
    );
    expect(MetaSystems.challengeClearEssenceBonus(inRun), 3);
  });

  test('flasks disabled by no_flask affix on run', () {
    final state = GameLogic.createInitialState().copyWith(
      keystoneRunActive: true,
      keystoneRunLevel: 10,
      keystoneRunAffixes: const ['no_flask'],
    );
    expect(Keystone.flasksDisabled(state), isTrue);
    expect(GameLogic.canUseConsumable(state), isFalse);
  });

  test('legacy hardmodeLevel migrates within new 0–20 clamp', () {
    final json = GameLogic.createInitialState()
        .copyWith(hardmodeLevel: 10)
        .toJson();
    final loaded = GameLogic.stateFromJson(json);
    expect(loaded.hardmodeLevel, 10);
    expect(loaded.keystoneRunActive, isFalse);
  });

  test('stateFromJson re-locks KEY run when dungeon save lacks keystone flag', () {
    final json = GameLogic.createInitialState()
        .copyWith(
          ascensionLevel: 5,
          inDungeon: true,
          hardmodeLevel: 6,
          keystoneRunActive: false,
          keystoneRunLevel: 0,
        )
        .toJson();
    final loaded = GameLogic.stateFromJson(json);
    expect(loaded.keystoneRunActive, isTrue);
    expect(loaded.keystoneRunLevel, 6);
    expect(Keystone.combatLevel(loaded), 6);
  });

  test('ascend keeps high KEY preference up to AL-gated max', () {
    final ready = GameLogic.createInitialState(now: DateTime(2026, 8, 1))
        .copyWith(
          ascensionLevel: 15,
          bossVictories: 16,
          hardmodeLevel: 15,
        );
    expect(GameLogic.canAscend(ready), isTrue);
    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 8, 2));
    expect(ascended.ascensionLevel, 16);
    expect(ascended.effectiveMaxHardmode, 19);
    expect(ascended.hardmodeLevel, 15);
  });

  test('ensureDailyVault migrates legacy weekly progress once', () {
    final now = DateTime.utc(2026, 8, 10, 12);
    final state = GameLogic.createInitialState(now: now).copyWith(
      metaDepth: MetaDepthState(
        weeklyProgress: 1,
        weeklyClaimed: false,
        weeklyBestTimedKey: 3,
        dailyVaultDate: '',
      ),
    );
    final migrated = GameLogic.ensureDailyVault(state, now: now);
    expect(migrated.metaDepth.dailyVaultDate, MetaSystems.dailyDateKey(now));
    expect(migrated.metaDepth.dailyVaultClears, 1);
    expect(migrated.metaDepth.dailyBestTimedKey, 3);
    expect(migrated.metaDepth.dailyVaultClaimed, isFalse);
  });
}
