import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/class_ability.dart';
import '../models/spell_bolt_style.dart';
import 'spell_vfx_palette.dart';

/// Anticipation / travel / impact motion on ability contact sheets (paint-only).
abstract final class AbilityShowcaseMotion {
  static final Path _path = Path();

  static void paintPhase(
    Canvas canvas, {
    required Rect tileRect,
    required ClassAbilityDef def,
    required double life,
  }) {
    final tile = tileRect.width / 3.2;
    final cx = tileRect.center.dx;
    final cy = tileRect.center.dy - tile * 0.1;
    final c = Offset(cx, cy);
    final style = def.boltStyle ?? SpellBoltStyle.weapon;
    final ramp = SpellSchoolRamp.forStyle(style);
  final phase = life.clamp(0.0, 1.0);

    if (phase < 0.2) {
      final t = (phase / 0.2).clamp(0.0, 1.0);
      final gather = tile * (0.35 + (1 - t) * 0.45);
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 + phase * 4;
        final p = Offset(cx + math.cos(a) * gather, cy + math.sin(a) * gather * 0.7);
        canvas.drawCircle(
          p,
          math.max(1.5, tile * 0.04),
          Paint()..color = ramp.lerp(0.45 + i * 0.08).withValues(alpha: 0.55 + t * 0.35),
        );
      }
      canvas.drawCircle(
        c,
        tile * 0.12,
        Paint()..color = ramp.hot.withValues(alpha: 0.25 + t * 0.35),
      );
    } else if (phase < 0.42) {
      final t = ((phase - 0.2) / 0.22).clamp(0.0, 1.0);
      for (var i = 0; i < 5; i++) {
        final a = -1.05 + i * 0.52;
        final reach = tile * (0.35 + t * 0.45);
        canvas.drawLine(
          c,
          Offset(cx + math.cos(a) * reach, cy + math.sin(a) * reach * 0.85),
          Paint()
            ..color = ramp.bright.withValues(alpha: 0.25 + t * 0.4)
            ..strokeWidth = math.max(2.0, tile * 0.09)
            ..strokeCap = StrokeCap.round,
        );
      }
    } else if (phase < 0.58) {
      final t = ((phase - 0.42) / 0.16).clamp(0.0, 1.0);
      final flash = (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2;
        canvas.drawLine(
          c,
          Offset(cx + math.cos(a) * tile * (0.4 + flash * 0.35), cy + math.sin(a) * tile * (0.35 + flash * 0.28)),
          Paint()
            ..color = ramp.hot.withValues(alpha: 0.35 + flash * 0.55)
            ..strokeWidth = math.max(2.2, tile * 0.08)
            ..strokeCap = StrokeCap.round,
        );
      }
      SpellVfxLayers.impactSparks(canvas, c, tile * 0.22, ramp, 0.65 + flash * 0.35, count: 8);
    } else {
      final fade = (1 - (phase - 0.58) / 0.42).clamp(0.0, 1.0);
      if (fade > 0.05) {
        SpellVfxLayers.softGlow(canvas, c, tile * 0.35, ramp, fade * 0.35);
      }
    }
  }
}