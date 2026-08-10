import '../models/meta_depth.dart';
import 'game_logic.dart';
import 'meta_systems.dart';

/// Player-facing Ascend unlock teasers — “what’s next after this AL?”
abstract final class AscendRoadmap {
  /// Concrete unlock when the player **reaches** [al] (after Ascend).
  static String? unlockAtAl(int al) {
    switch (al) {
      case 1:
        return 'Combat Rogue (Shade)';
      case 2:
        return '5th party slot '
            '(Forge · ${GameLogic.partySlot5EssenceCost}e)';
      case GameLogic.gauntletMinAscension:
        return 'Infinity Gauntlet';
      default:
        break;
    }

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

  /// Compact teaser for TODAY / hub chase detail.
  static String chaseTeaser(int currentAl) {
    for (var al = currentAl + 1; al <= 40; al++) {
      final unlock = unlockAtAl(al);
      if (unlock == null) continue;
      return 'AL$al → $unlock';
    }
    return 'Stack Blessings + AL power';
  }
}
