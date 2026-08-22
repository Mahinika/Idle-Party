import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../models/enemy.dart';

/// Tunable drop-rate defaults loaded from `assets/data/drop_tables.json`.
///
/// Embedded fallbacks match the pre-JSON magic numbers in [LootPipeline].
abstract final class DropTables {
  static DropTablesData _data = DropTablesData.defaults;

  static DropTablesData get current => _data;

  static Future<void> load({AssetBundle? bundle}) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(
        'assets/data/drop_tables.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      _data = DropTablesData.fromJson(decoded);
    } catch (_) {
      _data = DropTablesData.defaults;
    }
  }

  static void resetToDefaults() {
    _data = DropTablesData.defaults;
  }
}

class DropTablesData {
  const DropTablesData({
    required this.killLoot,
    required this.roomChest,
    required this.floorClear,
    required this.finalize,
    required this.rarityForBattle,
    required this.offHandTargetWeight,
  });

  static final DropTablesData defaults = DropTablesData(
    killLoot: KillLootTable.defaults,
    roomChest: RoomChestTable.defaults,
    floorClear: FloorClearTable.defaults,
    finalize: FinalizeTable.defaults,
    rarityForBattle: RarityForBattleTable.defaults,
    offHandTargetWeight: OffHandWeightTable.defaults,
  );

