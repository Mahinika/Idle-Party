import 'dart:math';

import '../models/apex_craft.dart';
import '../models/dungeon_mode.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/proficiency.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'gear_service.dart';
import 'keystone.dart';
import 'logic_notices.dart';
import 'meta_systems.dart';

/// Apex weapons and the soulbound item: the two pieces of gear that survive.
///
/// Boss-only mats with pity (farm loops are diluted on purpose), crafting,
/// rank upgrades, and the vault that keeps an Apex through Ascend.
abstract final class ApexForge {
  static int craftMatCount(GameState state, String matId) =>
      state.craftMaterials[matId] ?? 0;

  static bool canAffordCraftCosts(GameState state, Map<String, int> costs) {
    for (final e in costs.entries) {
      if (craftMatCount(state, e.key) < e.value) return false;
    }
    return true;
  }

  static GameState _spendCraftMats(GameState state, Map<String, int> costs) {
    final next = Map<String, int>.from(state.craftMaterials);
    for (final e in costs.entries) {
      final left = (next[e.key] ?? 0) - e.value;
      if (left <= 0) {
        next.remove(e.key);
      } else {
        next[e.key] = left;
      }
    }
    return state.copyWith(craftMaterials: next);
  }

  static GameState _addCraftMat(GameState state, String matId, [int qty = 1]) {
    final next = Map<String, int>.from(state.craftMaterials);
    next[matId] = (next[matId] ?? 0) + qty;
    return state.copyWith(craftMaterials: next);
  }

  /// Boss-only craft mat grants with soft/hard pity. Farm loops are diluted.
  static GameState grantBossCraftMats(
    GameState state, {
    required bool clearedBoss,
  }) {
    LogicNotices.startCraftMats();
    if (!clearedBoss) return state;

    final farm = state.dungeonMode == DungeonMode.farm;
    final weight = farm ? ApexCraft.farmPityWeight : 1.0;
    var pity = Map<String, int>.from(state.craftPity);
    var next = state;

    void bumpPity(String key, double amount) {
      final add = max(1, (amount * 10).round()); // store tenths for dilution
      pity[key] = (pity[key] ?? 0) + add;
    }

    int pityUnits(String key) => pity[key] ?? 0;

    bool rollFamily({
      required String pityKey,
      required double pBase,
      required String matId,
      required double weightMul,
    }) {
      final units = pityUnits(pityKey);
      // Convert tenths back to boss-equivalent streak.
      final streak = (units / 10).floor();
      final chance = ApexCraft.pityChance(streak, pBase: pBase) * weightMul;
      final hit = chance >= 1.0 || GameLogic.random.nextDouble() < chance;
      if (hit) {
        next = _addCraftMat(next, matId);
        LogicNotices.addCraftMat(matId);
        pity[pityKey] = 0;
        return true;
      }
      bumpPity(pityKey, weight);
      return false;
    }

    // Zone shard
    final shardId = ApexCraft.shardIdForDungeon(state.dungeonId);
    if (ApexCraft.materialsById.containsKey(shardId)) {
      rollFamily(
        pityKey: 'pity_$shardId',
        pBase: ApexCraft.shardPBase,
        matId: shardId,
        weightMul: 1.0,
      );
    } else {
      bumpPity('pity_$shardId', weight);
    }

    // Role core — bias toward party roles
    final roleWeights = <SpecRoleTag, int>{
      for (final r in SpecRoleTag.values) r: 1,
    };
    for (final h in state.heroes) {
      roleWeights[h.spec.roleTag] = (roleWeights[h.spec.roleTag] ?? 1) + 3;
    }
    var rolePick = SpecRoleTag.meleeDps;
    var total = roleWeights.values.fold<int>(0, (s, v) => s + v);
    var roll = GameLogic.random.nextInt(max(1, total));
    for (final e in roleWeights.entries) {
      roll -= e.value;
      if (roll < 0) {
        rolePick = e.key;
        break;
      }
    }
    final coreId = ApexCraft.coreIdForRole(rolePick);
    rollFamily(
      pityKey: 'pity_$coreId',
      pBase: ApexCraft.corePBase,
      matId: coreId,
      weightMul: 1.0,
    );

    // Class catalyst — bias toward party classes
    final classWeights = <HeroClassId, int>{
      for (final c in HeroClassId.values) c: 1,
    };
    for (final h in state.heroes) {
      classWeights[h.spec.classId] = (classWeights[h.spec.classId] ?? 1) + 4;
    }
    var classPick = HeroClassId.warrior;
    total = classWeights.values.fold<int>(0, (s, v) => s + v);
    roll = GameLogic.random.nextInt(max(1, total));
    for (final e in classWeights.entries) {
      roll -= e.value;
      if (roll < 0) {
        classPick = e.key;
        break;
      }
    }
    final catId = ApexCraft.catalystIdForClass(classPick);
    rollFamily(
      pityKey: 'pity_$catId',
      pBase: ApexCraft.catalystPBase,
      matId: catId,
      weightMul: farm ? 0.5 : 1.0,
    );

    // Apex slag — gauntlet / crystal only
    if (state.inGauntlet || state.dungeonId == 'crystal') {
      rollFamily(
        pityKey: 'pity_apex_slag',
        pBase: ApexCraft.slagPBase,
        matId: 'apex_slag',
        weightMul: state.inGauntlet ? 1.25 : 1.0,
      );
    }

    // Keystone / challenge slight pity acceleration (still boss-gated).
    final keyCombat = Keystone.combatLevel(state);
    if (keyCombat > 0 || state.challengeBossRush || state.challengeNoFlask) {
      for (final key in pity.keys.toList()) {
        if ((pity[key] ?? 0) > 0) {
          pity[key] = pity[key]! + (farm ? 1 : 2);
        }
      }
    }

    return next.copyWith(craftPity: pity, lastUpdated: DateTime.now());
  }

