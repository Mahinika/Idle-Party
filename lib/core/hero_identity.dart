import '../models/hero_spec.dart';

/// Spec fantasy identity — sprite remap + tint + unlock copy.
///
/// Tint is ARGB (`0xAARRGGBB`); UI converts with `Color(tint)`.
abstract final class HeroIdentity {
  /// Which class body to draw (some specs borrow a sibling fantasy).
  static HeroClassId spriteClassFor(HeroSpecId specId) {
    return switch (specId) {
      // Shadow reads as void caster, not white-robe healer.
      HeroSpecId.shadow => HeroClassId.warlock,
      _ => HeroSpecs.def(specId).classId,
    };
  }

  /// Soft recolor so specs in the same class don't look identical.
  static int? tintArgb(HeroSpecId specId) {
    return switch (specId) {
      // Warrior
      HeroSpecId.arms => 0xFFE8E0D0,
      HeroSpecId.fury => 0xFFFFB080,
      HeroSpecId.protection => 0xFFB0C8F0,
      // Paladin
      HeroSpecId.holyPaladin => 0xFFFFF0A8,
      HeroSpecId.protPaladin => 0xFFC0D0FF,
      HeroSpecId.retribution => 0xFFFFD070,
      // Hunter
      HeroSpecId.beastMastery => 0xFFB8E090,
      HeroSpecId.marksmanship => 0xFF90D0A8,
      HeroSpecId.survival => 0xFFD0B070,
      // Rogue
      HeroSpecId.assassination => 0xFFE090C0,
      HeroSpecId.combat => 0xFFE8C090,
      HeroSpecId.subtlety => 0xFFB090E0,
      // Priest
      HeroSpecId.discipline => 0xFFFFF8E0,
      HeroSpecId.holyPriest => 0xFFFFE8A0,
      HeroSpecId.shadow => 0xFFC090E8,
      // DK
      HeroSpecId.blood => 0xFFFF9090,
      HeroSpecId.frostDk => 0xFFA0D8FF,
      HeroSpecId.unholy => 0xFF90E0A0,
      // Shaman
      HeroSpecId.elemental => 0xFF90D0FF,
      HeroSpecId.enhancement => 0xFFFFB070,
      HeroSpecId.restorationShaman => 0xFF90E8C0,
      // Mage
      HeroSpecId.arcane => 0xFFD0A0FF,
      HeroSpecId.fire => 0xFFFFA060,
      HeroSpecId.frostMage => 0xFFA0E0FF,
      // Warlock
      HeroSpecId.affliction => 0xFFC080E0,
      HeroSpecId.demonology => 0xFFE08060,
      HeroSpecId.destruction => 0xFFFF8060,
      // Druid
      HeroSpecId.balance => 0xFFE0C060,
      HeroSpecId.feral => 0xFFE09060,
      HeroSpecId.guardian => 0xFFB0A080,
      HeroSpecId.restorationDruid => 0xFF90E090,
    };
  }

  /// One-line fantasy for unlock toast / Meet card (GEAR/SYSTEMS meetBlurb).
  static String meetBlurb(HeroSpecId specId) => fantasyLine(specId);

