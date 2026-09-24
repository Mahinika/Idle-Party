part of 'game_director.dart';

/// Gold forge tracks. Menus still call these on the director.
extension GameDirectorForge on GameDirector {
  void applyTraining() {
    // Gold Train removed — levels come from combat XP only (cap maxHeroLevel).
  }

  void upgradeAttack({ForgeGoldSpendMode mode = ForgeGoldSpendMode.one}) {
    _upgradePartyTrack(PartyUpgradeType.attack, mode: mode);
  }

  void upgradeDefense({ForgeGoldSpendMode mode = ForgeGoldSpendMode.one}) {
    _upgradePartyTrack(PartyUpgradeType.defense, mode: mode);
  }

  void upgradeVitality({ForgeGoldSpendMode mode = ForgeGoldSpendMode.one}) {
    _upgradePartyTrack(PartyUpgradeType.vitality, mode: mode);
  }

  void upgradeMoveSpeed({ForgeGoldSpendMode mode = ForgeGoldSpendMode.one}) {
    _upgradePartyTrack(PartyUpgradeType.moveSpeed, mode: mode);
  }

  void upgradeAttackSpeed({ForgeGoldSpendMode mode = ForgeGoldSpendMode.one}) {
    _upgradePartyTrack(PartyUpgradeType.attackSpeed, mode: mode);
  }

  void upgradeCrit({ForgeGoldSpendMode mode = ForgeGoldSpendMode.one}) {
    _upgradePartyTrack(PartyUpgradeType.crit, mode: mode);
  }

  void upgradePartyTrack(
    PartyUpgradeType type, {
    ForgeGoldSpendMode mode = ForgeGoldSpendMode.one,
  }) {
    _upgradePartyTrack(type, mode: mode);
  }

  void upgradeSpendAllEvenly() {
    if (_isLoading) {
      return;
    }
    final beforeRec = GameLogic.recommendedForgeUpgrade(_state);
    final beforeAtk = _state.attackBonus;
    final beforeMove = _state.moveSpeedBonus;
    final beforeHaste = _state.attackSpeedBonus;
    final updated = GameLogic.upgradeSpendAllEvenly(_state);
    if (identical(updated, _state)) {
      return;
    }
    _applyUpgrade(updated);
    final afterRec = GameLogic.recommendedForgeUpgrade(_state);
    if (afterRec != beforeRec) {
      final name = GameDirector._forgeTrackShort(PartyUpgradeType.values[afterRec]);
      showToast('BEST is now $name', life: 2.0);
    } else if (_state.attackBonus > beforeAtk ||
        _state.moveSpeedBonus > beforeMove ||
        _state.attackSpeedBonus > beforeHaste) {
      showToast('Gold spent evenly', life: 2.0);
    }
  }

  void _upgradePartyTrack(
    PartyUpgradeType type, {
    required ForgeGoldSpendMode mode,
  }) {
    if (_isLoading) {
      return;
    }
    final beforeRec = GameLogic.recommendedForgeUpgrade(_state);
    final beforeAtk = _state.attackBonus;
    final beforeMove = _state.moveSpeedBonus;
    final beforeHaste = _state.attackSpeedBonus;
    final updated = GameLogic.upgradeWithSpendMode(
      _state,
      type: type,
      mode: mode,
    );
    if (identical(updated, _state)) {
      return;
    }
    _applyUpgrade(updated);
    final afterRec = GameLogic.recommendedForgeUpgrade(_state);
    if (afterRec != beforeRec) {
      final name = GameDirector._forgeTrackShort(PartyUpgradeType.values[afterRec]);
      showToast('BEST is now $name', life: 2.0);
      return;
    }
    if (type == PartyUpgradeType.attack && _state.attackBonus > beforeAtk) {
      showToast(_forgeSpeedToast('ATK'), life: 2.0);
    } else if (type == PartyUpgradeType.moveSpeed &&
        _state.moveSpeedBonus > beforeMove) {
      showToast(_forgeSpeedToast('MOVE'), life: 2.0);
    } else if (type == PartyUpgradeType.attackSpeed &&
        _state.attackSpeedBonus > beforeHaste) {
      showToast(_forgeSpeedToast('HASTE'), life: 2.0);
    }
  }
}
