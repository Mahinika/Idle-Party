import 'dungeon_def.dart';
import 'hero.dart';
import 'loot.dart';

/// Lightweight dungeon armor sets (2pc / 4pc). Original Idle Party names only.
abstract final class GearSets {
  GearSets._();

  static const setSlots = <EquipmentSlot>{
    EquipmentSlot.head,
    EquipmentSlot.shoulder,
    EquipmentSlot.chest,
    EquipmentSlot.legs,
  };

  static String? setIdFor({
    required String dungeonId,
    required ArmorType armorType,
    required LootRarity rarity,
    required EquipmentSlot slot,
  }) {
    if (!setSlots.contains(slot)) return null;
    if (rarity.index < LootRarity.rare.index) return null;
    return '${DungeonCatalog.byId(dungeonId).id}_${armorType.name}';
  }

  static String displayName(String setId) {
    final parts = setId.split('_');
    if (parts.length < 2) return setId;
    final dungeonId = parts.first;
    final armorRaw = parts.sublist(1).join('_');
    final zone = switch (dungeonId) {
      'sandy' => 'Cavern',
      'goblin' => 'Hideout',
      'king' => 'Fort',
      'underworld' => 'Underworld',
      'dead' => 'Necropolis',
      'hell' => 'Infernal',
      'crystal' => 'Spire',
      'tide' => 'Tidehold',
      'ember' => 'Ashen',
      'grove' => 'Hollow',
      'storm' => 'Stormwake',
      _ => dungeonId,
    };
    final armor = switch (armorRaw) {
      'cloth' => 'Cloth',
      'leather' => 'Leather',
      'mail' => 'Mail',
      'plate' => 'Plate',
      _ => armorRaw,
    };
    return '$zone $armor';
  }

  /// Pieces of [setId] currently worn (set slots only).
  static int wornCount(Map<EquipmentSlot, EquipmentItem> equipped, String setId) {
    var n = 0;
    for (final slot in setSlots) {
      final item = equipped[slot];
      if (item?.setId == setId) n++;
    }
    return n;
  }

