import 'dart:math' as math;
import 'dart:ui' as ui;

import '../anchor_table.dart';
import '../body_family.dart';
import '../character_layer.dart';
import '../character_visual_painter.dart';
import '../character_visual_pose.dart';
import '../hero_anim_state.dart';
import '../owned_gear_grips.dart';
import 'rig_data.dart';
import 'rig_part_cache.dart';
import 'rig_pose.dart';

/// Draws one posed part, a rigid cape, or a gripped weapon into the 256 frame.
abstract final class HeroRigDraw {
  static bool isWeapon(ResolvedLayer layer) =>
      layer.id == CharacterLayerId.mainHand ||
      layer.id == CharacterLayerId.offHand;

  static void part(
    ui.Canvas canvas,
    RigAtlas atlas,
    String name,
    Map<String, RigWorld> world,
    ui.Color? tint,
  ) {
    RigPiece? piece;
    for (final candidate in atlas.pieces) {
      if (candidate.part == name) piece = candidate;
    }
    if (piece == null) return;
    final bone = world[name];
    if (bone == null) return;
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..isAntiAlias = false;
    if (tint != null) {
      paint.colorFilter = ui.ColorFilter.mode(tint, ui.BlendMode.modulate);
    }
    if (bone.deg.abs() < 0.05) {
      final left = (RigData.origin + bone.x - piece.pivotX).roundToDouble();
      final top = (RigData.origin + bone.y - piece.pivotY).roundToDouble();
      canvas.drawImageRect(
        atlas.image,
        piece.rect,
        ui.Rect.fromLTWH(left, top, piece.rect.width, piece.rect.height),
        paint,
      );
      return;
    }
    canvas.drawAtlas(
      atlas.image,
      [
        ui.RSTransform.fromComponents(
          rotation: bone.deg * math.pi / 180,
          scale: 1,
          anchorX: piece.pivotX,
          anchorY: piece.pivotY,
          translateX: RigData.origin + bone.x,
          translateY: RigData.origin + bone.y,
        ),
      ],
      [piece.rect],
      null,
      null,
      null,
      paint,
    );
  }

  static void rigid(
    ui.Canvas canvas,
    ui.Image image,
    Map<String, RigWorld> world,
    RigData rig,
    String boneName,
    ui.Color? tint,
  ) {
    final bone = world[boneName];
    final rest = rig.bones[boneName];
    if (bone == null || rest == null) return;
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..isAntiAlias = false;
    if (tint != null) {
      paint.colorFilter = ui.ColorFilter.mode(tint, ui.BlendMode.modulate);
    }
    canvas.drawAtlas(
      image,
      [
        ui.RSTransform.fromComponents(
          rotation: bone.deg * math.pi / 180,
          scale: 1,
          anchorX: rest.restX,
          anchorY: rest.restY,
          translateX: RigData.origin + bone.x,
          translateY: RigData.origin + bone.y,
        ),
      ],
      [ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble())],
      null,
      null,
      null,
      paint,
    );
  }

  static void weapon(
    ui.Canvas canvas,
    ui.Image image,
    ResolvedLayer layer,
    RigData rig,
    Map<String, RigWorld> world,
    RigPose rigPose,
    CharacterVisualPose pose,
  ) {
    final off = layer.id == CharacterLayerId.offHand;
    final placed = _placed(rig, world, pose, off, layer.ownedAsset);
    if (placed == null || layer.ownedAsset == null) return;
    final grip = OwnedGearGrips.forAsset(layer.ownedAsset!, offHand: off);
    var rot = placed.rotation;
    rot += off ? pose.offHandExtraRotation : pose.mainHandExtraRotation;
    rot += OwnedGearGrips.restForAsset(layer.ownedAsset!, offHand: off);
    rot += placed.boneDeg * math.pi / 180;
    rot += (rigPose.angles[off ? 'shield' : 'sword'] ?? 0) * math.pi / 180;
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..isAntiAlias = false;
    if (layer.tint != null) {
      paint.colorFilter = ui.ColorFilter.mode(
        layer.tint!,
        ui.BlendMode.modulate,
      );
    }
    if (!rot.isFinite || !placed.x.isFinite || !placed.y.isFinite) return;
    canvas.save();
    canvas.translate(placed.x, placed.y);
    canvas.rotate(rot);
    canvas.translate(-grip.dx * image.width, -grip.dy * image.height);
    canvas.drawImage(image, ui.Offset.zero, paint);
    // A one-pixel string vanishes under nearest rotation. A second copy,
    // one pixel over, keeps the line in the turn. Confirmed for bows.
    if (layer.ownedAsset!.contains('/bow_')) {
      canvas.drawImage(image, const ui.Offset(1, 0), paint);
    }
    canvas.restore();
  }

  /// Where the idle grip sits after the holding bone moves.
  static ui.Offset gripPoint(
    RigData rig,
    Map<String, RigWorld> world,
    CharacterVisualPose pose, {
    required bool offHand,
  }) {
    final placed = _placed(rig, world, pose, offHand, null);
    return ui.Offset(placed?.x ?? 0, placed?.y ?? 0);
  }

  static _Placed? _placed(
    RigData rig,
    Map<String, RigWorld> world,
    CharacterVisualPose pose,
    bool off,
    String? asset,
  ) {
    final boneName =
        rig.handBones[off ? 'off' : 'main'] ?? (off ? 'hand_l' : 'hand_r');
    final bone = world[boneName];
    final rest = rig.bones[boneName];
    if (bone == null || rest == null) return null;
    final anchor = AnchorTables.lookup(
      anim: HeroAnimKind.idle,
      frame: 0,
      id: off ? AnchorId.offHand : AnchorId.mainHand,
      flipX: false,
      profile: BodyAnchorProfile.owned,
      family: pose.bodyFamily ?? BodyFamily.warrior,
    ).scaled(RigData.canvas.toDouble());
    final glove = CharacterVisualPainter.wornGloveShift(pose, offHand: off);
    var ax = RigData.canvas / 2 + anchor.x + glove.dx * RigData.canvas;
    var ay = RigData.canvas / 2 + anchor.y + glove.dy * RigData.canvas;
    if (!off && asset != null && asset.contains('/bow_')) {
      ax += RigData.canvas * 0.12;
      ay += RigData.canvas * 0.06;
    }
    final a = bone.deg * math.pi / 180;
    final c = math.cos(a);
    final s = math.sin(a);
    final dx = ax - rest.restX;
    final dy = ay - rest.restY;
    return _Placed(
      RigData.origin + bone.x + c * dx - s * dy,
      RigData.origin + bone.y + s * dx + c * dy,
      anchor.rotation,
      bone.deg,
    );
  }
}

class _Placed {
  const _Placed(this.x, this.y, this.rotation, this.boneDeg);

  final double x;
  final double y;
  final double rotation;
  final double boneDeg;
}
