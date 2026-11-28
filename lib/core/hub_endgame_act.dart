import 'game_state.dart';
import 'greater_rift.dart';
import 'hub_chase.dart';

/// Hub ENDGAME tab map that unlocks when the active party is all Lv100.
///
/// Not dungeon #16 and not a footer under the 15-zone path — a separate
/// board. Hunts reuse Crystal Spire / Mothveil / Stormwake / Ashen Vault
/// staging. KEY still holds KEY; Farm Rift and Ranked GR pick tier on ENTER.
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
    this.dailyPreview = false,
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

  /// Shown on the board as a preview. It is not a hunt enter button.
  final bool dailyPreview;
}

abstract final class HubEndgameAct {
  static const String mapTitle = 'ENDGAME';
  static const String pathTabLabel = 'PATH';

  static String get mapUnlockLine =>
      'PATH caves · KEY is harder · hunts are not a 16th cave';

  static const List<HubEndgameNode> nodes = <HubEndgameNode>[
    HubEndgameNode(
      hunt: HubEndgameHunt.gauntlet,
      shortLabel: 'GAUNTLET',
      title: 'Gauntlet',
      blurb:
          'Boss every 5 · not a 16th cave',
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
          'Pick GR on ENTER · Mothveil · no gear mid-run',
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
          'Elapsed clock only · no fail timer · Stormwake · gold + gear mid-run · not ranked',
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
      blurb: 'Weekly ticket.\nA different shipped cave each week.',
      portraitDungeonId: 'ember',
      enterLabel: 'ASHEN CROWN',
      chaseKind: HubChaseKind.ashenCrown,
      mapX: 0.50,
      mapY: 0.80,
    ),
  ];

  static const HubEndgameNode dailyRunPreview = HubEndgameNode(
    hunt: HubEndgameHunt.gauntlet,
    shortLabel: 'DAILY RUN',
    title: 'Daily Run',
    blurb: 'One cave each day. A look at the endgame board.',
    portraitDungeonId: 'sandy',
    enterLabel: 'DAILY RUN',
    chaseKind: HubChaseKind.dailyVaultProgress,
    mapX: 0.50,
    mapY: 0.62,
    dailyPreview: true,
  );

  /// The one hunt this save has not started yet. Ashen stays once the
  /// others have a best.
  static HubEndgameNode nextFromBests({
    required int gauntletBestFloor,
    required int riftBestTier,
    required int grBestTier,
  }) {
    if (gauntletBestFloor <= 0) return nodeFor(HubEndgameHunt.gauntlet);
    if (riftBestTier <= 0) return nodeFor(HubEndgameHunt.farmRift);
    if (grBestTier <= 0) return nodeFor(HubEndgameHunt.rankedGr);
    return nodeFor(HubEndgameHunt.ashen);
  }

  static HubEndgameNode nextMilestone(GameState state) {
    final md = state.metaDepth;
    return nextFromBests(
      gauntletBestFloor: md.gauntletBestFloor,
      riftBestTier: md.riftBestTier,
      grBestTier: md.grBestTier,
    );
  }

  /// ENDGAME page: the next hunt, plus the Daily Run preview.
  static List<HubEndgameNode> pageNodes(GameState state) => <HubEndgameNode>[
    nextMilestone(state),
    dailyRunPreview,
  ];

  static List<HubEndgameNode> pageFromBests({
    required int gauntletBestFloor,
    required int riftBestTier,
    required int grBestTier,
  }) => <HubEndgameNode>[
    nextFromBests(
      gauntletBestFloor: gauntletBestFloor,
      riftBestTier: riftBestTier,
      grBestTier: grBestTier,
    ),
    dailyRunPreview,
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

  static String enterLabelFor(HubEndgameHunt hunt, {int grBestTier = 0}) {
    if (hunt == HubEndgameHunt.rankedGr) {
      return GreaterRift.hubEnterLabel(grBestTier);
    }
    return nodeFor(hunt).enterLabel;
  }

  static String shortLabelFor(
    HubEndgameHunt hunt, {
    int grBestTier = 0,
    int gauntletBestFloor = 0,
    int riftBestTier = 0,
  }) {
    switch (hunt) {
      case HubEndgameHunt.rankedGr:
        return GreaterRift.hubShortLabel(grBestTier);
      case HubEndgameHunt.gauntlet:
        return gauntletBestFloor > 0
            ? 'GAUNTLET F$gauntletBestFloor'
            : nodeFor(hunt).shortLabel;
      case HubEndgameHunt.farmRift:
        return riftBestTier > 0
            ? 'FARM R$riftBestTier'
            : nodeFor(hunt).shortLabel;
      case HubEndgameHunt.ashen:
        return nodeFor(hunt).shortLabel;
    }
  }

  static String titleFor(HubEndgameHunt hunt, {int grBestTier = 0}) {
    if (hunt == HubEndgameHunt.rankedGr) {
      return GreaterRift.hubTitle(grBestTier);
    }
    return nodeFor(hunt).title;
  }

  static bool isEnterLabel(String label) {
    if (GreaterRift.isHubEnterLabel(label)) return true;
    for (final n in nodes) {
      if (n.enterLabel == label) return true;
    }
    return false;
  }
}
