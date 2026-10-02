import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/hero.dart';
import '../ui/hero_paper_doll.dart';
import 'anchor_table.dart';
import 'body_family.dart';
import 'character_layer.dart';
import 'character_visual_pose.dart';
import 'shadowform.dart';
import 'hero_anim_controller.dart';
import 'owned_gear_assets.dart';
import 'rig/rig_part_cache.dart';
import 'owned_gear_grips.dart';
import 'owned_glove_tips.dart';
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
    CharacterLayerId.boots,
    CharacterLayerId.torso,
    CharacterLayerId.shoulders,
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
  /// Size where each of the 128 art pixels lands on a whole device pixel.
  ///
  /// A 120-wide doll on a 3× phone is 2.8 device pixels per art pixel, so
  /// nearest-neighbor drops lines out of the plate. Snap to the nearest fit
  /// unless that would resize a tiny chip by more than 30%.
  static double pixelSpan(double size) {
    final dpr =
        ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
    if (dpr <= 0 || !dpr.isFinite || !size.isFinite || size <= 0) return size;
    final k = (size * dpr / 128).round().clamp(1, 4);
    final snapped = k * 128 / dpr;
    if ((snapped - size).abs() > size * 0.30) return size;
    return snapped;
  }

  /// [size] is the art span. The rect origin sits on a device pixel.
  static Rect pixelRect(Offset center, double size) =>
      alignedRect(center, pixelSpan(size));

  /// Places [span] on whole device pixels. Does not change [span].
  static Rect alignedRect(Offset center, double span) {
    final dpr =
        ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
    double snap(double v) =>
        dpr <= 0 || !dpr.isFinite ? v : (v * dpr).round() / dpr;
    return Rect.fromLTWH(
      snap(center.dx - span / 2),
      snap(center.dy - span / 2),
      span,
      span,
    );
  }

  static void paintOwnedHero(
    Canvas canvas,
    Offset center,
    double size, {
    required ui.Image body,
    required Map<String, ui.Image> images,
    required CharacterVisualPose pose,
    double alpha = 1,
    Set<CharacterLayerId>? onlyLayers,
  }) {
    final basePaint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..color = Color.fromRGBO(255, 255, 255, alpha);
    final dst = pixelRect(center, size);

    ui.Image? overlayImage(String? path) {
      if (path == null) return null;
      final direct = images[path] ?? images[OwnedGearAssets.idleFallback(path)];
      if (direct != null) return direct;
      final native = OwnedGearAssets.nativeCutFallback(path);
      if (native == null) return null;
      return images[native] ?? images[OwnedGearAssets.idleFallback(native)];
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
    final lean = ownedLeanRadians(pose);
    if (step != Offset.zero || lean != 0) {
      canvas.save();
      if (lean != 0) {
        final pivot = center.translate(0, size * 0.36);
        canvas.translate(pivot.dx, pivot.dy);
        canvas.rotate(lean);
        canvas.translate(-pivot.dx, -pivot.dy);
      }
      if (step != Offset.zero) {
        canvas.translate(step.dx, step.dy);
      }
    }

    if (pose.shadowform) {
      canvas.saveLayer(
        dst.inflate(size),
        Paint()..colorFilter = Shadowform.wash,
      );
    }

    for (final layer in pose.orderedLayers()) {
      if (onlyLayers != null && !onlyLayers.contains(layer.id)) continue;
      if (layer.id == CharacterLayerId.body) {
        final bodySrc = Rect.fromLTWH(
          0,
          0,
          body.width.toDouble(),
          body.height.toDouble(),
        );
        canvas.drawImageRect(body, bodySrc, dst, basePaint);
        // Spec color only where the cloth mask is opaque. Skin, hair, and
        // the empty corners stay the body PNG. Gear overlays paint after.
        final tint = pose.bodyTint;
        final mask = overlayImage(pose.bodyTintAsset);
        if (tint != null && mask != null) {
          final tintPaint = Paint()
            ..filterQuality = FilterQuality.none
            ..isAntiAlias = false
            ..color = Color.fromRGBO(255, 255, 255, alpha)
            ..colorFilter = ColorFilter.mode(
              tint.withValues(alpha: 1),
              BlendMode.modulate,
            );
          // Shoes live on the bottom of the undertunic. Dyeing them the spec
          // color makes short pants look barefoot.
          final shoeTop = OwnedGearAssets.undertunicShoeTop;
          canvas.drawImageRect(
            mask,
            Rect.fromLTWH(
              0,
              0,
              mask.width.toDouble(),
              mask.height * shoeTop,
            ),
            Rect.fromLTWH(
              dst.left,
              dst.top,
              dst.width,
              dst.height * shoeTop,
            ),
            tintPaint,
          );
        }
        continue;
      }
      if (!kOwnedGearOverlayLayers.contains(layer.id)) continue;
      final asset = layer.ownedAsset;
      final img = asset == null
          ? overlayImage(asset)
          : RigPartCache.prepared[asset] ?? overlayImage(asset);
      if (img == null) continue;
      final p = Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false
        ..color = Color.fromRGBO(255, 255, 255, alpha);
      final tint = layer.tint;
      if (tint != null) {
        p.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
      }
      final crop = layer.cropTop.clamp(0.0, 0.95);
      final src = Rect.fromLTWH(
        0,
        img.height * crop,
        img.width.toDouble(),
        img.height * (1 - crop),
      );
      final layerDst = crop == 0
          ? dst
          : Rect.fromLTWH(
              dst.left,
              dst.top + dst.height * crop,
              dst.width,
              dst.height * (1 - crop),
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
          family: pose.bodyFamily,
        ).scaled(size);
        var rot = ap.rotation;
        if (layer.anchorId == AnchorId.mainHand) {
          rot += pose.mainHandExtraRotation;
        } else if (layer.anchorId == AnchorId.offHand) {
          rot += pose.offHandExtraRotation;
        }
        final offHand = layer.anchorId == AnchorId.offHand;
        // The skin fist is under the glove. Hold the weapon at the glove's
        // outer rim, or a plate hand looks like it grew past the grip.
        final glove = wornGloveShift(pose, offHand: offHand);
        final ax = center.dx + ap.x + glove.dx * size;
        final ay = center.dy + ap.y + glove.dy * size;
        final grip = OwnedGearGrips.forAsset(
          asset,
          offHand: offHand,
        );
        rot += OwnedGearGrips.restForAsset(asset, offHand: offHand);
        final gripOnFull = Offset(
          dst.left + grip.dx * size,
          dst.top + grip.dy * size,
        );
        var shifted = dst.shift(
          Offset(ax - gripOnFull.dx, ay - gripOnFull.dy),
        );
        // A bow's string curves back toward the cheek. Hold it out and down.
        if (!offHand && asset.contains('/bow_')) {
          shifted = shifted.shift(Offset(size * 0.12, size * 0.06));
        }
        canvas.save();
        canvas.translate(ax, ay);
        canvas.rotate(rot);
        canvas.translate(-ax, -ay);
        canvas.drawImageRect(img, src, shifted, p);
        if (!offHand && asset.contains('/bow_')) {
          canvas.drawImageRect(img, src, shifted.shift(const Offset(1, 0)), p);
        }
        canvas.restore();
        continue;
      }

      // The rogue attack clip drops the head. Same-origin helms are drawn
      // for the idle head, so follow the head or a large helm covers the face.
      final helmShift = layer.id == CharacterLayerId.head
          ? _rogueAttackHelmShift(pose, size)
          : Offset.zero;
      canvas.drawImageRect(
        img,
        src,
        helmShift == Offset.zero ? layerDst : layerDst.shift(helmShift),
        p,
      );
      final dyeMaskPath = layer.dyeMaskAsset;
      final dyeTint = layer.dyeTint;
      if (dyeMaskPath != null && dyeTint != null) {
        final dyeImg = overlayImage(dyeMaskPath);
        if (dyeImg != null) {
          final dyePaint = Paint()
            ..filterQuality = FilterQuality.none
            ..isAntiAlias = false
            ..color = Color.fromRGBO(255, 255, 255, alpha)
            ..colorFilter = ColorFilter.mode(dyeTint, BlendMode.modulate);
          canvas.drawImageRect(
            dyeImg,
            Rect.fromLTWH(
              0,
              0,
              dyeImg.width.toDouble(),
              dyeImg.height.toDouble(),
            ),
            helmShift == Offset.zero ? dst : dst.shift(helmShift),
            dyePaint,
          );
        }
      }
    }

    if (pose.shadowform) canvas.restore();

    if (step != Offset.zero || lean != 0) {
      canvas.restore();
    }
    if (pose.flipX) {
      canvas.restore();
    }
  }

  /// Rogue's attack clip draws the head lower and to the right of idle.
  /// Helms are idle-aligned, so they follow that shift on attack and cast.
  static Offset _rogueAttackHelmShift(CharacterVisualPose pose, double size) {
    if (pose.bodyFamily != BodyFamily.rogue) return Offset.zero;
    final kind = pose.anim.kind;
    if (kind != HeroAnimKind.attack && kind != HeroAnimKind.cast) {
      return Offset.zero;
    }
    return Offset(size * 8 / 128, size * 13 / 128);
  }

  /// Extra shift from the skin fist to the outer rim of a worn glove.
  /// Fractions of the sprite. Bare hands stay at zero.
  static Offset wornGloveShift(
    CharacterVisualPose pose, {
    required bool offHand,
  }) {
    for (final layer in pose.layers) {
      if (layer.id != CharacterLayerId.gloves) continue;
      return OwnedGloveTips.shiftFor(
        layer.ownedAsset,
        pose.bodyFamily,
        offHand: offHand,
      );
    }
    return Offset.zero;
  }

  /// Where [paintOwnedHero] puts a hand anchor on screen, after the step
  /// and the lean. Unflipped poses only. [gloveShift] is the worn-glove rim.
  static Offset ownedHandPoint(
    CharacterVisualPose pose,
    Offset center,
    double size,
    AnchorId id, {
    Offset gloveShift = Offset.zero,
  }) {
    final ap = AnchorTables.lookup(
      anim: pose.anim.kind,
      frame: pose.anim.frame,
      id: id,
      flipX: false,
      profile: BodyAnchorProfile.owned,
      family: pose.bodyFamily,
    ).scaled(size);
    final step = ownedStepOffset(pose, size);
    var p = Offset(
      center.dx + ap.x + gloveShift.dx * size + step.dx,
      center.dy + ap.y + gloveShift.dy * size + step.dy,
    );
    final lean = ownedLeanRadians(pose);
    if (lean != 0) {
      final pivot = center.translate(0, size * 0.36);
      final dx = p.dx - pivot.dx;
      final dy = p.dy - pivot.dy;
      final c = math.cos(lean);
      final s = math.sin(lean);
      p = Offset(pivot.dx + c * dx - s * dy, pivot.dy + s * dx + c * dy);
    }
    return p;
  }

  /// Walk bobs, hit recoils, cast lifts, death drops. Idle stays put.
  static Offset ownedStepOffset(CharacterVisualPose pose, double size) =>
      clipMotion(
        pose.anim.kind,
        pose.anim.progress,
        size,
        flipX: pose.flipX,
      );

  /// Shared by the paper doll and unique form sprites (cat, bear, moonkin,
  /// tree, Shadow) so a walk reads without a second PNG.
  static Offset clipMotion(
    HeroAnimKind kind,
    double progress,
    double size, {
    bool flipX = false,
  }) {
    final p = progress.clamp(0.0, 1.0);
    return switch (kind) {
      HeroAnimKind.walk => Offset(
        math.sin(p * math.pi * 2) * size * 0.04,
        -(math.sin(p * math.pi * 2).abs()) * size * 0.07,
      ),
      HeroAnimKind.hit => Offset(
        -size * 0.10 * (1 - p),
        size * 0.02 * (1 - p),
      ),
      HeroAnimKind.cast => Offset(0, -size * 0.06 * math.sin(p * math.pi)),
      HeroAnimKind.attack => Offset(
        (flipX ? -1.0 : 1.0) * size * 0.10 * math.sin(p * math.pi),
        -size * 0.03 * math.sin(p * math.pi),
      ),
      HeroAnimKind.death => Offset(0, size * 0.14),
      _ => Offset.zero,
    };
  }

  /// Feet-pivot lean. Hit tips back; death lies down. Idle clip stays put.
  static double ownedLeanRadians(CharacterVisualPose pose) {
    final p = pose.anim.progress.clamp(0.0, 1.0);
    return switch (pose.anim.kind) {
      HeroAnimKind.hit => -0.22 * (1 - p),
      HeroAnimKind.death => 0.7,
      HeroAnimKind.cast => -0.12 * math.sin(p * math.pi),
      _ => 0,
    };
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
          family: pose.bodyFamily,
        ).scaled(size);
        var rot = ap.rotation;
        if (anchorId == AnchorId.mainHand) {
          rot += pose.mainHandExtraRotation;
        } else if (anchorId == AnchorId.offHand) {
          rot += pose.offHandExtraRotation;
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
}
