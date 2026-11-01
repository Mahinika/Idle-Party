import 'tile_map.dart';

/// One step of a floor path. Floors build a new [TileMap], and open gates
/// are part of the key, so a hit is the same step the search would return.
class WaypointCache {
  WaypointCache._();

  static const int _capacity = 64;
  static final List<_Slot?> _slots = List<_Slot?>.filled(_capacity, null);
  static int computes = 0;

  static void clear() {
    for (var i = 0; i < _capacity; i++) {
      _slots[i] = null;
    }
    computes = 0;
  }

  static (double, double)? take({
    required TileMap map,
    required Set<int> openGateIds,
    required int sx,
    required int sy,
    required int gx,
    required int gy,
    required (double, double)? Function() compute,
  }) {
    final gates = _gatesOf(openGateIds);
    final mapId = identityHashCode(map);
    final index = _index(mapId, gates, sx, sy, gx, gy);
    final slot = _slots[index];
    if (slot != null &&
        slot.mapId == mapId &&
        slot.sx == sx &&
        slot.sy == sy &&
        slot.gx == gx &&
        slot.gy == gy &&
        _sameGates(slot.gates, gates)) {
      return slot.point;
    }
    computes++;
    final point = compute();
    _slots[index] = _Slot(mapId, gates, sx, sy, gx, gy, point);
    return point;
  }

  static int _index(
    int mapId,
    List<int> gates,
    int sx,
    int sy,
    int gx,
    int gy,
  ) {
    var h = mapId;
    for (final id in gates) {
      h = 0x1fffffff & (h * 31 + id);
    }
    h = 0x1fffffff & (h * 31 + sx);
    h = 0x1fffffff & (h * 31 + sy);
    h = 0x1fffffff & (h * 31 + gx);
    h = 0x1fffffff & (h * 31 + gy);
    return h % _capacity;
  }

  static List<int> _gatesOf(Set<int> ids) {
    final out = List<int>.of(ids)..sort();
    return out;
  }

  static bool _sameGates(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _Slot {
  _Slot(this.mapId, this.gates, this.sx, this.sy, this.gx, this.gy, this.point);

  final int mapId;
  final List<int> gates;
  final int sx;
  final int sy;
  final int gx;
  final int gy;
  final (double, double)? point;
}
