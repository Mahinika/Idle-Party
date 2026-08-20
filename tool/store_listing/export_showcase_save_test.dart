/// Writes a photogenic save JSON for Play Store browser capture.
///
///   flutter test tool/store_listing/export_showcase_save_test.dart
@Tags(['store_shots'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/first_session_tips.dart';

GameState showcaseState() {
  final tipIds = [for (final t in FirstSessionTips.tips) t.id];
  final state = GameLogic.createInitialState(
    now: DateTime.utc(2026, 8, 20, 12),
    partySpecs: const [
      HeroSpecId.protection,
      HeroSpecId.discipline,
      HeroSpecId.fire,
    ],
  );
  final heroes = [
    for (final h in state.heroes)
      h.copyWith(
        level: 28 + (h.specId == HeroSpecId.fire ? 4 : 0),
        xp: 400,
      ),
  ];
  const slots = [
    EquipmentSlot.weapon,
    EquipmentSlot.head,
    EquipmentSlot.chest,
    EquipmentSlot.legs,
    EquipmentSlot.hands,
    EquipmentSlot.boots,
    EquipmentSlot.ring,
    EquipmentSlot.trinket,
  ];
  final stash = <EquipmentItem>[
    for (var i = 0; i < slots.length; i++)
      EquipmentFactory.create(
        slot: slots[i],
        rarity: i.isEven ? LootRarity.epic : LootRarity.rare,
        battleNumber: 55 + i * 3,
        bias: HeroRole.mage,
        dungeonId: 'ember',
        ascensionLevel: 3,
      ),
  ];
  return state.copyWith(
    heroes: heroes,
    gold: 18420,
    lifetimeGoldEarned: 2_600_000,
    essence: 340,
    attackBonus: 18,
    defenseBonus: 22,
    vitalityBonus: 30,
    sanctuaryGoldLevel: 6,
    sanctuaryPowerLevel: 4,
    sanctuaryVitalityLevel: 3,
    godHandLevel: 5,
    highestDungeonCleared: 9,
    highestFloorCleared: 12,
    dungeonId: 'ember',
    dungeonMode: DungeonMode.farm,
    hardmodeLevel: 4,
    ascensionLevel: 3,
    gearStash: stash,
    seenTips: tipIds,
    soundMuted: true,
    metaDepth: state.metaDepth.copyWith(
      ascendBlessings: 3,
      unlockedSpecs: [for (final s in HeroSpecs.all) s.id.name],
      partySlot5Unlocked: true,
    ),
  );
}

void main() {
  test('export showcase save json', () {
    final out = File('tool/store_listing/showcase_save.json');
    out.parent.createSync(recursive: true);
    final state = showcaseState();
    out.writeAsStringSync(jsonEncode(state.toJson()));
    expect(out.existsSync(), isTrue);
    final roundTrip = GameState.fromJson(
      jsonDecode(out.readAsStringSync()) as Map<String, dynamic>,
    );
    expect(roundTrip.gold, 18420);
    expect(roundTrip.ascensionLevel, 3);
    expect(GameLogic.importSaveJson(out.readAsStringSync()), isNotNull);
    // ignore: avoid_print
    print('wrote ${out.path} (${out.lengthSync()} bytes)');
  });
}
