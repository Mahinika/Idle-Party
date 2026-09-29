import 'dart:math';

import 'floor_blueprint.dart';
import 'floor_theme.dart';
import 'tile_map.dart';
import 'zone_layout_kit.dart';

/// One prop in a vignette, offset from the anchor cell.
class VignettePiece {
  const VignettePiece(this.dx, this.dy, this.kind);
  final int dx;
  final int dy;
  final MapPropKind kind;
}

/// Small composed prop groups — a camp, a crypt row, a forge corner — so a
/// room reads as a place something happened, not a random scatter.
abstract final class PropVignettes {
  static const Map<PropVignetteKind, List<VignettePiece>> _templates = {
    PropVignetteKind.camp: [
      VignettePiece(0, 0, MapPropKind.table),
      VignettePiece(-1, 0, MapPropKind.stool),
      VignettePiece(1, 0, MapPropKind.stool),
      VignettePiece(3, 0, MapPropKind.barrel),
      VignettePiece(4, 0, MapPropKind.sacks),
    ],
    PropVignetteKind.crypt: [
      VignettePiece(0, 0, MapPropKind.gravestone),
      VignettePiece(2, 0, MapPropKind.gravestone),
      VignettePiece(4, 0, MapPropKind.gravestone),
      VignettePiece(1, 1, MapPropKind.bones),
      VignettePiece(3, 1, MapPropKind.skull),
      VignettePiece(5, 0, MapPropKind.chains),
    ],
    PropVignetteKind.forge: [
      VignettePiece(0, 0, MapPropKind.anvil),
      VignettePiece(1, 0, MapPropKind.cauldron),
      VignettePiece(-1, 0, MapPropKind.barrel),
      VignettePiece(2, 0, MapPropKind.torch),
    ],
    PropVignetteKind.storage: [
      VignettePiece(0, 0, MapPropKind.crate),
      VignettePiece(1, 0, MapPropKind.crate),
      VignettePiece(0, 1, MapPropKind.crate),
      VignettePiece(2, 0, MapPropKind.shelf),
      VignettePiece(3, 0, MapPropKind.sacks),
      VignettePiece(-1, 0, MapPropKind.barrel),
    ],
    PropVignetteKind.shrine: [
      VignettePiece(0, 0, MapPropKind.altar),
      VignettePiece(-2, 0, MapPropKind.statue),
      VignettePiece(2, 0, MapPropKind.statue),
    ],
    PropVignetteKind.library: [
      VignettePiece(0, 0, MapPropKind.bookshelf),
      VignettePiece(1, 0, MapPropKind.bookshelf),
      VignettePiece(3, 0, MapPropKind.bookshelf),
      VignettePiece(2, 1, MapPropKind.table),
      VignettePiece(5, 0, MapPropKind.banner),
    ],
    PropVignetteKind.ruin: [
      VignettePiece(0, 0, MapPropKind.rubble),
      VignettePiece(1, 0, MapPropKind.pillar),
      VignettePiece(2, 0, MapPropKind.rubble),
      VignettePiece(1, 1, MapPropKind.bones),
      VignettePiece(3, 0, MapPropKind.crystalCluster),
    ],
  };

  /// Something that does not belong — players build a story around it.
  static const Map<PropVignetteKind, List<MapPropKind>> _oddOnes = {
    PropVignetteKind.camp: [MapPropKind.bones, MapPropKind.skull],
    PropVignetteKind.crypt: [MapPropKind.sacks, MapPropKind.stool],
    PropVignetteKind.forge: [MapPropKind.skull, MapPropKind.bookshelf],
    PropVignetteKind.storage: [MapPropKind.bones, MapPropKind.chains],
    PropVignetteKind.shrine: [MapPropKind.rubble, MapPropKind.sacks],
    PropVignetteKind.library: [MapPropKind.skull, MapPropKind.cauldron],
    PropVignetteKind.ruin: [MapPropKind.stool, MapPropKind.banner],
  };

  /// Share of vignettes that get one out-of-place piece (aftermath).
  static const double aftermathChance = 0.2;

  static List<VignettePiece> build(PropVignetteKind kind, Random rng) {
    final base = List<VignettePiece>.of(_templates[kind]!);
    if (base.length > 2 && rng.nextDouble() < aftermathChance) {
      final i = 1 + rng.nextInt(base.length - 1);
      final odd = _oddOnes[kind]!;
      base[i] = VignettePiece(
        base[i].dx,
        base[i].dy,
        odd[rng.nextInt(odd.length)],
      );
    }
    return base;
  }

  /// Width in cells (for fitting against a wall run).
  static int span(List<VignettePiece> pieces) {
    var lo = 0;
    var hi = 0;
    for (final p in pieces) {
      lo = min(lo, p.dx);
      hi = max(hi, p.dx);
    }
    return hi - lo + 1;
  }

  /// The one landmark a chamber is built around.
  static MapPropKind heroFor(
    FloorBeatKind? beat,
    ZoneLayoutKit kit,
    WonderKind? wonder,
    Random rng,
  ) {
    switch (beat) {
      case FloorBeatKind.shrine:
        return MapPropKind.altar;
      case FloorBeatKind.wonder:
        return switch (wonder) {
          WonderKind.hoard => MapPropKind.sacks,
          WonderKind.starfall => MapPropKind.crystalCluster,
          WonderKind.soulWell => MapPropKind.fountain,
          WonderKind.giantSkeleton || null => MapPropKind.skull,
        };
      case FloorBeatKind.setpiece || FloorBeatKind.boss:
        return MapPropKind.signatureA;
      case FloorBeatKind.hub:
        return MapPropKind.signatureB;
      case FloorBeatKind.elite:
        return MapPropKind.banner;
      case FloorBeatKind.treasure:
        return MapPropKind.chest;
      default:
        final pool = kit.landmarks.isNotEmpty ? kit.landmarks : kit.edgeClutter;
        final safe = [
          for (final k in pool)
            if (k != MapPropKind.chest) k,
        ];
        final use = safe.isEmpty ? const [MapPropKind.pillar] : safe;
        return use[rng.nextInt(use.length)];
    }
  }

  /// Symmetric pair flanking the hero, or null for rooms that stay plain.
  static MapPropKind? flankFor(FloorBeatKind? beat, MapPropKind torch) =>
      switch (beat) {
        FloorBeatKind.shrine => MapPropKind.statue,
        FloorBeatKind.setpiece => MapPropKind.signatureB,
        FloorBeatKind.boss || FloorBeatKind.treasure => torch,
        FloorBeatKind.wonder => MapPropKind.crystalCluster,
        _ => null,
      };
}
