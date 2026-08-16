import 'dart:math';

import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import 'dungeon_generator.dart';
import 'equipment_factory.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'keystone.dart';

/// What a kill, a chest or a cleared floor is worth, and the item it rolls.
///
/// Everything here answers one question — *what dropped* — and hands the
/// result to [GearService] to decide where it goes. Kept separate from the
/// bag so drop rates can be read (and balanced) without scrolling past
/// equip rules.
abstract final class LootPipeline {
  /// Gold granted by a Gold Pouch drop ([LootDrop.amount] is the base gold).
  static int goldPouchBaseGold(int battleNumber) =>
      20 + max(1, battleNumber) * 5;

  static bool isWalletGoldDrop(LootDrop drop) {
    if (drop.equipment != null) return false;
    final n = drop.name.toLowerCase();
    return n.contains('gold pouch') || n.contains('coin pouch');
  }

  /// Per-kill loot: gear (or Faded Dust). No room fillers — those are
  /// [rollFloorClearLoot] once per clear.
  static List<LootDrop> rollKillLoot(
    int battleNumber, {
    int ascensionLevel = 0,
    int lootFindPercent = 0,
    int hardmodeLevel = 0,
    List<PartyHero>? party,
    String dungeonId = 'sandy',
    EnemyRole enemyRole = EnemyRole.normal,
  }) {
    final hm = hardmodeLevel.clamp(0, Keystone.maxLevel);
    final roleSkipRelief = switch (enemyRole) {
      EnemyRole.boss => 0.25,
      EnemyRole.elite => 0.12,
      EnemyRole.normal => 0.0,
    };

    // AL drop penalty: chance to skip gear entirely (pets / HM / elites blunt).
    final skipChance =
        (ascensionLevel * GameLogic.ascensionDropPenalty -
                lootFindPercent / 100.0 -
                hm * 0.012 -
                roleSkipRelief)
            .clamp(0.0, 0.55);
    if (GameLogic.random.nextDouble() < skipChance) {
      return <LootDrop>[
        const LootDrop(
          name: 'Faded Dust',
          amount: 1,
          rarity: LootRarity.common,
        ),
      ];
    }

    var primaryRarity = _rarityForBattle(battleNumber, hardmodeLevel: hm);
    final rarityBumps = switch (enemyRole) {
      EnemyRole.boss => 2,
      EnemyRole.elite => 1,
      EnemyRole.normal => 0,
    };
    for (var i = 0; i < rarityBumps; i++) {
      if (primaryRarity.index < LootRarity.values.length - 1) {
        primaryRarity = LootRarity.values[primaryRarity.index + 1];
      }
    }

    final slots = EquipmentSlot.values
        .where((s) => s != EquipmentSlot.consumable)
        .toList();

    (
      HeroRole bias,
      ArmorType? preferred,
      SpecRoleTag? roleTag,
      HeroSpecId? specId,
    )
    pickBias() {
      final target = _lootTargetHero(party);
      if (target != null) {
        return (
          // Naming + affix pool follow gearAffinity (Enh→rogue, Holy→healer).
          target.spec.gearAffinity,
          GameLogic.preferredArmorForSpec(target.spec, max(1, battleNumber)),
          target.spec.roleTag,
          target.specId,
        );
      }
      return (
        HeroRole.values[GameLogic.random.nextInt(HeroRole.values.length)],
        null,
        null,
        null,
      );
    }

    final slot = slots[GameLogic.random.nextInt(slots.length)];
    final (bias, preferredArmor, roleTag, lootSpecId) = pickBias();
    final piece = createEquipment(
      slot: slot,
      rarity: primaryRarity,
      battleNumber: battleNumber,
      bias: bias,
      preferredArmor: preferredArmor,
      roleTag: roleTag,
      lootSpecId: lootSpecId,
      dungeonId: dungeonId,
      ascensionLevel: ascensionLevel,
      hardmodeLevel: hardmodeLevel,
    );
    final drops = <LootDrop>[
      LootDrop(
        name: piece.name,
        amount: 1,
        rarity: primaryRarity,
        equipment: piece,
      ),
    ];

    final roleSecondMul = switch (enemyRole) {
      EnemyRole.boss => 1.75,
      EnemyRole.elite => 1.35,
      EnemyRole.normal => 1.0,
    };
    final secondChance =
        (battleNumber >= 6
            ? (0.22 + lootFindPercent / 200.0)
            : (0.08 + lootFindPercent / 250.0)) *
        roleSecondMul;
    final secondCap = battleNumber >= 6 ? 0.55 : 0.28;
    if (battleNumber >= 4 &&
        GameLogic.random.nextDouble() < secondChance.clamp(0.0, secondCap)) {
      final slot2 = slots[GameLogic.random.nextInt(slots.length)];
      final (bias2, preferred2, roleTag2, lootSpecId2) = pickBias();
      final rarity2 = primaryRarity.index > 0
          ? LootRarity.values[primaryRarity.index - 1]
          : LootRarity.common;
      final piece2 = createEquipment(
        slot: slot2,
        rarity: rarity2,
        battleNumber: battleNumber,
        bias: bias2,
        preferredArmor: preferred2,
        roleTag: roleTag2,
        lootSpecId: lootSpecId2,
        dungeonId: dungeonId,
        ascensionLevel: ascensionLevel,
        hardmodeLevel: hardmodeLevel,
      );
      drops.add(
        LootDrop(
          name: piece2.name,
          amount: 1,
          rarity: rarity2,
          equipment: piece2,
        ),
      );
    }

    return drops;
  }

