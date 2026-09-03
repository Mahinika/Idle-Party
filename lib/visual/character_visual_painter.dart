import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/hero.dart';
import '../ui/hero_paper_doll.dart';
import 'anchor_table.dart';
import 'character_layer.dart';
import 'character_visual_pose.dart';
import 'hero_anim_controller.dart';
import 'owned_gear_assets.dart';
import 'hero_anim_state.dart';

/// Canvas painter for modular layered heroes (dungeon path).
abstract final class CharacterVisualPainter {
  /// Layers drawn on top of a class PNG / Kenney body (gear that must read).
  static const Set<CharacterLayerId> kGearOverlayLayers = {
    CharacterLayerId.cape,
    CharacterLayerId.head,
    CharacterLayerId.offHand,
    CharacterLayerId.mainHand,
  };

  /// Owned 128×128 overlays drawn on denser bodies (not Kenney atlas cells).
  static const Set<CharacterLayerId> kOwnedGearOverlayLayers = {
    CharacterLayerId.cape,
    CharacterLayerId.legs,
    CharacterLayerId.torso,
    CharacterLayerId.gloves,
    CharacterLayerId.head,
    CharacterLayerId.offHand,
    CharacterLayerId.mainHand,
  };

  /// Full Kenney paper-doll stack (fallback when no class sprite).
  static void paint(
    Canvas canvas,
    ui.Image atlas,
    Offset center,
    double size, {
    required PartyHero hero,
    required HeroAnimSignals signals,
    bool flipX = false,
    int partyIndex = 0,
    double alpha = 1,
    double walkPhase = 0,
    HeroAnimPose? poseOverride,
    String? cacheId,
  }) {
    final pose = _poseFor(
      hero: hero,
      signals: signals,
      flipX: flipX,
      partyIndex: partyIndex,
      walkPhase: walkPhase,
      poseOverride: poseOverride,
      cacheId: cacheId,
    );
    paintPose(canvas, atlas, center, size, pose: pose, alpha: alpha);
  }

  /// Denser owned body + matching 128×128 gear overlays (GEAR and dungeon).
  static void paintOwnedHero(
    Canvas canvas,
    Offset center,
    double size, {
    required ui.Image body,
    required Map<String, ui.Image> images,
    required CharacterVisualPose pose,
    double alpha = 1,
  }) {
    final basePaint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..color = Color.fromRGBO(255, 255, 255, alpha);
    final dst = Rect.fromCenter(center: center, width: size, height: size);

    ui.Image? overlayImage(String? path) {
      if (path == null) return null;
      return images[path] ?? images[OwnedGearAssets.idleFallback(path)];
    }

    if (pose.flipX) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(-1, 1);
      canvas.translate(-center.dx, -center.dy);
    }

