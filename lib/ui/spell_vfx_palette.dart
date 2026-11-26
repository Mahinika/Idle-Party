import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/spell_bolt_style.dart';

/// v3-inspired school ramps for layered spell paint (paint-only).
final class SpellSchoolRamp {
  const SpellSchoolRamp({
    required this.rim,
    required this.mid,
    required this.light,
    required this.bright,
    required this.hot,
    required this.ink,
  });

  final Color rim;
  final Color mid;
  final Color light;
  final Color bright;
  final Color hot;
  final Color ink;

  static SpellSchoolRamp forStyle(SpellBoltStyle style) => switch (style) {
        SpellBoltStyle.holy => const SpellSchoolRamp(
            rim: Color(0xFF8A7030),
            mid: Color(0xFFD8B050),
            light: Color(0xFFFFE890),
            bright: Color(0xFFFFF4C8),
            hot: Color(0xFFFFFFFF),
            ink: Color(0xFF2A1808),
          ),
        SpellBoltStyle.fire => const SpellSchoolRamp(
            rim: Color(0xFF8A2810),
            mid: Color(0xFFD84818),
            light: Color(0xFFFF6828),
            bright: Color(0xFFFFA050),
            hot: Color(0xFFFFF0D0),
            ink: Color(0xFF280804),
          ),
        SpellBoltStyle.frost => const SpellSchoolRamp(
            rim: Color(0xFF2868A0),
            mid: Color(0xFF50B8E8),
            light: Color(0xFF90E8FF),
            bright: Color(0xFFD0F8FF),
            hot: Color(0xFFFFFFFF),
            ink: Color(0xFF102030),
          ),
        SpellBoltStyle.lightning => const SpellSchoolRamp(
            rim: Color(0xFF3050A8),
            mid: Color(0xFF70B0FF),
            light: Color(0xFFB8F0FF),
            bright: Color(0xFFE8FFFF),
            hot: Color(0xFFFFFFFF),
            ink: Color(0xFF101828),
          ),
        SpellBoltStyle.arcane => const SpellSchoolRamp(
            rim: Color(0xFF6020A0),
            mid: Color(0xFFB040F0),
            light: Color(0xFFE080FF),
            bright: Color(0xFFF8D0FF),
            hot: Color(0xFFFFFFFF),
            ink: Color(0xFF180828),
          ),
        SpellBoltStyle.shadow => const SpellSchoolRamp(
            rim: Color(0xFF402060),
            mid: Color(0xFF7040B0),
            light: Color(0xFFA070E0),
            bright: Color(0xFFD0B0FF),
            hot: Color(0xFFFFE8FF),
            ink: Color(0xFF100818),
          ),
        SpellBoltStyle.demon => const SpellSchoolRamp(
            rim: Color(0xFF305010),
            mid: Color(0xFF60B020),
            light: Color(0xFF90F040),
            bright: Color(0xFFC0FF80),
            hot: Color(0xFFFFF8E0),
            ink: Color(0xFF101808),
          ),
        SpellBoltStyle.nature => const SpellSchoolRamp(
            rim: Color(0xFF1A5028),
            mid: Color(0xFF3A9850),
            light: Color(0xFF78D070),
            bright: Color(0xFFB8F098),
            hot: Color(0xFFE8FFD8),
            ink: Color(0xFF0A1810),
          ),
        SpellBoltStyle.poison => const SpellSchoolRamp(
            rim: Color(0xFF486010),
            mid: Color(0xFF90C030),
            light: Color(0xFFD0F060),
            bright: Color(0xFFFFF0A0),
            hot: Color(0xFFFFFFFF),
            ink: Color(0xFF182008),
          ),
        SpellBoltStyle.arrow => const SpellSchoolRamp(
            rim: Color(0xFF6A5030),
            mid: Color(0xFFB89850),
            light: Color(0xFFE8D090),
            bright: Color(0xFFFFF0C8),
            hot: Color(0xFFFFFFFF),
            ink: Color(0xFF201810),
          ),
        SpellBoltStyle.weapon => const SpellSchoolRamp(
            rim: Color(0xFF8A6830),
            mid: Color(0xFFD0A858),
            light: Color(0xFFFFE090),
            bright: Color(0xFFFFF4D0),
            hot: Color(0xFFFFFFFF),
            ink: Color(0xFF201408),
          ),
      };

  Color lerp(double t) => Color.lerp(lerpChain(t), hot, t > 0.85 ? (t - 0.85) / 0.15 : 0)!;

  Color lerpChain(double t) {
    if (t < 0.25) return Color.lerp(rim, mid, t / 0.25)!;
    if (t < 0.55) return Color.lerp(mid, light, (t - 0.25) / 0.3)!;
    if (t < 0.85) return Color.lerp(light, bright, (t - 0.55) / 0.3)!;
    return Color.lerp(bright, hot, (t - 0.85) / 0.15)!;
  }
}

abstract final class SpellVfxLayers {
  static void softGlow(
    Canvas canvas,
    Offset c,
    double radius,
    SpellSchoolRamp ramp,
    double alpha,
  ) {
    for (var i = 3; i >= 0; i--) {
      final t = i / 3.0;
      canvas.drawCircle(
        c,
        radius * (1.1 + t * 0.55),
        Paint()..color = ramp.lerp(0.15 + t * 0.35).withValues(alpha: alpha * (0.14 - t * 0.03)),
      );
    }
  }

  static void impactSparks(
    Canvas canvas,
    Offset c,
    double r,
    SpellSchoolRamp ramp,
    double alpha, {
    int count = 6,
  }) {
    for (var i = 0; i < count; i++) {
      final a = i * math.pi * 2 / count + 0.2;
      final dist = r * (0.9 + (i.isOdd ? 0.25 : 0.45));
      canvas.drawCircle(
        Offset(c.dx + math.cos(a) * dist, c.dy + math.sin(a) * dist),
        math.max(1.5, r * 0.1),
        Paint()..color = ramp.bright.withValues(alpha: alpha * (0.9 - i * 0.08)),
      );
    }
    canvas.drawCircle(c, r * 0.22, Paint()..color = ramp.hot.withValues(alpha: alpha * 0.95));
  }

  static void taperBeam(
    Canvas canvas,
    Offset a,
    Offset b,
    SpellSchoolRamp ramp,
    double alpha,
    double tile,
  ) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy) + 0.001;
    final nx = -dy / len;
    final ny = dx / len;
    SpellVfxLayers.softGlow(canvas, Offset.lerp(a, b, 0.5)!, len * 0.08, ramp, alpha * 0.45);
    for (var t = 0.0; t <= 1.0; t += 0.11) {
      final w = (1 - (t - 0.5).abs() * 2) * math.max(3.0, tile * 0.22) + tile * 0.06;
      final p = Offset(a.dx + dx * t, a.dy + dy * t);
      canvas.drawLine(
        Offset(p.dx + nx * w, p.dy + ny * w),
        Offset(p.dx - nx * w, p.dy - ny * w),
        Paint()
          ..color = ramp.lerp(0.35 + t * 0.5).withValues(alpha: alpha)
          ..strokeWidth = math.max(1.2, tile * 0.05)
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawLine(a, b, Paint()
      ..color = ramp.hot.withValues(alpha: alpha * 0.92)
      ..strokeWidth = math.max(1.4, tile * 0.06)
      ..strokeCap = StrokeCap.round);
  }
}