import '../models/hero.dart';
import '../models/loot.dart';
import '../ui/hero_paper_doll.dart';
import 'anchor_table.dart';
import 'character_layer.dart';
import 'equipment_visual_resolver.dart';
import 'hero_anim_state.dart';

/// One atlas cell (or body column) in the layered stack.
class ResolvedLayer {
  const ResolvedLayer({
    required this.id,
    required this.col,
    required this.row,
    this.anchored = false,
    this.anchorId,
    this.iconKey,
  });

  final CharacterLayerId id;
  final int col;
  final int row;

  /// When true, paint at [anchorId] with optional swing rotation.
  final bool anchored;
  final AnchorId? anchorId;
  final String? iconKey;
}

/// Fully resolved visual pose for one hero this frame.
class CharacterVisualPose {
  const CharacterVisualPose({
    required this.layers,
    required this.anim,
    required this.flipX,
    required this.layerOrder,
    this.equipHash = '',
  });

  final List<ResolvedLayer> layers;
  final HeroAnimPose anim;
  final bool flipX;
  final List<CharacterLayerId> layerOrder;
  final String equipHash;

  AnchorPose anchor(AnchorId id) => AnchorTables.lookup(
    anim: anim.kind,
    frame: anim.frame,
    id: id,
    flipX: flipX,
  );

  double get mainHandExtraRotation {
    if (anim.kind != HeroAnimKind.attack) return 0;
    return AnchorTables.attackSwingRotation(anim.progress);
  }

  /// Build pose from party hero + animation + facing.
  factory CharacterVisualPose.resolve({
    required PartyHero hero,
    required HeroAnimPose anim,
    bool flipX = false,
    int partyIndex = 0,
  }) {
    final bodyCol = anim.frame.clamp(0, 1);
    final skin = HeroPaperDoll.skinRowFor(hero, partyIndex);
    final layers = <ResolvedLayer>[
      ResolvedLayer(
        id: CharacterLayerId.body,
        col: bodyCol,
        row: skin,
      ),
    ];

    final cape = HeroPaperDoll.capeFor(hero);
    if (cape != null) {
      layers.add(
        ResolvedLayer(
          id: CharacterLayerId.cape,
          col: cape.col,
          row: cape.row,
        ),
      );
    }

    final pants = HeroPaperDoll.pantsFor(hero);
    if (pants != null) {
      layers.add(
        ResolvedLayer(
          id: CharacterLayerId.legs,
          col: bodyCol == 0 ? 3 : 4,
          row: pants.row,
        ),
      );
    }

    final torso = HeroPaperDoll.torsoFor(hero);
    if (torso != null) {
      layers.add(
        ResolvedLayer(
          id: CharacterLayerId.torso,
          col: torso.col,
          row: torso.row,
        ),
      );
    }

    final gloves = HeroPaperDoll.glovesFor(hero);
    if (gloves != null) {
      layers.add(
        ResolvedLayer(
          id: CharacterLayerId.gloves,
          col: gloves.col,
          row: gloves.row,
        ),
      );
    }

    final head = HeroPaperDoll.headFor(hero);
    if (head == null) {
      final hair = HeroPaperDoll.hairFor(hero);
      layers.add(
        ResolvedLayer(
          id: CharacterLayerId.hair,
          col: hair.col,
          row: hair.row,
        ),
      );
    } else {
      layers.add(
        ResolvedLayer(
          id: CharacterLayerId.head,
          col: head.col,
          row: head.row,
        ),
      );
    }

    _addHandLayer(
      layers,
      hero.itemIn(EquipmentSlot.offHand),
      fallback: CharacterLayerId.offHand,
    );
    final main =
        hero.itemIn(EquipmentSlot.weapon) ?? hero.itemIn(EquipmentSlot.ranged);
    _addHandLayer(layers, main, fallback: CharacterLayerId.mainHand);

    final order = layerOrderFor(anim.kind, frame: anim.frame, flipX: flipX);

    return CharacterVisualPose(
      layers: layers,
      anim: anim,
      flipX: flipX,
      layerOrder: order,
      equipHash: equipHashOf(hero),
    );
  }

  static void _addHandLayer(
    List<ResolvedLayer> layers,
    EquipmentItem? item, {
    required CharacterLayerId fallback,
  }) {
    if (item == null) return;
    final def = EquipmentVisualResolver.defForItem(item);
    if (def == null || def.atlasCol == null || def.atlasRow == null) {
      return;
    }
    final anchorName = def.anchor;
    final anchorId = switch (anchorName) {
      'mainHand' => AnchorId.mainHand,
      'offHand' => AnchorId.offHand,
      'head' => AnchorId.head,
      _ => null,
    };
    layers.add(
      ResolvedLayer(
        id: def.layer,
        col: def.atlasCol!,
        row: def.atlasRow!,
        anchored: def.useAnchor && anchorId != null,
        anchorId: anchorId,
        iconKey: def.iconKey,
      ),
    );
  }

  static String equipHashOf(PartyHero hero) {
    final buf = StringBuffer();
    for (final e in hero.equipped.entries) {
      buf.write(e.key.name);
      buf.write(':');
      buf.write(EquipmentVisualResolver.resolveId(e.value));
      buf.write(';');
    }
    return buf.toString();
  }

  /// Layers sorted by draw order.
  List<ResolvedLayer> orderedLayers() {
    final rank = <CharacterLayerId, int>{
      for (var i = 0; i < layerOrder.length; i++) layerOrder[i]: i,
    };
    final sorted = List<ResolvedLayer>.from(layers);
    sorted.sort(
      (a, b) => (rank[a.id] ?? 99).compareTo(rank[b.id] ?? 99),
    );
    return sorted;
  }
}

/// Caches resolved poses per hero until equip/anim/flip inputs change.
abstract final class CharacterVisualPoseCache {
  static final Map<String, _CachedPose> _byHero = <String, _CachedPose>{};

  static CharacterVisualPose resolve({
    required String heroId,
    required PartyHero hero,
    required HeroAnimPose anim,
    bool flipX = false,
    int partyIndex = 0,
  }) {
    final equipHash = CharacterVisualPose.equipHashOf(hero);
    final key =
        '$equipHash|${anim.kind.name}|${anim.frame}|$flipX|$partyIndex';
    final existing = _byHero[heroId];
    if (existing != null && existing.key == key) {
      return existing.pose;
    }
    final pose = CharacterVisualPose.resolve(
      hero: hero,
      anim: anim,
      flipX: flipX,
      partyIndex: partyIndex,
    );
    _byHero[heroId] = _CachedPose(key, pose);
    return pose;
  }

  static void clear() => _byHero.clear();

  static void evict(String heroId) => _byHero.remove(heroId);
}

class _CachedPose {
  const _CachedPose(this.key, this.pose);
  final String key;
  final CharacterVisualPose pose;
}