  /// Room chest reward (socket pickup). Small gold pouch + occasional gear.
  static List<LootDrop> rollRoomChestLoot(GameState state, {Random? random}) {
    final rng =
        random ?? Random(state.layoutSeed ^ state.battleNumber ^ 0xC7E57);
    final gold = max(4, treasureGoldBudget(state) ~/ 5);
    final drops = <LootDrop>[
      LootDrop(name: 'Gold Pouch', amount: gold, rarity: LootRarity.common),
    ];
    if (rng.nextDouble() < 0.42) {
      final gear = rollKillLoot(
        state.battleNumber,
        ascensionLevel: state.ascensionLevel,
        lootFindPercent: state.petLootFindPercent,
        hardmodeLevel: Keystone.combatLevel(state),
        party: state.heroes,
        dungeonId: state.dungeonId,
      );
      for (final d in gear) {
        if (d.isEquipment) {
          drops.add(d);
          break;
        }
      }
    }
    if (state.currentRoom.type == RoomType.treasure) {
      drops.add(
        const LootDrop(
          name: 'Essence Vial',
          amount: 1,
          rarity: LootRarity.rare,
        ),
      );
    }
    return drops;
  }

  /// Once-per-clear fillers (sigil / pouch / relic / vial). Uses live [roomType]
  /// so gauntlet bosses (`floor % 5 == 0`) get Boss Sigil correctly.
  static List<LootDrop> rollFloorClearLoot(
    int battleNumber, {
    required RoomType roomType,
  }) {
    final drops = <LootDrop>[];
    if (battleNumber % 4 == 0) {
      drops.add(
        LootDrop(
          name: 'Gold Pouch',
          amount: goldPouchBaseGold(battleNumber),
          rarity: LootRarity.common,
        ),
      );
    }
    if (battleNumber % 9 == 0) {
      drops.add(
        const LootDrop(name: 'Relic Shard', amount: 1, rarity: LootRarity.rare),
      );
    }
    if (roomType == RoomType.boss) {
      drops.add(
        const LootDrop(name: 'Boss Sigil', amount: 1, rarity: LootRarity.epic),
      );
    }
    if (roomType == RoomType.treasure) {
      drops.add(
        const LootDrop(
          name: 'Essence Vial',
          amount: 1,
          rarity: LootRarity.rare,
        ),
      );
    }
    return drops;
  }

