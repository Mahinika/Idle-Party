import 'dart:math' as math;
import 'dart:ui' show Color;

import '../core/hero_identity.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../spatial/spatial_combat.dart';
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
    this.bodyTint,
    this.bodyTintAsset,
  });

  final List<ResolvedLayer> layers;
  final HeroAnimPose anim;
  final bool flipX;
  final List<CharacterLayerId> layerOrder;
  final String equipHash;
  final BodyAnchorProfile anchorProfile;

  /// Spec wash for the owned body layer (gear overlays keep rarity tints).
  final Color? bodyTint;

  /// Cloth-only grayscale mask; keeps spec color off skin, hair and face ink.
  final String? bodyTintAsset;

  /// Same layers, fresher clip progress — bob and weapon swing read live even
  /// though the cache only keys on kind/frame.
  CharacterVisualPose withAnim(HeroAnimPose next) => CharacterVisualPose(
    layers: layers,
    anim: next,
    flipX: flipX,
    layerOrder: layerOrder,
    equipHash: equipHash,
    anchorProfile: anchorProfile,
    bodyTint: bodyTint,
    bodyTintAsset: bodyTintAsset,
  );

  AnchorPose anchor(AnchorId id) => AnchorTables.lookup(
    anim: anim.kind,
    frame: anim.frame,
    id: id,
    flipX: flipX,
    profile: anchorProfile,
  );

  double get mainHandExtraRotation {
    if (anim.kind == HeroAnimKind.attack) {
      return AnchorTables.attackSwingRotation(anim.progress);
    }
    // Cast reuses the attack body clip. Raise the weapon so it is not a swing.
    if (anim.kind == HeroAnimKind.cast) {
      return -1.15 * math.sin(anim.progress * math.pi);
    }
    // Walk has one body clip — swing the held weapon so steps read as motion.
    if (anim.kind == HeroAnimKind.walk) {
      return math.sin(anim.progress * math.pi * 2) * 0.28;
    }
    return 0;
  }

  /// Shield tips up while blocking, and kicks out on a hit.
  double get offHandExtraRotation {
    if (anim.blocking) return -0.55;
    if (anim.kind == HeroAnimKind.hit) {
      return 0.32 * (1 - anim.progress.clamp(0.0, 1.0));
    }
    return 0;
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
      layers: _sortedLayers(layers, order),
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
        heroClass: hero.spec.classId,
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
      heroClass: hero.spec.classId,
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
      heroClass: hero.spec.classId,
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
      layers: _sortedLayers(layers, order),
      anim: anim,
      flipX: flipX,
      layerOrder: order,
      equipHash: equipHashOf(hero),
      anchorProfile: BodyAnchorProfile.owned,
      bodyTint: Color(
        HeroIdentity.clothArgb(
          hero.specId,
          colorblind: SpatialCombat.colorblindMode,
        ),
      ),
      bodyTintAsset: BodyFamilyCatalog.tintMaskAssetFor(hero, anim.kind),
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
    HeroClassId? heroClass,
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
      // Shoulders and belts have no PNG, so a plain chest or legs steps up
      // to the t2 extract. A wide or slim cut already is the look, so keep it.
      if (booster != null &&
          !OwnedGearAssets.kArmorShapeIds.contains(visId) &&
          !OwnedGearAssets.isArmorVariantId(visId)) {
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
      heroClass: heroClass,
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

  /// Cache key for a hero's doll. Material and rarity must be in here — they
  /// pick the overlay PNG (mail/plate) and its tint without changing the id.
  static String equipHashOf(PartyHero hero) {
    final buf = StringBuffer();
    for (final e in hero.equipped.entries) {
      buf.write(e.key.name);
      buf.write(':');
      buf.write(EquipmentVisualResolver.resolveId(e.value));
      buf.write('/');
      buf.write(e.value.armorType?.name ?? '-');
      buf.write('/');
      buf.write(e.value.rarity.index);
      buf.write(';');
    }
    return buf.toString();
  }

  /// Layers already sorted by [layerOrder] at resolve time.
  List<ResolvedLayer> orderedLayers() => layers;

  static List<ResolvedLayer> _sortedLayers(
    List<ResolvedLayer> layers,
    List<CharacterLayerId> order,
  ) {
    final rank = <CharacterLayerId, int>{
      for (var i = 0; i < order.length; i++) order[i]: i,
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
        '$equipHash|${hero.specId.name}|${anim.kind.name}|${anim.frame}'
        '|$flipX|$partyIndex|$owned';
    final existing = _byHero[heroId];
    if (existing != null && existing.key == key) {
      return existing.pose.anim.progress == anim.progress
          ? existing.pose
          : existing.pose.withAnim(anim);
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
}

class _CachedPose {
  const _CachedPose(this.key, this.pose);
  final String key;
  final CharacterVisualPose pose;
}
