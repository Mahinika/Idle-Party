import '../models/vfx_quality.dart';

/// Where a combat floater is painted relative to the fight view.
enum CombatFloaterPlacement {
  /// Teal beneficial numbers — left screen gutter, scrolling up.
  gutterBeneficial,

  /// Hostile hit numbers — right gutter (coral / gold crit).
  gutterHostile,

  /// DODGE/BLOCK/PARRY/MISS and short cast tags under the unit.
  unitPill,

  /// Mid-fight payoff (loot, +g, rare banners) — may drift from anchor.
  payoff,

  /// Speech bark — bubble above hero.
  speech,

  /// Rare room shouts (BOSS DOWN, CHEST) — north of scrum, not on bodies.
  payoffBanner,
}

/// Central classification for [SpatialCombat.spawnFloater].
abstract final class CombatFloaterLayout {
  static const double mergeWindowSec = 0.4;

  /// Sentinel [SpatialFloater.x] — left gutter (paint only).
  static const double laneLeftX = -900;

  /// Sentinel [SpatialFloater.x] — right gutter (paint only).
  static const double laneRightX = -901;

  static String heroInitial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '';
  return t[0].toUpperCase();
  }

  static bool isMitigationWord(String text) {
    switch (text.trim().toUpperCase()) {
      case 'DODGE':
      case 'BLOCK':
      case 'PARRY':
      case 'MISS':
      case 'ICE BLOCK':
        return true;
      default:
        return false;
    }
  }

  static bool isAbsorbWord(String text) =>
      text.trim().toUpperCase().startsWith('ABSORB');

  static bool isHostileNumber(String text) {
    final t = text.trim();
    if (RegExp(r'^CRIT\b', caseSensitive: false).hasMatch(t)) return true;
    if (RegExp(r'^\-?\d+$').hasMatch(t)) return true;
    return false;
  }

  static bool isBeneficialNumber(String text, int argb, int healArgb) {
    if (argb != healArgb) return false;
    final t = text.trim();
    if (!t.startsWith('+')) return false;
    final body = t.substring(1);
    return int.tryParse(body) != null;
  }

  static bool isPayoffBannerWord(String text) {
    final t = text.trim().toUpperCase();
    return t.contains('ELITE DOWN') ||
        t.contains('LEVEL UP') ||
        t.contains('BOSS DOWN') ||
        t.contains('CHEST');
  }

  static bool isLootPayout(String text, int priority) {
    if (priority >= 3) return true;
    if (isPayoffBannerWord(text)) return true;
    final t = text.trim().toUpperCase();
    if (t.contains('CHEST') ||
        t.contains('BOSS DOWN') ||
        t.contains('LEVEL UP')) {
      return true;
    }
    if (text.contains('+') &&
        (text.contains('g') || text.contains('XP') || text.contains('xp'))) {
      return true;
    }
    return false;
  }

  /// Cast / status names (not bare numbers).
  static bool isAbilityOrStatusName(String text) {
    final t = text.trim();
    if (t.length < 3) return false;
    if (isMitigationWord(t) || isAbsorbWord(t)) return false;
    if (RegExp(r'^[+\-]?\d').hasMatch(t)) return false;
    if (RegExp(r'^CRIT\b', caseSensitive: false).hasMatch(t)) return false;
    if (t.contains('+') &&
        (t.contains('g') || t.contains('XP') || t.contains('xp'))) {
      return false;
    }
    return RegExp(r'[A-Za-z]{3,}').hasMatch(t);
  }

  static CombatFloaterPlacement classify({
    required String text,
    required int argb,
    required int priority,
    required int healArgb,
    required bool speech,
  }) {
    if (speech) return CombatFloaterPlacement.speech;
    if (isMitigationWord(text) || isAbsorbWord(text)) {
      return CombatFloaterPlacement.unitPill;
    }
    if (isBeneficialNumber(text, argb, healArgb)) {
      return CombatFloaterPlacement.gutterBeneficial;
    }
    if (isHostileNumber(text)) {
      return CombatFloaterPlacement.gutterHostile;
    }
    if (isPayoffBannerWord(text) && priority >= 2) {
      return CombatFloaterPlacement.payoffBanner;
    }
    if (isLootPayout(text, priority) && priority >= 2) {
      return CombatFloaterPlacement.payoffBanner;
    }
    if (isLootPayout(text, priority)) {
      return CombatFloaterPlacement.payoff;
    }
    if (isAbilityOrStatusName(text)) {
      return CombatFloaterPlacement.unitPill;
    }
    if (RegExp(r'^\-?\d+$').hasMatch(text.trim())) {
      return CombatFloaterPlacement.gutterHostile;
    }
    return CombatFloaterPlacement.unitPill;
  }

  static String formatLaneLabel({
    required CombatFloaterPlacement placement,
    required String text,
    required String sourceInitial,
    required bool isCrit,
  }) {
    final initial = sourceInitial.isEmpty ? '' : '${sourceInitial.trim()} ';
    if (placement == CombatFloaterPlacement.gutterHostile && isCrit) {
      final t = text.trim();
      if (RegExp(r'^CRIT\b', caseSensitive: false).hasMatch(t)) {
        return '$initial$t';
      }
      return '$initial CRIT $t';
    }
    if (placement == CombatFloaterPlacement.gutterBeneficial &&
        text.startsWith('+')) {
      return '$initial$text';
    }
    if (placement == CombatFloaterPlacement.gutterHostile) {
      return '$initial$text'.trim();
    }
    return '$initial$text'.trim();
  }

  /// Returns merged hostile/beneficial lane text, or null if not mergeable.
  static String? mergeLaneText(String existing, String incoming, {required bool hostile}) {
    if (hostile) {
      final wasCrit = RegExp(r'^(\w+ )?CRIT ', caseSensitive: false).hasMatch(existing);
      final incCrit = RegExp(r'^(\w+ )?CRIT ', caseSensitive: false).hasMatch(incoming);
      final existingSum = _sumHostile(existing);
      final incomingSum = _sumHostile(incoming);
      if (existingSum == null || incomingSum == null) return null;
      final sum = existingSum + incomingSum;
      final initial = _leadingInitial(existing) ?? _leadingInitial(incoming) ?? '';
      if (wasCrit || incCrit) {
        return initial.isEmpty ? 'CRIT $sum' : '$initial CRIT $sum';
      }
      return initial.isEmpty ? '$sum' : '$initial $sum';
    }
    final e = _sumHeal(existing);
    final i = _sumHeal(incoming);
    if (e == null || i == null) return null;
    final initial = _leadingInitial(existing) ?? _leadingInitial(incoming) ?? '';
    final body = '+${e + i}';
    return initial.isEmpty ? body : '$initial $body';
  }

  static String? _leadingInitial(String text) {
    final m = RegExp(r'^([A-Za-z]) ').firstMatch(text.trim());
    return m?.group(1);
  }

  static int? _sumHostile(String text) {
    final t = text.trim();
    final crit = RegExp(r'^(?:\w+ )?CRIT (\d+)$', caseSensitive: false).firstMatch(t);
    if (crit != null) return int.tryParse(crit.group(1)!);
    final bare = RegExp(r'^(?:\w+ )?(\d+)$').firstMatch(t);
    if (bare != null) return int.tryParse(bare.group(1)!);
    return int.tryParse(t);
  }

  static int? _sumHeal(String text) {
    final t = text.trim();
    final m = RegExp(r'^(?:\w+ )?\+(\d+)$').firstMatch(t);
    if (m != null) return int.tryParse(m.group(1)!);
    if (t.startsWith('+')) return int.tryParse(t.substring(1));
    return null;
  }

  static double mergeWindowForPace(double combatPace) =>
      mergeWindowSec / (combatPace >= 2 ? 2.0 : 1.0);

  /// Whether paint/sim should show this floater at [quality].
  static bool visibleAtQuality({
    required VfxQuality quality,
    required CombatFloaterPlacement placement,
    required int priority,
    required bool mitigationPill,
  }) {
    if (mitigationPill) return true;
    if (quality == VfxQuality.full) return true;
    if (quality == VfxQuality.minimal) {
      return placement == CombatFloaterPlacement.unitPill && priority >= 2 ||
          priority >= 3;
    }
    // Lite: no routine gutter ticks; keep crits/heals/mitigation/banners.
    return switch (placement) {
      CombatFloaterPlacement.gutterHostile => priority >= 2,
      CombatFloaterPlacement.gutterBeneficial => priority >= 1,
      CombatFloaterPlacement.unitPill => true,
      CombatFloaterPlacement.payoffBanner => true,
      CombatFloaterPlacement.payoff => priority >= 2,
      CombatFloaterPlacement.speech => true,
    };
  }

  static bool isCritText(String text) =>
      RegExp(r'^CRIT\b', caseSensitive: false).hasMatch(text.trim());
}