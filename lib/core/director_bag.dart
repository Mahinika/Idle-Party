part of 'game_director.dart';

/// Bag equip, merge, and cleanup. Menus still call these on the director.
extension GameDirectorBag on GameDirector {
  void combineGear({required String primaryId, required String secondaryId}) {
    final primary = GameLogic.findStashGear(_state, primaryId);
    final secondary = GameLogic.findStashGear(_state, secondaryId);
    final beforeGold = _state.gold;
    final preview = primary != null && secondary != null
        ? GameLogic.previewCombine(primary, secondary)
        : null;
    _applyUpgrade(
      GameLogic.combineGear(
        _state,
        primaryId: primaryId,
        secondaryId: secondaryId,
      ),
    );
    if (preview == null || _state.gold >= beforeGold || primary == null) {
      return;
    }
    GameAudio.loot();
    final delta = preview.powerScore - primary.powerScore;
    showToast(
      delta > 0
          ? 'Merged ${preview.name} · i${preview.effectiveItemLevel} · SCORE +$delta'
          : 'Merged ${preview.name} · i${preview.effectiveItemLevel}',
      life: 2.4,
    );
  }

  void equipFromStash(
    String itemId, {
    int heroIndex = 0,
    EquipmentSlot? intoSlot,
  }) {
    _applyUpgrade(
      GameLogic.equipFromStash(
        _state,
        itemId,
        heroIndex: heroIndex,
        intoSlot: intoSlot,
      ),
    );
  }

  EquipFromStashResult equipSelectedFromStash(
    String id, {
    required int heroIndex,
  }) {
    if (!_state.gearStash.any((g) => g.id == id)) {
      showToast('Already worn — use UNEQUIP, or pick a BAG item', life: 2.4);
      return EquipFromStashResult.notInStash;
    }
    final item = GameLogic.findGear(_state, id);
    EquipmentSlot? into;
    if (item != null && heroIndex >= 0 && heroIndex < _state.heroes.length) {
      into = GameLogic.compareForHero(
        _state.heroes[heroIndex],
        item,
        pairingStash: _state.gearStash,
      ).intoSlot;
    }
    final beforeIds = _state.gearStash.map((g) => g.id).toSet();
    equipFromStash(id, heroIndex: heroIndex, intoSlot: into);
    final equipped =
        !_state.gearStash.any((g) => g.id == id) && beforeIds.contains(id);
    if (!equipped) {
      showToast('Cannot equip on that hero (class / level / slot)', life: 2.6);
      return EquipFromStashResult.cannotEquip;
    }
    return EquipFromStashResult.equipped;
  }

  void autoEquipBetterGear() {
    final result = GameLogic.autoEquipBetterGearResult(_state);
    _applyUpgrade(result.state);
    if (result.equipped > 0) {
      showToast(
        result.equipped == 1
            ? 'Equipped 1 upgrade'
            : 'Equipped ${result.equipped} upgrades',
        life: 1.8,
      );
    } else {
      showToast('No upgrades in bag', life: 1.5);
    }
  }

  // —— Bag cleanup ——————————————————————————————————————————————
  /// Merge → sell gold → disassemble essence (bag cleanup / near-full).
  void cleanBagJunk() {
    final beforeLen = _state.gearStash.length;
    final beforeGold = _state.gold;
    final beforeEss = _state.essence;
    final unstick = GearService.isBagJammed(_state);
    _applyUpgrade(
      GameLogic.cleanBagJunk(
        _state,
        unstickBag: unstick,
        mergeFirst: true,
        manualClean: true,
      ),
    );
    LogicNotices.takeBagCleanup(); // reported below, not as a second toast
    final cleared = beforeLen - _state.gearStash.length;
    final gold = _state.gold - beforeGold;
    final ess = _state.essence - beforeEss;
    if (cleared > 0) {
      final bits = <String>[if (gold > 0) '+${gold}g', if (ess > 0) '+${ess}e'];
      showToast(
        bits.isEmpty
            ? 'Cleaned $cleared junk'
            : 'Cleaned $cleared · ${bits.join(' · ')}',
        life: 1.9,
      );
    } else {
      showToast('No junk for sell/disassemble filters', life: 1.5);
    }
  }

  /// Merge junk bag pairs (same slot, not BiS/upgrades) while gold lasts.
  void autoMergeJunk() {
    final kept = GameLogic.autoMergeKeptCount(_state);
    final sample = GameLogic.autoMergeKeptNames(_state);
    final result = GameLogic.autoMergeJunk(_state);
    if (result.merges <= 0) {
      if (kept > 0 && sample.isNotEmpty) {
        final tail = kept > sample.length ? ' +${kept - sample.length}' : '';
        showToast('No pairs — kept ${sample.join(', ')}$tail', life: 2.2);
      } else {
        showToast('No junk pairs to merge', life: 1.5);
      }
      return;
    }
    _applyUpgrade(result.state);
    var msg = result.merges == 1
        ? 'Auto-merged 1 pair'
        : 'Auto-merged ${result.merges} pairs';
    if (kept > 0 && sample.isNotEmpty) {
      final tail = kept > sample.length ? ' +${kept - sample.length}' : '';
      msg += ' · skipped ${sample.join(', ')}$tail';
    }
    showToast(msg, life: 2.2);
  }

  void unequipSlot(EquipmentSlot slot, {int heroIndex = 0}) {
    _applyUpgrade(GameLogic.unequipSlot(_state, slot, heroIndex: heroIndex));
  }
}
