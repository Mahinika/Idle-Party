import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/greater_rift.dart';
import 'package:idle_party/core/loot_pipeline.dart';
import 'package:idle_party/core/play_games_scores.dart';
import 'package:idle_party/core/rift.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/models/stats.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  final now = DateTime.utc(2026, 8, 24);

  test('Greater Rift is harder than farm Rift at same tier', () {
    expect(GreaterRift.killTarget(5), greaterThan(Rift.killTarget(5)));
    expect(GreaterRift.threatMul(10), greaterThan(Rift.threatMul(10)));
    expect(GreaterRift.successEssence(8), greaterThan(Rift.successEssence(8)));
    expect(GreaterRift.parTimeMs(12), lessThan(Rift.parTimeMs(12)));
    expect(GreaterRift.parTimeMs(1), lessThan(Rift.parTimeMs(1)));
    expect(GreaterRift.parTimeMs(20), 90000);
    final grKps = GreaterRift.killTarget(20) /
        (GreaterRift.parTimeMs(20) / 1000);
    final farmKps =
        Rift.killTarget(20) / (Rift.parTimeMs(20) / 1000);
    expect(grKps, greaterThan(farmKps));
  });

  test('Greater Rift enter requires party max level', () {
    final early = GameLogic.createInitialState(now: now);
    expect(GameLogic.canEnterGreaterRift(early), isFalse);
    expect(GameLogic.enterGreaterRift(early).inGreaterRift, isFalse);

    final alOnly = early.copyWith(ascensionLevel: GameLogic.maxAscensionLevel);
    expect(GameLogic.canEnterGreaterRift(alOnly), isFalse);

    final endgame = _withPartyMaxLevel(alOnly);
    expect(GameLogic.canEnterGreaterRift(endgame), isTrue);
    final run = GameLogic.enterGreaterRift(endgame, tier: 1);
    expect(run.inGreaterRift, isTrue);
    expect(run.inRift, isFalse);
    expect(run.grTier, 1);
    expect(run.grKillTarget, GreaterRift.killTarget(1));
    expect(run.dungeonId, GreaterRift.dungeonId);
    expect(run.dungeonId, 'veil');
    expect(run.dungeonId, isNot(Rift.dungeonId));
  });

  test('Greater Rift success updates season PB and best tier', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
      ),
    );
    state = GameLogic.enterGreaterRift(state, tier: 1);
    final goldBefore = state.gold;
    state = GameLogic.noteGreaterRiftKills(state, state.grKillTarget);
    state = GameLogic.maybeActivateGreaterRiftGuardian(state);
    expect(state.grGuardianActive, isTrue);
    state = state.copyWith(
      grTimerMs: state.grParMs - 1_000,
      enemies: const [],
    );
    final resolved = GameLogic.tryResolveGreaterRift(state);
    expect(resolved, isNotNull);
    expect(resolved!.inGreaterRift, isFalse);
    expect(resolved.gold, greaterThan(goldBefore));
    expect(resolved.metaDepth.grBestTier, 1);
    expect(GreaterRift.hubEnterLabel(resolved.metaDepth.grBestTier), 'RANKED GR2');
    expect(resolved.metaDepth.seasonBestGrTier, 1);
    expect(resolved.metaDepth.seasonBestGrClearMs, state.grParMs - 1_000);
    expect(resolved.metaDepth.lifetimeGrClears, 1);
  });

  test('Greater Rift fails when par expires with Guardian alive', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        metaDepth: const MetaDepthState(grBestTier: 3),
      ),
    );
    state = GameLogic.enterGreaterRift(state, tier: 1);
    state = GameLogic.noteGreaterRiftKills(state, state.grKillTarget);
    state = GameLogic.maybeActivateGreaterRiftGuardian(state);
    expect(state.grGuardianActive, isTrue);
    expect(state.enemies, isNotEmpty);
    state = state.copyWith(grTimerMs: state.grParMs + 1);
    final resolved = GameLogic.tryResolveGreaterRift(state);
    expect(resolved, isNotNull);
    expect(resolved!.inGreaterRift, isFalse);
    expect(resolved.metaDepth.grBestTier, 3);
    expect(resolved.metaDepth.lifetimeGrClears, 0);
  });

  test('Greater Rift success counts last hit after par', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        metaDepth: const MetaDepthState(grBestTier: 20),
      ),
    );
    state = GameLogic.enterGreaterRift(state, tier: 21);
    state = GameLogic.noteGreaterRiftKills(state, state.grKillTarget);
    state = GameLogic.maybeActivateGreaterRiftGuardian(state);
    expect(state.grTier, 21);
    expect(state.grGuardianActive, isTrue);
    final dead = state.enemies.first.copyWith(currentHp: 0);
    state = state.copyWith(
      grTimerMs: state.grParMs + 1,
      enemies: [dead],
    );
    final resolved = GameLogic.tryResolveGreaterRift(state);
    expect(resolved, isNotNull);
    expect(resolved!.metaDepth.grBestTier, 21);
    expect(
      GreaterRift.hubEnterLabel(resolved.metaDepth.grBestTier),
      'RANKED GR22',
    );
    expect(resolved.metaDepth.lifetimeGrClears, 1);
  });

  test('Greater Rift success ignores leftover trash', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        metaDepth: const MetaDepthState(grBestTier: 20),
      ),
    );
    state = GameLogic.enterGreaterRift(state, tier: 21);
    state = GameLogic.noteGreaterRiftKills(state, state.grKillTarget);
    state = GameLogic.maybeActivateGreaterRiftGuardian(state);
    final deadGuardian = state.enemies.first.copyWith(currentHp: 0);
    final trash = EnemyUnit(
      name: 'Leftover',
      level: 1,
      currentHp: 40,
      stats: Stats.enemy(attack: 4, defense: 1, maxHp: 40),
      rewardGold: 0,
    );
    state = state.copyWith(
      grTimerMs: state.grParMs - 1_000,
      enemies: [deadGuardian, trash],
    );
    final resolved = GameLogic.tryResolveGreaterRift(state);
    expect(resolved, isNotNull);
    expect(resolved!.metaDepth.grBestTier, 21);
    expect(
      GreaterRift.hubEnterLabel(resolved.metaDepth.grBestTier),
      'RANKED GR22',
    );
  });

  test('Rift Guardian is awake after activate on a GR floor', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
      ),
    );
    state = GameLogic.enterGreaterRift(state, tier: 1);
    state = GameLogic.noteGreaterRiftKills(state, state.grKillTarget);
    state = GameLogic.maybeActivateGreaterRiftGuardian(state);
    expect(state.currentRoom.type, RoomType.boss);
    final world = SpatialCombat.build(state);
    expect(world.enemies, isNotEmpty);
    expect(
      world.enemies.every((e) => e.role != EnemyRole.boss || !e.dormant),
      isTrue,
    );
  });

  test('fast GR clear gifts the skip rank as highest cleared', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
      ),
    );
    state = GameLogic.enterGreaterRift(state, tier: 1);
    state = GameLogic.noteGreaterRiftKills(state, state.grKillTarget);
    state = GameLogic.maybeActivateGreaterRiftGuardian(state);
    state = state.copyWith(grTimerMs: 5_000, enemies: const []);
    final resolved = GameLogic.tryResolveGreaterRift(state)!;
    expect(resolved.metaDepth.grBestTier, 2);
    expect(GreaterRift.hubEnterLabel(resolved.metaDepth.grBestTier), 'RANKED GR3');
    expect(resolved.metaDepth.seasonBestGrTier, 1);
  });

  test('Greater Rift encode prefers higher tier then faster clear', () {
    final low = PlayGamesScores.encodeGreaterRift(tier: 4, clearMs: 1000);
    final high = PlayGamesScores.encodeGreaterRift(tier: 5, clearMs: 900000);
    expect(high, greaterThan(low));
    final slow = PlayGamesScores.encodeGreaterRift(tier: 7, clearMs: 80000);
    final fast = PlayGamesScores.encodeGreaterRift(tier: 7, clearMs: 40000);
    expect(fast, greaterThan(slow));
    expect(
      PlayGamesScores.formatGreaterRiftLabel(7, 40000),
      contains('GR7'),
    );
  });

  test('farm Rift success does not set Greater season PB', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
      ),
    );
    state = GameLogic.enterRift(state, tier: 1);
    state = GameLogic.noteRiftKills(state, state.riftKillTarget);
    state = GameLogic.maybeActivateRiftGuardian(state);
    state = state.copyWith(
      riftTimerMs: 2_000,
      enemies: const [],
    );
    final resolved = GameLogic.tryResolveRift(state)!;
    expect(resolved.metaDepth.seasonBestGrTier, 0);
    expect(resolved.metaDepth.riftBestTier, greaterThan(0));
  });

  test('enter without a tier uses preferred; any tier is open', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        metaDepth: const MetaDepthState(
          grBestTier: 20,
          grPreferredTier: 8,
        ),
      ),
    );
    expect(GreaterRift.maxSelectableTier(20), GreaterRift.maxTier);
    expect(GreaterRift.nextOfferTier(20), 21);
    expect(
      GreaterRift.pickerStart(preferred: 1, bestCleared: 20),
      20,
    );
    expect(
      GreaterRift.pickerStart(preferred: 8, bestCleared: 20),
      8,
    );
    expect(
      GreaterRift.pickerStart(preferred: 21, bestCleared: 20),
      21,
    );
    final farm = GameLogic.enterGreaterRift(state);
    expect(farm.grTier, 8);
    final push = GameLogic.enterGreaterRift(state, tier: 21);
    expect(push.grTier, 21);
    final skip = GameLogic.enterGreaterRift(state, tier: 50);
    expect(skip.grTier, 50);
  });

  test('Ranked GR stays selectable past 20', () {
    expect(GreaterRift.maxSelectableTier(20), GreaterRift.maxTier);
    expect(GreaterRift.killTarget(21), GreaterRift.killTarget(20));
    expect(GreaterRift.parTimeMs(21), GreaterRift.parTimeMs(20));
    expect(GreaterRift.parTimeMs(50), 90000);
    expect(GreaterRift.threatMul(21), greaterThan(GreaterRift.threatMul(20)));
    expect(GreaterRift.threatMul(250) / GreaterRift.threatMul(25), greaterThan(8));
    expect(GreaterRift.densityMul(50), GreaterRift.densityMul(20));
    expect(GreaterRift.successEssence(21), greaterThan(GreaterRift.successEssence(20)));
    double kps(int t) =>
        GreaterRift.killTarget(t) / (GreaterRift.parTimeMs(t) / 1000);
    expect(kps(21), kps(20));
    expect(kps(30), kps(21));
  });

  test('GR250 trash is much tougher than GR25 at the same party', () {
    final room = DungeonRoom(
      floorNumber: 1,
      roomIndex: 0,
      type: RoomType.normal,
      enemyLevel: 100,
      enemyCount: 8,
    );
    var hub = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
      ),
    );
    final low = GameLogic.createEnemyGroup(
      room,
      fromState: hub.copyWith(inGreaterRift: true, grTier: 25),
    );
    final high = GameLogic.createEnemyGroup(
      room,
      fromState: hub.copyWith(inGreaterRift: true, grTier: 250),
    );
    expect(low, isNotEmpty);
    expect(high.length, low.length);
    final lowHp = low.fold<int>(0, (s, e) => s + e.stats.maxHp);
    final highHp = high.fold<int>(0, (s, e) => s + e.stats.maxHp);
    expect(highHp / lowHp, greaterThan(8));
  });

  test('Greater Rift GR25 survives save load', () {
    final now = DateTime.utc(2026, 8, 24);
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        metaDepth: const MetaDepthState(
          grBestTier: 25,
          grPreferredTier: 26,
        ),
      ),
    );
    state = GameLogic.setGrPreferredTier(state, 26);
    expect(state.metaDepth.grPreferredTier, 26);
    final loaded = GameLogic.stateFromJson(state.toJson());
    expect(loaded.metaDepth.grBestTier, 25);
    expect(loaded.metaDepth.grPreferredTier, 26);
    expect(GameLogic.enterGreaterRift(loaded, tier: 26).grTier, 26);
  });

  test('Ranked GR room chests never roll gear', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
      ),
    );
    state = GameLogic.enterGreaterRift(state, tier: 1);
    for (var i = 0; i < 48; i++) {
      final drops = LootPipeline.rollRoomChestLoot(state, random: Random(i));
      expect(
        drops.any((d) => d.isEquipment),
        isFalse,
        reason: 'seed $i rolled gear in Ranked GR',
      );
    }
  });

  test('Ranked GR floor spawn has no gear on chests', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
      ),
    );
    state = GameLogic.enterGreaterRift(state, tier: 1);
    final world = SpatialCombat.build(state);
    expect(world.groundLoot.where((g) => g.drop.isEquipment), isEmpty);
  });

  test('Ranked GR floor fillers keep gold pouch only', () {
    final mixed = LootPipeline.rollFloorClearLoot(9, roomType: RoomType.boss);
    expect(mixed.any((d) => d.name == 'Relic Shard'), isTrue);
    expect(mixed.any((d) => d.name == 'Boss Sigil'), isTrue);
    final goldOnly = mixed.where(LootPipeline.isWalletGoldDrop).toList();
    expect(goldOnly.any((d) => d.name == 'Relic Shard'), isFalse);
    expect(goldOnly.any((d) => d.name == 'Boss Sigil'), isFalse);
    expect(goldOnly.every(LootPipeline.isWalletGoldDrop), isTrue);
  });
}

GameState _withPartyMaxLevel(GameState state) => state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