  /// Combined roll (kill gear + floor fillers). Prefer [rollKillLoot] /
  /// [rollFloorClearLoot] at call sites. Kept for tests / tooling.
  static List<LootDrop> rollLoot(
    int battleNumber, {
    int ascensionLevel = 0,
    int lootFindPercent = 0,
    int hardmodeLevel = 0,
    List<PartyHero>? party,
    String dungeonId = 'sandy',
    EnemyRole enemyRole = EnemyRole.normal,
    RoomType? roomType,
  }) {
    final resolvedType =
        roomType ??
        DungeonGenerator.generateFloor(
          max(1, battleNumber),
          ascensionLevel: ascensionLevel,
          dungeonId: dungeonId,
          bossEvery: null,
        ).first.type;
    return finalizeLootDrops([
      ...rollKillLoot(
        battleNumber,
        ascensionLevel: ascensionLevel,
        lootFindPercent: lootFindPercent,
        hardmodeLevel: hardmodeLevel,
        party: party,
        dungeonId: dungeonId,
        enemyRole: enemyRole,
      ),
      ...rollFloorClearLoot(battleNumber, roomType: resolvedType),
    ]);
  }

  /// Keep all gear / sigil / relic / vial; fill remaining slots with filler
  /// (gold pouch). Soft cap 5 — never discards important drops.
  static List<LootDrop> finalizeLootDrops(List<LootDrop> drops) {
    const softCap = 5;
    if (drops.length <= softCap) return List<LootDrop>.from(drops);

    bool important(LootDrop d) {
      if (d.isEquipment) return true;
      final n = d.name.toLowerCase();
      return n.contains('boss sigil') ||
          n.contains('relic') ||
          n.contains('essence vial');
    }

    final keep = <LootDrop>[];
    final filler = <LootDrop>[];
    for (final d in drops) {
      if (important(d)) {
        keep.add(d);
      } else {
        filler.add(d);
      }
    }
    final out = List<LootDrop>.from(keep);
    for (final d in filler) {
      if (out.length >= softCap) break;
      out.add(d);
    }
    return out;
  }

  static PartyHero? _lootTargetHero(List<PartyHero>? party) {
    if (party == null || party.isEmpty) return null;
    final living = [
      for (final h in party)
        if (h.isAlive) h,
    ];
    final pool = living.isNotEmpty ? living : party;
    return pool[GameLogic.random.nextInt(pool.length)];
  }

  static EquipmentItem createEquipment({
    required EquipmentSlot slot,
    required LootRarity rarity,
    required int battleNumber,
    HeroRole? bias,
    ArmorType? preferredArmor,
    SpecRoleTag? roleTag,
    HeroSpecId? lootSpecId,
    String? dungeonId,
    int ascensionLevel = 0,
    int hardmodeLevel = 0,
  }) {
    EquipmentFactory.random = GameLogic.random;
    return EquipmentFactory.create(
      slot: slot,
      rarity: rarity,
      battleNumber: battleNumber,
      bias: bias,
      preferredArmor: preferredArmor,
      roleTag: roleTag,
      lootSpecId: lootSpecId,
      dungeonId: dungeonId,
      ascensionLevel: ascensionLevel,
      hardmodeLevel: hardmodeLevel,
    );
  }

  /// Item level from floor + rarity + dungeon/AL/HM band (soft-capped late).
  static int itemLevelFor({
    required int battleNumber,
    required LootRarity rarity,
    String? dungeonId,
    int ascensionLevel = 0,
    int hardmodeLevel = 0,
  }) => EquipmentFactory.itemLevelFor(
    battleNumber: battleNumber,
    rarity: rarity,
    dungeonId: dungeonId,
    ascensionLevel: ascensionLevel,
    hardmodeLevel: hardmodeLevel,
  );

