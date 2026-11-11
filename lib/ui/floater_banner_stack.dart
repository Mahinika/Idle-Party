import 'dart:math' as math;

/// One in-view combat banner, ready for purely visual vertical stacking.
class FloaterBannerSpec {
  const FloaterBannerSpec({
    required this.id,
    required this.x,
    required this.y,
    required this.priority,
    required this.born,
    required this.heightTiles,
  });

  final int id;
  final double x;
  final double y;
  final int priority;
  final int born;

  /// Text height in world tiles (painter height / tile size).
  final double heightTiles;
}

/// Visual-only Y offsets so priority banners do not cover each other.
///
/// Ordinary damage numbers (priority 0, except ABSORB) are not stacked here;
/// they keep the small spawn jitter.
abstract final class FloaterBannerStack {
  static const double clusterRadiusTiles = 1.0;
  static const double gapTiles = 0.08;

  static bool isStackable({
    required bool speech,
    required int priority,
    required String text,
  }) {
    if (speech) return false;
    if (priority >= 1) return true;
    return text.startsWith('ABSORB');
  }

  /// Extra world-Y for each [FloaterBannerSpec.id]. Down is positive, so a
  /// negative value lifts the banner. Highest priority (then earliest
  /// [FloaterBannerSpec.born]) keeps its authored Y; later banners in the
  /// same ~1-tile cluster move up by text height plus [gapTiles].
  static Map<int, double> dyById(List<FloaterBannerSpec> banners) {
    final dy = <int, double>{for (final b in banners) b.id: 0.0};
    if (banners.length < 2) return dy;

    final n = banners.length;
    final parent = List<int>.generate(n, (i) => i);
    int find(int i) {
      var p = i;
      while (parent[p] != p) {
        parent[p] = parent[parent[p]];
        p = parent[p];
      }
      return p;
    }

    void union(int a, int b) {
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    final r2 =
        FloaterBannerStack.clusterRadiusTiles *
        FloaterBannerStack.clusterRadiusTiles;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final dx = banners[i].x - banners[j].x;
        final dyy = banners[i].y - banners[j].y;
        if (dx * dx + dyy * dyy <= r2) union(i, j);
      }
    }

    final groups = <int, List<int>>{};
    for (var i = 0; i < n; i++) {
      groups.putIfAbsent(find(i), () => <int>[]).add(i);
    }

    const gap = FloaterBannerStack.gapTiles;
    for (final members in groups.values) {
      if (members.length < 2) continue;
      members.sort((a, b) {
        final pa = banners[a];
        final pb = banners[b];
        final byPriority = pb.priority.compareTo(pa.priority);
        if (byPriority != 0) return byPriority;
        final byBorn = pa.born.compareTo(pb.born);
        if (byBorn != 0) return byBorn;
        return pa.id.compareTo(pb.id);
      });
      final placedY = <double>[];
      final placedH = <double>[];
      for (final i in members) {
        var y = banners[i].y;
        final h = banners[i].heightTiles;
        for (var k = 0; k < placedY.length; k++) {
          final py = placedY[k];
          final ph = placedH[k];
          final overlaps = y + h + gap > py && y < py + ph + gap;
          if (overlaps) {
            y = math.min(y, py - h - gap);
          }
        }
        dy[banners[i].id] = y - banners[i].y;
        placedY.add(y);
        placedH.add(h);
      }
    }
    return dy;
  }
}