  /// Dominant set among equipped armor (highest count, then first).
  static String? primarySetId(Map<EquipmentSlot, EquipmentItem> equipped) {
    final counts = <String, int>{};
    for (final slot in setSlots) {
      final id = equipped[slot]?.setId;
      if (id == null || id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    String? best;
    var bestN = 0;
    for (final e in counts.entries) {
      if (e.value > bestN) {
        best = e.key;
        bestN = e.value;
      }
    }
    return best;
  }

  static bool isClothSet(String setId) => setId.endsWith('_cloth');

  /// Flat stamina from 2pc (non-cloth) or spirit for cloth.
  static int setStaminaBonus(Map<EquipmentSlot, EquipmentItem> equipped) {
    final id = primarySetId(equipped);
    if (id == null) return 0;
    final n = wornCount(equipped, id);
    if (n < 2) return 0;
    if (isClothSet(id)) return 0;
    return n >= 4 ? 6 : 3;
  }

  static int setSpiritBonus(Map<EquipmentSlot, EquipmentItem> equipped) {
    final id = primarySetId(equipped);
    if (id == null) return 0;
    final n = wornCount(equipped, id);
    if (n < 2 || !isClothSet(id)) return 0;
    return n >= 4 ? 6 : 3;
  }

  static int setSpellPowerBonus(Map<EquipmentSlot, EquipmentItem> equipped) {
    final id = primarySetId(equipped);
    if (id == null) return 0;
    final n = wornCount(equipped, id);
    if (n < 4 || !isClothSet(id)) return 0;
    return 4;
  }

  /// 4pc combat bump: +crit % (non-cloth) or included in SP for cloth.
  static int setCritBonus(Map<EquipmentSlot, EquipmentItem> equipped) {
    final id = primarySetId(equipped);
    if (id == null) return 0;
    final n = wornCount(equipped, id);
    if (n < 4 || isClothSet(id)) return 0;
    return 2;
  }

  /// Mild 4pc role fantasy on top of stamina/crit/spirit/SP set bonuses.
  static int setRoleArmorBonus(
    Map<EquipmentSlot, EquipmentItem> equipped,
    HeroRole role,
  ) {
    if (role != HeroRole.warrior) return 0;
    final id = primarySetId(equipped);
    if (id == null || wornCount(equipped, id) < 4) return 0;
    return 4;
  }

  static int setRoleHasteBonus(
    Map<EquipmentSlot, EquipmentItem> equipped,
    HeroRole role,
  ) {
    if (role != HeroRole.rogue) return 0;
    final id = primarySetId(equipped);
    if (id == null || wornCount(equipped, id) < 4) return 0;
    return 2;
  }

  static int setRoleSpiritBonus(
    Map<EquipmentSlot, EquipmentItem> equipped,
    HeroRole role,
  ) {
    if (role != HeroRole.healer) return 0;
    final id = primarySetId(equipped);
    if (id == null || wornCount(equipped, id) < 4) return 0;
    return 2;
  }

  static int setRoleSpellPowerBonus(
    Map<EquipmentSlot, EquipmentItem> equipped,
    HeroRole role,
  ) {
    if (role != HeroRole.mage) return 0;
    final id = primarySetId(equipped);
    if (id == null || wornCount(equipped, id) < 4) return 0;
    return 2;
  }

  /// 4pc on-hit combat proc (chance + damage mul + floater tag).
  static ({double chance, double damageMul, String tag, int argb})?
      fourPieceProc(Map<EquipmentSlot, EquipmentItem> equipped) {
    final id = primarySetId(equipped);
    if (id == null || wornCount(equipped, id) < 4) return null;
    final zone = id.split('_').first;
    final (tag, argb) = switch (zone) {
      'sandy' => ('CAVERN', 0xFFE0A050),
      'goblin' => ('HIDEOUT', 0xFF60C070),
      'king' => ('FORT', 0xFF70A0E0),
      'underworld' => ('UNDER', 0xFFA070E0),
      'dead' => ('NECRO', 0xFF70A090),
      'hell' => ('INFERNO', 0xFFE05040),
      'crystal' => ('SPIRE', 0xFF80D0FF),
      'tide' => ('TIDE', 0xFF40C0B0),
      'ember' => ('ASHEN', 0xFFE09040),
      'grove' => ('GROVE', 0xFF68B048),
      'storm' => ('GALE', 0xFFE8E040),
      _ => ('SET', 0xFFFFD070),
    };
    return (chance: 0.10, damageMul: 1.35, tag: tag, argb: argb);
  }

  /// Short UI blurb for the dominant worn set.
  static String? setBonusBlurb(Map<EquipmentSlot, EquipmentItem> equipped) {
    final id = primarySetId(equipped);
    if (id == null) return null;
    final n = wornCount(equipped, id);
    if (n < 2) return null;
    final name = displayName(id);
    if (n >= 4) {
      return '$name 4pc · +stats · 10% set proc on auto';
    }
    return '$name 2pc · +stats';
  }

  /// Equip-score bonus for completing / progressing a set with [candidate].
  ///
  /// Kept modest so real stats/iLvl still dominate BiS (completion is a nudge,
  /// not a +100 hammer that beats clearly better non-set gear).
  static int equipScoreBonus({
    required Map<EquipmentSlot, EquipmentItem> equipped,
    required EquipmentItem candidate,
  }) {
    final setId = candidate.setId;
    if (setId == null || setId.isEmpty) return 0;
    if (!setSlots.contains(candidate.slot)) return 0;
    final without = Map<EquipmentSlot, EquipmentItem>.from(equipped)
      ..remove(candidate.slot);
    final before = wornCount(without, setId);
    final after = before + 1;
    var bonus = 8; // any set piece
    if (after >= 2 && before < 2) bonus += 14;
    if (after >= 4 && before < 4) bonus += 18;
    if (after >= 2) bonus += after * 3;
    return bonus;
  }
}
