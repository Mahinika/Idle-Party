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

enum LootOutcome { essence, equipped, replaced, stashed, gold }

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
    this.masteryBonus = 0,
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
    this.visualSetId,
    this.affixPrefixId,
    this.affixSuffixId,
    this.setId,
    this.isApex = false,
    this.apexClassId,
    this.apexRoleTag,
    this.apexRank = 0,
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
  final int masteryBonus;
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

  /// Optional layered visual set id (e.g. `sword_t1`, `helm_plate`).
  /// When null, [EquipmentVisualResolver] derives from slot/type/rarity.
  final String? visualSetId;

  /// Data-driven affix ids from `item_affixes.json` (null = none).
  final String? affixPrefixId;
  final String? affixSuffixId;

  /// Dungeon armor set id (`{dungeonId}_{armorType}`), rare+ set slots only.
  final String? setId;

  /// Crafted Apex BiS (forge-only). Survives Ascend when equipped / vaulted.
  final bool isApex;

  /// [HeroClassId.name] this Apex piece is bound to.
  final String? apexClassId;

  /// [SpecRoleTag.name] this Apex piece was crafted for.
  final String? apexRoleTag;

  /// Apex upgrade rank (1–3). 0 when not Apex.
  final int apexRank;

  int get resolvedArmor => armorBonus + defenseBonus;
  int get resolvedStamina => staminaBonus + vitalityBonus;

  /// Stat-only value (no ilvl) — junk/gold helpers and fallback ilvl.
  int get statPowerScore =>
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
      masteryBonus +
      attackSpeedBonus +
      moveSpeedBonus +
      effectValue;

  int get effectiveItemLevel {
    if (itemLevel > 0) return itemLevel;
    return (statPowerScore ~/ 3) + rarity.index * 2 + 1;
  }

  /// Neutral item value for junk / merge / gold (includes ilvl).
  /// Equip/BiS uses [GameLogic.roleEquipScore] / [GameLogic.specEquipScore] instead.
  int get powerScore => statPowerScore + effectiveItemLevel;

  String get effectLabel => switch (effectId) {
    GearEffectId.lifesteal => 'Lifesteal $effectValue%',
    GearEffectId.pierce => 'Pierce',
    GearEffectId.goldFind => 'Gold Find $effectValue%',
    GearEffectId.crit => 'Crit +$effectValue%',
    GearEffectId.haste => 'Haste +$effectValue%',
    GearEffectId.none => '',
  };

  /// Short in-fight pickup word (avoids stacked full item names).
  String get combatPopLabel {
    if (slot == EquipmentSlot.weapon) {
      return switch (weaponType) {
        WeaponType.axe => 'Axe',
        WeaponType.sword => 'Sword',
        WeaponType.mace => 'Mace',
        WeaponType.dagger => 'Dagger',
        WeaponType.fist => 'Fist',
        WeaponType.staff => 'Staff',
        WeaponType.polearm => 'Polearm',
        WeaponType.bow => 'Bow',
        WeaponType.crossbow => 'Crossbow',
        WeaponType.gun => 'Gun',
        WeaponType.thrown => 'Thrown',
        WeaponType.wand => 'Wand',
        null => 'Weapon',
      };
    }
    if (slot == EquipmentSlot.offHand) {
      return switch (offHandKind ?? OffHandKind.shield) {
        OffHandKind.shield => 'Shield',
        OffHandKind.frill => 'Tome',
        OffHandKind.weapon => 'Off-hand',
      };
    }
    if (slot == EquipmentSlot.ranged) return 'Ranged';
    return switch (slot) {
      EquipmentSlot.head => 'Head',
      EquipmentSlot.neck => 'Neck',
      EquipmentSlot.shoulder => 'Shoulder',
      EquipmentSlot.chest => 'Chest',
      EquipmentSlot.waist => 'Belt',
      EquipmentSlot.legs => 'Legs',
      EquipmentSlot.boots => 'Boots',
      EquipmentSlot.wrist => 'Wrist',
      EquipmentSlot.hands => 'Hands',
      EquipmentSlot.cloak => 'Cloak',
      EquipmentSlot.ring || EquipmentSlot.ring2 => 'Ring',
      EquipmentSlot.trinket || EquipmentSlot.trinket2 => 'Trinket',
      EquipmentSlot.consumable => 'Flask',
      _ => 'Gear',
    };
  }

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
    if (attackBonus != 0) parts.add('+$attackBonus ATK');
    if (mp5Bonus != 0) parts.add('+$mp5Bonus Mp5');
    if (critChanceBonus != 0) parts.add('+$critChanceBonus% CRIT');
    if (masteryBonus != 0) parts.add('+$masteryBonus Mastery');
    if (attackSpeedBonus != 0) parts.add('+$attackSpeedBonus% ASPD');
    if (moveSpeedBonus != 0) parts.add('+$moveSpeedBonus% MOVE');
    if (effectLabel.isNotEmpty) parts.add(effectLabel);
    if (setId != null && setId!.isNotEmpty) {
      parts.add(setLabel);
    }
    if (isApex) parts.add('APEX R$apexRank');
    return parts.join(' · ');
  }

  /// Human-readable set tag for tooltips (e.g. "Cavern Plate").
  String get setLabel {
    final id = setId;
    if (id == null || id.isEmpty) return '';
    final parts = id.split('_');
    if (parts.length < 2) return id;
    final zone = switch (parts.first) {
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
      'rime' => 'Rimeglass',
      'fen' => 'Blightfen',
      'brass' => 'Brassvault',
      'veil' => 'Mothveil',
      _ => parts.first,
    };
    final armor = parts.sublist(1).join(' ');
    final armorTitle = armor.isEmpty
        ? ''
        : '${armor[0].toUpperCase()}${armor.substring(1)}';
    return '$zone $armorTitle'.trim();
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
    'masteryBonus': masteryBonus,
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
    if (visualSetId != null) 'visualSetId': visualSetId,
    if (affixPrefixId != null) 'affixPrefixId': affixPrefixId,
    if (affixSuffixId != null) 'affixSuffixId': affixSuffixId,
    if (setId != null) 'setId': setId,
    if (isApex) 'isApex': true,
    if (apexClassId != null) 'apexClassId': apexClassId,
    if (apexRoleTag != null) 'apexRoleTag': apexRoleTag,
    if (apexRank != 0) 'apexRank': apexRank,
  };

  factory EquipmentItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? fallback;
    }

    final slot = EquipmentSlotX.parse(json['slot'] as String);
    final patternRaw = json['pattern'] as String?;
    final effectRaw = json['effectId'] as String?;
    final armorRaw = json['armorType'] as String?;
    final weaponRaw = json['weaponType'] as String?;
    final handedRaw = json['handed'] as String?;
    final offHandRaw = json['offHandKind'] as String?;

    var strength = asInt(json['strengthBonus']);
    var agility = asInt(json['agilityBonus']);
    var stamina = asInt(json['staminaBonus']);
    var intellect = asInt(json['intellectBonus']);
    var spirit = asInt(json['spiritBonus']);
    var spellPower = asInt(json['spellPowerBonus']);
    var armor = asInt(json['armorBonus']);
    final attack = asInt(json['attackBonus']);
    final defense = asInt(json['defenseBonus']);
    final vitality = asInt(json['vitalityBonus']);

    // Legacy-only piece: fold old flats into new fields.
    final hasPrimaries =
        json.containsKey('strengthBonus') ||
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
      mp5Bonus: asInt(json['mp5Bonus']),
      attackBonus: attack,
      defenseBonus: defense,
      vitalityBonus: vitality,
      critChanceBonus: asInt(json['critChanceBonus']),
      masteryBonus: asInt(json['masteryBonus']),
      attackSpeedBonus: asInt(json['attackSpeedBonus']),
      moveSpeedBonus: asInt(json['moveSpeedBonus']),
      pattern: patternRaw == null
          ? ProjectilePattern.single
          : ProjectilePattern.values.byName(patternRaw),
      effectId: effectRaw == null
          ? GearEffectId.none
          : GearEffectId.values.byName(effectRaw),
      effectValue: asInt(json['effectValue']),
      affinity: json['affinity'] as String?,
      itemLevel: asInt(json['itemLevel']),
      armorType: armorRaw == null ? null : ArmorType.values.byName(armorRaw),
      weaponType: weaponRaw == null
          ? null
          : WeaponType.values.byName(weaponRaw),
      handed: handedRaw == null ? null : WeaponHanded.values.byName(handedRaw),
      offHandKind: offKind,
      iconId: json['iconId'] as String?,
      visualSetId: json['visualSetId'] as String?,
      affixPrefixId: json['affixPrefixId'] as String?,
      affixSuffixId: json['affixSuffixId'] as String?,
      setId: json['setId'] as String?,
      isApex: json['isApex'] as bool? ?? false,
      apexClassId: json['apexClassId'] as String?,
      apexRoleTag: json['apexRoleTag'] as String?,
      apexRank: asInt(json['apexRank']),
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
    int? masteryBonus,
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
    String? visualSetId,
    bool clearVisualSetId = false,
    String? affixPrefixId,
    String? affixSuffixId,
    String? setId,
    bool clearSetId = false,
    bool? isApex,
    String? apexClassId,
    String? apexRoleTag,
    int? apexRank,
    bool clearApexClassId = false,
    bool clearApexRoleTag = false,
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
      masteryBonus: masteryBonus ?? this.masteryBonus,
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
      visualSetId: clearVisualSetId
          ? null
          : (visualSetId ?? this.visualSetId),
      affixPrefixId: affixPrefixId ?? this.affixPrefixId,
      affixSuffixId: affixSuffixId ?? this.affixSuffixId,
      setId: clearSetId ? null : (setId ?? this.setId),
      isApex: isApex ?? this.isApex,
      apexClassId: clearApexClassId ? null : (apexClassId ?? this.apexClassId),
      apexRoleTag: clearApexRoleTag ? null : (apexRoleTag ?? this.apexRoleTag),
      apexRank: apexRank ?? this.apexRank,
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
    int asInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? fallback;
    }

    final equipmentJson = json['equipment'] as Map<String, dynamic>?;
    final outcomeRaw = json['outcome'] as String?;
    return LootDrop(
      name: json['name'] as String,
      amount: asInt(json['amount']),
      rarity: LootRarity.values.byName(json['rarity'] as String),
      equipment: equipmentJson == null
          ? null
          : EquipmentItem.fromJson(equipmentJson),
      outcome: outcomeRaw == null
          ? LootOutcome.essence
          : LootOutcome.values.byName(outcomeRaw),
      essenceGained: asInt(json['essenceGained']),
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
