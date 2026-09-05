import 'dart:ui' show Color;

import '../models/hero.dart';
import '../models/loot.dart';
import '../ui/hero_paper_doll.dart';
import 'anchor_table.dart';
import 'body_family.dart';
import 'character_layer.dart';
import 'equipment_visual_resolver.dart';
import 'hero_anim_state.dart';
import 'owned_gear_assets.dart';

/// One atlas cell (or body column) in the layered stack.
class ResolvedLayer {
  const ResolvedLayer({
    required this.id,
    required this.col,
    required this.row,
    this.anchored = false,
    this.anchorId,
    this.iconKey,
    this.ownedAsset,
    this.tint,
  });

  final CharacterLayerId id;
  final int col;
  final int row;

  /// When true, paint at [anchorId] with optional swing rotation.
  final bool anchored;
  final AnchorId? anchorId;
  final String? iconKey;

  /// Owned 128×128 overlay (`assets/custom/char/...`). Kenney cells ignore this.
  final String? ownedAsset;

  /// Optional rarity wash for owned overlays.
  final Color? tint;
}

/// Fully resolved visual pose for one hero this frame.
class CharacterVisualPose {
  const CharacterVisualPose({
    required this.layers,
    required this.anim,
    required this.flipX,
    required this.layerOrder,
    this.equipHash = '',
    this.anchorProfile = BodyAnchorProfile.kenney,
  });

  final List<ResolvedLayer> layers;
  final HeroAnimPose anim;
  final bool flipX;
  final List<CharacterLayerId> layerOrder;
  final String equipHash;
  final BodyAnchorProfile anchorProfile;

  AnchorPose anchor(AnchorId id) => AnchorTables.lookup(
    anim: anim.kind,
    frame: anim.frame,
    id: id,
    flipX: flipX,
    profile: anchorProfile,
  );

  double get mainHandExtraRotation {
    if (anim.kind != HeroAnimKind.attack) return 0;
    return AnchorTables.attackSwingRotation(anim.progress);
  }

  /// Build pose from party hero + animation + facing.
  ///
  /// [owned] uses 128×128 overlay paths (GEAR + dungeon). Kenney atlas
  /// cells stay on the fallback paper-doll path (`owned: false`).
  factory CharacterVisualPose.resolve({
    required PartyHero hero,
    required HeroAnimPose anim,
    bool flipX = false,
    int partyIndex = 0,
    bool owned = false,
  }) {
    if (owned) {
      return _resolveOwned(hero: hero, anim: anim, flipX: flipX);
    }
    return _resolveKenney(
      hero: hero,
      anim: anim,
      flipX: flipX,
      partyIndex: partyIndex,
    );
  }

  static CharacterVisualPose _resolveKenney({
    required PartyHero hero,
    required HeroAnimPose anim,
    required bool flipX,
    required int partyIndex,
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
      anchorProfile: BodyAnchorProfile.kenney,
    );
  }

