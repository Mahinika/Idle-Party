import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/greater_rift.dart';
import 'package:idle_party/core/loot_pipeline.dart';
import 'package:idle_party/core/play_games_scores.dart';
import 'package:idle_party/core/rift.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  final now = DateTime.utc(2026, 8, 24);

  test('Greater Rift is harder than farm Rift at same tier', () {
    expect(GreaterRift.killTarget(5), greaterThan(Rift.killTarget(5)));
    expect(GreaterRift.threatMul(10), greaterThan(Rift.threatMul(10)));
    expect(GreaterRift.successEssence(8), greaterThan(Rift.successEssence(8)));
    expect(GreaterRift.parTimeMs(12), lessThan(Rift.parTimeMs(12)));
    expect(GreaterRift.parTimeMs(1), lessThan(Rift.parTimeMs(1)));
    expect(GreaterRift.parTimeMs(20), greaterThanOrEqualTo(58000));
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
    state = state.copyWith(
      grKills: state.grKillTarget,
      grTimerMs: 5_000,
    );
    final resolved = GameLogic.tryResolveGreaterRift(state);
    expect(resolved, isNotNull);
    expect(resolved!.inGreaterRift, isFalse);
    expect(resolved.gold, greaterThan(goldBefore));
    expect(resolved.metaDepth.grBestTier, greaterThanOrEqualTo(2));
    expect(resolved.metaDepth.seasonBestGrTier, 1);
    expect(resolved.metaDepth.seasonBestGrClearMs, 5_000);
    expect(resolved.metaDepth.lifetimeGrClears, 1);
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
    state = state.copyWith(
      riftKills: state.riftKillTarget,
      riftTimerMs: 2_000,
    );
    final resolved = GameLogic.tryResolveRift(state)!;
    expect(resolved.metaDepth.seasonBestGrTier, 0);
    expect(resolved.metaDepth.riftBestTier, greaterThan(0));
  });

  test('enter without a tier is always best+1, not KEY preferred', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        metaDepth: const MetaDepthState(
          grBestTier: 34,
          grPreferredTier: 1,
        ),
      ),
    );
    expect(GreaterRift.nextOfferTier(34), 35);
    expect(GreaterRift.hubEnterLabel(34), 'RANKED GR35');
    expect(GreaterRift.hubShortLabel(34), 'GR35');
    final run = GameLogic.enterGreaterRift(state);
    expect(run.grTier, 35);
    expect(run.inGreaterRift, isTrue);
  });

  test('Ranked GR stays selectable past 20', () {
    expect(GreaterRift.maxSelectableTier(20), 21);
    expect(GreaterRift.killTarget(21), GreaterRift.killTarget(20));
    expect(GreaterRift.parTimeMs(21), greaterThan(GreaterRift.parTimeMs(20)));
    expect(GreaterRift.parTimeMs(50), 90000);
    expect(GreaterRift.threatMul(21), greaterThan(GreaterRift.threatMul(20)));
    expect(GreaterRift.densityMul(50), GreaterRift.densityMul(20));
    expect(GreaterRift.successEssence(21), greaterThan(GreaterRift.successEssence(20)));
    double kps(int t) =>
        GreaterRift.killTarget(t) / (GreaterRift.parTimeMs(t) / 1000);
    expect(kps(21), lessThan(kps(20)));
    expect(kps(30), lessThan(kps(21)));
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
