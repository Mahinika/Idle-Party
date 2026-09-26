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

  /// Fist pivots measured on each family's body clip (center origin).
  ///
  /// Walk and attack PNGs move the arms. Cast reuses the attack body, so it
  /// uses that fist. Hit, death, and victory stay on the idle body.
  /// Both frames of a clip share one fist — the PNG does not change mid-swing.
  static const Map<BodyFamily, _FamilyFists> _familyFists = {
    BodyFamily.warrior: _FamilyFists(
      idleMain: (0.233, 0.033),
      idleOff: (-0.236, 0.032),
      walkMain: (0.236, 0.008),
      walkOff: (-0.234, 0.011),
      attackMain: (0.259, -0.024),
      attackOff: (-0.228, 0.036),
    ),
    BodyFamily.rogue: _FamilyFists(
      idleMain: (0.222, 0.001),
      idleOff: (-0.226, -0.003),
      walkMain: (0.225, -0.003),
      walkOff: (-0.217, -0.002),
      attackMain: (0.241, 0.053),
      attackOff: (-0.191, 0.086),
    ),
    BodyFamily.mage: _FamilyFists(
      idleMain: (0.226, 0.078),
      idleOff: (-0.230, 0.078),
      walkMain: (0.222, -0.063),
      walkOff: (-0.234, -0.063),
      attackMain: (0.222, -0.016),
      attackOff: (-0.234, -0.016),
    ),
    BodyFamily.healer: _FamilyFists(
      idleMain: (0.225, 0.038),
      idleOff: (-0.230, 0.032),
      walkMain: (0.225, -0.009),
      walkOff: (-0.230, -0.015),
      attackMain: (0.225, 0.046),
      attackOff: (-0.230, 0.039),
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
    final castLean = anim == HeroAnimKind.cast && frame == 1;
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
        castLean: castLean,
      ),
    };
  }

  static AnchorPose _ownedHand(
    BodyFamily family,
    HeroAnimKind anim,
    AnchorId id, {
    required bool attackLean,
    required bool castLean,
  }) {
    final fists = _familyFists[family]!;
    final (double x, double y) = switch (anim) {
      HeroAnimKind.walk =>
        id == AnchorId.mainHand ? fists.walkMain : fists.walkOff,
      HeroAnimKind.attack || HeroAnimKind.cast =>
        id == AnchorId.mainHand ? fists.attackMain : fists.attackOff,
      _ => id == AnchorId.mainHand ? fists.idleMain : fists.idleOff,
    };
    // Art is already angled in the PNG. Attack/cast add lean on top of the
    // swing in [attackSwingRotation] / cast raise.
    final rotation = id == AnchorId.offHand
        ? (attackLean ? 0.10 : 0.0)
        : (attackLean
              ? -0.40
              : (castLean ? -0.15 : (anim == HeroAnimKind.walk ? 0.06 : 0.0)));
    return AnchorPose(x: x, y: y, rotation: rotation);
  }

  /// Swing rotation boost for attack progress 0–1.
  static double attackSwingRotation(double progress) {
    if (progress < 0.35) {
      return -0.4 - progress * 1.2;
    }
    if (progress < 0.55) {
      return -0.9 + (progress - 0.35) * 4.5;
    }
    return math.max(-0.2, 0.6 - (progress - 0.55) * 1.8);
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