  static bool hasApexWeaponRank1(
    GameState state,
    HeroClassId classId,
    SpecRoleTag role,
  ) {
    final id = ApexCraft.pieceId(
      classId: classId,
      role: role,
      slot: EquipmentSlot.weapon,
    );
    return _findApexItem(state, id) != null;
  }

  static EquipmentItem? _findApexItem(GameState state, String itemId) {
    for (final h in state.heroRoster) {
      for (final item in h.equipped.values) {
        if (item.id == itemId && item.isApex) return item;
      }
    }
    for (final item in state.apexVault) {
      if (item.id == itemId) return item;
    }
    for (final item in state.gearStash) {
      if (item.id == itemId && item.isApex) return item;
    }
    return null;
  }

  static bool canCraftApex(
    GameState state, {
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
  }) {
    if (!ApexCraft.isValidPair(classId, role)) return false;
    if (!ApexCraft.craftSlots.contains(slot)) return false;
    if (_findApexItem(
          state,
          ApexCraft.pieceId(classId: classId, role: role, slot: slot),
        ) !=
        null) {
      return false;
    }
    if (slot != EquipmentSlot.weapon &&
        !hasApexWeaponRank1(state, classId, role)) {
      return false;
    }
    final costs = ApexCraft.absoluteCost(
      classId: classId,
      role: role,
      slot: slot,
      rank: 1,
    );
    return canAffordCraftCosts(state, costs);
  }

  static GameState craftApex(
    GameState state, {
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
  }) {
    if (!canCraftApex(state, classId: classId, role: role, slot: slot)) {
      return state;
    }
    final costs = ApexCraft.absoluteCost(
      classId: classId,
      role: role,
      slot: slot,
      rank: 1,
    );
    var next = _spendCraftMats(state, costs);
    final item = ApexCraft.buildItem(
      classId: classId,
      role: role,
      slot: slot,
      rank: 1,
      ascensionLevel: state.ascensionLevel,
    );
    next = next.copyWith(
      apexVault: [...next.apexVault, item],
      lastUpdated: DateTime.now(),
    );
    return MetaSystems.evaluateAchievements(next);
  }

  static bool canUpgradeApex(GameState state, String itemId) {
    final item = _findApexItem(state, itemId);
    if (item == null || !item.isApex) return false;
    if (item.apexRank >= ApexCraft.maxRank) return false;
    final classId = HeroClassId.values.byName(item.apexClassId!);
    final role = SpecRoleTag.values.byName(item.apexRoleTag!);
    final costs = ApexCraft.upgradeDeltaCost(
      classId: classId,
      role: role,
      slot: item.slot,
      fromRank: item.apexRank,
      toRank: item.apexRank + 1,
    );
    return canAffordCraftCosts(state, costs);
  }

