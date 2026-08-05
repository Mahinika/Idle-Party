import 'dungeon_def.dart';
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

  /// Equip-score bonus for completing / progressing a set with [candidate].
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
    var bonus = 18; // any set piece
    if (after >= 2 && before < 2) bonus += 36;
    if (after >= 4 && before < 4) bonus += 55;
    if (after >= 2) bonus += after * 10;
    return bonus;
  }
}
