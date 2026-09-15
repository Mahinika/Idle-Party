import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/keystone.dart';
import 'package:idle_party/core/rift.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/stats.dart';

void main() {
  final now = DateTime.utc(2026, 8, 24);

  test('tier scaling grows kills; clock follows work not a shrinking fuse', () {
    expect(Rift.killTarget(1), 22);
    expect(Rift.killTarget(20), 60);
    expect(Rift.parTimeMs(20), greaterThanOrEqualTo(Rift.parTimeMs(1)));
    expect(Rift.threatMul(20), greaterThan(Rift.threatMul(1)));
    expect(Rift.successEssence(5), 18);
    expect(Rift.failEssence(8), 2);
  });

  test('HUD progress labels use percent / GUARDIAN (no kill counts)', () {
    expect(
      Rift.hudChipLabel(progress01: 0.06, tier: 5, guardianActive: false),
      'FARM R5 · 6%',
    );
    expect(
      Rift.hudChipLabel(progress01: 1, tier: 5, guardianActive: true),
      'FARM R5 · GUARDIAN',
    );
    expect(
      Rift.progressLabel(
        progress01: 0.06,
        timerMs: 5_000,
        tier: 5,
        guardianActive: false,
      ),
      'FARM R5 · 6% · 00:05',
    );
    expect(Rift.formatTimer(65_000), '01:05');
  });

  test('Farm clear unlocks +1 only (no timer +2)', () {
    expect(Rift.unlockTierAfterSuccess(clearedTier: 3), 4);
    expect(Rift.unlockTierAfterSuccess(clearedTier: 20), 21);
  });

  test('Rift enter requires party max level', () {
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
    expect(run.riftProgress01, 0);
    expect(run.riftGuardianActive, isFalse);
    expect(run.dungeonId, Rift.dungeonId);
    expect(run.dungeonId, 'storm');
    expect(run.dungeonId, isNot('crystal'));
  });

  test('KEY dial blocked before party max and clamped on load', () {
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

  test('progress fills then Guardian kill clears even after long elapsed', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
      ),
    );
    state = GameLogic.enterRift(state, tier: 1);
    final goldBefore = state.gold;
    final essenceBefore = state.essence;
    state = GameLogic.noteRiftKills(state, state.riftKillTarget);
    expect(state.riftProgress01, 1.0);
    state = GameLogic.maybeActivateRiftGuardian(state);
    expect(state.riftGuardianActive, isTrue);
    expect(state.enemies, isNotEmpty);
    expect(state.enemies.first.name, 'Rift Guardian');
    // Long elapsed — Farm must still succeed (no timer fail).
    state = state.copyWith(
      riftTimerMs: state.riftParMs * 5,
      enemies: const <EnemyUnit>[],
    );
    final resolved = GameLogic.tryResolveRift(state);
    expect(resolved, isNotNull);
    expect(resolved!.inRift, isFalse);
    expect(resolved.inDungeon, isFalse);
    expect(resolved.gold, greaterThan(goldBefore));
    expect(resolved.essence, greaterThan(essenceBefore));
    expect(resolved.metaDepth.riftBestTier, 1);
    expect(Rift.maxSelectableTier(resolved.metaDepth.riftBestTier), Rift.maxTier);
    expect(resolved.metaDepth.lifetimeRiftClears, 1);
  });

  test('Farm does not fail on timer alone', () {
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
    expect(GameLogic.tryResolveRift(state), isNull);
    expect(state.metaDepth.riftBestTier, 4);
  });

  test('leave mid-run depletes with consolation essence', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
      ),
    );
    state = GameLogic.enterRift(state, tier: 5);
    final essenceBefore = state.essence;
    final left = GameLogic.leaveDungeon(state);
    expect(left.inRift, isFalse);
    expect(left.essence, greaterThan(essenceBefore));
  });

  test('progress + Guardian fields survive save load', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
      ),
    );
    state = GameLogic.enterRift(state, tier: 2);
    state = state.copyWith(
      riftProgress01: 0.42,
      riftGuardianActive: true,
      enemies: [
        EnemyUnit(
          name: 'Rift Guardian',
          level: 10,
          currentHp: 100,
          stats: Stats.enemy(attack: 5, defense: 1, maxHp: 100),
          rewardGold: 0,
          role: EnemyRole.boss,
        ),
      ],
    );
    final loaded = GameLogic.stateFromJson(state.toJson());
    expect(loaded.riftProgress01, closeTo(0.42, 0.0001));
    expect(loaded.riftGuardianActive, isTrue);
  });

  test('Farm Rift stays selectable past 20', () {
    expect(Rift.maxSelectableTier(20), Rift.maxTier);
    expect(Rift.killTarget(21), Rift.killTarget(20));
    expect(Rift.parTimeMs(50), Rift.parTimeMs(20));
    expect(Rift.threatMul(21), greaterThan(Rift.threatMul(20)));
    expect(Rift.densityMul(50), Rift.densityMul(20));
    expect(Rift.successEssence(21), greaterThan(Rift.successEssence(20)));
  });

  test('Farm Rift R25 survives save load', () {
    final now = DateTime.utc(2026, 8, 24);
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              riftBestTier: 25,
              riftPreferredTier: 26,
            ),
      ),
    );
    state = GameLogic.setRiftPreferredTier(state, 26);
    expect(state.metaDepth.riftPreferredTier, 26);
    final loaded = GameLogic.stateFromJson(state.toJson());
    expect(loaded.metaDepth.riftBestTier, 25);
    expect(loaded.metaDepth.riftPreferredTier, 26);
    expect(GameLogic.enterRift(loaded, tier: 26).riftTier, 26);
  });

  test('Farm Rift picker can pick below or far above best', () {
    expect(Rift.pickerStart(preferred: 1, bestCleared: 20), 20);
    expect(Rift.pickerStart(preferred: 7, bestCleared: 20), 7);
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              riftBestTier: 20,
              riftPreferredTier: 7,
            ),
      ),
    );
    expect(GameLogic.enterRift(state).riftTier, 7);
    expect(GameLogic.enterRift(state, tier: 21).riftTier, 21);
    expect(GameLogic.enterRift(state, tier: 50).riftTier, 50);
  });
}

GameState _withPartyMaxLevel(GameState state) => state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