  static CharacterVisualPose _resolveOwned({
    required PartyHero hero,
    required HeroAnimPose anim,
    required bool flipX,
  }) {
    final family = BodyFamilyCatalog.familyFor(hero);
    final layers = <ResolvedLayer>[
      const ResolvedLayer(id: CharacterLayerId.body, col: 0, row: 0),
    ];
    final seen = <CharacterLayerId>{CharacterLayerId.body};

    void addItem(EquipmentItem? item, {CharacterLayerId? layer}) {
      if (item == null) return;
      final def = EquipmentVisualResolver.defForItem(item);
      if (def == null) return;
      final visId = EquipmentVisualResolver.resolveId(item);
      final path = OwnedGearAssets.pathFor(
        visualSetId: visId,
        family: family,
        anim: anim.kind,
        armorType: item.armorType,
      );
      if (path == null) return;
      final id = layer ?? def.layer;
      if (!seen.add(id)) return;
      // Hand items: grip → owned hand anchors (armor stays full-body blit).
      final AnchorId? handAnchor = switch (id) {
        CharacterLayerId.mainHand => AnchorId.mainHand,
        CharacterLayerId.offHand => AnchorId.offHand,
        _ => null,
      };
      layers.add(
        ResolvedLayer(
          id: id,
          col: 0,
          row: 0,
          ownedAsset: path,
          anchored: handAnchor != null,
          anchorId: handAnchor,
          tint: EquipmentVisualResolver.rarityTint(
            visId,
            rarityTier: item.rarity.index,
          ),
        ),
      );
    }

    addItem(hero.itemIn(EquipmentSlot.cloak), layer: CharacterLayerId.cape);
    _addFoldedArmor(
      layers: layers,
      seen: seen,
      family: family,
      anim: anim.kind,
      primary: hero.itemIn(EquipmentSlot.legs) ?? hero.itemIn(EquipmentSlot.boots),
      booster: hero.itemIn(EquipmentSlot.waist),
      layer: CharacterLayerId.legs,
      t2Id: 'legs_t2',
    );
    _addFoldedArmor(
      layers: layers,
      seen: seen,
      family: family,
      anim: anim.kind,
      primary: hero.itemIn(EquipmentSlot.chest),
      booster: hero.itemIn(EquipmentSlot.shoulder),
      layer: CharacterLayerId.torso,
      t2Id: 'chest_t2',
    );
    addItem(
      hero.itemIn(EquipmentSlot.hands) ?? hero.itemIn(EquipmentSlot.wrist),
      layer: CharacterLayerId.gloves,
    );
    addItem(hero.itemIn(EquipmentSlot.head), layer: CharacterLayerId.head);

    final main =
        hero.itemIn(EquipmentSlot.weapon) ?? hero.itemIn(EquipmentSlot.ranged);
    final hideOff = main?.handed == WeaponHanded.twoHand;
    if (!hideOff) {
      addItem(hero.itemIn(EquipmentSlot.offHand));
    }
    addItem(main, layer: CharacterLayerId.mainHand);

    final order = layerOrderFor(
      anim.kind,
      frame: anim.frame,
      flipX: flipX,
      owned: true,
    );
    return CharacterVisualPose(
      layers: layers,
      anim: anim,
      flipX: flipX,
      layerOrder: order,
      equipHash: equipHashOf(hero),
      anchorProfile: BodyAnchorProfile.owned,
    );
  }

  /// Shoulder → chest silhouette, waist → legs. No dedicated PNGs — boost to
  /// t2 when a booster is worn, or paint t2 alone when only the booster is on.
  static void _addFoldedArmor({
    required List<ResolvedLayer> layers,
    required Set<CharacterLayerId> seen,
    required BodyFamily family,
    required HeroAnimKind anim,
    required EquipmentItem? primary,
    required EquipmentItem? booster,
    required CharacterLayerId layer,
    required String t2Id,
  }) {
    if (primary == null && booster == null) return;
    if (!seen.add(layer)) return;

    String visId;
    EquipmentItem tintFrom;
    ArmorType? armorType;
    if (primary != null) {
      tintFrom = primary;
      armorType = primary.armorType ?? booster?.armorType;
      visId = EquipmentVisualResolver.resolveId(primary);
      if (booster != null) {
        visId = t2Id;
      }
    } else {
      tintFrom = booster!;
      armorType = booster.armorType;
      visId = t2Id;
    }
    final path = OwnedGearAssets.pathFor(
      visualSetId: visId,
      family: family,
      anim: anim,
      armorType: armorType,
    );
    if (path == null) {
      seen.remove(layer);
      return;
    }
    layers.add(
      ResolvedLayer(
        id: layer,
        col: 0,
        row: 0,
        ownedAsset: path,
        tint: EquipmentVisualResolver.rarityTint(
          visId,
          rarityTier: tintFrom.rarity.index,
        ),
      ),
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
    bool owned = false,
  }) {
    final equipHash = CharacterVisualPose.equipHashOf(hero);
    final key =
        '$equipHash|${anim.kind.name}|${anim.frame}|$flipX|$partyIndex|$owned';
    final existing = _byHero[heroId];
    if (existing != null && existing.key == key) {
      return existing.pose;
    }
    final pose = CharacterVisualPose.resolve(
      hero: hero,
      anim: anim,
      flipX: flipX,
      partyIndex: partyIndex,
      owned: owned,
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
