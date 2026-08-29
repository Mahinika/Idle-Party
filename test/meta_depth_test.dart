import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/keystone.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/achievement_def.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/models/pet.dart';

void main() {
  test('pet catalog covers meta-depth species roster', () {
    expect(PetCatalog.all.length, greaterThanOrEqualTo(12));
    expect(
      PetCatalog.all.map((s) => s.passive).toSet(),
      containsAll([
        PetPassive.attack,
        PetPassive.goldFind,
        PetPassive.lootFind,
        PetPassive.xpFind,
        PetPassive.mitigate,
        PetPassive.healBoost,
      ]),
    );
  });

  test('achievement catalog spans categories', () {
    expect(AchievementCatalog.all.length, greaterThanOrEqualTo(30));
    expect(
      AchievementCatalog.all.map((a) => a.category).toSet().length,
      greaterThanOrEqualTo(4),
    );
  });

  test('hatch respects roster and rolls rarity fields', () {
    var state = GameLogic.createInitialState(
      now: DateTime(2026, 7, 31),
    ).copyWith(essence: 5000);
    state = GameLogic.hatchPet(state);
    expect(state.ownedPets, isNotEmpty);
    final pet = state.ownedPets.first;
    expect(pet.resolvedSpecies, isNotEmpty);
    expect(pet.rarity, isNotNull);
    expect(state.metaDepth.lifetimePetHatches, greaterThanOrEqualTo(1));
  });

  test('prestige shop and weekly contract operate', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 31))
        .copyWith(
          essence: 500,
          ascensionLevel: 5,
          metaDepth: const MetaDepthState(weeklyProgress: 3),
        );
    state = GameLogic.ensureWeeklyContract(state);
    expect(state.metaDepth.weeklyKey, isNotEmpty);
    state = GameLogic.buyPrestigeShopItem(state, 'torch_keep');
    expect(state.metaDepth.torchKeepLevel, greaterThan(0));
    expect(state.metaDepth.hasPrestige('torch_keep'), isTrue);
  });

  test('collection score and will rank move with progress', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 31));
    final base = state.collectionScore;
    state = state.copyWith(
      achievements: ['first_floor', 'first_boss'],
      metaDepth: state.metaDepth.copyWith(
        zoneTrophies: ['sandy'],
        titles: ['Reborn'],
      ),
    );
    expect(state.collectionScore, greaterThan(base));
    expect(WillRanks.titleForScore(state.collectionScore), isNotEmpty);
    expect(MetaSystems.collectionScore(state), state.collectionScore);
  });

  test('merge pets upgrades rarity', () {
    var state = GameLogic.createInitialState(
      now: DateTime(2026, 7, 31),
    ).copyWith(essence: 200);
    final a = Pet(
      id: 'ember_pup_1',
      name: 'Ember Pup',
      attackBonus: 2,
      speciesId: 'ember_pup',
      rarity: PetRarity.common,
      passive: PetPassive.attack,
      affinityDungeonId: 'hell',
    );
    final b = Pet(
      id: 'ember_pup_2',
      name: 'Ember Pup',
      attackBonus: 2,
      speciesId: 'ember_pup',
      rarity: PetRarity.common,
      passive: PetPassive.attack,
      affinityDungeonId: 'hell',
    );
    state = state.copyWith(ownedPets: [a, b], activePet: a);
    state = GameLogic.mergePets(state, a.id, b.id);
    expect(state.ownedPets.length, 1);
    expect(
      state.ownedPets.first.rarity.index,
      greaterThan(PetRarity.common.index),
    );
    expect(state.metaDepth.lifetimePetMerges, 1);
  });

  test('daily vault progress increments on floor clear path', () {
    final now = DateTime.now();
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.ensureWeeklyContract(state, now: now);
    expect(state.metaDepth.dailyVaultClears, 0);
    state = GameLogic.completeCurrentRoom(
      state,
      goldGain: 10,
      skipLootRoll: true,
    );
    expect(state.metaDepth.dailyVaultClears, 1);
    expect(state.metaDepth.lifetimeFloorClears, greaterThanOrEqualTo(1));
    // Ascend must not wipe daily vault progress.
    state = state.copyWith(
      bossVictories: GameLogic.bossesRequiredForAscension(state.ascensionLevel),
      metaDepth: state.metaDepth.copyWith(dailyVaultClears: 1),
    );
    final beforeVault = state.metaDepth.dailyVaultClears;
    state = GameLogic.ascend(state, now: now);
    expect(state.metaDepth.dailyVaultClears, beforeVault);
  });

  test('weekly rollover resets legacy weeklyProgress on new week', () {
    var state = GameLogic.createInitialState(now: DateTime.now());
    // Stale prior-week key with leftover progress that would be wiped on rotate.
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        weeklyKey: '2020-W01',
        weeklyProgress: 2,
        weeklyClaimed: false,
        weeklyModifier: 'swarm',
      ),
    );
    state = GameLogic.completeCurrentRoom(
      state,
      goldGain: 10,
      skipLootRoll: true,
    );
    final key = GameLogic.isoWeekKey(DateTime.now().toUtc());
    expect(state.metaDepth.weeklyKey, key);
    expect(state.metaDepth.weeklyProgress, 0);
    expect(state.metaDepth.dailyVaultClears, 1);
  });

  test('createEnemyGroup glass modifier shrinks HP and boosts ATK', () {
    const room = DungeonRoom(
      floorNumber: 3,
      roomIndex: 0,
      type: RoomType.normal,
      enemyLevel: 3,
      enemyCount: 4,
    );
    final baseState = GameLogic.createInitialState(now: DateTime(2026, 7, 31))
        .copyWith(
          keystoneRunActive: true,
          keystoneRunLevel: 2,
          keystoneRunAffixes: const <String>['elite'],
        );
    final plain = GameLogic.createEnemyGroup(room, fromState: baseState);
    final glassState = baseState.copyWith(
      keystoneRunAffixes: const <String>['glass'],
      metaDepth: baseState.metaDepth.copyWith(weeklyModifier: 'glass'),
    );
    final glass = GameLogic.createEnemyGroup(room, fromState: glassState);
    expect(plain, isNotEmpty);
    expect(glass.length, plain.length);
    final plainHp = plain.fold<int>(0, (s, e) => s + e.maxHp);
    final glassHp = glass.fold<int>(0, (s, e) => s + e.maxHp);
    final plainAtk = plain.fold<int>(0, (s, e) => s + e.attack);
    final glassAtk = glass.fold<int>(0, (s, e) => s + e.attack);
    expect(glassHp, lessThan(plainHp));
    expect(glassAtk, greaterThan(plainAtk));
  });

  test('awardPartyXp applies sanctuary and pet XP bonuses', () {
    final xpPet = Pet(
      id: 'xp_pet',
      name: 'Scholar Cub',
      attackBonus: 1,
      speciesId: 'ember_pup',
      rarity: PetRarity.rare,
      passive: PetPassive.xpFind,
      affinityDungeonId: 'sandy',
      level: 5,
      passivePerLevel: 2,
    );
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 31))
        .copyWith(
          activePet: xpPet,
          ownedPets: [xpPet],
          metaDepth: const MetaDepthState(sanctuaryXpLevel: 5),
        );
    final beforeXp = state.heroes.first.xp;
    final amount = 20;
    final expectedBoost =
        amount +
        (amount * (state.sanctuaryXpBonusPercent + state.petXpFindPercent)) ~/
            100;
    state = GameLogic.awardPartyXp(state, amount);
    expect(state.heroes.first.level, 1);
    expect(state.heroes.first.xp - beforeXp, expectedBoost);
  });

  test('mergePets no-ops when both are already legendary', () {
    final a = Pet(
      id: 'leg_a',
      name: 'Ember Pup',
      attackBonus: 5,
      speciesId: 'ember_pup',
      rarity: PetRarity.legendary,
      passive: PetPassive.attack,
      affinityDungeonId: 'hell',
    );
    final b = Pet(
      id: 'leg_b',
      name: 'Ember Pup',
      attackBonus: 5,
      speciesId: 'ember_pup',
      rarity: PetRarity.legendary,
      passive: PetPassive.attack,
      affinityDungeonId: 'hell',
    );
    final state = GameLogic.createInitialState(
      now: DateTime(2026, 7, 31),
    ).copyWith(ownedPets: [a, b], activePet: a);
    expect(GameLogic.canMergePets(state, a.id, b.id), isFalse);
    final next = GameLogic.mergePets(state, a.id, b.id);
    expect(identical(next, state) || next.ownedPets.length == 2, isTrue);
    expect(next.ownedPets.length, 2);
    expect(next.metaDepth.lifetimePetMerges, 0);
  });

  test('prestige shop respects level caps', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 31))
        .copyWith(
          essence: 5000,
          ascensionLevel: 20,
          metaDepth: const MetaDepthState(torchKeepLevel: 10),
        );
    final blocked = GameLogic.buyPrestigeShopItem(state, 'torch_keep');
    expect(blocked.metaDepth.torchKeepLevel, 10);
    expect(blocked.essence, state.essence);

    state = state.copyWith(metaDepth: const MetaDepthState(combinatorLuck: 4));
    state = GameLogic.buyPrestigeShopItem(state, 'combine_luck');
    expect(state.metaDepth.combinatorLuck, 5);
    final atCap = GameLogic.buyPrestigeShopItem(state, 'combine_luck');
    expect(atCap.metaDepth.combinatorLuck, 5);
    expect(atCap.essence, state.essence);
  });

  test('Combinator Charm cheapens MERGE gold, not odds', () {
    final item = PrestigeShopCatalog.all.firstWhere((i) => i.id == 'combine_luck');
    expect(item.description.toLowerCase(), contains('gold'));
    expect(item.description.toLowerCase(), isNot(contains('odds')));
  });

  test('MetaDepthState.fromJson parses num ints safely', () {
    final md = MetaDepthState.fromJson(<String, dynamic>{
      'weeklyProgress': 2.0,
      'torchKeepLevel': 3,
      'lifetimeAbilityCasts': 12.5,
      'godHandStyle': 1.0,
      'dailyEssenceBonusLevel': 2,
      'gauntletGoldBonusLevel': 1,
    });
    expect(md.weeklyProgress, 2);
    expect(md.torchKeepLevel, 3);
    expect(md.lifetimeAbilityCasts, 12);
    expect(md.godHandStyle, 1);
    expect(md.dailyEssenceBonusLevel, 2);
    expect(md.gauntletGoldBonusLevel, 1);
    expect(md.claimedWillRanks, isEmpty);
    expect(md.claimedGauntletMilestones, isEmpty);
  });

  test('legacy metaDepth json omits Q2-Q3 fields safely', () {
    final md = MetaDepthState.fromJson(<String, dynamic>{
      'weeklyProgress': 1,
      'torchKeepLevel': 1,
    });
    expect(md.godHandStyle, 0);
    expect(md.seasonKey, '');
    expect(md.claimedWillRanks, isEmpty);
    expect(md.claimedGauntletMilestones, isEmpty);
    expect(md.dailyEssenceBonusLevel, 0);
    expect(md.gauntletGoldBonusLevel, 0);
    expect(md.ascendBlessings, 0);
    expect(md.dismissedPlayUpdateVersionCode, 0);
  });

  test('daily vault claim pays essence and seasons rotate', () {
    final now = DateTime.utc(2026, 8, 7);
    final key = GameLogic.isoWeekKey(now);
    var state = GameLogic.createInitialState(now: now).copyWith(
      metaDepth: MetaDepthState(
        weeklyKey: key,
        weeklyModifier: 'glass',
        seasonKey: GameLogic.seasonLabel(now),
        dailyVaultDate: MetaSystems.dailyDateKey(now),
        dailyVaultClears: 1,
        dailyVaultClaimed: false,
        claimedSeasonRewards: const <String>[],
      ),
    );
    expect(state.metaDepth.seasonKey, contains('2026-W'));
    expect(state.metaDepth.seasonKey, contains('2026-08'));
    expect(GameLogic.canClaimDailyVault(state), isTrue);
    final before = state.essence;
    final expectedMin =
        Keystone.dailyVaultEssence(0) + GameLogic.seasonWeeklyBonusEssence;
    state = GameLogic.claimDailyVault(state, now: now);
    expect(state.metaDepth.dailyVaultClaimed, isTrue);
    expect(state.essence, greaterThanOrEqualTo(before + expectedMin));
    expect(state.achievements, contains('weekly_clear'));
    expect(state.metaDepth.claimedSeasonRewards, contains('2026-08'));
  });

  test('will ranks and gauntlet milestones claim once', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 7));
    state = state.copyWith(
      achievements: List.generate(20, (i) => 'a$i'),
      unlockedRelics: ['war_banner', 'iron_ward'],
      metaDepth: state.metaDepth.copyWith(gauntletBestFloor: 50),
    );
    final before = state.essence;
    state = GameLogic.syncMetaPayoffs(state);
    expect(state.metaDepth.claimedWillRanks, isNotEmpty);
    expect(
      state.metaDepth.claimedGauntletMilestones,
      containsAll(['f25', 'f50']),
    );
    expect(state.metaDepth.claimedGauntletMilestones.contains('f100'), isFalse);
    expect(state.essence, greaterThan(before));
    final mid = state.essence;
    state = GameLogic.syncMetaPayoffs(state);
    expect(state.essence, mid);
  });

  test('new relics and prestige sinks wire through', () {
    var state = GameLogic.createInitialState(
      now: DateTime(2026, 8, 7),
    ).copyWith(essence: 500, ascensionLevel: 12);
    expect(GameLogic.relicOrder, contains(GameLogic.godHandFocusRelic));
    expect(
      PrestigeShopCatalog.all.firstWhere((i) => i.id == 'gh_cdr').name,
      contains('Cadence'),
    );
    state = GameLogic.unlockRelic(state, GameLogic.godHandFocusRelic);
    expect(state.hasRelic(GameLogic.godHandFocusRelic), isTrue);
    expect(state.relicGodHandDamageBonus, 3);
    state = GameLogic.unlockRelic(state, GameLogic.chamberLuckRelic);
    expect(state.relicLootFindPercent, 5);
    state = GameLogic.unlockRelic(state, GameLogic.ironWillRelic);
    expect(state.relicMitigateFlat, GameLogic.relicMitigatePerTier);
    state = GameLogic.setGodHandStyle(state, 2);
    expect(state.metaDepth.godHandStyle, 2);
    state = GameLogic.buyPrestigeShopItem(state, 'daily_essence');
    expect(state.metaDepth.dailyEssenceBonusLevel, 1);
    state = GameLogic.buyPrestigeShopItem(state, 'gauntlet_gold');
    expect(state.metaDepth.gauntletGoldBonusLevel, 1);
    expect(
      GameLogic.gauntletGoldMul(1, prestigeBonusLevel: 1),
      greaterThan(GameLogic.gauntletGoldMul(1)),
    );
  });

  test('new prestige QoL shop items apply and round-trip', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 20))
        .copyWith(essence: 2000, ascensionLevel: 10);
    final flaskBefore = GameLogic.marketFlaskCost(state);
    final capBefore = GameLogic.maxAutoSellIlvlCap(state);
    expect(GameLogic.maxLoadoutsFor(state), 3);

    state = GameLogic.buyPrestigeShopItem(state, 'loadout_slot');
    expect(state.metaDepth.loadoutBonusSlots, 1);
    expect(GameLogic.maxLoadoutsFor(state), 4);

    state = GameLogic.buyPrestigeShopItem(state, 'flask_discount');
    expect(state.metaDepth.marketDiscountLevel, 1);
    expect(GameLogic.marketFlaskCost(state), lessThan(flaskBefore));

    state = GameLogic.buyPrestigeShopItem(state, 'filter_span');
    expect(state.metaDepth.filterSpanLevel, 1);
    expect(GameLogic.maxAutoSellIlvlCap(state), capBefore + 8);

    state = GameLogic.buyPrestigeShopItem(state, 'offline_ledger');
    expect(state.metaDepth.offlineHighlightBonus, 1);

    final json = state.metaDepth.toJson();
    json.remove('loadoutBonusSlots');
    final legacy = MetaDepthState.fromJson(json);
    expect(legacy.loadoutBonusSlots, 0);

    final round = MetaDepthState.fromJson(state.metaDepth.toJson());
    expect(round.loadoutBonusSlots, 1);
    expect(round.marketDiscountLevel, 1);
    expect(round.filterSpanLevel, 1);
    expect(round.offlineHighlightBonus, 1);
  });

  test('prestige catalog ownedCount and atCap match shop maxes', () {
    const empty = MetaDepthState();
    expect(PrestigeShopCatalog.ownedCount(empty, 'stash_slot'), 0);
    expect(PrestigeShopCatalog.atCap(empty, 'stash_slot'), isFalse);
    expect(PrestigeShopCatalog.atCap(empty, 'nope'), isFalse);

    const capped = MetaDepthState(
      stashBonusSlots: 20,
      combinatorLuck: 5,
      torchKeepLevel: 10,
      godHandCdLevel: 8,
      petRosterCapBonus: 10,
      loadoutBonusSlots: 2,
      marketDiscountLevel: 5,
      filterSpanLevel: 5,
      offlineHighlightBonus: 3,
      legacyPoints: 20,
      dailyEssenceBonusLevel: 5,
      gauntletGoldBonusLevel: 5,
    );
    expect(PrestigeShopCatalog.ownedCount(capped, 'stash_slot'), 10);
    expect(PrestigeShopCatalog.atCap(capped, 'stash_slot'), isTrue);
    expect(PrestigeShopCatalog.atCap(capped, 'combine_luck'), isTrue);
    expect(PrestigeShopCatalog.atCap(capped, 'torch_keep'), isTrue);
    expect(PrestigeShopCatalog.atCap(capped, 'gh_cdr'), isTrue);
    expect(PrestigeShopCatalog.atCap(capped, 'roster_cap'), isTrue);
    expect(PrestigeShopCatalog.atCap(capped, 'loadout_slot'), isTrue);
    expect(PrestigeShopCatalog.atCap(capped, 'flask_discount'), isTrue);
    expect(PrestigeShopCatalog.atCap(capped, 'filter_span'), isTrue);
    expect(PrestigeShopCatalog.atCap(capped, 'offline_ledger'), isTrue);
    expect(PrestigeShopCatalog.atCap(capped, 'legacy_spark'), isTrue);
    expect(PrestigeShopCatalog.atCap(capped, 'daily_essence'), isTrue);
    expect(PrestigeShopCatalog.atCap(capped, 'gauntlet_gold'), isTrue);
  });

  test('Loadout Folio stays off POWER SHOP but save math still works', () {
    expect(
      PrestigeShopCatalog.offered.any((i) => i.id == 'loadout_slot'),
      isFalse,
    );
    expect(PrestigeShopCatalog.byId('loadout_slot')?.listedInShop, isFalse);

    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 21))
        .copyWith(essence: 200, ascensionLevel: 10);
    state = GameLogic.buyPrestigeShopItem(state, 'loadout_slot');
    expect(state.metaDepth.loadoutBonusSlots, 1);
  });
}