  /// Recommended auto-sell iLvl ceiling for the player's progression.
  static int maxAutoSellIlvlCap(GameState state) {
    final fromDungeon = state.highestDungeonCleared * 22;
    final fromAl = state.ascensionLevel * 4;
    return (60 + fromDungeon + fromAl).clamp(60, 200);
  }

  /// Scale a soulbound piece so Ascend AL keeps it relevant vs new drops.
  ///
  /// Primaries track the target ilvl ratio; total power stays near the same
  /// budget curve as fresh drops at that ilvl.
  static EquipmentItem scaleSoulboundForAl(
    EquipmentItem item,
    int ascensionLevel,
  ) {
    // Fold legacy Vit/Def into Sta/Armor before scaling so clamps can't wipe them.
    var base = item;
    if (base.vitalityBonus != 0 || base.defenseBonus != 0) {
      base = base.copyWith(
        staminaBonus: base.resolvedStamina,
        armorBonus: base.resolvedArmor,
        vitalityBonus: 0,
        defenseBonus: 0,
      );
    }

    final al = ascensionLevel.clamp(0, 40);
    final rawTarget = max(base.effectiveItemLevel, 20 + al * 3);
    final targetIlvl = EquipmentFactory.softCapItemLevel(rawTarget);
    if (targetIlvl <= base.effectiveItemLevel) {
      return base.copyWith(itemLevel: base.effectiveItemLevel);
    }
    final ratio = targetIlvl / max(1, base.effectiveItemLevel);
    int bump(int v) {
      if (v <= 0) return 0;
      return max(v, (v * ratio).round());
    }

    var scaled = base.copyWith(
      itemLevel: targetIlvl,
      strengthBonus: bump(base.strengthBonus),
      agilityBonus: bump(base.agilityBonus),
      staminaBonus: bump(base.staminaBonus),
      intellectBonus: bump(base.intellectBonus),
      spiritBonus: bump(base.spiritBonus),
      spellPowerBonus: bump(base.spellPowerBonus),
      armorBonus: bump(base.armorBonus),
      attackBonus: bump(base.attackBonus),
      defenseBonus: 0,
      vitalityBonus: 0,
      mp5Bonus: bump(base.mp5Bonus),
      critChanceBonus: bump(base.critChanceBonus),
      attackSpeedBonus: bump(base.attackSpeedBonus),
      moveSpeedBonus: bump(base.moveSpeedBonus),
      effectValue: bump(base.effectValue),
    );

    // Soft-clamp runaway primaries to ~1.35× drop budget at the new ilvl.
    final cap =
        (EquipmentFactory.budgetForItemLevel(
                  itemLevel: targetIlvl,
                  rarity: base.rarity.index >= LootRarity.rare.index
                      ? base.rarity
                      : LootRarity.rare,
                  slot: base.slot,
                  handed: base.handed,
                ) *
                1.35)
            .round();
    final primarySum =
        scaled.strengthBonus +
        scaled.agilityBonus +
        scaled.staminaBonus +
        scaled.intellectBonus +
        scaled.spiritBonus +
        scaled.spellPowerBonus +
        scaled.armorBonus +
        scaled.attackBonus;
    if (primarySum > cap && primarySum > 0) {
      final shrink = cap / primarySum;
      int sh(int v) => v <= 0 ? 0 : max(1, (v * shrink).round());
      scaled = scaled.copyWith(
        strengthBonus: sh(scaled.strengthBonus),
        agilityBonus: sh(scaled.agilityBonus),
        staminaBonus: sh(scaled.staminaBonus),
        intellectBonus: sh(scaled.intellectBonus),
        spiritBonus: sh(scaled.spiritBonus),
        spellPowerBonus: sh(scaled.spellPowerBonus),
        armorBonus: sh(scaled.armorBonus),
        attackBonus: sh(scaled.attackBonus),
        defenseBonus: 0,
        vitalityBonus: 0,
      );
    }
    return scaled;
  }

