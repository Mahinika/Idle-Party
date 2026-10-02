import 'dart:ui';

/// WotLK Shadowform: the same doll and gear, pushed into a dark see-through
/// violet so the armor silhouette stays and the gold does not.
abstract final class Shadowform {
  /// Luminance kept, then mapped to a dark violet. The last row leaves the
  /// figure slightly transparent so the floor shows through.
  static const ColorFilter wash = ColorFilter.matrix(<double>[
    0.08, 0.08, 0.08, 0, 6,
    0.03, 0.03, 0.03, 0, 0,
    0.14, 0.14, 0.14, 0, 10,
    0, 0, 0, 0.82, 0,
  ]);
}