  /// One-line fantasy for unlock toast / reveal card.
  static String fantasyLine(HeroSpecId specId) {
    return switch (specId) {
      HeroSpecId.arms => 'Sweeping arms — cleave the pack.',
      HeroSpecId.fury => 'Dual rage — hit hard, hit often.',
      HeroSpecId.protection => 'Shield wall — hold the line.',
      HeroSpecId.holyPaladin => 'Holy light — plate healer.',
      HeroSpecId.protPaladin => 'Consecrated tank — righteous fury.',
      HeroSpecId.retribution => 'Holy strike — melee crusader.',
      HeroSpecId.beastMastery => 'Pet power — beast and hunter.',
      HeroSpecId.marksmanship => 'Aimed shots — clean single-target.',
      HeroSpecId.survival => 'Traps and kite — messy survival.',
      HeroSpecId.assassination => 'Poisons and finishers.',
      HeroSpecId.combat => 'Combat blades — combo pressure.',
      HeroSpecId.subtlety => 'Shadows and openers.',
      HeroSpecId.discipline => 'Shields and triage.',
      HeroSpecId.holyPriest => 'Holy waves — party heal.',
      HeroSpecId.shadow => 'DoTs from the void.',
      HeroSpecId.blood => 'Selfish tank — blood for blood.',
      HeroSpecId.frostDk => 'Frost and howls — icy pressure.',
      HeroSpecId.unholy => 'Disease and ghouls.',
      HeroSpecId.elemental => 'Lightning and lava bursts.',
      HeroSpecId.enhancement => 'Stormstrike melee shaman.',
      HeroSpecId.restorationShaman => 'Totems and chain heals.',
      HeroSpecId.arcane => 'Charge and dump — mana missiles.',
      HeroSpecId.fire => 'Hot Streak pyroblasts.',
      HeroSpecId.frostMage => 'Freeze and shatter.',
      HeroSpecId.affliction => 'Stack the curses.',
      HeroSpecId.demonology => 'Demons fight for you.',
      HeroSpecId.destruction => 'Chaos bolts — big nukes.',
      HeroSpecId.balance => 'Moonfire and stars.',
      HeroSpecId.feral => 'Bleeds and bites.',
      HeroSpecId.guardian => 'Bear form — thrash the pack.',
      HeroSpecId.restorationDruid => 'HoTs that keep ticking.',
    };
  }

  /// Visible kit hook for Meet / Ascend teasers (what to watch in combat).
  static String meetHook(HeroSpecId specId) {
    return switch (specId) {
      HeroSpecId.arms => 'Watch Bladestorm / cleave waves.',
      HeroSpecId.fury => 'Watch dual-wield rage dumps.',
      HeroSpecId.protection => 'Watch Shield Slam + block fantasy.',
      HeroSpecId.holyPaladin => 'Watch Holy Light / Beacon peels.',
      HeroSpecId.protPaladin => 'Watch Consecration under packs.',
      HeroSpecId.retribution => 'Watch Crusader Strike pressure.',
      HeroSpecId.beastMastery => 'Watch the pet melt with you.',
      HeroSpecId.marksmanship => 'Watch Aimed Shot punches.',
      HeroSpecId.survival => 'Watch traps and Explosive Shot.',
      HeroSpecId.assassination => 'Watch poisons tick into finishers.',
      HeroSpecId.combat => 'Watch Sinister → Eviscerate chains.',
      HeroSpecId.subtlety => 'Watch openers from stealth.',
      HeroSpecId.discipline => 'Watch shields land before damage.',
      HeroSpecId.holyPriest => 'Watch Circle of Healing splashes.',
      HeroSpecId.shadow => 'Watch DoTs blanket the pack.',
      HeroSpecId.blood => 'Watch self-heals while tanking.',
      HeroSpecId.frostDk => 'Watch Howling Blast / frost pressure.',
      HeroSpecId.unholy => 'Watch diseases and ghoul assists.',
      HeroSpecId.elemental => 'Watch Lightning / Lava Burst bursts.',
      HeroSpecId.enhancement => 'Watch Stormstrike melee swings.',
      HeroSpecId.restorationShaman => 'Watch Riptide / Chain Heal.',
      HeroSpecId.arcane => 'Watch charge stacks then missiles.',
      HeroSpecId.fire => 'Watch Hot Streak Pyroblasts.',
      HeroSpecId.frostMage => 'Watch freeze into shatter.',
      HeroSpecId.affliction => 'Watch curses stack and drain.',
      HeroSpecId.demonology => 'Watch demons join the fight.',
      HeroSpecId.destruction => 'Watch Chaos Bolt nukes.',
      HeroSpecId.balance => 'Watch Moonfire / Starfall.',
      HeroSpecId.feral => 'Watch bleeds build into bites.',
      HeroSpecId.guardian => 'Watch Thrash / bear threat.',
      HeroSpecId.restorationDruid => 'Watch Rejuvenation HoTs tick.',
    };
  }

  /// Meet card body: fantasy + combat hook.
  static String meetDetail(HeroSpecId specId) =>
      '${meetBlurb(specId)} ${meetHook(specId)}';

  static HeroSpecId? tryParseSpec(String name) {
    for (final id in HeroSpecId.values) {
      if (id.name == name) return id;
    }
    return null;
  }
}
