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

/// A world-space box the stacker must not cover, e.g. a hero's head.
class FloaterReserve {
  const FloaterReserve({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  /// Upper half of the hero's tile — matches the stacking test head box.
  static FloaterReserve heroHead({required double x, required double y}) {
    const halfW = FloaterBannerStack.heroHeadWidthTiles / 2;
    const halfH = FloaterBannerStack.heroHeadHeightTiles / 2;
    final cy = y - FloaterBannerStack.heroHeadCenterUpTiles;
    return FloaterReserve(
      left: x - halfW,
      top: cy - halfH,
      right: x + halfW,
      bottom: cy + halfH,
    );
  }
}

/// Visual-only Y offsets so priority banners do not cover each other.
///
/// Ordinary damage numbers (priority 0, except ABSORB) are not stacked here;
/// they keep the small spawn jitter.
abstract final class FloaterBannerStack {
  static const double clusterRadiusTiles = 1.0;
  static const double gapTiles = 0.08;

  /// Non-speech label top sits this many tiles above the floater centre,
  /// matching [floaterLabelAnchor].
  static const double labelAnchorUpTiles = 0.22;

  /// Non-speech labels are nudged right of the floater centre.
  static const double labelNudgeXTiles = 0.46;

  static const double heroHeadWidthTiles = 0.7;
  static const double heroHeadHeightTiles = 0.55;
  static const double heroHeadCenterUpTiles = 0.2;

  static bool isStackable({
    required bool speech,
    required int priority,
    required String text,
  }) {
    if (speech) return false;
    if (priority >= 1) return true;
    return text.startsWith('ABSORB');
  }

  static double labelTop(double displayY) => displayY - labelAnchorUpTiles;

  /// Extra world-Y for each [FloaterBannerSpec.id]. Down is positive, so a
  /// negative value lifts the banner. Highest priority (then earliest
  /// [FloaterBannerSpec.born]) keeps its authored Y unless that would cover
  /// a [avoid] box or leave the view; later banners in the same ~1-tile
  /// cluster move up by text height plus [gapTiles], or down when up would
  /// cross [minLabelTop].
  static Map<int, double> dyById(
    List<FloaterBannerSpec> banners, {
    double? minLabelTop,
    double? maxLabelBottom,
    List<FloaterReserve> avoid = const [],
  }) {
    final dy = <int, double>{for (final b in banners) b.id: 0.0};
    if (banners.isEmpty) return dy;

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

    for (final members in groups.values) {
      // Isolated floaters keep their authored Y so fight-hit goldens and
      // ordinary damage ticks do not jump. Head clearance and view packing
      // apply only when two or more banners share a cluster.
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
      final placedTops = <double>[];
      final placedBots = <double>[];
      for (final i in members) {
        final h = banners[i].heightTiles;
        final authored = banners[i].y;
        final obstacles = <({double top, double bottom})>[
          for (var k = 0; k < placedTops.length; k++)
            (top: placedTops[k], bottom: placedBots[k]),
          for (final reserved in avoid)
            if (_horizNear(banners[i], reserved))
              (top: reserved.top, bottom: reserved.bottom),
        ];
        final y = _place(
          authoredY: authored,
          height: h,
          obstacles: obstacles,
          minLabelTop: minLabelTop,
          maxLabelBottom: maxLabelBottom,
        );
        dy[banners[i].id] = y - authored;
        final top = labelTop(y);
        placedTops.add(top);
        placedBots.add(top + h);
      }
    }
    return dy;
  }

  static bool _horizNear(FloaterBannerSpec banner, FloaterReserve reserved) {
    final lx = banner.x + labelNudgeXTiles;
    // Label width is not in the spec; a 1-tile pad covers typical banner text.
    return lx + 1.0 > reserved.left && lx - 1.0 < reserved.right;
  }

  /// Closest valid centre Y to [authoredY]. Prefers a lift (up) when it stays
  /// inside the view; otherwise sits just below a blocking box.
  static double _place({
    required double authoredY,
    required double height,
    required List<({double top, double bottom})> obstacles,
    double? minLabelTop,
    double? maxLabelBottom,
  }) {
    const gap = gapTiles;
    const up = labelAnchorUpTiles;

    bool valid(double top) {
      final bot = top + height;
      if (minLabelTop != null && top < minLabelTop - 1e-12) return false;
      if (maxLabelBottom != null && bot > maxLabelBottom + 1e-12) return false;
      for (final o in obstacles) {
        if (top < o.bottom + gap && o.top < bot + gap) return false;
      }
      return true;
    }

    final authoredTop = authoredY - up;
    if (valid(authoredTop)) return authoredY;

    final upCandidates = <double>[];
    final downCandidates = <double>[];
    for (final o in obstacles) {
      upCandidates.add(o.top - height - gap);
      downCandidates.add(o.bottom + gap);
    }
    if (minLabelTop != null) downCandidates.add(minLabelTop);
    if (maxLabelBottom != null) upCandidates.add(maxLabelBottom - height);

    double? bestUp;
    for (final t in upCandidates) {
      if (t <= authoredTop + 1e-12 && valid(t)) {
        if (bestUp == null || t > bestUp) bestUp = t;
      }
    }
    if (bestUp != null) return bestUp + up;

    double? bestDown;
    for (final t in downCandidates) {
      if (t >= authoredTop - 1e-12 && valid(t)) {
        if (bestDown == null || t < bestDown) bestDown = t;
      }
    }
    if (bestDown != null) return bestDown + up;

    // Tight view: pin to the top of the view rather than flying off-screen.
    if (minLabelTop != null && valid(minLabelTop)) return minLabelTop + up;
    return authoredY;
  }
}
