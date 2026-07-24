import 'dart:math';

import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/loot.dart';
import '../models/stats.dart';
import 'game_state.dart';

class GameLogic {
  static const String warBannerRelic = 'war_banner';
  static const String ironWardRelic = 'iron_ward';
  static const String phoenixEmberRelic = 'phoenix_ember';
  static const List<String> relicOrder = <String>[
    warBannerRelic,
    ironWardRelic,
    phoenixEmberRelic,
  ];
  static const Map<LootRarity, String> rarityNames = <LootRarity, String>{
    LootRarity.common: 'Common',
    LootRarity.uncommon: 'Uncommon',
    LootRarity.rare: 'Rare',
    LootRarity.epic: 'Epic',
  };
  static const Map<String, String> relicNames = <String, String>{
    warBannerRelic: 'War Banner',
    ironWardRelic: 'Iron Ward',
    phoenixEmberRelic: 'Phoenix Ember',
  };
  static const Map<String, String> relicDescriptions = <String, String>{
    warBannerRelic: 'Permanent +4 team attack aura.',
    ironWardRelic: 'Permanent +2 team defense aura.',
    phoenixEmberRelic: 'Permanent +10 max HP for every hero.',
  };
  static const Map<String, int> relicCosts = <String, int>{
    warBannerRelic: 6,
    ironWardRelic: 14,
    phoenixEmberRelic: 28,
  };

