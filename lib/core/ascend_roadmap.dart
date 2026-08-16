import '../models/hero_spec.dart';
import '../models/meta_depth.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'hero_identity.dart';
import 'meta_systems.dart';

/// Player-facing Ascend unlock teasers — “what’s next after this AL?”
abstract final class AscendRoadmap {
  /// Specs that unlock primarily by reaching this Ascension Level.
  ///
  /// Zone-clear and shop unlocks stay on their own hints; this list is the
  /// Ascend / TODAY “party power” ladder.
  static const Map<int, List<(HeroSpecId id, String label)>> kitUnlocksByAl = {
    1: [
      (HeroSpecId.combat, 'Combat Rogue'),
      (HeroSpecId.arms, 'Arms Warrior'),
      (HeroSpecId.holyPaladin, 'Holy Paladin'),
    ],
    2: [
      (HeroSpecId.beastMastery, 'Beast Mastery'),
      (HeroSpecId.holyPriest, 'Holy Priest'),
      (HeroSpecId.arcane, 'Arcane Mage'),
    ],
    3: [
      (HeroSpecId.protPaladin, 'Protection Paladin'),
      (HeroSpecId.assassination, 'Assassination'),
      (HeroSpecId.restorationShaman, 'Resto Shaman'),
      (HeroSpecId.frostMage, 'Frost Mage'),
      (HeroSpecId.restorationDruid, 'Resto Druid'),
    ],
    4: [
      (HeroSpecId.survival, 'Survival'),
      (HeroSpecId.elemental, 'Elemental'),
      (HeroSpecId.enhancement, 'Enhancement'),
      (HeroSpecId.balance, 'Balance'),
      (HeroSpecId.feral, 'Feral'),
    ],
    5: [
      (HeroSpecId.blood, 'Blood DK'),
      (HeroSpecId.frostDk, 'Frost DK'),
      (HeroSpecId.guardian, 'Guardian'),
    ],
    6: [
      (HeroSpecId.affliction, 'Affliction'),
      (HeroSpecId.demonology, 'Demonology'),
    ],
  };

  /// Short kit list for [al], or null if none.
  static String? kitUnlockSummary(int al, {int maxNames = 3}) {
    final kits = kitUnlocksByAl[al];
    if (kits == null || kits.isEmpty) return null;
    final names = [for (final k in kits.take(maxNames)) k.$2];
    final extra = kits.length - names.length;
    final joined = names.join(' · ');
    if (extra > 0) return '$joined · +$extra more';
    return joined;
  }

  /// Concrete unlock when the player **reaches** [al] (after Ascend).
  static String? unlockAtAl(int al) {
    if (al == 2) {
      final kits = kitUnlockSummary(2);
      return '$kits · 5th party slot '
          '(Forge · ${GameLogic.partySlot5EssenceCost}e)';
    }
    if (al == GameLogic.gauntletMinAscension) {
      final kits = kitUnlockSummary(al);
      return kits == null ? 'Infinity Gauntlet' : '$kits · Infinity Gauntlet';
    }

    final kits = kitUnlockSummary(al);
    if (kits != null) return kits;

    final title = AscendTitles.byAl[al];
    if (title != null) {
      final milestone = MetaSystems.ascendMilestones.contains(al)
          ? ' · +${MetaSystems.ascendMilestoneEssence(al)}e milestone'
          : '';
      return 'Title: $title$milestone';
    }

    if (MetaSystems.ascendMilestones.contains(al)) {
      return '+${MetaSystems.ascendMilestoneEssence(al)}e Ascend milestone';
    }
    return null;
  }

  /// Short line for confirm / toast when ascending **to** [nextAl].
  static String? unlockLineForAscendTo(int nextAl) {
    final unlock = unlockAtAl(nextAl);
    if (unlock == null) return null;
    return 'Unlock at AL$nextAl: $unlock';
  }

  /// Next meaningful goal from the player’s **current** AL (before Ascend).
  static String nextGoalLine(int currentAl) {
    for (var al = currentAl + 1; al <= 40; al++) {
      final unlock = unlockAtAl(al);
      if (unlock == null) continue;
      return 'Next: AL$al unlocks $unlock';
    }
    return 'Next: keep stacking Blessings and AL power';
  }

  /// Ascend level that unlocks [id], or null if it is not on this ladder.
  static int? ascendLevelForKit(HeroSpecId id) {
    for (final entry in kitUnlocksByAl.entries) {
      for (final kit in entry.value) {
        if (kit.$1 == id) return entry.key;
      }
    }
    return null;
  }

  /// Compact teaser for TODAY / hub chase detail.
  static String chaseTeaser(int currentAl) {
    for (var al = currentAl + 1; al <= 40; al++) {
      final unlock = unlockAtAl(al);
      if (unlock == null) continue;
      return 'AL$al → $unlock';
    }
    return 'Stack Blessings + AL power';
  }

  /// Next AL that still has kit unlocks the player has not rostered yet.
  static String? nextMissingKitTeaser(GameState state) {
    final al = state.ascensionLevel;
    for (var target = al + 1; target <= 6; target++) {
      final kits = kitUnlocksByAl[target];
      if (kits == null) continue;
      final missing = <(HeroSpecId id, String label)>[
        for (final k in kits)
          if (!state.isSpecUnlocked(k.$1) &&
              !state.heroRoster.any((h) => h.specId == k.$1))
            k,
      ];
      if (missing.isEmpty) continue;
      final first = missing.first;
      final shownList = [for (final k in missing.take(2)) k.$2];
      final shown = shownList.join(' · ');
      final rest = missing.length - shownList.length;
      final bit = rest > 0 ? '$shown · +$rest more' : shown;
      final hook = HeroIdentity.meetHook(first.$1);
      return 'AL$target unlocks $bit — $hook';
    }
    return null;
  }
}
