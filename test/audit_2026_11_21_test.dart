import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_rewarded.dart';
import 'package:idle_party/core/comeback_chest.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gold_income.dart';
import 'package:idle_party/core/offline_progress.dart';
import 'package:idle_party/core/wisp_gift.dart';
import 'package:idle_party/models/pet.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _bat = Pet(
  id: 'cave_bat_1',
  name: 'Cave Bat',
  attackBonus: 3,
  speciesId: 'cave_bat',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'pause during away credit persists the credited wallet',
    () async {
      final seed = GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime.utc(2026, 11, 21)),
        dungeonId: 'sandy',
      );
      final storage = InMemoryGameStorage(seed);
      final director = GameDirector(
        storage,
        initialState: seed,
        enableSpatialLoop: false,
      );
      director.debugHoldSave(seed);
      await director.setAppPaused(true);
      director.debugStampAway(lastUpdatedAgo: const Duration(minutes: 10));
      final frozen = director.state;

      final gate = Completer<void>();
      director.debugAwayCreditPause = gate.future;
      await director.setAppPaused(false);
      final pausing = director.setAppPaused(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      gate.complete();
      await pausing;
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (DateTime.now().isBefore(deadline) &&
          director.state.offlineSecondsRecovered ==
              frozen.offlineSecondsRecovered) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(
        director.state.offlineSecondsRecovered,
        greaterThan(frozen.offlineSecondsRecovered),
      );
      final saved = await storage.load();
      expect(saved, isNotNull);
      expect(saved!.gold, director.state.gold);
      expect(saved.essence, director.state.essence);
      expect(saved.offlineSecondsRecovered, director.state.offlineSecondsRecovered);
      expect(saved.highestFloorCleared, director.state.highestFloorCleared);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('sync keeps a dead pet at 0 HP', () {
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime.utc(2026, 11, 21)).copyWith(
        activePet: _bat,
        ownedPets: const [_bat],
      ),
      dungeonId: 'sandy',
    );
    final world = SpatialCombat.build(state);
    final pet = world.pets.where((p) => p.id == 'pet_${_bat.id}').first;
    expect(pet.hp, greaterThan(0));
    pet.hp = 0;
    final synced = SpatialCombat.syncPartyFromState(world, state);
    final again = synced.pets.where((p) => p.id == 'pet_${_bat.id}').first;
    expect(again.hp, 0);
  });

  test('ascend keeps leaveDungeon gauntlet best and Ashen ticket', () {
    final clock = DateTime.utc(2026, 11, 21, 12);
    final seeded = GameLogic.createInitialState(now: clock);
    final state = seeded.copyWith(
      bossVictories: 1,
      essence: 100,
      inDungeon: true,
      inGauntlet: true,
      inWorldBoss: true,
      worldBossPractice: false,
      currentRoom: seeded.currentRoom.copyWith(floorNumber: 8),
      metaDepth: seeded.metaDepth.copyWith(
        gauntletBestFloor: 1,
        worldBossTickets: 0,
        worldBossClearedWeek: false,
        worldBossWeekKey: GameLogic.isoWeekKey(clock),
      ),
    );
    final next = GameLogic.ascend(state, now: clock);
    expect(next.metaDepth.gauntletBestFloor, 7);
    expect(next.metaDepth.worldBossTickets, 1);
  });

  test('failed WISP ad keeps the pending claim and skip still clears it', () async {
    final seeded = GameLogic.createInitialState(now: DateTime.utc(2026, 11, 21));
    final tapped = WispGift.onWispTapped(
      seeded.copyWith(
        metaDepth: seeded.metaDepth.copyWith(wispUnlocked: true),
      ),
    );
    final director = GameDirector.preview();
    director.debugHoldSave(tapped);
    final claims = director.state.metaDepth.wispGiftClaimsToday;
    final pending = director.state.metaDepth.wispPendingWatchGold;
    expect(pending, greaterThan(0));

    director.debugWispAdResult = Future<AdWatchResult>.value(AdWatchResult.failed);
    await director.watchWispGiftAd();
    expect(director.state.metaDepth.wispGiftClaimsToday, claims);
    expect(director.state.metaDepth.wispPendingWatchGold, pending);
    expect(director.wispPendingChoice, isTrue);

    director.debugWispAdResult = Future<AdWatchResult>.value(
      AdWatchResult.skipped,
    );
    await director.watchWispGiftAd();
    expect(director.wispPendingChoice, isFalse);
    expect(director.state.metaDepth.wispGiftClaimsToday, claims);
  });

  test('DODGE and PARRY float at priority 2 like BLOCK', () {
    final hero = _hero(hp: 400);
    final world = _world(hero);
    hero.dodgePercent = 100;
    combatApplyHeroIncomingDamage(
      world,
      hero,
      40,
      reducedVfx: true,
      rng: Random(1),
    );
    expect(
      world.floaters.where((f) => f.text == 'DODGE' && f.priority == 2),
      isNotEmpty,
    );

    world.floaters.clear();
    hero.dodgePercent = 0;
    hero.parryPercent = 100;
    hero.hp = 400;
    for (var i = 0; i < 4; i++) {
      SpatialCombat.spawnFloater(
        world,
        x: hero.x,
        y: hero.y,
        text: '$i',
        argb: 0xFFFFFFFF,
      );
    }
    combatApplyHeroIncomingDamage(
      world,
      hero,
      40,
      reducedVfx: false,
      rng: Random(2),
    );
    expect(
      world.floaters.where((f) => f.text == 'PARRY' && f.priority == 2),
      isNotEmpty,
    );
  });

  test('STA buy does not revive the dead and only adds the max-HP delta', () {
    final seeded = GameLogic.createInitialState(now: DateTime.utc(2026, 11, 21));
    final dead = seeded.heroes[0];
    final living = seeded.heroes[1];
    final oldDeadMax = seeded.effectiveHeroMaxHp(dead);
    final oldLivingMax = seeded.effectiveHeroMaxHp(living);
    final half = oldLivingMax ~/ 2;
    final state = seeded.copyWith(
      gold: GameLogic.upgradeCostFor(seeded, PartyUpgradeType.vitality),
      heroes: [
        dead.copyWith(currentHp: 0),
        living.copyWith(currentHp: half),
        for (final hero in seeded.heroes.skip(2)) hero,
      ],
    );
    final bought = GameLogic.upgradeVitality(state);
    final newDeadMax = bought.effectiveHeroMaxHp(bought.heroes[0]);
    final newLivingMax = bought.effectiveHeroMaxHp(bought.heroes[1]);
    expect(newDeadMax, greaterThan(oldDeadMax));
    expect(newLivingMax, greaterThan(oldLivingMax));
    expect(bought.heroes[0].currentHp, 0);
    expect(bought.heroes[1].currentHp, half + (newLivingMax - oldLivingMax));
    expect(bought.heroes[1].currentHp, lessThan(newLivingMax));
  });

  test('a DoT-killed enemy does not swing on that frame', () {
    final hero = _hero(hp: 400);
    hero.attack = 0;
    hero.physicalAttack = 0;
    hero.spellPower = 0;
    hero.fireCooldown = 100;
    hero.moveSpeed = 0;
    final foe = SpatialActor(
      id: 'slime',
      name: 'Slime',
      team: SpatialTeam.enemy,
      x: 1,
      y: 1,
      hp: 500,
      maxHp: 500,
      attack: 80,
      defense: 0,
      moveSpeed: 0,
      attackRange: 2,
      attackCooldown: 1,
      fireCooldown: 0,
    );
    foe.bleedTimer = 5;
    foe.bleedDps = 8000;
    foe.bleedAcc = 0;
    foe.specialCd = 100;
    final world = _world(hero);
    world.enemies.add(foe);
    final state = GameLogic.createInitialState(now: DateTime.utc(2026, 11, 21));
    final stepped = SpatialCombat.step(world, state, dt: 0.25);
    expect(foe.hp, 0);
    expect(stepped.world.heroes.single.hp, 400);
    expect(stepped.world.heroes.single.attackSlowTimer, 0);
  });

  test('hub idle and the comeback chest use the offline cap', () async {
    final seeded = GameLogic.createInitialState(now: DateTime.utc(2026, 11, 21));
    final start = seeded.copyWith(
      inDungeon: false,
      autoCaveOnLeave: false,
      gold: 0,
      essence: 0,
      lastUpdated: DateTime.now().subtract(const Duration(hours: 48)),
    );
    final cap = GoldIncome.hubChestCapSecFor(start);
    final cappedGold = GoldIncome.applyHubIdle(start, cap).gold;
    final dayGold = GoldIncome.applyHubIdle(start, 48 * 3600).gold;
    expect(dayGold, greaterThan(cappedGold));

    final ticking = GameDirector.preview();
    ticking.debugHoldSave(start);
    ticking.debugTickHubIdle();
    expect(ticking.state.gold, cappedGold);

    final flushing = GameDirector.preview();
    flushing.debugHoldSave(start);
    await flushing.setAppPaused(true);
    expect(flushing.state.gold, cappedGold);

    final away = OfflineProgress.applyOfflineProgress(
      start,
      const Duration(days: 14),
    );
    expect(away.secondsApplied, cap);
    expect(away.state.metaDepth.comebackTier, ComebackChest.tierFor(cap));
    expect(
      ComebackChest.noteAbsence(start, ComebackChest.day14Sec)
          .metaDepth
          .comebackTier,
      14,
    );
  });

  test('melee Shield Block applies the extra 0.55 reduction', () {
    final hero = _hero(hp: 500);
    hero.shieldBlockTimer = 1;
    hero.dodgePercent = 0;
    hero.parryPercent = 0;
    hero.blockChance = 0;
    hero.kitInMul = 1;
    final world = _world(hero);
    combatApplyHeroIncomingDamage(
      world,
      hero,
      100,
      reducedVfx: false,
      rng: Random(1),
    );
    // Avoidance marks the hit blocked and takes 30% off (100 → 70).
    // Shield Block then takes the existing ×0.55 (70 → 39).
    expect(500 - hero.hp, 39);
  });

  test('writeActiveRaw rolls back when setString returns false', () async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = _SlotCommitFailsStore();
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('idle_party_save_slot_0', 'OLD');
    final storage = SharedPreferencesGameStorage(preferences: prefs);
    expect(await storage.writeActiveRaw('NEW'), isFalse);
    expect(prefs.getString('idle_party_save_slot_0'), 'OLD');
    expect(prefs.getString('idle_party_save_v2'), isNull);
  });
}

