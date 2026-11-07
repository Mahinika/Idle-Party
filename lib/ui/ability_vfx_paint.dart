import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vfx_quality.dart';
import '../spatial/spatial_combat.dart';

/// Canvas marks for ability readability. No sprites, no extra bursts.
abstract final class AbilityVfxPaint {
  static bool showCastGlint({
    required VfxQuality quality,
    required double castFlash,
  }) => SpellVfx.castGlintVisible(
    reduceMotion: quality == VfxQuality.minimal,
    castFlash: castFlash,
  );

  /// Four-point glint. Dies once [castFlash] falls through the floor, so it
  /// does not sit on top of the release burst for the whole lockout.
  static void paintCastGlint(
    Canvas canvas,
    Offset center,
    double tile,
    double castFlash,
  ) {
    final t = ((castFlash - SpellVfx.castGlintFloor) / 0.15).clamp(0.0, 1.0);
    final arm = tile * (0.16 + 0.06 * t);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2.2, tile * 0.07)
      ..color = const Color(0xFF100C08).withValues(alpha: 0.85 * t);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.2, tile * 0.035)
      ..color = Colors.white.withValues(alpha: t);
    canvas.drawLine(center + Offset(-arm, 0), center + Offset(arm, 0), ink);
    canvas.drawLine(center + Offset(0, -arm), center + Offset(0, arm), ink);
    canvas.drawLine(center + Offset(-arm, 0), center + Offset(arm, 0), core);
    canvas.drawLine(center + Offset(0, -arm), center + Offset(0, arm), core);
  }

  /// Shape, not hue. A chevron is a hero bolt. A closed diamond is hostile.
  /// Drawn in white over a dark stroke so colorblind mode still separates them.
  static void paintBoltAllegiance(
    Canvas canvas, {
    required bool hero,
    required double thick,
  }) {
    final s = math.max(2.4, thick * 0.95);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(2.4, thick * 0.55)
      ..color = const Color(0xFF100C08);
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1.3, thick * 0.28)
      ..color = Colors.white;
    final path = Path();
    if (hero) {
      path
        ..moveTo(-s, -s * 0.85)
        ..lineTo(s * 0.35, 0)
        ..lineTo(-s, s * 0.85);
    } else {
      path
        ..moveTo(0, -s)
        ..lineTo(s, 0)
        ..lineTo(0, s)
        ..lineTo(-s, 0)
        ..close();
    }
    canvas.drawPath(path, outline);
    canvas.drawPath(path, mark);
  }

  /// Short bright core on a signature impact. The school shape stays around it.
  static void paintCrispCore(
    Canvas canvas,
    Offset center,
    double radiusPx,
    double alpha,
  ) {
    if (alpha <= 0.02 || radiusPx <= 0.5) return;
    final a = alpha.clamp(0.0, 1.0);
    final r = radiusPx * (0.55 + 0.45 * a);
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r * 0.72, center.dy)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r * 0.72, center.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF100C08).withValues(alpha: 0.9 * a),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, radiusPx * 0.18)
        ..color = Colors.white.withValues(alpha: a),
    );
  }
}
