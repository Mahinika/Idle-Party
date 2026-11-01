import 'blessing_constellation.dart';
import 'game_state.dart';
import 'gauntlet_anomaly.dart';
import 'gauntlet_pact.dart';
import 'logic_notices.dart';

/// One Spire trophy per squeeze under each climb pact.
///
/// Twelve cells: four squeezes under MIGHT, WARD, and GREED. MIGHT earns RUSH
/// instead of SWARM. The first clear of a cell pays essence. A full pact row
/// grants a title. All twelve grant one STAR point. Kept on Ascend.
abstract final class GauntletTrophies {
  static const int firstEssence = 4;

  static List<GauntletAnomaly> squeezesFor(GauntletPact pact) =>
      GauntletAnomalies.trophiesFor(pact);

  static String keyFor(GauntletPact pact, GauntletAnomaly squeeze) =>
      '${pact.name}:${squeeze.name}';

  static String rowTitle(GauntletPact pact) => switch (pact) {
    GauntletPact.might => 'Mightbound',
    GauntletPact.ward => 'Wardbound',
    GauntletPact.greed => 'Greedbound',
  };

  static bool owned(GameState state, GauntletPact pact, GauntletAnomaly squeeze) =>
      state.metaDepth.spireTrophies.contains(keyFor(pact, squeeze));

  static bool rowComplete(List<String> keys, GauntletPact pact) =>
      squeezesFor(pact).every((squeeze) => keys.contains(keyFor(pact, squeeze)));

  /// Next empty cell, pact by pact. Null when the grid is full.
  static ({GauntletPact pact, GauntletAnomaly squeeze})? nextMissing(
    GameState state,
  ) {
    final keys = state.metaDepth.spireTrophies;
    for (final pact in GauntletPact.values) {
      for (final squeeze in squeezesFor(pact)) {
        if (!keys.contains(keyFor(pact, squeeze))) {
          return (pact: pact, squeeze: squeeze);
        }
      }
    }
    return null;
  }

  /// One sentence when a pact row is a single squeeze short. Empty otherwise.
  static String oneShortLine(GameState state, GauntletPact pact) {
    final missing = <GauntletAnomaly>[
      for (final squeeze in squeezesFor(pact))
        if (!owned(state, pact, squeeze)) squeeze,
    ];
    if (missing.length != 1) return '';
    return '${GauntletPacts.title(pact)} needs ${GauntletAnomalies.chip(missing.single)}.';
  }

  /// Sentence for TODAY while Gauntlet is the chase. Empty when unused.
  static String todayBit(GameState state) {
    final next = nextMissing(state);
    if (next == null) return ' All 12 Spire trophies earned.';
    return ' Next trophy: ${GauntletPacts.title(next.pact)} · '
        '${GauntletAnomalies.chip(next.squeeze)}.';
  }

  /// First clear of this floor's squeeze under the active pact.
  static GameState onSqueezeClear(GameState state, {required int floor}) {
    if (!state.inGauntlet) return state;
    final pact = GauntletPacts.parse(state.gauntletPact);
    final squeeze = GauntletAnomalies.forFloor(
      floor,
      inGauntlet: true,
      pact: pact,
    );
    if (squeeze == null || pact == null) return state;
    final key = keyFor(pact, squeeze);
    final owned = state.metaDepth.spireTrophies;
    if (owned.contains(key)) return state;
    final nextKeys = <String>[...owned, key];
    final titles = List<String>.from(state.metaDepth.titles);
    final notices = <String>[
      'Spire trophy · ${GauntletPacts.title(pact)} · '
          '${GauntletAnomalies.chip(squeeze)} · +${firstEssence}e',
    ];
    if (rowComplete(nextKeys, pact) && !rowComplete(owned, pact)) {
      final title = rowTitle(pact);
      if (!titles.contains(title)) titles.add(title);
      notices.add(title);
    }
    var next = state.copyWith(
      essence: state.essence + firstEssence,
      metaDepth: state.metaDepth.copyWith(
        spireTrophies: nextKeys,
        titles: titles,
      ),
    );
    if (nextKeys.length >= 12 && owned.length < 12) {
      next = BlessingConstellation.grantPoints(next, 1);
      notices.add('+1 STAR');
    }
    LogicNotices.addMetaPayoffs(notices);
    return next;
  }
}
