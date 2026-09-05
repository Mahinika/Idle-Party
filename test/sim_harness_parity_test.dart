import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';

import '../tool/sim_harness.dart';

void main() {
  test('live mode uses flasks and God Hand like the director', () {
    seedEquipmentRng(7);
    var state = createPartyState(partySpecs: const [
      HeroSpecId.protection,
      HeroSpecId.discipline,
      HeroSpecId.fire,
    ]);
    state = prepareSimParty(state, band: 'light', partyLevel: 10);
    expect(
      state.heroes.every(
        (h) => h.equipped[EquipmentSlot.consumable] != null,
      ),
      isTrue,
    );
    state = enterFloor(
      state,
      dungeonId: 'sandy',
      floor: 5,
      seed: 42,
    );
    final live = simulateFloor(state, mode: SimPlayMode.live, maxSeconds: 45);
    expect(live.godHandCasts, greaterThan(0));
    expect(live.cleared || live.wiped || live.timedOut, isTrue);
  });

  test('afk mode enables assist and still clears sandy F5', () {
    seedEquipmentRng(9);
    var state = createPartyState(partySpecs: const [
      HeroSpecId.protection,
      HeroSpecId.discipline,
      HeroSpecId.arms,
    ]);
    state = prepareSimParty(state, band: 'mid', partyLevel: 12);
    state = enterFloor(
      state,
      dungeonId: 'sandy',
      floor: 5,
      seed: 99,
    );
    final afk = simulateFloor(state, mode: SimPlayMode.afk, maxSeconds: 60);
    expect(afk.cleared, isTrue);
    expect(afk.godHandCasts, greaterThan(0));
  });

  test('mid gear outfits full kits at party level', () {
    seedEquipmentRng(3);
    var state = createPartyState(partySpecs: const [
      HeroSpecId.protection,
      HeroSpecId.discipline,
      HeroSpecId.marksmanship,
    ]);
    state = prepareSimParty(state, band: 'mid', partyLevel: 12);
    for (final h in state.heroes) {
      expect(h.equipped[EquipmentSlot.weapon], isNotNull);
      expect(h.equipped[EquipmentSlot.chest], isNotNull);
      expect(
        h.equipped[EquipmentSlot.weapon]!.rarity.index,
        greaterThanOrEqualTo(LootRarity.rare.index),
      );
    }
  });

  test('light band keeps starter kits (forge only)', () {
    seedEquipmentRng(5);
    var light = createPartyState(partySpecs: const [
      HeroSpecId.protection,
      HeroSpecId.discipline,
      HeroSpecId.fire,
    ]);
    light = prepareSimParty(light, band: 'light', partyLevel: 12);
    var mid = createPartyState(partySpecs: const [
      HeroSpecId.protection,
      HeroSpecId.discipline,
      HeroSpecId.fire,
    ]);
    mid = prepareSimParty(mid, band: 'mid', partyLevel: 12);
    expect(
      mid.heroes.first.equipped[EquipmentSlot.weapon]!.rarity.index,
      greaterThanOrEqualTo(LootRarity.rare.index),
    );
    expect(
      light.heroes.first.equipped[EquipmentSlot.weapon]!.rarity.index,
      lessThan(LootRarity.rare.index),
    );
  });
}
