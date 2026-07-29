enum LootRarity { common, uncommon, rare, epic, legendary }

enum ArmorType { cloth, leather, mail, plate }

enum WeaponType {
  axe,
  sword,
  mace,
  dagger,
  fist,
  staff,
  polearm,
  bow,
  crossbow,
  gun,
  thrown,
  wand,
}

enum WeaponHanded { oneHand, twoHand }

enum OffHandKind { shield, frill, weapon }

enum EquipmentSlot {
  weapon,
  offHand,
  ranged,
  head,
  neck,
  shoulder,
  chest,
  waist,
  legs,
  boots,
  wrist,
  hands,
  cloak,
  ring,
  ring2,
  trinket,
  trinket2,
  consumable,
}

extension EquipmentSlotX on EquipmentSlot {
  static const armorSlots = <EquipmentSlot>{
    EquipmentSlot.head,
    EquipmentSlot.shoulder,
    EquipmentSlot.chest,
    EquipmentSlot.waist,
    EquipmentSlot.legs,
    EquipmentSlot.boots,
    EquipmentSlot.wrist,
    EquipmentSlot.hands,
  };

  bool get isArmorSlot => EquipmentSlotX.armorSlots.contains(this);

  /// Migrate legacy JSON slot names.
  static EquipmentSlot parse(String raw) {
    if (raw == 'armor') return EquipmentSlot.cloak;
    if (raw == 'shield') return EquipmentSlot.offHand;
    return EquipmentSlot.values.byName(raw);
  }
}

/// Projectile / attack pattern identity for weapons (and hero roles).
enum ProjectilePattern { single, spread, arc, pierce }

/// Unique gear effect ids (data-driven).
enum GearEffectId { none, lifesteal, pierce, goldFind, crit, haste }

enum LootOutcome { essence, equipped, replaced, stashed }

class EquipmentItem {
  const EquipmentItem({
    required this.id,
    required this.name,
    required this.slot,
    required this.rarity,
    this.strengthBonus = 0,
    this.agilityBonus = 0,
    this.staminaBonus = 0,
    this.intellectBonus = 0,
    this.spiritBonus = 0,
    this.spellPowerBonus = 0,
    this.armorBonus = 0,
    this.mp5Bonus = 0,
    this.attackBonus = 0,
    this.defenseBonus = 0,
    this.vitalityBonus = 0,
    this.critChanceBonus = 0,
    this.attackSpeedBonus = 0,
    this.moveSpeedBonus = 0,
    this.pattern = ProjectilePattern.single,
    this.effectId = GearEffectId.none,
    this.effectValue = 0,
    this.affinity,
    this.itemLevel = 0,
    this.armorType,
    this.weaponType,
    this.handed,
    this.offHandKind,
    this.iconId,
  });

  final String id;
  final String name;
  final EquipmentSlot slot;
  final LootRarity rarity;

  final int strengthBonus;
  final int agilityBonus;
  final int staminaBonus;
  final int intellectBonus;
  final int spiritBonus;
  final int spellPowerBonus;
  final int armorBonus;
  final int mp5Bonus;

  /// Legacy / flat AP contribution (melee affinity gear).
  final int attackBonus;

  /// Legacy — prefer [armorBonus].
  final int defenseBonus;

  /// Legacy — prefer [staminaBonus].
  final int vitalityBonus;

  final int critChanceBonus;
  final int attackSpeedBonus;
  final int moveSpeedBonus;

  final ProjectilePattern pattern;
  final GearEffectId effectId;
  final int effectValue;

  /// Optional class this piece was rolled for (`warrior`/`healer`/`mage`/`rogue`).
  final String? affinity;

  final int itemLevel;

  final ArmorType? armorType;
  final WeaponType? weaponType;
  final WeaponHanded? handed;
  final OffHandKind? offHandKind;

  /// Optional Kenney icon key override.
  final String? iconId;

  int get resolvedArmor => armorBonus + defenseBonus;
  int get resolvedStamina => staminaBonus + vitalityBonus;

