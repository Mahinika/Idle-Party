import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/hero_paper_doll.dart';

void main() {
  test('naked hero is body + hair only', () {
    final warrior = PartyHero.starting(
      name: 'Aegis',
      specId: HeroSpecId.protection,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.protection),
    );
    expect(warrior.equipped, isEmpty);
    final layers = HeroPaperDoll.layersFor(warrior);
    expect(layers.length, 2); // body + hair
    expect(layers.first.col, anyOf(0, 1));
  });

  test('equipped weapon and shield add visible layers', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    var warrior = state.heroes.firstWhere((h) => h.gearAffinity == HeroRole.warrior);
    final sword = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 5,
      bias: HeroRole.warrior,
    );
    final shield = GameLogic.createEquipment(
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.uncommon,
      battleNumber: 5,
      bias: HeroRole.warrior,
    );
    warrior = warrior.copyWith(
      equipped: {
        EquipmentSlot.weapon: sword,
        EquipmentSlot.offHand: shield,
      },
    );
    final layers = HeroPaperDoll.layersFor(warrior);
    expect(layers.length, greaterThanOrEqualTo(4)); // body hair shield weapon
    expect(HeroPaperDoll.weaponFor(warrior), isNotNull);
    expect(HeroPaperDoll.shieldFor(warrior), isNotNull);
    expect(HeroPaperDoll.torsoFor(warrior), isNull);
  });

  test('cloak and boots add torso and pants layers', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    var warrior = state.heroes.firstWhere((h) => h.gearAffinity == HeroRole.warrior);
    warrior = warrior.copyWith(
      equipped: {
        EquipmentSlot.cloak: GameLogic.createEquipment(
          slot: EquipmentSlot.cloak,
          rarity: LootRarity.common,
          battleNumber: 3,
          bias: HeroRole.warrior,
        ),
        EquipmentSlot.boots: GameLogic.createEquipment(
          slot: EquipmentSlot.boots,
          rarity: LootRarity.common,
          battleNumber: 3,
          bias: HeroRole.warrior,
        ),
        EquipmentSlot.head: GameLogic.createEquipment(
          slot: EquipmentSlot.head,
          rarity: LootRarity.rare,
          battleNumber: 6,
          bias: HeroRole.warrior,
        ),
      },
    );
    expect(HeroPaperDoll.torsoFor(warrior), isNotNull);
    expect(HeroPaperDoll.pantsFor(warrior), isNotNull);
    expect(HeroPaperDoll.headFor(warrior), isNotNull);
    final layers = HeroPaperDoll.layersFor(warrior);
    // Helmet replaces hair.
    expect(layers.any((l) => l.col >= 28 && l.col <= 31), isTrue);
  });
}
