import 'game_logic.dart';
import 'hub_chase.dart';

/// World Path act that unlocks when the active party is all Lv100.
///
/// Not dungeon #16 — the four hunts reuse Crystal Spire / Mothveil /
/// Stormwake / Ashen Vault staging. KEY dials stay on the KEY tab.
enum HubEndgameHunt { gauntlet, rankedGr, farmRift, ashen }

class HubEndgameNode {
  const HubEndgameNode({
    required this.hunt,
    required this.shortLabel,
    required this.title,
    required this.blurb,
    required this.portraitDungeonId,
    required this.enterLabel,
    required this.chaseKind,
  });

  final HubEndgameHunt hunt;
  final String shortLabel;
  final String title;
  final String blurb;

  /// Existing zone portrait (no new art).
  final String portraitDungeonId;
  final String enterLabel;
  final HubChaseKind chaseKind;
}

abstract final class HubEndgameAct {
  static const String mapTitle = 'ENDGAME';

  static String get mapUnlockLine =>
      'Party Lv${GameLogic.maxHeroLevel} · tap a hunt, then ENTER';

  static const List<HubEndgameNode> nodes = <HubEndgameNode>[
    HubEndgameNode(
      hunt: HubEndgameHunt.gauntlet,
      shortLabel: 'GAUNTLET',
      title: 'Infinity Gauntlet',
      blurb: 'Endless Crystal Spire climb · boss every 5 · wipe returns to hub',
      portraitDungeonId: 'crystal',
      enterLabel: 'GAUNTLET',
      chaseKind: HubChaseKind.gauntletMilestone,
    ),
    HubEndgameNode(
      hunt: HubEndgameHunt.rankedGr,
      shortLabel: 'GR',
      title: 'Ranked GR',
      blurb: 'Mothveil timer · no mid-run gear · ranks on KEY · BOARDS',
      portraitDungeonId: 'veil',
      enterLabel: 'RANKED GR',
      chaseKind: HubChaseKind.greaterRiftMilestone,
    ),
    HubEndgameNode(
      hunt: HubEndgameHunt.farmRift,
      shortLabel: 'RIFT',
      title: 'Farm Rift',
      blurb: 'Stormwake timed farm · gold and gear mid-run',
      portraitDungeonId: 'storm',
      enterLabel: 'FARM RIFT',
      chaseKind: HubChaseKind.riftMilestone,
    ),
    HubEndgameNode(
      hunt: HubEndgameHunt.ashen,
      shortLabel: 'ASHEN',
      title: 'Ashen Crown',
      blurb: 'Weekly ticket boss · PRACTICE is free after the paid clear',
      portraitDungeonId: 'ember',
      enterLabel: 'ASHEN CROWN',
      chaseKind: HubChaseKind.ashenCrown,
    ),
  ];

  static HubEndgameNode nodeFor(HubEndgameHunt hunt) {
    for (final n in nodes) {
      if (n.hunt == hunt) return n;
    }
    return nodes.first;
  }

  static HubEndgameHunt? huntForChase(HubChaseKind kind) {
    return switch (kind) {
      HubChaseKind.gauntletMilestone => HubEndgameHunt.gauntlet,
      HubChaseKind.greaterRiftMilestone => HubEndgameHunt.rankedGr,
      HubChaseKind.riftMilestone => HubEndgameHunt.farmRift,
      HubChaseKind.ashenCrown => HubEndgameHunt.ashen,
      _ => null,
    };
  }

  static bool isEnterLabel(String label) {
    for (final n in nodes) {
      if (n.enterLabel == label) return true;
    }
    return false;
  }
}
