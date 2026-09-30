import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/menu_alerts.dart';

/// Where a one-line coach hint lives (the real control, not a GOT IT card).
enum CoachTarget { enter, godhand, farmPush, kit, gear, gold, essence }

/// Active first-session nudge: one short line on [target].
class CoachHint {
  const CoachHint({
    required this.id,
    required this.line,
    required this.target,
  });

  final String id;
  final String line;
  final CoachTarget target;
}

/// First-session coaching. Persist via [GameState.seenTips].
///
/// Overlay cards are gone — [active] drives a pulse + one line on the real
/// button. Longer copy stays under MORE → INFO.
class FirstSessionTips extends StatelessWidget {
  const FirstSessionTips({super.key, required this.director});

  final GameDirector director;

  /// Button-anchored tips only (order = priority).
  static final tips = <({String id, String title, String body})>[
    (
      id: 'first_run',
      title: 'ENTER DUNGEON',
      body: 'Tap ENTER DUNGEON.',
    ),
    (
      id: 'hub_enter',
      title: 'ENTER DUNGEON',
      body: 'Tap ENTER DUNGEON for the next floor.',
    ),
    (
      id: 'godhand',
      title: 'Long-press the fight',
      body: 'Long-press the fight, or tap the fist.',
    ),
    (
      id: 'farm_push',
      title: 'Repeat / Next',
      body: 'Repeat loots. Next goes deeper.',
    ),
    (
      id: 'kit_abilities',
      title: 'Abilities',
      body: 'Tap a hero — kit chips open beside the strip.',
    ),
    (
      id: 'bag',
      title: 'BAG & GEAR',
      body: 'Better gear waiting.',
    ),
    (
      id: 'forge',
      title: 'GOLD',
      body: 'Power for this run.',
    ),
    (
      id: 'sanctuary',
      title: 'ESSENCE',
      body: 'Power that stays.',
    ),
  ];

  static const Map<String, CoachTarget> _targets = {
    'first_run': CoachTarget.enter,
    'hub_enter': CoachTarget.enter,
    'godhand': CoachTarget.godhand,
    'farm_push': CoachTarget.farmPush,
    'kit_abilities': CoachTarget.kit,
    'bag': CoachTarget.gear,
    'forge': CoachTarget.gold,
    'sanctuary': CoachTarget.essence,
  };

  /// True after the player has actually run a floor (or already Ascended).
  static bool leftPorch(GameState s) =>
      s.highestFloorCleared >= 1 ||
      s.metaDepth.lifetimeFloorClears >= 1 ||
      s.ascensionLevel >= 1;

  /// First combat gold / floor / boss — GOLD / ESSENCE wait until then.
  static bool earnedFirstReward(GameState s) => GameLogic.earnedFirstReward(s);

  /// Overlay tips allowed before the first reward (hub job + tap the fight).
  static const List<String> firstRunBeatIds = <String>['first_run', 'godhand'];

  static CoachHint? active(GameState s, {required bool inDungeon}) {
    final id = nextTipId(s, inDungeon: inDungeon);
    if (id == null) return null;
    final tip = tips.firstWhere((t) => t.id == id);
    final target = _targets[id];
    if (target == null) return null;
    final line = tip.id == 'farm_push'
        ? _farmPushLine(s)
        : tip.body;
    return CoachHint(id: tip.id, line: line, target: target);
  }

  /// FARM/PUSH labels match the dungeon mode chips when jargon is on.
  static String _farmPushLine(GameState s) {
    if (GameLogic.plainPlayerChrome(s)) {
      return 'Repeat loots. Next goes deeper.';
    }
    return 'FARM loops loot. PUSH climbs.';
  }

  static String godHandModeLabel(GameState s) => switch (s.metaDepth.godHandStyle) {
        1 => 'FOCUS',
        2 => 'WIDE',
        _ => 'BAL',
      };

  static String? lineFor(
    GameState s,
    CoachTarget target, {
    required bool inDungeon,
  }) {
    final hint = active(s, inDungeon: inDungeon);
    if (hint == null || hint.target != target) return null;
    if (hint.id == 'godhand') {
      final mode = godHandModeLabel(s);
      return GameLogic.plainPlayerChrome(s)
          ? 'Long-press the fight — $mode smash'
          : 'God Hand · $mode — long-press the fight or tap the fist';
    }
    return hint.line;
  }

  static String? nextTipId(GameState s, {required bool inDungeon}) {
    final seen = s.seenTips;
    final porch = leftPorch(s);
    final rewarded = earnedFirstReward(s);
    for (final tip in tips) {
      if (seen.contains(tip.id)) continue;
      if (!rewarded && !firstRunBeatIds.contains(tip.id)) continue;

      if (tip.id == 'first_run') {
        if (inDungeon) continue;
        return tip.id;
      }
      if (tip.id == 'hub_enter') {
        if (inDungeon || !porch || !seen.contains('first_run')) continue;
        if (!seen.contains('godhand')) continue;
        return tip.id;
      }
      if (tip.id == 'godhand') {
        if (!inDungeon) continue;
        return tip.id;
      }
      if (tip.id == 'farm_push') {
        if (!inDungeon || !porch) continue;
        return tip.id;
      }
      if (tip.id == 'kit_abilities') {
        if (!inDungeon || !seen.contains('godhand')) continue;
        return tip.id;
      }
      if (tip.id == 'bag') {
        if (MenuAlerts.bagUpgradeCount(s) <= 0) continue;
        return tip.id;
      }
      if (tip.id == 'forge') {
        if (inDungeon || !MenuTabs.showGold(s)) continue;
        return tip.id;
      }
      if (tip.id == 'sanctuary') {
        if (inDungeon || !MenuTabs.showCamp(s)) continue;
        return tip.id;
      }
    }
    return null;
  }

  /// Cards removed — hints live on the real controls.
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
