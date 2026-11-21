import '../../models/hero_spec.dart';
import '../../models/loot.dart';
import '../game_logic.dart';
import '../game_state.dart';
import 'gear_scorer.dart';

/// Player-facing gear / train previews. Does not touch scores or prices.
abstract final class GearUpgradeCopy {
  static String _formatDelta(int value) {
    if (value > 0) return '+$value';
    if (value < 0) return '$value';
    return '0';
  }
  static ({
    int powerDelta,
    int atkDelta,
    int defDelta,
    int vitDelta,
    int heroIndex,
  })?
  bestStashCompare(GameState state, EquipmentItem item) {
  var bestPower = -100000;
  ({
    int powerDelta,
    int atkDelta,
    int defDelta,
    int vitDelta,
    int heroIndex,
  })? best;
    for (var i = 0; i < state.heroes.length; i++) {
      final cmp = GearScorer.compareForHero(
        state.heroes[i],
        item,
        pairingStash: state.gearStash,
      );
      if (cmp.powerDelta <= -9000) continue;
      if (cmp.powerDelta > bestPower) {
        bestPower = cmp.powerDelta;
        best = (
          powerDelta: cmp.powerDelta,
          atkDelta: cmp.atkDelta,
          defDelta: cmp.defDelta,
          vitDelta: cmp.vitDelta,
          heroIndex: i,
        );
      }
    }
    return best;
  }

  static String compareStatLine({
    required int atkDelta,
    required int defDelta,
    required int vitDelta,
    required int powerDelta,
  }) {
    return 'AP${_formatDelta(atkDelta)} '
        'Armor${_formatDelta(defDelta)} '
        'STA${_formatDelta(vitDelta)} · '
        'Score ${_formatDelta(powerDelta)}';
  }

  static int? stashPowerDelta(GameState state, EquipmentItem item) {
    final best = bestStashCompare(state, item);
    if (best == null || best.powerDelta <= 0) return null;
    return best.powerDelta;
  }

  static const String bestBadgeLabel = 'Best';

  /// Visible chip on a bag tile (no [FittedBox]).
  static String upgradeBadgeLabel(int powerDelta, {required bool compact}) =>
      compact ? '+$powerDelta' : 'Better +$powerDelta';

  static String upgradeBadgeSemantics(int powerDelta) => 'Better by $powerDelta';

  /// Short line under a bag upgrade badge (detail row, not the chip).
  static String bagTileDeltaLine(GameState state, EquipmentItem item) {
    final best = bestStashCompare(state, item);
    if (best == null || best.powerDelta <= 0) return '';
    if (best.atkDelta > 0) {
      return '+${best.atkDelta} AP';
    }
    if (best.defDelta > 0) {
      return '+${best.defDelta} Armor';
    }
    if (best.vitDelta > 0) {
      return '+${best.vitDelta} STA';
    }
    return 'Score ${_formatDelta(best.powerDelta)}';
  }

  /// One combat sentence for the next FORGE buy (presentation only).
  static String forgeNextFloorLine(
    GameState state,
    PartyUpgradeType type,
  ) {
    final (_, nextRaw, _) = _forgeGainParts(state, type);
    final stat = switch (type) {
      PartyUpgradeType.attack => 'ATK',
      PartyUpgradeType.defense => 'Armor',
      PartyUpgradeType.vitality => 'STA',
      PartyUpgradeType.moveSpeed => 'MOVE',
      PartyUpgradeType.attackSpeed => 'HASTE',
      PartyUpgradeType.crit => 'CRIT',
      PartyUpgradeType.mastery => 'MASTERY',
    };
    final next = nextRaw.replaceFirst('+', '');
    return '+$next $stat for the next floor';
  }

  static (String now, String next, bool soft) _forgeGainParts(
    GameState state,
    PartyUpgradeType type,
  ) {
    String flat(int points, int gain, double softAt, String stat) {
      final now = GameState.softForgePercent(points, softAt: softAt).round();
      final next = GameState.softForgePercent(
        points + gain,
        softAt: softAt,
      ).round();
      return '+$now $stat|+$next';
    }

    String pct(int points, int gain, double softAt) {
      final now = GameState.softForgePercent(points, softAt: softAt).round();
      final next = GameState.softForgePercent(
        points + gain,
        softAt: softAt,
      ).round();
      return '+$now%|+$next%';
    }

    final line = switch (type) {
      PartyUpgradeType.attack => flat(
        state.attackBonus,
        GameLogic.forgeAttackGain,
        GameLogic.forgeAttackSoftAt,
        'AP',
      ),
      PartyUpgradeType.defense => flat(
        state.defenseBonus,
        GameLogic.forgeDefenseGain,
        GameLogic.forgeDefenseSoftAt,
        'Armor',
      ),
      PartyUpgradeType.vitality => flat(
        state.vitalityBonus,
        GameLogic.forgeVitalityGain,
        GameLogic.forgeVitalitySoftAt,
        'STA',
      ),
      PartyUpgradeType.moveSpeed => pct(state.moveSpeedBonus, GameLogic.forgeMoveGain, 40),
      PartyUpgradeType.attackSpeed => pct(state.attackSpeedBonus, GameLogic.forgeHasteGain, 40),
      PartyUpgradeType.crit => pct(state.critBonus, GameLogic.forgeCritGain, 25),
      PartyUpgradeType.mastery => flat(
        state.masteryBonus,
        GameLogic.forgeMasteryGain,
        GameLogic.forgeMasterySoftAt,
        'MASTERY',
      ),
    };
    final parts = line.split('|');
    final soft = switch (type) {
      PartyUpgradeType.attack => state.attackBonus >= GameLogic.forgeAttackSoftAt,
      PartyUpgradeType.defense => state.defenseBonus >= GameLogic.forgeDefenseSoftAt,
      PartyUpgradeType.vitality => state.vitalityBonus >= GameLogic.forgeVitalitySoftAt,
      PartyUpgradeType.moveSpeed => state.moveSpeedBonus >= 40,
      PartyUpgradeType.attackSpeed => state.attackSpeedBonus >= 40,
      PartyUpgradeType.crit => state.critBonus >= 25,
      PartyUpgradeType.mastery => state.masteryBonus >= GameLogic.forgeMasterySoftAt,
    };
    return (parts[0], parts[1], soft);
  }
}

/// Spec picker lines — role plus what changes vs the current hero.
extension HeroSpecVersus on HeroSpecDef {
  String versusLine(HeroSpecDef? current) {
    if (current == null || current.id == id) return plainRoleLine;
    final bits = <String>['${roleTag.plainLabel} — ${roleTag.plainJob}'];
    if (roleTag != current.roleTag) {
      bits.add('Not ${current.roleTag.plainLabel.toLowerCase()}');
    }
    final armor = armorTypes.map((a) => a.name).toList()..sort();
    final was = current.armorTypes.map((a) => a.name).toList()..sort();
    if (armor.join('/') != was.join('/')) {
      bits.add('${armor.first} armor');
    } else if (ranged != current.ranged) {
      bits.add(ranged ? 'Ranged' : 'Melee');
    }
    return bits.join(' · ');
  }
}