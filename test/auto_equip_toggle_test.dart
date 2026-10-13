import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';

void main() {
  test('AUTO EQUIP wears a budget upgrade, and off or Ranked GR does not', () {
    final worn = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.uncommon,
      battleNumber: 4,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'worn_cloak_auto',
      strengthBonus: 2,
      staminaBonus: 2,
      armorBonus: 2,
      itemLevel: 12,
      effectId: GearEffectId.none,
      effectValue: 0,
      clearAffinity: true,
    );
    final upgrade = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'bag_cloak_auto',
      strengthBonus: 14,
      staminaBonus: 12,
      armorBonus: 16,
      itemLevel: 28,
      effectId: GearEffectId.none,
      effectValue: 0,
      clearAffinity: true,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 10, 13));
    expect(state.autoEquipUpgrades, isTrue);
    final heroes = [
      for (var i = 0; i < state.heroes.length; i++)
        state.heroes[i].copyWith(
          equipped: {
            for (final e in state.heroes[i].equipped.entries)
              if (e.key != EquipmentSlot.cloak) e.key: e.value,
            EquipmentSlot.cloak: worn.copyWith(id: 'worn_cloak_auto_$i'),
          },
        ),
    ];
    state = state.copyWith(heroes: heroes, gearStash: [upgrade]);

    final off = GameLogic.maybeAutoEquip(
      state.copyWith(autoEquipUpgrades: false),
    );
    expect(off.heroes[0].itemIn(EquipmentSlot.cloak)?.id, 'worn_cloak_auto_0');

    final rift = GameLogic.maybeAutoEquip(state.copyWith(inGreaterRift: true));
    expect(rift.gearStash.map((e) => e.id), contains(upgrade.id));

    final wornOn = GameLogic.maybeAutoEquip(state);
    expect(wornOn.heroes[0].itemIn(EquipmentSlot.cloak)?.id, upgrade.id);
  });

  test('old saves default AUTO EQUIP on, and Ascend keeps the switch', () {
    final fresh = GameLogic.createInitialState(now: DateTime(2026, 10, 13));
    final json = fresh.toJson()..remove('autoEquipUpgrades');
    expect(GameLogic.stateFromJson(json).autoEquipUpgrades, isTrue);

    final off = fresh.copyWith(
      autoEquipUpgrades: false,
      bossVictories: GameLogic.bossesRequiredForAscension(0),
      essence: 9999,
    );
    expect(GameLogic.ascend(off).autoEquipUpgrades, isFalse);
  });
}
