import 'dart:math' as math;

import 'hero_anim_state.dart';

/// Attachment points for equipment overlays.
enum AnchorId { head, body, mainHand, offHand, back, feet }

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

/// Per-frame anchors for Kenney body family (v1).
///
/// Coordinates are fractions of the destination sprite size (center origin).
abstract final class AnchorTables {
  static AnchorPose lookup({
    required HeroAnimKind anim,
    required int frame,
    required AnchorId id,
    bool flipX = false,
  }) {
    final pose = _kenneyV1(anim, frame, id);
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

  /// Swing rotation boost for attack progress 0–1.
  static double attackSwingRotation(double progress) {
    // Raise → peak → return.
    if (progress < 0.35) {
      return -0.4 - progress * 1.2;
    }
    if (progress < 0.55) {
      return -0.9 + (progress - 0.35) * 4.5;
    }
    return math.max(-0.2, 0.6 - (progress - 0.55) * 1.8);
  }
}
