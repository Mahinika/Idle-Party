import 'game_logic.dart';
import 'game_state.dart';
import 'play_games_scores.dart';

/// Whether a local file is still the untouched starter party.
///
/// Noise is whatever already differs between two brand-new parties (floor
/// seed, hero ids, clocks). A paid unlock or any other leaf is not noise, so
/// it cannot be classified as empty and replaced on its own.
abstract final class SaveProgress {
  static Set<String>? _noise;

  static bool isReplaceable(GameState state) => blockers(state).isEmpty;

  /// Leaves that stop this file counting as an untouched starter party.
  static List<String> blockers(GameState state) {
    if (PlayGamesScores.hasPaidOwnership(state)) {
      return const <String>['paid-ownership'];
    }
    final noise = _noise ??= _freshNoise();
    final probes = <GameState>[
      GameLogic.createInitialState(now: state.lastUpdated),
      GameLogic.createInitialState(),
    ];
    List<String>? smallest;
    for (final fresh in probes) {
      final blocking = <String>[];
      for (final path in _leafDiff(state.toJson(), fresh.toJson())) {
        if (path == 'metaDepth.cloudSaveUpdatedMs') continue;
        if (noise.contains(path)) continue;
        blocking.add(path);
      }
      if (blocking.isEmpty) return const <String>[];
      if (smallest == null || blocking.length < smallest.length) {
        smallest = blocking;
      }
    }
    return smallest ?? const <String>[];
  }

  /// Leaves that already differ between untouched parties: floor seed, ids,
  /// and the daily board, which changes with the date.
  static Set<String> _freshNoise() {
    final stamps = <DateTime>[
      DateTime.utc(2020, 1, 1),
      DateTime.utc(2020, 6, 15),
      DateTime.utc(2024, 3, 2),
      DateTime.utc(2026, 11, 6),
      DateTime.now().toUtc(),
    ];
    final states = <GameState>[
      for (final stamp in stamps) ...<GameState>[
        GameLogic.createInitialState(now: stamp),
        GameLogic.createInitialState(now: stamp),
      ],
    ];
    final noise = <String>{'lastUpdated', 'metaDepth.cloudSaveUpdatedMs'};
    for (var i = 0; i < states.length; i++) {
      for (var j = i + 1; j < states.length; j++) {
        noise.addAll(_leafDiff(states[i].toJson(), states[j].toJson()));
      }
    }
    return noise;
  }

  static Set<String> _leafDiff(Object? left, Object? right) {
    final out = <String>{};
    void walk(Object? x, Object? y, String at) {
      if (x is Map && y is Map) {
        final keys = <Object>{...x.keys, ...y.keys};
        for (final key in keys) {
          final next = at.isEmpty ? '$key' : '$at.$key';
          walk(x[key], y[key], next);
        }
        return;
      }
      if (x is List && y is List) {
        if (x.length != y.length) {
          out.add(at.isEmpty ? 'length' : '$at.length');
        }
        final n = x.length < y.length ? x.length : y.length;
        for (var i = 0; i < n; i++) {
          walk(x[i], y[i], '$at.$i');
        }
        return;
      }
      if (x != y) out.add(at);
    }

    walk(left, right, '');
    return out;
  }
}
