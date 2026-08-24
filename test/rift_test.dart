import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/keystone.dart';
import 'package:idle_party/core/rift.dart';

void main() {
  final now = DateTime.utc(2026, 8, 24);

  test('tier scaling grows kills and shrinks par time', () {
    expect(Rift.killTarget(1), 23);
    expect(Rift.killTarget(20), 80);
    expect(Rift.parTimeMs(1), greaterThan(Rift.parTimeMs(20)));
    expect(Rift.threatMul(20), greaterThan(Rift.threatMul(1)));
    expect(Rift.successEssence(5), 18);
    expect(Rift.failEssence(8), 2);
  });

  test('fast clear unlocks +2 tiers', () {
    expect(
      Rift.unlockTierAfterSuccess(
        clearedTier: 3,
        timerMs: 10_000,
        parMs: 100_000,
      ),
      5,
    );
    expect(
      Rift.unlockTierAfterSuccess(
        clearedTier: 3,
        timerMs: 90_000,
        parMs: 100_000,
      ),
      4,
    );
  });

  test('Rift enter requires party Lv60', () {
    final early = GameLogic.createInitialState(now: now);
    expect(GameLogic.canEnterRift(early), isFalse);
    expect(GameLogic.enterRift(early).inRift, isFalse);

    final alOnly = early.copyWith(ascensionLevel: GameLogic.maxAscensionLevel);
    expect(GameLogic.canEnterRift(alOnly), isFalse);

    final endgame = _withPartyMaxLevel(alOnly);
    expect(GameLogic.canEnterRift(endgame), isTrue);
    final run = GameLogic.enterRift(endgame, tier: 1);
    expect(run.inRift, isTrue);
    expect(run.inDungeon, isTrue);
    expect(run.riftTier, 1);
    expect(run.riftKillTarget, Rift.killTarget(1));
    expect(run.riftParMs, Rift.parTimeMs(1));
    expect(run.dungeonId, Rift.dungeonId);
  });

  test('KEY dial blocked before party Lv60 and clamped on load', () {
    final early = GameLogic.createInitialState(now: now).copyWith(
      hardmodeLevel: 5,
    );
    expect(Keystone.maxForState(early), 0);
    final blocked = GameLogic.setHardmodeLevel(early, 3);
    expect(blocked.hardmodeLevel, 0);

    final loaded = GameLogic.stateFromJson(early.toJson());
    expect(loaded.hardmodeLevel, 0);
    expect(loaded.keystoneRunActive, isFalse);
  });

  test('Rift success pays out and unlocks next tier', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
      ),
    );
    state = GameLogic.enterRift(state, tier: 1);
    final goldBefore = state.gold;
    final essenceBefore = state.essence;
    state = state.copyWith(
      riftKills: state.riftKillTarget,
      riftTimerMs: 1_000,
    );
    final resolved = GameLogic.tryResolveRift(state);
    expect(resolved, isNotNull);
    expect(resolved!.inRift, isFalse);
    expect(resolved.inDungeon, isFalse);
    expect(resolved.gold, greaterThan(goldBefore));
    expect(resolved.essence, greaterThan(essenceBefore));
    expect(resolved.metaDepth.riftBestTier, greaterThanOrEqualTo(2));
    expect(resolved.metaDepth.lifetimeRiftClears, 1);
  });

  test('Rift fail on timeout keeps best tier', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              riftBestTier: 4,
            ),
      ),
    );
    state = GameLogic.enterRift(state, tier: 5);
    state = state.copyWith(riftTimerMs: state.riftParMs + 1);
    final resolved = GameLogic.tryResolveRift(state);
    expect(resolved, isNotNull);
    expect(resolved!.inRift, isFalse);
    expect(resolved.metaDepth.riftBestTier, 4);
    expect(resolved.essence, greaterThan(0));
  });
}

GameState _withPartyMaxLevel(GameState state) => state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
