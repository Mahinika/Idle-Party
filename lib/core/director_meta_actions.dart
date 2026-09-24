part of 'game_director.dart';

/// Apex, relics, and quests. Menus still call these on the director.
extension GameDirectorMetaActions on GameDirector {
  void craftApex({
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
  }) {
    if (_isLoading) return;
    if (!GameLogic.canCraftApex(
      _state,
      classId: classId,
      role: role,
      slot: slot,
    )) {
      showToast('Missing mats or unlock gate', life: 1.8);
      return;
    }
    final pieceId = ApexCraft.pieceId(classId: classId, role: role, slot: slot);
    final name = ApexCraft.pieceName(classId: classId, role: role, slot: slot);
    _applyUpgrade(
      GameLogic.setApexCraftGoal(
        GameLogic.craftApex(_state, classId: classId, role: role, slot: slot),
        classId: classId,
        role: role,
        slot: slot,
      ),
    );
    GameAudio.ui();
    final equippedOnHero = _state.heroes.any(
      (h) => h.equipped.values.any((g) => g.id == pieceId),
    );
    if (equippedOnHero) {
      showToast('Crafted & equipped $name', life: 2.6);
    } else if (_state.apexVault.any((i) => i.id == pieceId)) {
      showToast('Crafted $name · try Auto Equip All', life: 2.6);
    } else {
      showToast('Crafted $name', life: 2.4);
    }
  }

  void upgradeApex(String itemId) {
    if (_isLoading) return;
    if (!GameLogic.canUpgradeApex(_state, itemId)) {
      showToast('Cannot upgrade yet', life: 1.8);
      return;
    }
    final before = GameLogic.canUpgradeApex(_state, itemId);
    _applyUpgrade(GameLogic.upgradeApex(_state, itemId));
    if (before) {
      GameAudio.ui();
      showToast('Apex upgraded', life: 2.0);
    }
  }

  void equipFromApexVault(
    String itemId, {
    int? heroIndex,
    EquipmentSlot? intoSlot,
  }) {
    if (_isLoading) return;
    final reason = GameLogic.apexEquipBlockReason(
      _state,
      itemId,
      heroIndex: heroIndex,
    );
    final before = _state.apexVault.length;
    _applyUpgrade(
      GameLogic.equipFromApexVault(
        _state,
        itemId,
        heroIndex: heroIndex,
        intoSlot: intoSlot,
      ),
    );
    if (_state.apexVault.length < before) {
      showToast('Equipped Apex', life: 1.6);
    } else {
      showToast(reason ?? 'Cannot equip Apex', life: 2.0);
    }
  }

  void autoEquipAllApex() {
    if (_isLoading) return;
    if (_state.apexVault.isEmpty) {
      showToast('Apex vault is empty', life: 1.6);
      return;
    }
    final result = GameLogic.autoEquipAllApexVault(_state);
    _applyUpgrade(result.state);
    if (result.equipped > 0) {
      GameAudio.ui();
      final skip = result.skipped > 0 ? ' · ${result.skipped} skipped' : '';
      showToast('Equipped ${result.equipped} Apex$skip', life: 2.4);
    } else {
      showToast('No Apex could equip — check party match', life: 2.2);
    }
  }

  void setApexCraftGoal({
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
  }) {
    _applyUpgrade(
      GameLogic.setApexCraftGoal(
        _state,
        classId: classId,
        role: role,
        slot: slot,
      ),
    );
  }

  void setApexTargetMat(String matId) {
    _applyUpgrade(GameLogic.setApexTargetMat(_state, matId));
  }

  void clearApexTargetMatOverride() {
    _applyUpgrade(GameLogic.clearApexTargetMatOverride(_state));
  }

