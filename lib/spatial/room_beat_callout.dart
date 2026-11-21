import '../models/dungeon_def.dart';
import 'floor_blueprint.dart';
import 'floor_theme.dart';
import 'tile_map.dart';

/// On-screen label when the party steps into a shrine / wonder / setpiece.
abstract final class RoomBeatCallout {
  /// Returns a one-shot label for this chamber, or null.
  static String? labelFor(String dungeonId, Chamber chamber) {
    return switch (chamber.beatKind) {
      FloorBeatKind.shrine => 'SHRINE',
      FloorBeatKind.wonder => 'WONDER',
      FloorBeatKind.setpiece => _setpieceName(dungeonId),
      _ => null,
    };
  }

  static String _setpieceName(String dungeonId) {
    final callout = ZoneFloorStyle.byId(dungeonId).setpieceCallout;
    if (callout != null && callout.isNotEmpty) return callout;
    final tag = DungeonCatalog.byId(dungeonId).hubMapTag;
    return '$tag SETPIECE';
  }

  /// Poll hero position once per chamber index per floor visit.
  static void poll({
    required TileMap map,
    required double heroX,
    required double heroY,
    required void Function(String label) onShow,
    required Set<int> shown,
    required String dungeonId,
  }) {
    for (final c in map.chambers) {
      if (!c.containsWorld(heroX, heroY)) continue;
      if (shown.contains(c.index)) return;
      final label = labelFor(dungeonId, c);
      if (label == null) return;
      shown.add(c.index);
      onShow(label);
      return;
    }
  }
}