import 'dart:math' as math;

import 'body_family.dart';
import 'hero_anim_state.dart';

/// Attachment points for equipment overlays.
enum AnchorId { head, body, mainHand, offHand, back, feet }

/// Which body silhouette the anchors were tuned for.
enum BodyAnchorProfile {
  /// Kenney 16×16 paper-doll proportions.
  kenney,

  /// Owned denser 128×128 bodies (`assets/custom/char/`).
  owned,
}

/// Pixel offset + rotation relative to character center (normalized −0.5..0.5
/// of sprite size for x/y; [rotation] in radians).
class AnchorPose {
  const AnchorPose({
    required this.x,
    required this.y,
    this.rotation = 0,
  });

  final double x;
  final double y;
  final double rotation;

  AnchorPose flipped() => AnchorPose(x: -x, y: y, rotation: -rotation);

  AnchorPose scaled(double size) => AnchorPose(
    x: x * size,
    y: y * size,
    rotation: rotation,
  );
}

/// Relative Kenney-tile size when drawn on a body sprite.
class GearOverlayScales {
  const GearOverlayScales({
    required this.head,
    required this.hand,
    required this.cape,
  });

  final double head;
  final double hand;
  final double cape;

  static const kenney = GearOverlayScales(
    head: 0.42,
    hand: 0.55,
    cape: 0.85,
  );

  /// Tighter Kenney-tile scales for denser bodies on the fallback atlas path.
  /// Owned heroes use full 128 overlays + [OwnedGearGrips] instead.
  static const owned = GearOverlayScales(
    head: 0.24,
    hand: 0.30,
    cape: 0.50,
  );
}

/// Per-frame anchors for layered heroes.
///
/// Coordinates are fractions of the destination sprite size (center origin).
abstract final class AnchorTables {
  static AnchorPose lookup({
    required HeroAnimKind anim,
    required int frame,
    required AnchorId id,
    bool flipX = false,
    BodyAnchorProfile profile = BodyAnchorProfile.kenney,
    BodyFamily? family,
  }) {
    final pose = switch (profile) {
      BodyAnchorProfile.kenney => _kenneyV1(anim, frame, id),
      BodyAnchorProfile.owned => _ownedV1(
        anim,
        frame,
        id,
        family: family ?? BodyFamily.warrior,
      ),
    };
    return flipX ? pose.flipped() : pose;
  }

  static AnchorPose _kenneyV1(HeroAnimKind anim, int frame, AnchorId id) {
    final attackLean = anim == HeroAnimKind.attack && frame == 1;
    final castLean = anim == HeroAnimKind.cast && frame == 1;
    return switch (id) {
      AnchorId.head => const AnchorPose(x: 0, y: -0.28),
      AnchorId.body => const AnchorPose(x: 0, y: 0),
      AnchorId.back => const AnchorPose(x: 0, y: -0.05),
      AnchorId.feet => const AnchorPose(x: 0, y: 0.38),
      AnchorId.mainHand => AnchorPose(
        x: attackLean ? 0.28 : (castLean ? 0.18 : 0.22),
        y: attackLean ? -0.05 : (castLean ? -0.18 : 0.08),
        rotation: attackLean
            ? -0.85
            : (castLean ? -0.35 : (anim == HeroAnimKind.walk ? 0.15 : 0)),
      ),
      AnchorId.offHand => AnchorPose(
        x: attackLean ? -0.22 : -0.24,
        y: attackLean ? 0.02 : 0.06,
        rotation: attackLean ? 0.25 : 0,
      ),
    };
  }