  static GameState createInitialState({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    return GameState(
      heroes: <PartyHero>[
        PartyHero.starting(
          name: 'Aegis',
          stats: const Stats(attack: 8, defense: 4, maxHp: 40),
        ),
        PartyHero.starting(
          name: 'Vale',
          stats: const Stats(attack: 6, defense: 3, maxHp: 34),
        ),
        PartyHero.starting(
          name: 'Ember',
          stats: const Stats(attack: 5, defense: 2, maxHp: 30),
        ),
      ],
      enemy: createEnemy(1),
      gold: 0,
      essence: 0,
      battleNumber: 1,
      bossVictories: 0,
      lastUpdated: timestamp,
      offlineSecondsRecovered: 0,
      attackBonus: 0,
      defenseBonus: 0,
      vitalityBonus: 0,
      recentLoot: <LootDrop>[],
      unlockedRelics: <String>[],
    );
  }

  static bool isBossBattle(int battleNumber) => battleNumber % 10 == 0;

  static bool isEliteBattle(int battleNumber) =>
      battleNumber % 5 == 0 && !isBossBattle(battleNumber);

  static EnemyUnit createEnemy(int battleNumber) {
    final level = battleNumber;
    final isBoss = isBossBattle(battleNumber);
    final isElite = isEliteBattle(battleNumber);
    final stats = Stats(
      attack: 4 + (isElite ? 2 : 0) + (isBoss ? 4 : 0),
      defense: 1 + (isElite ? 1 : 0) + (isBoss ? 2 : 0),
      maxHp:
          24 +
          (level * 3) +
          ((level ~/ 5) * 10) +
          (isElite ? 14 : 0) +
          (isBoss ? 48 : 0),
    );

    return EnemyUnit(
      name: isBoss
          ? 'Gate Warden'
          : isElite
          ? 'Elite Golem'
          : 'Cave Slime',
      level: level,
      currentHp: stats.maxHp,
      stats: stats,
      rewardGold: 8 + (level * 2) + (isElite ? 8 : 0) + (isBoss ? 24 : 0),
    );
  }

  static GameState advance(GameState state, {int steps = 1}) {
    var current = state;
    for (var i = 0; i < steps; i++) {
      current = _advanceOneTick(current);
    }
    return current;
  }

  static GameState applyOfflineProgress(GameState state, Duration elapsed) {
    final seconds = elapsed.inSeconds.clamp(0, 3600);
    if (seconds == 0) {
      return state.copyWith(lastUpdated: DateTime.now());
    }

    final progressed = advance(state, steps: seconds);
    return progressed.copyWith(
      offlineSecondsRecovered: progressed.offlineSecondsRecovered + seconds,
      lastUpdated: DateTime.now(),
    );
  }

  static int partyTrainingCostFor(GameState state) {
    final totalLevels = state.heroes.fold<int>(
      0,
      (sum, hero) => sum + hero.level,
    );
    return 16 + (totalLevels * 3) + (state.bossVictories * 6);
  }

  static int upgradeCostFor(GameState state, PartyUpgradeType type) {
    final currentTier = switch (type) {
      PartyUpgradeType.attack => state.attackBonus ~/ 2,
      PartyUpgradeType.defense => state.defenseBonus,
      PartyUpgradeType.vitality => state.vitalityBonus ~/ 6,
    };

    return 18 + (currentTier * 10) + (state.bossVictories * 5);
  }

  static GameState trainParty(GameState state) {
    final trainingCost = partyTrainingCostFor(state);
    if (state.gold < trainingCost) {
      return state;
    }

    final trainedHeroes = state.heroes
        .map(
          (hero) => hero.copyWith(
            level: hero.level + 1,
            currentHp: hero.maxHp + state.vitalityBonus + 5,
          ),
        )
        .toList();
    return state.copyWith(
      heroes: trainedHeroes,
      gold: state.gold - trainingCost,
      lastUpdated: DateTime.now(),
    );
  }

  static GameState upgradeAttack(GameState state) =>
      _applyUpgrade(state, type: PartyUpgradeType.attack);

  static GameState upgradeDefense(GameState state) =>
      _applyUpgrade(state, type: PartyUpgradeType.defense);

  static GameState upgradeVitality(GameState state) =>
      _applyUpgrade(state, type: PartyUpgradeType.vitality);

  static GameState _applyUpgrade(
    GameState state, {
    required PartyUpgradeType type,
  }) {
    final cost = upgradeCostFor(state, type);
    if (state.gold < cost) {
      return state;
    }

    switch (type) {
      case PartyUpgradeType.attack:
        return state.copyWith(
          attackBonus: state.attackBonus + 2,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
      case PartyUpgradeType.defense:
        return state.copyWith(
          defenseBonus: state.defenseBonus + 1,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
      case PartyUpgradeType.vitality:
        final healedHeroes = state.heroes
            .map(
              (hero) => hero.copyWith(
                currentHp: hero.maxHp + state.vitalityBonus + 6,
              ),
            )
            .toList();
        return state.copyWith(
          vitalityBonus: state.vitalityBonus + 6,
          heroes: healedHeroes,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
    }
  }

  static GameState unlockRelic(GameState state, String relicId) {
    final cost = relicCosts[relicId];
    if (cost == null || state.hasRelic(relicId) || state.essence < cost) {
      return state;
    }

    final unlockedRelics = List<String>.from(state.unlockedRelics)
      ..add(relicId);
    final healedHeroes = state.heroes
        .map(
          (hero) => hero.copyWith(
            currentHp: min(
              hero.currentHp,
              hero.maxHp +
                  state.totalVitalityBonus +
                  (relicId == phoenixEmberRelic ? 10 : 0),
            ),
          ),
        )
        .toList();

    return state.copyWith(
      essence: state.essence - cost,
      heroes: healedHeroes,
      unlockedRelics: unlockedRelics,
      lastUpdated: DateTime.now(),
    );
  }

  static List<LootDrop> rollLoot(int battleNumber) {
    final primaryRarity = _rarityForBattle(battleNumber);
    final drops = <LootDrop>[
      LootDrop(
        name: _lootNameForRarity(primaryRarity),
        amount: _lootAmountForRarity(primaryRarity),
        rarity: primaryRarity,
      ),
    ];

    if (battleNumber % 4 == 0) {
      drops.add(
        const LootDrop(
          name: 'Gold Pouch',
          amount: 1,
          rarity: LootRarity.common,
        ),
      );
    }

    if (battleNumber % 9 == 0) {
      drops.add(
        const LootDrop(name: 'Relic Shard', amount: 1, rarity: LootRarity.rare),
      );
    }

    if (isBossBattle(battleNumber)) {
      drops.add(
        const LootDrop(name: 'Boss Sigil', amount: 1, rarity: LootRarity.epic),
      );
    }

    return drops.take(3).toList();
  }

  static int lootEssenceValue(LootDrop drop) {
    final perItem = switch (drop.rarity) {
      LootRarity.common => 2,
      LootRarity.uncommon => 5,
      LootRarity.rare => 9,
      LootRarity.epic => 16,
    };

    return perItem * drop.amount;
  }

  static LootRarity _rarityForBattle(int battleNumber) {
    if (battleNumber % 12 == 0) {
      return LootRarity.epic;
    }
    if (battleNumber % 6 == 0) {
      return LootRarity.rare;
    }
    if (battleNumber % 3 == 0) {
      return LootRarity.uncommon;
    }
    return LootRarity.common;
  }

  static String _lootNameForRarity(LootRarity rarity) {
    switch (rarity) {
      case LootRarity.common:
        return 'Iron Scraps';
      case LootRarity.uncommon:
        return 'Hunter Token';
      case LootRarity.rare:
        return 'Ancient Core';
      case LootRarity.epic:
        return 'Mythic Crest';
    }
  }

  static int _lootAmountForRarity(LootRarity rarity) {
    switch (rarity) {
      case LootRarity.common:
        return 2;
      case LootRarity.uncommon:
        return 3;
      case LootRarity.rare:
        return 4;
      case LootRarity.epic:
        return 6;
    }
  }

  static GameState _advanceOneTick(GameState state) {
    if (state.isPartyDefeated) {
      return state.copyWith(
        heroes: state.heroes
            .map(
              (hero) =>
                  hero.copyWith(currentHp: state.effectiveHeroMaxHp(hero)),
            )
            .toList(),
        enemy: state.enemy.healToFull(),
      );
    }

    final enemyAfterHit = state.enemy.takeDamage(state.totalAttack);
    if (enemyAfterHit.isDefeated) {
      final nextBattle = state.battleNumber + 1;
      final drops = rollLoot(state.battleNumber);
      final essenceGain = drops.fold<int>(
        0,
        (sum, drop) => sum + lootEssenceValue(drop),
      );
      return state.copyWith(
        gold: state.gold + state.enemy.rewardGold,
        essence: state.essence + essenceGain,
        battleNumber: nextBattle,
        bossVictories:
            state.bossVictories + (isBossBattle(state.battleNumber) ? 1 : 0),
        enemy: createEnemy(nextBattle),
        heroes: state.heroes
            .map(
              (hero) =>
                  hero.copyWith(currentHp: state.effectiveHeroMaxHp(hero)),
            )
            .toList(),
        recentLoot: drops,
      );
    }

    final defenderIndex = state.heroes.indexWhere((hero) => hero.isAlive);
    if (defenderIndex < 0) {
      return state.copyWith(enemy: enemyAfterHit);
    }

    final defender = state.heroes[defenderIndex];
    final damageTaken = max(
      1,
      enemyAfterHit.attack - state.effectiveHeroDefense(defender),
    );
    final updatedHeroes = List<PartyHero>.from(state.heroes);
    updatedHeroes[defenderIndex] = defender.copyWith(
      currentHp: max(0, defender.currentHp - damageTaken),
    );

    return state.copyWith(heroes: updatedHeroes, enemy: enemyAfterHit);
  }
}

enum PartyUpgradeType { attack, defense, vitality }