  int get effectiveItemLevel {
    if (itemLevel > 0) return itemLevel;
    return (powerScore ~/ 3) + rarity.index * 2 + 1;
  }

  int get powerScore =>
      (strengthBonus * 3) +
      (agilityBonus * 3) +
      (resolvedStamina * 2) +
      (intellectBonus * 3) +
      (spiritBonus * 2) +
      (spellPowerBonus * 3) +
      (resolvedArmor * 2) +
      (attackBonus * 3) +
      mp5Bonus +
      critChanceBonus +
      attackSpeedBonus +
      moveSpeedBonus +
      effectValue;

  String get effectLabel => switch (effectId) {
        GearEffectId.lifesteal => 'Lifesteal $effectValue%',
        GearEffectId.pierce => 'Pierce',
        GearEffectId.goldFind => 'Gold Find $effectValue%',
        GearEffectId.crit => 'Crit +$effectValue%',
        GearEffectId.haste => 'Haste +$effectValue%',
        GearEffectId.none => '',
      };

  String get typeLabel {
    if (slot == EquipmentSlot.offHand) {
      return switch (offHandKind ?? OffHandKind.shield) {
        OffHandKind.shield => 'shield',
        OffHandKind.frill => 'tome',
        OffHandKind.weapon => 'weapon',
      };
    }
    if (weaponType != null) {
      final h = handed;
      final hand = h == null ? '' : (h == WeaponHanded.twoHand ? '2H ' : '1H ');
      return '$hand${weaponType!.name}';
    }
    if (armorType != null) return armorType!.name;
    return slot.name;
  }

  String get statsLine {
    final parts = <String>[];
    parts.add('i$effectiveItemLevel');
    parts.add(typeLabel);
    if (strengthBonus != 0) parts.add('+$strengthBonus Str');
    if (agilityBonus != 0) parts.add('+$agilityBonus Agi');
    if (resolvedStamina != 0) parts.add('+$resolvedStamina Sta');
    if (intellectBonus != 0) parts.add('+$intellectBonus Int');
    if (spiritBonus != 0) parts.add('+$spiritBonus Spi');
    if (spellPowerBonus != 0) parts.add('+$spellPowerBonus SP');
    if (resolvedArmor != 0) parts.add('+$resolvedArmor Armor');
    if (attackBonus != 0) parts.add('+$attackBonus AP');
    if (mp5Bonus != 0) parts.add('+$mp5Bonus Mp5');
    if (critChanceBonus != 0) parts.add('+$critChanceBonus% CRIT');
    if (attackSpeedBonus != 0) parts.add('+$attackSpeedBonus% ASPD');
    if (moveSpeedBonus != 0) parts.add('+$moveSpeedBonus% MOVE');
    if (effectLabel.isNotEmpty) parts.add(effectLabel);
    return parts.join(' · ');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'slot': slot.name,
        'rarity': rarity.name,
        'strengthBonus': strengthBonus,
        'agilityBonus': agilityBonus,
        'staminaBonus': staminaBonus,
        'intellectBonus': intellectBonus,
        'spiritBonus': spiritBonus,
        'spellPowerBonus': spellPowerBonus,
        'armorBonus': armorBonus,
        'mp5Bonus': mp5Bonus,
        'attackBonus': attackBonus,
        'defenseBonus': defenseBonus,
        'vitalityBonus': vitalityBonus,
        'critChanceBonus': critChanceBonus,
        'attackSpeedBonus': attackSpeedBonus,
        'moveSpeedBonus': moveSpeedBonus,
        'pattern': pattern.name,
        'effectId': effectId.name,
        'effectValue': effectValue,
        if (affinity != null) 'affinity': affinity,
        'itemLevel': effectiveItemLevel,
        if (armorType != null) 'armorType': armorType!.name,
        if (weaponType != null) 'weaponType': weaponType!.name,
        if (handed != null) 'handed': handed!.name,
        if (offHandKind != null) 'offHandKind': offHandKind!.name,
        if (iconId != null) 'iconId': iconId,
      };