  /// Skin hand on the idle body, center origin. The same point for every clip.
  ///
  /// These are the visible bare fists. A worn glove then shifts the grip
  /// into that glove's painted palm (owned glove tips).
  /// Walk and attack keep it too: those clips do not move the glove.
  static const Map<BodyFamily, _FamilyFists> _familyFists = {
    BodyFamily.warrior: _FamilyFists(
      idleMain: (0.238, 0.035),
      idleOff: (-0.246, 0.035),
      walkMain: (0.238, 0.035),
      walkOff: (-0.246, 0.035),
      attackMain: (0.238, 0.035),
      attackOff: (-0.246, 0.035),
    ),
    BodyFamily.rogue: _FamilyFists(
      idleMain: (0.212, -0.004),
      idleOff: (-0.221, -0.006),
      walkMain: (0.212, -0.004),
      walkOff: (-0.221, -0.006),
      attackMain: (0.212, -0.004),
      attackOff: (-0.221, -0.006),
    ),
    BodyFamily.mage: _FamilyFists(
      idleMain: (0.212, 0.024),
      idleOff: (-0.224, 0.071),
      walkMain: (0.212, 0.024),
      walkOff: (-0.224, 0.071),
      attackMain: (0.212, 0.024),
      attackOff: (-0.224, 0.071),
    ),
    BodyFamily.healer: _FamilyFists(
      idleMain: (0.214, 0.030),
      idleOff: (-0.225, 0.029),
      walkMain: (0.214, 0.030),
      walkOff: (-0.225, 0.029),
      attackMain: (0.214, 0.030),
      attackOff: (-0.225, 0.029),
    ),
  };

  /// Tuned for front-facing denser idle/walk/attack frames.
  static AnchorPose _ownedV1(
    HeroAnimKind anim,
    int frame,
    AnchorId id, {
    required BodyFamily family,
  }) {
    final attackLean = anim == HeroAnimKind.attack && frame == 1;
    return switch (id) {
      AnchorId.head => const AnchorPose(x: 0, y: -0.30),
      AnchorId.body => const AnchorPose(x: 0, y: 0),
      AnchorId.back => const AnchorPose(x: 0, y: -0.08),
      AnchorId.feet => const AnchorPose(x: 0, y: 0.40),
      AnchorId.mainHand || AnchorId.offHand => _ownedHand(
        family,
        anim,
        id,
        attackLean: attackLean,
      ),
    };
  }

  static AnchorPose _ownedHand(
    BodyFamily family,
    HeroAnimKind anim,
    AnchorId id, {
    required bool attackLean,
  }) {
    final fists = _familyFists[family]!;
    final (double x, double y) = switch (anim) {
      HeroAnimKind.walk =>
        id == AnchorId.mainHand ? fists.walkMain : fists.walkOff,
      HeroAnimKind.attack || HeroAnimKind.cast =>
        id == AnchorId.mainHand ? fists.attackMain : fists.attackOff,
      _ => id == AnchorId.mainHand ? fists.idleMain : fists.idleOff,
    };
    // Rest angle already aims the blade. The swing and the cast raise live
    // in [attackSwingRotation] and [CharacterVisualPose.mainHandExtraRotation].
    // An extra inward lean here pulls the blade across the face.
    final rotation = id == AnchorId.offHand
        ? (attackLean ? 0.10 : 0.0)
        : (anim == HeroAnimKind.walk ? 0.06 : 0.0);
    return AnchorPose(x: x, y: y, rotation: rotation);
  }

  /// Swing rotation for attack progress 0–1.
  ///
  /// Positive is clockwise, so the right-hand blade chambers out, away from
  /// the face, then cuts back without parking on the head.
  static double attackSwingRotation(double progress) {
    if (progress < 0.35) {
      return 0.20 + progress * 1.1;
    }
    if (progress < 0.55) {
      return 0.585 - (progress - 0.35) * 3.2;
    }
    return math.max(-0.25, -0.055 - (progress - 0.55) * 0.5);
  }
}

/// Main-hand and off-hand fist points for one body family.
///
/// Each pair is center-origin (x right, y down), fractions of the 128 sprite.
class _FamilyFists {
  const _FamilyFists({
    required this.idleMain,
    required this.idleOff,
    required this.walkMain,
    required this.walkOff,
    required this.attackMain,
    required this.attackOff,
  });

  final (double, double) idleMain;
  final (double, double) idleOff;
  final (double, double) walkMain;
  final (double, double) walkOff;
  final (double, double) attackMain;
  final (double, double) attackOff;
}
