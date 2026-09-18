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
import 'owned_gear_grips.dart';
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

    // One body clip per anim — a step bob / flinch recoil carries the motion.
    // Applied inside the flip so "backward" follows facing.
    final step = ownedStepOffset(pose, size);
    if (step != Offset.zero) {
      canvas.save();
      canvas.translate(step.dx, step.dy);
    }

    for (final layer in pose.orderedLayers()) {
      if (layer.id == CharacterLayerId.body) {
        final bodyTint = pose.bodyTint;
        final tintAsset = pose.bodyTintAsset;
        final tintMask = tintAsset == null ? null : images[tintAsset];
        if (bodyTint != null &&
            bodyTint != const Color(0xFFFFFFFF) &&
            tintMask != null) {
          final maskSrc = Rect.fromLTWH(
            0,
            0,
            tintMask.width.toDouble(),
            tintMask.height.toDouble(),
          );
          // A one-pixel cloth rim keeps specs readable even when armor covers
          // most of the undertunic, without recoloring the equipped item art.
          final rim = math.max(1.0, size / 96);
          final rimPaint = Paint()
            ..filterQuality = FilterQuality.none
            ..isAntiAlias = false
            ..color = Color.fromRGBO(255, 255, 255, alpha * 0.72)
            ..colorFilter = ColorFilter.mode(bodyTint, BlendMode.srcIn);
          for (final offset in [
            Offset(-rim, 0),
            Offset(rim, 0),
            Offset(0, -rim),
            Offset(0, rim),
          ]) {
            canvas.drawImageRect(
              tintMask,
              maskSrc,
              dst.shift(offset),
              rimPaint,
            );
          }
        }
        canvas.drawImageRect(
          body,
          Rect.fromLTWH(0, 0, body.width.toDouble(), body.height.toDouble()),
          dst,
          basePaint,
        );
        // The prior whole-body filter also recolored faces and hair. Draw the
        // generated cloth mask instead, before all equipped layers.
        if (bodyTint != null &&
            bodyTint != const Color(0xFFFFFFFF) &&
            tintMask != null) {
          final tintPaint = Paint()
            ..filterQuality = FilterQuality.none
            ..isAntiAlias = false
            ..color = Color.fromRGBO(255, 255, 255, alpha)
            ..colorFilter = ColorFilter.mode(bodyTint, BlendMode.modulate);
          canvas.drawImageRect(
            tintMask,
            Rect.fromLTWH(
              0,
              0,
              tintMask.width.toDouble(),
              tintMask.height.toDouble(),
            ),
            dst,
            tintPaint,
          );
        } else if (bodyTint != null && tintAsset != null && tintMask == null) {
          assert(() {
            debugPrint('paper-doll missing body tint mask: $tintAsset');
            return true;
          }());
        }
        continue;
      }
      if (!kOwnedGearOverlayLayers.contains(layer.id)) continue;
      final asset = layer.ownedAsset;
      final img = overlayImage(asset);
      if (img == null) {
        assert(() {
          debugPrint('paper-doll missing overlay: $asset');
          return true;
        }());
        continue;
      }
      final p = Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false
        ..color = Color.fromRGBO(255, 255, 255, alpha);
      final tint = layer.tint;
      if (tint != null) {
        p.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
      }
      final src = Rect.fromLTWH(
        0,
        0,
        img.width.toDouble(),
        img.height.toDouble(),
      );

      // Weapons / shields: shift full 128 canvas so grip UV sits on hand
      // anchor (armor layers stay unshifted same-origin blit).
      if (layer.anchored &&
          layer.anchorId != null &&
          asset != null &&
          (layer.id == CharacterLayerId.mainHand ||
              layer.id == CharacterLayerId.offHand)) {
        final ap = AnchorTables.lookup(
          anim: pose.anim.kind,
          frame: pose.anim.frame,
          id: layer.anchorId!,
          flipX: false,
          profile: BodyAnchorProfile.owned,
        ).scaled(size);
        var rot = ap.rotation;
        if (layer.anchorId == AnchorId.mainHand) {
          rot += pose.mainHandExtraRotation;
        }
        final ax = center.dx + ap.x;
        final ay = center.dy + ap.y;
        final grip = OwnedGearGrips.forAsset(
          asset,
          offHand: layer.anchorId == AnchorId.offHand,
        );
        final gripOnFull = Offset(
          dst.left + grip.dx * size,
          dst.top + grip.dy * size,
        );
        final shifted = dst.shift(
          Offset(ax - gripOnFull.dx, ay - gripOnFull.dy),
        );
        canvas.save();
        canvas.translate(ax, ay);
        canvas.rotate(rot);
        canvas.translate(-ax, -ay);
        canvas.drawImageRect(img, src, shifted, p);
        canvas.restore();
        continue;
      }

      canvas.drawImageRect(img, src, dst, p);
    }

    if (step != Offset.zero) {
      canvas.restore();
    }
    if (pose.flipX) {
      canvas.restore();
    }
  }

  /// Whole-doll offset that fakes motion the single body clip cannot show.
  ///
  /// Walk = step bob, hit = short recoil away from facing, cast = slow float.
  static Offset ownedStepOffset(CharacterVisualPose pose, double size) {
    final p = pose.anim.progress.clamp(0.0, 1.0);
    return switch (pose.anim.kind) {
      HeroAnimKind.walk => Offset(
        0,
        -(math.sin(p * math.pi * 2).abs()) * size * 0.048,
      ),
      HeroAnimKind.hit => Offset(-size * 0.055 * (1 - p), size * 0.014 * (1 - p)),
      HeroAnimKind.cast => Offset(0, -size * 0.022 * math.sin(p * math.pi)),
      HeroAnimKind.attack => Offset(
        (pose.flipX ? -1.0 : 1.0) * size * 0.085 * math.sin(p * math.pi),
        -size * 0.02 * math.sin(p * math.pi),
      ),
      _ => Offset.zero,
    };
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
