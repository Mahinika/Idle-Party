import 'dart:math' as math;

/// Where the fight-view HP bar sits, in pixels.
///
/// The bar used to hang a fixed fraction above the actor center, which put
/// it through the face on the tall hero sprites.
abstract final class DungeonBarLayout {
  /// Track thickness. Scales with the tile, never thinner than 4 px.
  static double barHeight(double tile) => math.max(4.0, tile * 0.08);

  /// Y of the bar's top edge. [centerY] is the sprite's draw center.
  ///
  /// The sprite is a square of side `tile * scale`, so the head is at most
  /// half that square above the center. The bar sits a small gap above that.
  static double top({
    required double centerY,
    required double tile,
    required double scale,
  }) {
    final spriteTop = centerY - tile * scale / 2;
    return spriteTop - tile * 0.1 - barHeight(tile);
  }
}