SpatialActor _hero({required int hp}) {
  return SpatialActor(
    id: 'hero_0',
    name: 'Ada',
    team: SpatialTeam.hero,
    x: 1,
    y: 1,
    hp: hp,
    maxHp: hp,
    attack: 10,
    defense: 0,
    moveSpeed: 1,
    attackRange: 1.2,
    attackCooldown: 1,
  );
}

SpatialWorld _world(SpatialActor hero) {
  return SpatialWorld(
    map: TileMap(
      cols: 3,
      rows: 3,
      tiles: List<TileKind>.filled(9, TileKind.floor),
      spawnPoints: const [(1, 1)],
      exitPoint: (2, 1),
      enemySpawns: const <(int, int)>[],
    ),
    heroes: [hero],
    enemies: <SpatialActor>[],
    projectiles: <SpatialProjectile>[],
    groundLoot: <GroundLoot>[],
    isTreasure: false,
  );
}

/// Writes the slot, then reports failure, matching a commit that updated
/// the map and then returned false.
class _SlotCommitFailsStore extends InMemorySharedPreferencesStore {
  _SlotCommitFailsStore() : super.empty();

  int slotSets = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    await super.setValue(valueType, key, value);
    if (key.endsWith('idle_party_save_slot_0')) {
      slotSets++;
      if (slotSets == 2) return false;
    }
    return true;
  }
}