  factory EquipmentItem.fromJson(Map<String, dynamic> json) {
    final slot = EquipmentSlotX.parse(json['slot'] as String);
    final patternRaw = json['pattern'] as String?;
    final effectRaw = json['effectId'] as String?;
    final armorRaw = json['armorType'] as String?;
    final weaponRaw = json['weaponType'] as String?;
    final handedRaw = json['handed'] as String?;
    final offHandRaw = json['offHandKind'] as String?;

    var strength = (json['strengthBonus'] as int?) ?? 0;
    var agility = (json['agilityBonus'] as int?) ?? 0;
    var stamina = (json['staminaBonus'] as int?) ?? 0;
    var intellect = (json['intellectBonus'] as int?) ?? 0;
    var spirit = (json['spiritBonus'] as int?) ?? 0;
    var spellPower = (json['spellPowerBonus'] as int?) ?? 0;
    var armor = (json['armorBonus'] as int?) ?? 0;
    final attack = (json['attackBonus'] as int?) ?? 0;
    final defense = (json['defenseBonus'] as int?) ?? 0;
    final vitality = (json['vitalityBonus'] as int?) ?? 0;

    // Legacy-only piece: fold old flats into new fields.
    final hasPrimaries = json.containsKey('strengthBonus') ||
        json.containsKey('agilityBonus') ||
        json.containsKey('staminaBonus') ||
        json.containsKey('intellectBonus');
    if (!hasPrimaries) {
      stamina = vitality;
      armor = defense;
      final aff = json['affinity'] as String?;
      if (aff == 'mage' || aff == 'healer') {
        intellect = attack;
        spellPower = (attack / 2).ceil();
      } else if (aff == 'rogue') {
        agility = attack;
        strength = (attack / 2).ceil();
      } else {
        strength = attack;
      }
    }

    OffHandKind? offKind;
    if (offHandRaw != null) {
      offKind = OffHandKind.values.byName(offHandRaw);
    } else if (slot == EquipmentSlot.offHand) {
      // Legacy shield slot → shield off-hand.
      offKind = OffHandKind.shield;
    }

    return EquipmentItem(
      id: json['id'] as String,
      name: json['name'] as String,
      slot: slot,
      rarity: LootRarity.values.byName(json['rarity'] as String),
      strengthBonus: strength,
      agilityBonus: agility,
      staminaBonus: stamina,
      intellectBonus: intellect,
      spiritBonus: spirit,
      spellPowerBonus: spellPower,
      armorBonus: armor,
      mp5Bonus: (json['mp5Bonus'] as int?) ?? 0,
      attackBonus: attack,
      defenseBonus: defense,
      vitalityBonus: vitality,
      critChanceBonus: (json['critChanceBonus'] as int?) ?? 0,
      attackSpeedBonus: (json['attackSpeedBonus'] as int?) ?? 0,
      moveSpeedBonus: (json['moveSpeedBonus'] as int?) ?? 0,
      pattern: patternRaw == null
          ? ProjectilePattern.single
          : ProjectilePattern.values.byName(patternRaw),
      effectId: effectRaw == null
          ? GearEffectId.none
          : GearEffectId.values.byName(effectRaw),
      effectValue: (json['effectValue'] as int?) ?? 0,
      affinity: json['affinity'] as String?,
      itemLevel: (json['itemLevel'] as int?) ?? 0,
      armorType: armorRaw == null ? null : ArmorType.values.byName(armorRaw),
      weaponType:
          weaponRaw == null ? null : WeaponType.values.byName(weaponRaw),
      handed: handedRaw == null ? null : WeaponHanded.values.byName(handedRaw),
      offHandKind: offKind,
      iconId: json['iconId'] as String?,
    );
  }

