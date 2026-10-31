part of 'game_logic.dart';

int _gameLogicForgeTrackTier(GameState state, PartyUpgradeType type) {
  return switch (type) {
    PartyUpgradeType.attack => state.attackBonus ~/ GameLogic.forgeAttackGain,
    PartyUpgradeType.defense => state.defenseBonus ~/ GameLogic.forgeDefenseGain,
    PartyUpgradeType.vitality => state.vitalityBonus ~/ GameLogic.forgeVitalityGain,
    PartyUpgradeType.moveSpeed => state.moveSpeedBonus ~/ GameLogic.forgeMoveGain,
    PartyUpgradeType.attackSpeed => state.attackSpeedBonus ~/ GameLogic.forgeHasteGain,
    PartyUpgradeType.crit => state.critBonus ~/ GameLogic.forgeCritGain,
    PartyUpgradeType.mastery => state.masteryBonus ~/ GameLogic.forgeMasteryGain,
  };
}


int _gameLogicUpgradeCostFor(GameState state, PartyUpgradeType type) {
  return 18 +
      (_gameLogicForgeTrackTier(state, type) * 10) +
      (state.bossVictories * 5) +
      (state.ascensionLevel * 25);
}


int _gameLogicForgeGoldBudget(GameState state, ForgeGoldSpendMode mode) {
  return switch (mode) {
    ForgeGoldSpendMode.one => 0,
    ForgeGoldSpendMode.pct5 => (state.gold * 5) ~/ 100,
    ForgeGoldSpendMode.pct25 => (state.gold * 25) ~/ 100,
    ForgeGoldSpendMode.pct50 => (state.gold * 50) ~/ 100,
    ForgeGoldSpendMode.pct100 => state.gold,
  };
}


bool _gameLogicCanForgeGoldSpend( GameState state, PartyUpgradeType type, ForgeGoldSpendMode mode, ) {
  final cost = _gameLogicUpgradeCostFor(state, type);
  if (state.gold < cost) {
    return false;
  }
  if (mode == ForgeGoldSpendMode.one) {
    return true;
  }
  return _gameLogicForgeGoldBudget(state, mode) >= cost;
}


bool _gameLogicCanForgeGoldSpendEven(GameState state) {
  for (final type in PartyUpgradeType.values) {
    if (state.gold >= _gameLogicUpgradeCostFor(state, type)) {
      return true;
    }
  }
  return false;
}


({int buys, int spent}) _gameLogicPreviewForgeGoldSpend( GameState state, PartyUpgradeType type, ForgeGoldSpendMode mode, ) {
  if (mode == ForgeGoldSpendMode.one) {
    final cost = _gameLogicUpgradeCostFor(state, type);
    if (state.gold < cost) {
      return (buys: 0, spent: 0);
    }
    return (buys: 1, spent: cost);
  }
  final budget = _gameLogicForgeGoldBudget(state, mode);
  var remaining = min(budget, state.gold);
  var cur = state;
  var buys = 0;
  var spent = 0;
  for (var i = 0; i < 10000; i++) {
    final cost = _gameLogicUpgradeCostFor(cur, type);
    if (cost > remaining || cost > cur.gold) {
      break;
    }
    final next = _gameLogicForgeApplyUpgrade(cur, type: type);
    if (identical(next, cur)) {
      break;
    }
    remaining -= cost;
    spent += cost;
    buys += 1;
    cur = next;
  }
  return (buys: buys, spent: spent);
}


GameState _gameLogicUpgradeWithSpendMode( GameState state, { required PartyUpgradeType type, required ForgeGoldSpendMode mode, }) {
  if (mode == ForgeGoldSpendMode.one) {
    return _gameLogicForgeApplyUpgrade(state, type: type);
  }
  final budget = _gameLogicForgeGoldBudget(state, mode);
  if (budget <= 0) {
    return state;
  }
  return _gameLogicUpgradeWithBudget(state, type: type, budget: budget);
}