    for (final layer in pose.orderedLayers()) {
      if (layer.id == CharacterLayerId.body) {
        canvas.drawImageRect(
          body,
          Rect.fromLTWH(0, 0, body.width.toDouble(), body.height.toDouble()),
          dst,
          basePaint,
        );
        continue;
      }
      if (!kOwnedGearOverlayLayers.contains(layer.id)) continue;
      final img = overlayImage(layer.ownedAsset);
      if (img == null) continue;
      final p = Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false
        ..color = Color.fromRGBO(255, 255, 255, alpha);
      final tint = layer.tint;
      if (tint != null) {
        p.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
      }
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        p,
      );
    }

    if (pose.flipX) {
      canvas.restore();
    }
  }

  /// Anchored gear only — for hybrid (class PNG / Kenney body + equipment).
  static void paintGearOverlays(
    Canvas canvas,
    ui.Image atlas,
    Offset center,
    double size, {
    required PartyHero hero,
    required HeroAnimSignals signals,
    bool flipX = false,
    int partyIndex = 0,
    double alpha = 1,
    double walkPhase = 0,
    HeroAnimPose? poseOverride,
    String? cacheId,
    BodyAnchorProfile anchorProfile = BodyAnchorProfile.kenney,
    GearOverlayScales? overlayScales,
  }) {
    final pose = _poseFor(
      hero: hero,
      signals: signals,
      flipX: flipX,
      partyIndex: partyIndex,
      walkPhase: walkPhase,
      poseOverride: poseOverride,
      cacheId: cacheId,
    );
    final owned = anchorProfile == BodyAnchorProfile.owned;
    paintPose(
      canvas,
      atlas,
      center,
      size,
      pose: pose,
      alpha: alpha,
      onlyLayers:
          owned ? kOwnedGearOverlayLayers : kGearOverlayLayers,
      preferAnchored: true,
      anchorProfile: anchorProfile,
      overlayScales: overlayScales ??
          (owned ? GearOverlayScales.owned : GearOverlayScales.kenney),
    );
  }

  static CharacterVisualPose _poseFor({
    required PartyHero hero,
    required HeroAnimSignals signals,
    required bool flipX,
    required int partyIndex,
    required double walkPhase,
    HeroAnimPose? poseOverride,
    String? cacheId,
  }) {
    final anim =
        poseOverride ??
        HeroAnimController.snapshot(signals, walkPhase: walkPhase);
    return CharacterVisualPoseCache.resolve(
      heroId: cacheId ?? hero.id,
      hero: hero,
      anim: anim,
      flipX: flipX,
      partyIndex: partyIndex,
    );
  }

  static void paintPose(
    Canvas canvas,
    ui.Image atlas,
    Offset center,
    double size, {
    required CharacterVisualPose pose,
    double alpha = 1,
    Set<CharacterLayerId>? onlyLayers,
    bool preferAnchored = false,
    BodyAnchorProfile anchorProfile = BodyAnchorProfile.kenney,
    GearOverlayScales overlayScales = GearOverlayScales.kenney,
  }) {
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..color = Color.fromRGBO(255, 255, 255, alpha);

    final fullDst = Rect.fromCenter(center: center, width: size, height: size);

    void drawCell(int col, int row, Rect dst) {
      canvas.drawImageRect(
        atlas,
        RoguelikeCharAtlas.src(col, row),
        dst,
        paint,
      );
    }

    if (pose.flipX) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(-1, 1);
      canvas.translate(-center.dx, -center.dy);
    }

    for (final layer in pose.orderedLayers()) {
      if (onlyLayers != null && !onlyLayers.contains(layer.id)) continue;

      final useAnchor =
          (layer.anchored && layer.anchorId != null) ||
          (preferAnchored &&
              (layer.id == CharacterLayerId.mainHand ||
                  layer.id == CharacterLayerId.offHand ||
                  layer.id == CharacterLayerId.head));

      if (useAnchor) {
        final anchorId =
            layer.anchorId ??
            switch (layer.id) {
              CharacterLayerId.mainHand => AnchorId.mainHand,
              CharacterLayerId.offHand => AnchorId.offHand,
              CharacterLayerId.head => AnchorId.head,
              _ => AnchorId.body,
            };
        final ap = AnchorTables.lookup(
          anim: pose.anim.kind,
          frame: pose.anim.frame,
          id: anchorId,
          flipX: false,
          profile: anchorProfile,
        ).scaled(size);
        var rot = ap.rotation;
        if (anchorId == AnchorId.mainHand) {
          rot += pose.mainHandExtraRotation;
        }
        final ax = center.dx + ap.x;
        final ay = center.dy + ap.y;
        final overlay = switch (layer.id) {
          CharacterLayerId.head => size * overlayScales.head,
          CharacterLayerId.cape => size * overlayScales.cape,
          _ => size * overlayScales.hand,
        };
        canvas.save();
        canvas.translate(ax, ay);
        canvas.rotate(rot);
        drawCell(
          layer.col,
          layer.row,
          Rect.fromCenter(
            center: Offset.zero,
            width: overlay,
            height: overlay,
          ),
        );
        canvas.restore();
      } else if (layer.id == CharacterLayerId.cape && onlyLayers != null) {
        // Cape behind: full-body tile would hide the PNG — skip unless anchored.
        continue;
      } else {
        drawCell(layer.col, layer.row, fullDst);
      }
    }

    if (pose.flipX) {
      canvas.restore();
    }
  }

  /// Tiny facing lean helper used by dungeon view.
  static Offset leanOffset({
    required Offset center,
    required double tile,
    required double heroX,
    required double heroY,
    required double aimX,
    required double aimY,
    required double flash,
    required bool warrior,
  }) {
    if (flash > 0.02 && (aimX != 0 || aimY != 0)) {
      final adx = aimX - heroX;
      final ady = aimY - heroY;
      final alen = math.sqrt(adx * adx + ady * ady);
      if (alen > 0.05) {
        final punch = warrior ? 0.38 : 0.22;
        return Offset(
          center.dx + (adx / alen) * tile * punch * flash,
          center.dy + (ady / alen) * tile * punch * flash,
        );
      }
    } else if (aimX != 0 || aimY != 0) {
      final adx = aimX - heroX;
      final ady = aimY - heroY;
      final alen = math.sqrt(adx * adx + ady * ady);
      if (alen > 0.08) {
        return Offset(
          center.dx + (adx / alen) * tile * 0.06,
          center.dy + (ady / alen) * tile * 0.04,
        );
      }
    }
    return center;
  }
}