  void unlockRelic(String relicId) {
    final name = GameLogic.relicNames[relicId] ?? relicId;
    final before = _state.hasRelic(relicId);
    _applyUpgrade(GameLogic.unlockRelic(_state, relicId));
    if (!before && _state.hasRelic(relicId)) {
      GameAudio.unlock();
      final pay = GameLogic.relicOwnedPayout(_state, relicId);
      showToast(
        pay.isEmpty ? 'Relic: $name' : 'Relic: $name · $pay',
        life: 2.4,
      );
    }
  }

  void claimMission(String missionId, {bool silent = false}) {
    int? goldReward;
    int? essenceReward;
    String? title;
    final beforeChain = _state.metaDepth.jobChainCount;
    final beforeEssence = _state.essence;
    for (final m in _state.missions) {
      if (m.id == missionId && m.canClaim) {
        goldReward = m.goldReward;
        essenceReward = m.essenceReward;
        title = m.title;
        break;
      }
    }
    _applyUpgrade(GameLogic.claimMission(_state, missionId));
    if (silent ||
        goldReward == null ||
        essenceReward == null ||
        title == null) {
      return;
    }
    GameAudio.loot();
    final chainBonus = _state.essence - beforeEssence - essenceReward;
    if (chainBonus > 0 ||
        (beforeChain == 2 && _state.metaDepth.jobChainCount == 0)) {
      showToast(
        '$title: +${goldReward}g +${essenceReward}e · chain +5e!',
        life: 2.8,
      );
    } else {
      showToast('$title: +${goldReward}g +${essenceReward}e', life: 2.6);
    }
  }

  /// Claims every ready quest once and toasts the count (TODAY / QUESTS sync).
  int claimAllReadyMissions() {
    if (_isLoading) return 0;
    final ready = _state.missions.where((m) => m.canClaim).toList();
    if (ready.isEmpty) return 0;
    final beforeGold = _state.gold;
    final beforeEssence = _state.essence;
    for (final m in ready) {
      claimMission(m.id, silent: true);
    }
    final claimed = ready.length;
    final gold = _state.gold - beforeGold;
    final essence = _state.essence - beforeEssence;
    GameAudio.loot();
    showToast(
      claimed == 1
          ? 'Claimed 1 quest · +${gold}g +${essence}e'
          : 'Claimed $claimed quests · +${gold}g +${essence}e',
      life: 2.4,
    );
    return claimed;
  }

  void upgradeRelicTier(String relicId) {
    final before = _state.metaDepth.relicTierOf(relicId);
    _applyUpgrade(GameLogic.upgradeRelicTier(_state, relicId));
    final after = _state.metaDepth.relicTierOf(relicId);
    if (after > before) {
      final name = GameLogic.relicNames[relicId] ?? relicId;
      GameAudio.ui();
      final pay = GameLogic.relicOwnedPayout(_state, relicId);
      showToast(
        pay.isEmpty ? '$name · Tier $after' : '$name · T$after · $pay',
        life: 2.2,
      );
    }
  }

  void salvageRelic(String relicId) {
    final before = _state.metaDepth.embers;
    _applyUpgrade(GameLogic.salvageRelic(_state, relicId));
    if (_state.metaDepth.embers != before || !_state.hasRelic(relicId)) {
      GameAudio.ui();
      final back = _state.metaDepth.embers - before;
      showToast(
        back > 0 ? 'Salvaged · +$back Embers' : 'Salvaged',
        life: 2.2,
      );
    }
  }

  void exchangeCinders() {
    final before = _state.metaDepth.embers;
    _applyUpgrade(GameLogic.exchangeCinders(_state));
    if (_state.metaDepth.embers > before) {
      GameAudio.ui();
      showToast('4 Cinders → 1 Ember', life: 2.0);
    }
  }

  void buyCinderWithTickets() {
    final before = _state.metaDepth.cinders;
    _applyUpgrade(GameLogic.buyCinderWithTickets(_state));
    if (_state.metaDepth.cinders > before) {
      GameAudio.ui();
      showToast('2 tickets → 1 Cinder', life: 2.0);
    }
  }
}