GameState _gameLogicUpgradeWithBudget( GameState state, { required PartyUpgradeType type, required int budget, }) {
  var remaining = min(budget, state.gold);
  var cur = state;
  for (var i = 0; i < 10000; i++) {
    final cost = _gameLogicUpgradeCostFor(cur, type);
    if (cost > remaining || cost > cur.gold) {
      break;
    }
    final next = _gameLogicForgeApplyUpgrade(cur, type: type);
    if (identical(next, cur)) {
      break;
    }
    remaining -= cost;
    cur = next;
  }
  return cur;
}


GameState _gameLogicUpgradeSpendAllEvenly(GameState state) {
  var cur = state;
  for (var round = 0; round < 10000; round++) {
    var bought = false;
    for (final type in PartyUpgradeType.values) {
      final cost = _gameLogicUpgradeCostFor(cur, type);
      if (cur.gold < cost) {
        continue;
      }
      final next = _gameLogicForgeApplyUpgrade(cur, type: type);
      if (!identical(next, cur)) {
        cur = next;
        bought = true;
      }
    }
    if (!bought) {
      break;
    }
  }
  return cur;
}


GameState _gameLogicUpgradeAttack(GameState state) => _gameLogicForgeApplyUpgrade(state, type: PartyUpgradeType.attack);


GameState _gameLogicUpgradeDefense(GameState state) => _gameLogicForgeApplyUpgrade(state, type: PartyUpgradeType.defense);


GameState _gameLogicUpgradeVitality(GameState state) => _gameLogicForgeApplyUpgrade(state, type: PartyUpgradeType.vitality);


GameState _gameLogicUpgradeMoveSpeed(GameState state) => _gameLogicForgeApplyUpgrade(state, type: PartyUpgradeType.moveSpeed);


GameState _gameLogicUpgradeAttackSpeed(GameState state) => _gameLogicForgeApplyUpgrade(state, type: PartyUpgradeType.attackSpeed);


GameState _gameLogicUpgradeCrit(GameState state) => _gameLogicForgeApplyUpgrade(state, type: PartyUpgradeType.crit);


GameState _gameLogicUpgradeMastery(GameState state) => _gameLogicForgeApplyUpgrade(state, type: PartyUpgradeType.mastery);


GameState _gameLogicForgeApplyUpgrade( GameState state, { required PartyUpgradeType type, }) {
  final cost = _gameLogicUpgradeCostFor(state, type);
  if (state.gold < cost) {
    return state;
  }

  switch (type) {
    case PartyUpgradeType.attack:
      return state.copyWith(
        attackBonus: state.attackBonus + GameLogic.forgeAttackGain,
        gold: state.gold - cost,
        lastUpdated: DateTime.now(),
      );
    case PartyUpgradeType.defense:
      return state.copyWith(
        defenseBonus: state.defenseBonus + GameLogic.forgeDefenseGain,
        gold: state.gold - cost,
        lastUpdated: DateTime.now(),
      );
    case PartyUpgradeType.vitality:
      final nextVit = state.vitalityBonus + GameLogic.forgeVitalityGain;
      final probe = state.copyWith(vitalityBonus: nextVit);
      final healedHeroes = state.heroes
          .map(
            (hero) =>
                hero.copyWith(currentHp: probe.effectiveHeroMaxHp(hero)),
          )
          .toList();
      return state.copyWith(
        vitalityBonus: nextVit,
        heroes: healedHeroes,
        gold: state.gold - cost,
        lastUpdated: DateTime.now(),
      );
    case PartyUpgradeType.moveSpeed:
      return state.copyWith(
        moveSpeedBonus: state.moveSpeedBonus + GameLogic.forgeMoveGain,
        gold: state.gold - cost,
        lastUpdated: DateTime.now(),
      );
    case PartyUpgradeType.attackSpeed:
      return state.copyWith(
        attackSpeedBonus: state.attackSpeedBonus + GameLogic.forgeHasteGain,
        gold: state.gold - cost,
        lastUpdated: DateTime.now(),
      );
    case PartyUpgradeType.crit:
      return state.copyWith(
        critBonus: state.critBonus + GameLogic.forgeCritGain,
        gold: state.gold - cost,
        lastUpdated: DateTime.now(),
      );
    case PartyUpgradeType.mastery:
      return state.copyWith(
        masteryBonus: state.masteryBonus + GameLogic.forgeMasteryGain,
        gold: state.gold - cost,
        lastUpdated: DateTime.now(),
      );
  }
}


