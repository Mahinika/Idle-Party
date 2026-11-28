import '../models/hero.dart';
import '../models/hero_spec.dart';
import 'game_state.dart';

/// Fixed party positions: slot 1 tank, slot 2 healer, slots 3–5 DPS.
enum PartyRoleSlotKind { tank, healer, dps }

/// Saved in [GameState.activeHeroIds] when a role slot has no hero.
const String kPartyEmptySlotId = '';

abstract final class PartyRoleSlots {
  static const int tankIndex = 0;
  static const int healerIndex = 1;
  static const int firstDpsIndex = 2;

  static PartyRoleSlotKind kindAt(int slotIndex) {
    if (slotIndex <= tankIndex) return PartyRoleSlotKind.tank;
    if (slotIndex == healerIndex) return PartyRoleSlotKind.healer;
    return PartyRoleSlotKind.dps;
  }

  static PartyRoleBucket bucketForKind(PartyRoleSlotKind kind) =>
      switch (kind) {
        PartyRoleSlotKind.tank => PartyRoleBucket.tank,
        PartyRoleSlotKind.healer => PartyRoleBucket.healer,
        PartyRoleSlotKind.dps => PartyRoleBucket.dps,
      };

  static PartyRoleBucket bucketForSlot(int slotIndex) =>
      bucketForKind(kindAt(slotIndex));

  static bool heroFitsSlot(PartyHero hero, int slotIndex) =>
      HeroSpecs.partyRole(hero.specId) == bucketForSlot(slotIndex);

  static String slotLabel(int slotIndex) => switch (kindAt(slotIndex)) {
        PartyRoleSlotKind.tank => 'TANK',
        PartyRoleSlotKind.healer => 'HEALER',
        PartyRoleSlotKind.dps => 'DPS',
      };

  /// Pads / trims [raw] to [maxSlots] and maps heroes into fixed role slots.
  static List<String> migrateActiveHeroIds({
    required List<String> raw,
    required List<PartyHero> roster,
    required int maxSlots,
  }) {
    if (maxSlots <= 0) return const [];
    final byId = <String, PartyHero>{for (final h in roster) h.id: h};
    final slots = List<String>.filled(maxSlots, kPartyEmptySlotId);

    for (final id in raw) {
      if (id.isEmpty || id == kPartyEmptySlotId) continue;
      final hero = byId[id];
      if (hero == null) continue;
      final bucket = HeroSpecs.partyRole(hero.specId);
      switch (bucket) {
        case PartyRoleBucket.tank:
          if (slots[tankIndex].isEmpty) {
            slots[tankIndex] = id;
          }
        case PartyRoleBucket.healer:
          if (slots[healerIndex].isEmpty) {
            slots[healerIndex] = id;
          }
        case PartyRoleBucket.dps:
          for (var i = firstDpsIndex; i < maxSlots; i++) {
            if (slots[i].isEmpty) {
              slots[i] = id;
              break;
            }
          }
      }
    }
    return slots;
  }

  static bool needsMigration(GameState state) {
    final max = state.maxActivePartySize;
    final raw = state.activeHeroIds;
    if (raw.length != max) return true;
    final byId = <String, PartyHero>{for (final h in state.heroRoster) h.id: h};
    for (var i = 0; i < max; i++) {
      final id = raw[i];
      if (id.isEmpty) continue;
      final hero = byId[id];
      if (hero == null) return true;
      if (!heroFitsSlot(hero, i)) return true;
    }
    return false;
  }

  static List<String> paddedActiveIds(List<String> ids, int maxSlots) {
    if (maxSlots <= 0) return const [];
    final out = List<String>.from(ids);
    while (out.length < maxSlots) {
      out.add(kPartyEmptySlotId);
    }
    if (out.length > maxSlots) {
      return out.sublist(0, maxSlots);
    }
    return out;
  }

  /// Heroes in slot order; null entries are open role slots.
  static List<PartyHero?> slotHeroes(GameState state) {
    final max = state.maxActivePartySize;
    final ids = paddedActiveIds(state.activeHeroIds, max);
    final byId = <String, PartyHero>{for (final h in state.heroRoster) h.id: h};
    return [for (final id in ids) id.isEmpty ? null : byId[id]];
  }

  /// Active heroes with empty slots removed (combat / counts).
  static List<PartyHero> filledActiveHeroes(GameState state) => [
        for (final h in slotHeroes(state)) ?h,
      ];

  /// First open slot index for [specId], or null when every matching slot is full.
  static int? firstOpenSlotForSpec(GameState state, HeroSpecId specId) {
    final bucket = HeroSpecs.partyRole(specId);
    final max = state.maxActivePartySize;
    final slots = paddedActiveIds(state.activeHeroIds, max);
    for (var i = 0; i < max; i++) {
      if (bucketForSlot(i) != bucket) continue;
      if (slots[i].isEmpty) return i;
    }
    return null;
  }

  /// Active ids after placing [heroId] into [slotIndex] (clears other slots with same id).
  static List<String> withHeroInSlot({
    required List<String> current,
    required int slotIndex,
    required int maxSlots,
    required String? heroId,
  }) {
    final slots = paddedActiveIds(current, maxSlots);
    if (slotIndex < 0 || slotIndex >= maxSlots) return slots;
    final trimmed = heroId?.trim() ?? '';
    final nextId = trimmed.isEmpty ? kPartyEmptySlotId : trimmed;
    for (var i = 0; i < slots.length; i++) {
      if (i != slotIndex && nextId.isNotEmpty && slots[i] == nextId) {
        slots[i] = kPartyEmptySlotId;
      }
    }
    slots[slotIndex] = nextId;
    return slots;
  }

  static List<String> idsFromHeroesInRoleOrder(List<PartyHero> heroes, int maxSlots) {
    return migrateActiveHeroIds(
      raw: [for (final h in heroes) h.id],
      roster: heroes,
      maxSlots: maxSlots,
    );
  }
}