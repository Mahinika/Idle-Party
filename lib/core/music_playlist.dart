import 'dart:math';

/// Picks the next song for one place.
///
/// The least-played song goes first, and the song that just finished cannot
/// come straight back. Each song starts at the beginning.
class MusicPlaylist {
  final Map<String, int> _plays = <String, int>{};
  final Map<String, String> _lastByPool = <String, String>{};

  void reset() {
    _plays.clear();
    _lastByPool.clear();
  }

  String pick(String pool, List<String> tracks, Random rng) {
    if (tracks.isEmpty) {
      throw StateError('MusicPlaylist pool $pool is empty');
    }
    if (tracks.length == 1) {
      _remember(pool, tracks.first);
      return tracks.first;
    }
    final last = _lastByPool[pool];
    var best = 1 << 30;
    final candidates = <String>[];
    for (final track in tracks) {
      if (track == last) continue;
      final played = _plays[track] ?? 0;
      if (played < best) {
        best = played;
        candidates
          ..clear()
          ..add(track);
      } else if (played == best) {
        candidates.add(track);
      }
    }
    final choice = candidates[rng.nextInt(candidates.length)];
    _remember(pool, choice);
    return choice;
  }

  void _remember(String pool, String track) {
    _plays[track] = (_plays[track] ?? 0) + 1;
    _lastByPool[pool] = track;
  }
}