  static GameState upgradeApex(GameState state, String itemId) {
    if (!canUpgradeApex(state, itemId)) return state;
    final item = _findApexItem(state, itemId)!;
    final classId = HeroClassId.values.byName(item.apexClassId!);
    final role = SpecRoleTag.values.byName(item.apexRoleTag!);
    final nextRank = item.apexRank + 1;
    final costs = ApexCraft.upgradeDeltaCost(
      classId: classId,
      role: role,
      slot: item.slot,
      fromRank: item.apexRank,
      toRank: nextRank,
    );
    var next = _spendCraftMats(state, costs);
    final upgraded = ApexCraft.buildItem(
      classId: classId,
      role: role,
      slot: item.slot,
      rank: nextRank,
      ascensionLevel: state.ascensionLevel,
    ).copyWith(id: item.id);

    // Replace in vault / equipped / stash
    final vaultIdx = next.apexVault.indexWhere((e) => e.id == itemId);
    if (vaultIdx >= 0) {
      final vault = [...next.apexVault];
      vault[vaultIdx] = upgraded;
      return MetaSystems.evaluateAchievements(
        next.copyWith(apexVault: vault, lastUpdated: DateTime.now()),
      );
    }
    for (var i = 0; i < next.heroRoster.length; i++) {
      final hero = next.heroRoster[i];
      for (final e in hero.equipped.entries) {
        if (e.value.id == itemId) {
          final gear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped);
          gear[e.key] = upgraded;
          final roster = [...next.heroRoster];
          roster[i] = hero.copyWith(equipped: gear);
          return MetaSystems.evaluateAchievements(
            next.copyWith(heroRoster: roster, lastUpdated: DateTime.now()),
          );
        }
      }
    }
    final stashIdx = next.gearStash.indexWhere((e) => e.id == itemId);
    if (stashIdx >= 0) {
      final stash = [...next.gearStash];
      stash[stashIdx] = upgraded;
      return MetaSystems.evaluateAchievements(
        next.copyWith(gearStash: stash, lastUpdated: DateTime.now()),
      );
    }
    return state;
  }

  static GameState equipFromApexVault(
    GameState state,
    String itemId, {
    int heroIndex = 0,
    EquipmentSlot? intoSlot,
  }) {
    if (heroIndex < 0 || heroIndex >= state.heroes.length) return state;
    EquipmentItem? item;
    for (final candidate in state.apexVault) {
      if (candidate.id == itemId) {
        item = candidate;
        break;
      }
    }
    if (item == null) return state;

    final targetSlot = intoSlot ?? item.slot;
    if (!GearService.equipTargetsFor(item).contains(targetSlot)) return state;
    final heroCheck = state.heroes[heroIndex];
    if (!GearService.canHeroReceive(heroCheck, item, slot: targetSlot)) return state;

    final equippedItem = item.slot == targetSlot
        ? item
        : item.copyWith(slot: targetSlot);
    var next = state.copyWith(
      apexVault: state.apexVault.where((g) => g.id != itemId).toList(),
    );
    final hero = next.heroes[heroIndex];
    final prev = hero.itemIn(targetSlot);
    final gear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped);
    gear[targetSlot] = equippedItem;
    // 2H weapon clears off-hand into vault if apex / stash otherwise
    if (targetSlot == EquipmentSlot.weapon &&
        ClassProficiency.weaponBlocksOffHand(equippedItem)) {
      final off = gear.remove(EquipmentSlot.offHand);
      if (off != null) {
        if (off.isApex) {
          next = next.copyWith(apexVault: [...next.apexVault, off]);
        } else {
          next = next.copyWith(gearStash: [...next.gearStash, off]);
        }
      }
    }
    var vault = List<EquipmentItem>.from(next.apexVault);
    if (prev != null) {
      if (prev.isApex) {
        vault = [...vault, prev];
      } else {
        next = next.copyWith(gearStash: [...next.gearStash, prev]);
      }
    }
    final roster = [...next.heroRoster];
    final ri = roster.indexWhere((h) => h.id == hero.id);
    if (ri < 0) return state;
    roster[ri] = hero.copyWith(equipped: gear);
    return next.copyWith(
      heroRoster: roster,
      apexVault: vault,
      lastUpdated: DateTime.now(),
    );
  }

  static Map<EquipmentSlot, EquipmentItem> keepApexOnly(PartyHero h) => {
    for (final e in h.equipped.entries)
      if (e.value.isApex) e.key: e.value,
  };

  /// Bind an equipped weapon (or armor when preferred) into the permanent
  /// soulbound slot.
  static GameState bindSoulbound(GameState state, {int? heroIndex}) {
    if (state.soulboundFragments < 3) {
      return state;
    }
    final preferArmor = state.metaDepth.soulboundIsArmor;
    final preferredSlots = preferArmor
        ? <EquipmentSlot>[EquipmentSlot.chest, EquipmentSlot.cloak]
        : <EquipmentSlot>[EquipmentSlot.weapon];
    final fallbackSlots = preferArmor
        ? <EquipmentSlot>[EquipmentSlot.weapon]
        : <EquipmentSlot>[EquipmentSlot.chest, EquipmentSlot.cloak];

    var sourceIndex = heroIndex;
    EquipmentItem? piece;
    EquipmentSlot? pieceSlot;

    EquipmentItem? findOnHero(int i, List<EquipmentSlot> slots) {
      for (final slot in slots) {
        final candidate = state.heroes[i].itemIn(slot);
        if (candidate != null) return candidate;
      }
      return null;
    }

    EquipmentSlot? slotOf(PartyHero hero, EquipmentItem item) {
      for (final e in hero.equipped.entries) {
        if (e.value.id == item.id) return e.key;
      }
      return null;
    }

    if (sourceIndex != null &&
        sourceIndex >= 0 &&
        sourceIndex < state.heroes.length) {
      piece =
          findOnHero(sourceIndex, preferredSlots) ??
          findOnHero(sourceIndex, fallbackSlots);
      if (piece != null) {
        pieceSlot = slotOf(state.heroes[sourceIndex], piece);
      }
    }
    // Fall back to any hero if the selected one has nothing bindable.
    if (piece == null) {
      for (var i = 0; i < state.heroes.length; i++) {
        piece = findOnHero(i, preferredSlots);
        if (piece != null) {
          sourceIndex = i;
          pieceSlot = slotOf(state.heroes[i], piece);
          break;
        }
      }
    }
    if (piece == null) {
      for (var i = 0; i < state.heroes.length; i++) {
        piece = findOnHero(i, fallbackSlots);
        if (piece != null) {
          sourceIndex = i;
          pieceSlot = slotOf(state.heroes[i], piece);
          break;
        }
      }
    }
    if (piece == null || sourceIndex == null || pieceSlot == null) {
      return state;
    }
    final isArmor =
        pieceSlot == EquipmentSlot.chest || pieceSlot == EquipmentSlot.cloak;
    final bound = piece.copyWith(
      id: 'soulbound_${piece.id}',
      name: 'Soulbound ${piece.name}',
    );
    final hero = state.heroes[sourceIndex];
    final nextHeroGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
      ..remove(pieceSlot);
    final heroes = [...state.heroes];
    heroes[sourceIndex] = hero.copyWith(equipped: nextHeroGear);
    return state.copyWith(
      heroes: heroes,
      equipped: const <EquipmentSlot, EquipmentItem>{},
      soulboundItem: bound,
      soulboundFragments: state.soulboundFragments - 3,
      metaDepth: state.metaDepth.copyWith(soulboundIsArmor: isArmor),
      lastUpdated: DateTime.now(),
    );
  }

  /// Spend soulbound fragments to refine the bound piece (+1 refine).
  static int refineSoulboundCost(int refineLevel) => 2 + (refineLevel ~/ 3);

  static GameState refineSoulbound(GameState state) {
    if (state.soulboundItem == null) return state;
    final cost = refineSoulboundCost(state.metaDepth.soulboundRefine);
    if (state.soulboundFragments < cost) return state;
    return state.copyWith(
      soulboundFragments: state.soulboundFragments - cost,
      metaDepth: state.metaDepth.copyWith(
        soulboundRefine: state.metaDepth.soulboundRefine + 1,
      ),
      lastUpdated: DateTime.now(),
    );
  }

  static GameState setSoulboundPreferArmor(GameState state, bool preferArmor) {
    if (state.metaDepth.soulboundIsArmor == preferArmor) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(soulboundIsArmor: preferArmor),
      lastUpdated: DateTime.now(),
    );
  }
}