  factory DropTablesData.fromJson(Map<String, dynamic> json) {
    return DropTablesData(
      killLoot: KillLootTable.fromJson(
        json['killLoot'] as Map<String, dynamic>? ?? const {},
      ),
      roomChest: RoomChestTable.fromJson(
        json['roomChest'] as Map<String, dynamic>? ?? const {},
      ),
      floorClear: FloorClearTable.fromJson(
        json['floorClear'] as Map<String, dynamic>? ?? const {},
      ),
      finalize: FinalizeTable.fromJson(
        json['finalize'] as Map<String, dynamic>? ?? const {},
      ),
      rarityForBattle: RarityForBattleTable.fromJson(
        json['rarityForBattle'] as Map<String, dynamic>? ?? const {},
      ),
      offHandTargetWeight: OffHandWeightTable.fromJson(
        json['offHandTargetWeight'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final KillLootTable killLoot;
  final RoomChestTable roomChest;
  final FloorClearTable floorClear;
  final FinalizeTable finalize;
  final RarityForBattleTable rarityForBattle;
  final OffHandWeightTable offHandTargetWeight;
}

class RoleScalars {
  const RoleScalars({required this.boss, required this.elite, required this.normal});

  static const RoleScalars defaults = RoleScalars(
    boss: 0.25,
    elite: 0.12,
    normal: 0.0,
  );

  factory RoleScalars.fromJson(Map<String, dynamic> json) {
    return RoleScalars(
      boss: (json['boss'] as num?)?.toDouble() ?? defaults.boss,
      elite: (json['elite'] as num?)?.toDouble() ?? defaults.elite,
      normal: (json['normal'] as num?)?.toDouble() ?? defaults.normal,
    );
  }

  double forRole(EnemyRole role) => switch (role) {
    EnemyRole.boss => boss,
    EnemyRole.elite => elite,
    EnemyRole.normal => normal,
  };

  final double boss;
  final double elite;
  final double normal;
}

class RoleMulScalars {
  const RoleMulScalars({required this.boss, required this.elite, required this.normal});

  static const RoleMulScalars defaults = RoleMulScalars(
    boss: 1.75,
    elite: 1.35,
    normal: 1.0,
  );

  factory RoleMulScalars.fromJson(Map<String, dynamic> json) {
    return RoleMulScalars(
      boss: (json['boss'] as num?)?.toDouble() ?? defaults.boss,
      elite: (json['elite'] as num?)?.toDouble() ?? defaults.elite,
      normal: (json['normal'] as num?)?.toDouble() ?? defaults.normal,
    );
  }

  double forRole(EnemyRole role) => switch (role) {
    EnemyRole.boss => boss,
    EnemyRole.elite => elite,
    EnemyRole.normal => normal,
  };

  final double boss;
  final double elite;
  final double normal;
}

class KillLootTable {
  const KillLootTable({
    required this.roleSkipRelief,
    required this.skipChanceMin,
    required this.skipChanceMax,
    required this.hmSkipFactor,
    required this.lootFindDivisor,
    required this.rarityBumps,
    required this.secondDropMinBattle,
    required this.secondHighBattleThreshold,
    required this.secondHighBase,
    required this.secondHighLootFindDivisor,
    required this.secondLowBase,
    required this.secondLowLootFindDivisor,
    required this.secondHighCap,
    required this.secondLowCap,
    required this.roleSecondMul,
  });

  static const KillLootTable defaults = KillLootTable(
    roleSkipRelief: RoleScalars.defaults,
    skipChanceMin: 0.0,
    skipChanceMax: 0.55,
    hmSkipFactor: 0.012,
    lootFindDivisor: 100.0,
    rarityBumps: RoleBumpScalars.defaults,
    secondDropMinBattle: 4,
    secondHighBattleThreshold: 6,
    secondHighBase: 0.22,
    secondHighLootFindDivisor: 200.0,
    secondLowBase: 0.08,
    secondLowLootFindDivisor: 250.0,
    secondHighCap: 0.55,
    secondLowCap: 0.28,
    roleSecondMul: RoleMulScalars.defaults,
  );

  factory KillLootTable.fromJson(Map<String, dynamic> json) {
    final clamp = json['skipChanceClamp'] as Map<String, dynamic>? ?? const {};
    final second = json['secondChance'] as Map<String, dynamic>? ?? const {};
    return KillLootTable(
      roleSkipRelief: RoleScalars.fromJson(
        json['roleSkipRelief'] as Map<String, dynamic>? ?? const {},
      ),
      skipChanceMin: (clamp['min'] as num?)?.toDouble() ?? defaults.skipChanceMin,
      skipChanceMax: (clamp['max'] as num?)?.toDouble() ?? defaults.skipChanceMax,
      hmSkipFactor:
          (json['hmSkipFactor'] as num?)?.toDouble() ?? defaults.hmSkipFactor,
      lootFindDivisor:
          (json['lootFindDivisor'] as num?)?.toDouble() ??
          defaults.lootFindDivisor,
      rarityBumps: RoleBumpScalars.fromJson(
        json['rarityBumps'] as Map<String, dynamic>? ?? const {},
      ),
      secondDropMinBattle:
          json['secondDropMinBattle'] as int? ?? defaults.secondDropMinBattle,
      secondHighBattleThreshold:
          second['highBattleThreshold'] as int? ??
          defaults.secondHighBattleThreshold,
      secondHighBase:
          (second['highBase'] as num?)?.toDouble() ?? defaults.secondHighBase,
      secondHighLootFindDivisor:
          (second['highLootFindDivisor'] as num?)?.toDouble() ??
          defaults.secondHighLootFindDivisor,
      secondLowBase:
          (second['lowBase'] as num?)?.toDouble() ?? defaults.secondLowBase,
      secondLowLootFindDivisor:
          (second['lowLootFindDivisor'] as num?)?.toDouble() ??
          defaults.secondLowLootFindDivisor,
      secondHighCap:
          (second['highCap'] as num?)?.toDouble() ?? defaults.secondHighCap,
      secondLowCap:
          (second['lowCap'] as num?)?.toDouble() ?? defaults.secondLowCap,
      roleSecondMul: RoleMulScalars.fromJson(
        json['roleSecondMul'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final RoleScalars roleSkipRelief;
  final double skipChanceMin;
  final double skipChanceMax;
  final double hmSkipFactor;
  final double lootFindDivisor;
  final RoleBumpScalars rarityBumps;
  final int secondDropMinBattle;
  final int secondHighBattleThreshold;
  final double secondHighBase;
  final double secondHighLootFindDivisor;
  final double secondLowBase;
  final double secondLowLootFindDivisor;
  final double secondHighCap;
  final double secondLowCap;
  final RoleMulScalars roleSecondMul;
}

class RoleBumpScalars {
  const RoleBumpScalars({required this.boss, required this.elite, required this.normal});

  static const RoleBumpScalars defaults = RoleBumpScalars(
    boss: 2,
    elite: 1,
    normal: 0,
  );

  factory RoleBumpScalars.fromJson(Map<String, dynamic> json) {
    return RoleBumpScalars(
      boss: json['boss'] as int? ?? defaults.boss,
      elite: json['elite'] as int? ?? defaults.elite,
      normal: json['normal'] as int? ?? defaults.normal,
    );
  }

  int forRole(EnemyRole role) => switch (role) {
    EnemyRole.boss => boss,
    EnemyRole.elite => elite,
    EnemyRole.normal => normal,
  };

  final int boss;
  final int elite;
  final int normal;
}

class RoomChestTable {
  const RoomChestTable({
    required this.goldMin,
    required this.goldBudgetDivisor,
    required this.gearChance,
  });

  static const RoomChestTable defaults = RoomChestTable(
    goldMin: 4,
    goldBudgetDivisor: 5,
    gearChance: 0.42,
  );

  factory RoomChestTable.fromJson(Map<String, dynamic> json) {
    return RoomChestTable(
      goldMin: json['goldMin'] as int? ?? defaults.goldMin,
      goldBudgetDivisor:
          json['goldBudgetDivisor'] as int? ?? defaults.goldBudgetDivisor,
      gearChance:
          (json['gearChance'] as num?)?.toDouble() ?? defaults.gearChance,
    );
  }

  final int goldMin;
  final int goldBudgetDivisor;
  final double gearChance;
}

class FloorClearTable {
  const FloorClearTable({
    required this.goldPouchEvery,
    required this.relicEvery,
  });

  static const FloorClearTable defaults = FloorClearTable(
    goldPouchEvery: 4,
    relicEvery: 9,
  );

  factory FloorClearTable.fromJson(Map<String, dynamic> json) {
    return FloorClearTable(
      goldPouchEvery:
          json['goldPouchEvery'] as int? ?? defaults.goldPouchEvery,
      relicEvery: json['relicEvery'] as int? ?? defaults.relicEvery,
    );
  }

  final int goldPouchEvery;
  final int relicEvery;
}

class FinalizeTable {
  const FinalizeTable({required this.softCap});

  static const FinalizeTable defaults = FinalizeTable(softCap: 5);

  factory FinalizeTable.fromJson(Map<String, dynamic> json) {
    return FinalizeTable(softCap: json['softCap'] as int? ?? defaults.softCap);
  }

  final int softCap;
}

class RarityForBattleTable {
  const RarityForBattleTable({
    required this.epicEvery,
    required this.rareEvery,
    required this.uncommonEvery,
  });

  static const RarityForBattleTable defaults = RarityForBattleTable(
    epicEvery: 12,
    rareEvery: 6,
    uncommonEvery: 3,
  );

  factory RarityForBattleTable.fromJson(Map<String, dynamic> json) {
    return RarityForBattleTable(
      epicEvery: json['epicEvery'] as int? ?? defaults.epicEvery,
      rareEvery: json['rareEvery'] as int? ?? defaults.rareEvery,
      uncommonEvery:
          json['uncommonEvery'] as int? ?? defaults.uncommonEvery,
    );
  }

  final int epicEvery;
  final int rareEvery;
  final int uncommonEvery;
}

class OffHandWeightTable {
  const OffHandWeightTable({required this.shield, required this.defaultWeight});

  static const OffHandWeightTable defaults = OffHandWeightTable(
    shield: 2,
    defaultWeight: 1,
  );

  factory OffHandWeightTable.fromJson(Map<String, dynamic> json) {
    return OffHandWeightTable(
      shield: json['shield'] as int? ?? defaults.shield,
      defaultWeight: json['default'] as int? ?? defaults.defaultWeight,
    );
  }

  final int shield;
  final int defaultWeight;
}
