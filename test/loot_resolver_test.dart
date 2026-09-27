import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gear/gear_cleanup.dart';
import 'package:idle_party/core/gear/loot_resolver.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/shell/shell_common.dart';

void main() {
  EquipmentItem junk({
    required String id,
    int ilvl = 10,
    LootRarity rarity = LootRarity.common,
  }) {
    return EquipmentItem(
      id: id,
      name: 'Junk $id',
      slot: EquipmentSlot.chest,
      rarity: rarity,
      staminaBonus: 4,
      itemLevel: ilvl,
    );
  }

  test('grant credits wallet gold via EconomyService bonuses', () {
    final state = GameLogic.createInitialState();
    const base = 100;
    final expected = GameLogic.applyGoldGain(state, base);
    final result = LootResolver.grant(state, [
      const LootDrop(
        name: 'Gold Pouch',
        amount: base,
        rarity: LootRarity.common,
      ),
    ]);
    expect(result.state.gold, state.gold + expected);
    expect(
      result.state.lifetimeGoldEarned,
      state.lifetimeGoldEarned + expected,
    );
    expect(result.receipt.goldGained, expected);
    expect(result.resolved.single.outcome, LootOutcome.gold);
  });

  test('grant stashes gear and reports receipt', () {
    final state = GameLogic.createInitialState().copyWith(
      autoSellMaxPower: 0,
      autoDisassembleMaxIlvl: 0,
    );
    final item = junk(id: 'chest_a', ilvl: 18, rarity: LootRarity.uncommon);
    final result = LootResolver.grant(state, [
      LootDrop(
        name: item.name,
        amount: 1,
        rarity: item.rarity,
        equipment: item,
      ),
    ]);
    expect(result.state.gearStash.any((g) => g.id == 'chest_a'), isTrue);
    expect(result.receipt.gearStashed, 1);
    expect(result.resolved.single.outcome, LootOutcome.stashed);
  });

  test('grant auto-sells low filter gear for gold', () {
    var state = GameLogic.createInitialState().copyWith(
      autoSellMaxPower: 30,
      autoSellMaxRarity: LootRarity.rare.index,
    );
    final item = junk(id: 'sell_me', ilvl: 12);
    final beforeGold = state.gold;
    final result = LootResolver.grant(state, [
      LootDrop(
        name: item.name,
        amount: 1,
        rarity: item.rarity,
        equipment: item,
      ),
    ]);
    expect(result.state.gearStash.any((g) => g.id == 'sell_me'), isFalse);
    expect(result.state.gold, greaterThan(beforeGold));
    expect(result.receipt.gearAutoSold, 1);
    expect(result.resolved.single.outcome, LootOutcome.gold);
  });

  test('grant essence for non-equipment drops', () {
    final state = GameLogic.createInitialState();
    final before = state.essence;
    final result = LootResolver.grant(state, [
      const LootDrop(name: 'Faded Dust', amount: 2, rarity: LootRarity.common),
    ]);
    expect(result.state.essence, greaterThan(before));
    expect(result.receipt.essenceGained, greaterThan(0));
    expect(result.resolved.single.outcome, LootOutcome.essence);
  });

  test('summaryLine summarizes mixed grant', () {
    const receipt = LootGrantResult(
      goldGained: 40,
      essenceGained: 6,
      gearStashed: 2,
      gearAutoSold: 1,
    );
    expect(receipt.summaryLine(), contains('2 gear'));
    expect(receipt.summaryLine(), contains('+40 g'));
    expect(receipt.summaryLine(includeGold: false), contains('2 gear'));
    expect(receipt.summaryLine(includeGold: false), contains('+6 e'));
    expect(receipt.summaryLine(includeGold: false), isNot(contains('+40 g')));
  });

  test('gold-only floor loot extra is empty so CLEAR does not double gold', () {
    const receipt = LootGrantResult(goldGained: 240);
    expect(receipt.summaryLine(), '+240 g');
    expect(receipt.summaryLine(includeGold: false), isEmpty);
  });

  test('near-iLvl slot backup is kept in bag heuristics', () {
    final worn = EquipmentItem(
      id: 'worn_chest',
      name: 'Worn',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      staminaBonus: 40,
      itemLevel: 42,
    );
    final backup = EquipmentItem(
      id: 'backup_chest',
      name: 'Backup',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      staminaBonus: 38,
      itemLevel: 40,
    );
    final junkChest = EquipmentItem(
      id: 'junk_chest',
      name: 'Junk',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.common,
      staminaBonus: 6,
      itemLevel: 38,
    );
    var state = GameLogic.createInitialState().copyWith(
      autoSellMaxPower: 50,
      autoSellMaxRarity: LootRarity.epic.index,
      gearStash: [backup, junkChest],
    );
    final heroes = [...state.heroes];
    heroes[0] = heroes[0].copyWith(equipped: {EquipmentSlot.chest: worn});
    state = state.copyWith(heroes: heroes);
    expect(GearCleanup.shouldKeepInBag(state, backup), isTrue);
    expect(GearCleanup.shouldAutoSellOnPickup(state, backup), isFalse);
    expect(GearCleanup.shouldAutoSellOnPickup(state, junkChest), isTrue);
  });

  test('manual CLEAN BAG sells filter matches even when upgrade backup', () {
    final worn = EquipmentItem(
      id: 'worn_chest',
      name: 'Worn',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      staminaBonus: 40,
      itemLevel: 42,
    );
    final backup = EquipmentItem(
      id: 'backup_chest',
      name: 'Backup',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      staminaBonus: 38,
      itemLevel: 40,
    );
    var state = GameLogic.createInitialState().copyWith(
      autoSellMaxPower: 50,
      autoSellMaxRarity: LootRarity.epic.index,
      autoDisassembleMaxIlvl: 0,
      gearStash: [backup],
    );
    final heroes = [...state.heroes];
    heroes[0] = heroes[0].copyWith(equipped: {EquipmentSlot.chest: worn});
    state = state.copyWith(heroes: heroes);
    expect(GearCleanup.shouldKeepInBag(state, backup), isTrue);

    final cleaned = GameLogic.cleanBagJunk(state, manualClean: true);
    expect(cleaned.gearStash.any((g) => g.id == 'backup_chest'), isFalse);
    expect(cleaned.gold, greaterThan(state.gold));
    expect(GearCleanup.cleanSellPreviewCount(state), 1);
    expect(GearCleanup.autoSellPreviewCount(state), 0);
  });

  test('combat pop label is a short slot word, not the full name', () {
    const mace = EquipmentItem(
      id: 'm1',
      name: 'Guard Plate Morningstar',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.uncommon,
      weaponType: WeaponType.mace,
      itemLevel: 17,
    );
    expect(mace.combatPopLabel, 'Mace');
    const chest = EquipmentItem(
      id: 'c1',
      name: 'Bulwark Plate Chest',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      itemLevel: 21,
    );
    expect(chest.combatPopLabel, 'Chest');
  });

  test('painted item level is the tag the sell filter uses', () {
    const sword = EquipmentItem(
      id: 'w1',
      name: 'Bulwark Sword',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.uncommon,
      strengthBonus: 22,
      staminaBonus: 43,
      masteryBonus: 5,
      effectValue: 9,
      itemLevel: 77,
      handed: WeaponHanded.oneHand,
    );
    expect(gearDisplayIlvl(sword), sword.effectiveItemLevel);
    expect(gearDisplayIlvl(sword), 77);
    const flask = EquipmentItem(
      id: 'f1',
      name: 'Healing Flask',
      slot: EquipmentSlot.consumable,
      rarity: LootRarity.common,
      itemLevel: 5,
    );
    expect(gearDisplayIlvl(flask), isNull);
  });

  test('worn item level is the median tag on the party', () {
    const sword = EquipmentItem(
      id: 'w77',
      name: 'Sword',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.uncommon,
      strengthBonus: 22,
      staminaBonus: 43,
      itemLevel: 77,
    );
    const chest = EquipmentItem(
      id: 'c70',
      name: 'Chest',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.uncommon,
      staminaBonus: 20,
      itemLevel: 70,
    );
    const helm = EquipmentItem(
      id: 'h80',
      name: 'Helm',
      slot: EquipmentSlot.head,
      rarity: LootRarity.uncommon,
      staminaBonus: 20,
      itemLevel: 80,
    );
    final base = GameLogic.createInitialState();
    final kit = {
      EquipmentSlot.weapon: sword,
      EquipmentSlot.chest: chest,
      EquipmentSlot.head: helm,
    };
    final state = base.copyWith(
      heroes: [for (final h in base.heroes) h.copyWith(equipped: kit)],
    );
    expect(GearCleanup.partyWornIlvl(state), 77);
  });
}