  static String equipmentNameFor(
    EquipmentSlot slot,
    LootRarity rarity, {
    HeroRole? bias,
    ArmorType? armorType,
    WeaponType? weaponType,
    OffHandKind? offHandKind,
    WeaponHanded? handed,
    String? affixPrefixId,
    String? affixSuffixId,
  }) => EquipmentFactory.equipmentNameFor(
    slot: slot,
    rarity: rarity,
    bias: bias,
    armorType: armorType,
    weaponType: weaponType,
    offHandKind: offHandKind,
    handed: handed,
    affixPrefix: EquipmentFactory.affixNameById(affixPrefixId),
    affixSuffix: EquipmentFactory.affixNameById(affixSuffixId),
  );

  static int lootEssenceValue(LootDrop drop) {
    if (drop.essenceGained > 0) {
      return drop.essenceGained;
    }
    if (drop.equipment != null) {
      return equipmentEssenceValue(drop.equipment!);
    }
    final perItem = switch (drop.rarity) {
      LootRarity.common => 2,
      LootRarity.uncommon => 5,
      LootRarity.rare => 9,
      LootRarity.epic => 16,
      LootRarity.legendary => 28,
    };

    return perItem * drop.amount;
  }

  static int equipmentEssenceValue(EquipmentItem item) {
    final base = switch (item.rarity) {
      LootRarity.common => 2,
      LootRarity.uncommon => 5,
      LootRarity.rare => 9,
      LootRarity.epic => 16,
      LootRarity.legendary => 28,
    };
    return base + (item.powerScore ~/ 4);
  }

  /// Merchant gold payout (stash-only sales).
  /// Uses stat power + 2×ilvl (ilvl is not double-counted via [powerScore]).
  static int equipmentGoldValue(EquipmentItem item) {
    final base = switch (item.rarity) {
      LootRarity.common => 8,
      LootRarity.uncommon => 18,
      LootRarity.rare => 40,
      LootRarity.epic => 90,
      LootRarity.legendary => 160,
    };
    return base + item.statPowerScore + (item.effectiveItemLevel * 2);
  }

  static LootRarity _rarityForBattle(
    int battleNumber, {
    int hardmodeLevel = 0,
  }) {
    final hm = hardmodeLevel.clamp(0, Keystone.maxLevel);
    // Direct legendary roll — key 20 ≈ old HM+10.
    final legendaryChance = Keystone.legendaryChance(hm);
    if (GameLogic.random.nextDouble() < legendaryChance) {
      return LootRarity.legendary;
    }

    var rarity = LootRarity.common;
    if (battleNumber % 12 == 0) {
      rarity = LootRarity.epic;
    } else if (battleNumber % 6 == 0) {
      rarity = LootRarity.rare;
    } else if (battleNumber % 3 == 0) {
      rarity = LootRarity.uncommon;
    }

    // Keystone can bump the base tier (never past legendary).
    final bumpChance = Keystone.rarityBump(hm);
    if (rarity.index < LootRarity.legendary.index &&
        GameLogic.random.nextDouble() < bumpChance) {
      rarity = LootRarity.values[rarity.index + 1];
    }
    if (rarity.index < LootRarity.legendary.index &&
        hm >= 14 &&
        GameLogic.random.nextDouble() < bumpChance * 0.5) {
      rarity = LootRarity.values[rarity.index + 1];
    }
    return rarity;
  }

  /// Treasure / chest gold budget using full zone · HM · AL · gear pressure.
  static int treasureGoldBudget(GameState state) {
    return GameLogic.roomCombatBudget(
      state.currentRoom,
      dungeonId: state.dungeonId,
      hardmodeLevel: Keystone.combatLevel(state),
      ascensionLevel: state.ascensionLevel,
      gearPressure: GameLogic.partyGearPressure(state),
    ).gold;
  }
}