  EquipmentItem copyWith({
    String? id,
    String? name,
    EquipmentSlot? slot,
    LootRarity? rarity,
    int? strengthBonus,
    int? agilityBonus,
    int? staminaBonus,
    int? intellectBonus,
    int? spiritBonus,
    int? spellPowerBonus,
    int? armorBonus,
    int? mp5Bonus,
    int? attackBonus,
    int? defenseBonus,
    int? vitalityBonus,
    int? critChanceBonus,
    int? attackSpeedBonus,
    int? moveSpeedBonus,
    ProjectilePattern? pattern,
    GearEffectId? effectId,
    int? effectValue,
    String? affinity,
    bool clearAffinity = false,
    int? itemLevel,
    ArmorType? armorType,
    WeaponType? weaponType,
    WeaponHanded? handed,
    OffHandKind? offHandKind,
    String? iconId,
  }) {
    return EquipmentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      slot: slot ?? this.slot,
      rarity: rarity ?? this.rarity,
      strengthBonus: strengthBonus ?? this.strengthBonus,
      agilityBonus: agilityBonus ?? this.agilityBonus,
      staminaBonus: staminaBonus ?? this.staminaBonus,
      intellectBonus: intellectBonus ?? this.intellectBonus,
      spiritBonus: spiritBonus ?? this.spiritBonus,
      spellPowerBonus: spellPowerBonus ?? this.spellPowerBonus,
      armorBonus: armorBonus ?? this.armorBonus,
      mp5Bonus: mp5Bonus ?? this.mp5Bonus,
      attackBonus: attackBonus ?? this.attackBonus,
      defenseBonus: defenseBonus ?? this.defenseBonus,
      vitalityBonus: vitalityBonus ?? this.vitalityBonus,
      critChanceBonus: critChanceBonus ?? this.critChanceBonus,
      attackSpeedBonus: attackSpeedBonus ?? this.attackSpeedBonus,
      moveSpeedBonus: moveSpeedBonus ?? this.moveSpeedBonus,
      pattern: pattern ?? this.pattern,
      effectId: effectId ?? this.effectId,
      effectValue: effectValue ?? this.effectValue,
      affinity: clearAffinity ? null : (affinity ?? this.affinity),
      itemLevel: itemLevel ?? this.itemLevel,
      armorType: armorType ?? this.armorType,
      weaponType: weaponType ?? this.weaponType,
      handed: handed ?? this.handed,
      offHandKind: offHandKind ?? this.offHandKind,
      iconId: iconId ?? this.iconId,
    );
  }
}

class LootDrop {
  const LootDrop({
    required this.name,
    required this.amount,
    required this.rarity,
    this.equipment,
    this.outcome = LootOutcome.essence,
    this.essenceGained = 0,
  });

  final String name;
  final int amount;
  final LootRarity rarity;
  final EquipmentItem? equipment;
  final LootOutcome outcome;
  final int essenceGained;

  bool get isEquipment => equipment != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'amount': amount,
        'rarity': rarity.name,
        if (equipment != null) 'equipment': equipment!.toJson(),
        'outcome': outcome.name,
        'essenceGained': essenceGained,
      };

  factory LootDrop.fromJson(Map<String, dynamic> json) {
    final equipmentJson = json['equipment'] as Map<String, dynamic>?;
    final outcomeRaw = json['outcome'] as String?;
    return LootDrop(
      name: json['name'] as String,
      amount: json['amount'] as int,
      rarity: LootRarity.values.byName(json['rarity'] as String),
      equipment: equipmentJson == null
          ? null
          : EquipmentItem.fromJson(equipmentJson),
      outcome: outcomeRaw == null
          ? LootOutcome.essence
          : LootOutcome.values.byName(outcomeRaw),
      essenceGained: (json['essenceGained'] as int?) ?? 0,
    );
  }

  LootDrop copyWith({
    String? name,
    int? amount,
    LootRarity? rarity,
    EquipmentItem? equipment,
    LootOutcome? outcome,
    int? essenceGained,
  }) {
    return LootDrop(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      rarity: rarity ?? this.rarity,
      equipment: equipment ?? this.equipment,
      outcome: outcome ?? this.outcome,
      essenceGained: essenceGained ?? this.essenceGained,
    );
  }
}
