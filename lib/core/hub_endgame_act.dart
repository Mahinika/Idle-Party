import 'hub_chase.dart';

/// Hub ENDGAME tab map that unlocks when the active party is all Lv100.
///
/// Not dungeon #16 and not a footer under the 15-zone path — a separate
/// board. Hunts reuse Crystal Spire / Mothveil / Stormwake / Ashen Vault
/// staging. KEY dials stay on the KEY tab.
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
    required this.mapX,
    required this.mapY,
  });

  final HubEndgameHunt hunt;
  final String shortLabel;
  final String title;
  final String blurb;

  /// Existing zone portrait (no new art).
  final String portraitDungeonId;
  final String enterLabel;
  final HubChaseKind chaseKind;

  /// Normalized center on the ENDGAME board (not the 15-zone path).
  final double mapX;
  final double mapY;
}

abstract final class HubEndgameAct {
  static const String mapTitle = 'ENDGAME';
  static const String pathTabLabel = 'PATH';

  static String get mapUnlockLine =>
      'PATH = 15 caves · KEY = harder PATH · these hunts are not a 16th cave';

  static const List<HubEndgameNode> nodes = <HubEndgameNode>[
    HubEndgameNode(
      hunt: HubEndgameHunt.gauntlet,
      shortLabel: 'GAUNTLET',
      title: 'Infinity Gauntlet',
      blurb:
          'Endless Spire · not a 16th cave · boss every 5 · wipe or leave → hub',
      portraitDungeonId: 'crystal',
      enterLabel: 'GAUNTLET',
      chaseKind: HubChaseKind.gauntletMilestone,
      mapX: 0.50,
      mapY: 0.24,
    ),
    HubEndgameNode(
      hunt: HubEndgameHunt.rankedGr,
      shortLabel: 'RANKED GR',
      title: 'Ranked GR',
      blurb:
          'Timer night · Mothveil · no gear mid-run · ranked board',
      portraitDungeonId: 'veil',
      enterLabel: 'RANKED GR',
      chaseKind: HubChaseKind.greaterRiftMilestone,
      mapX: 0.78,
      mapY: 0.52,
    ),
    HubEndgameNode(
      hunt: HubEndgameHunt.farmRift,
      shortLabel: 'FARM RIFT',
      title: 'Farm Rift',
      blurb:
          'Timer farm · Stormwake · gold + gear mid-run · not ranked',
      portraitDungeonId: 'storm',
      enterLabel: 'FARM RIFT',
      chaseKind: HubChaseKind.riftMilestone,
      mapX: 0.22,
      mapY: 0.52,
    ),
    HubEndgameNode(
      hunt: HubEndgameHunt.ashen,
      shortLabel: 'ASHEN',
      title: 'Ashen Crown',
      blurb:
          'Weekly ticket boss · one clear pays · PRACTICE free after',
      portraitDungeonId: 'ember',
      enterLabel: 'ASHEN CROWN',
      chaseKind: HubChaseKind.ashenCrown,
      mapX: 0.50,
      mapY: 0.80,
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
