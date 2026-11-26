import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/class_ability.dart';
import '../spatial/spatial_combat.dart';
import 'ability_showcase_motion.dart';
import 'ability_vfx_paint.dart';
import 'spell_vfx_palette.dart';

/// Shared spell burst / ground / bolt silhouettes for dungeon paint and VFX sheets.
abstract final class SpellShapePaint {
  static final Path _path = Path();
  static final Paint _fill = Paint()..style = PaintingStyle.fill;
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static Paint _fillC(Color color) {
    _fill.color = color;
    return _fill;
  }

  static Paint _strokeC(
    Color color,
    double width, {
    StrokeCap cap = StrokeCap.round,
    StrokeJoin join = StrokeJoin.miter,
  }) {
    _stroke
      ..color = color
      ..strokeWidth = width
      ..strokeCap = cap
      ..strokeJoin = join;
    return _stroke;
  }

  /// Melee abilities in the 61 set paint a bespoke overlay; the generic weapon
  /// slash arc reads as a beige/purple capsule in the lower-left on contact tiles.
  @visibleForTesting
  static bool suppressesGenericWeaponSlash(AbilityId? id) => switch (id) {
        AbilityId.executeFury ||
        AbilityId.hammerOfJusticeHoly ||
        AbilityId.hammerOfJusticeRet ||
        AbilityId.claw ||
        AbilityId.kidneyShotAssa ||
        AbilityId.adrenalineRush ||
        AbilityId.revealingStrike ||
        AbilityId.secretTechnique ||
        AbilityId.soulReaper ||
        AbilityId.maim =>
          true,
        _ => false,
      };

  /// Paints one [SpatialBurst] the same way fight floaters do.
  static void paintWorldBurst(
    Canvas canvas,
    SpatialBurst burst,
    double tile,
    Offset Function(double tx, double ty) centerAt,
  ) {
    final kind = burst.slash ? SpatialBurstKind.slash : burst.kind;
    if (kind == SpatialBurstKind.slash &&
        !suppressesGenericWeaponSlash(burst.paintId)) {
      _paintSlash(canvas, burst, tile, centerAt);
    } else if (kind == SpatialBurstKind.ring) {
      _paintRing(canvas, burst, tile, centerAt);
    } else if (kind == SpatialBurstKind.cone && burst.angle != null) {
      _paintCone(canvas, burst, tile, centerAt);
    } else if (kind == SpatialBurstKind.leaf) {
      _paintLeaf(canvas, burst, tile, centerAt);
    } else if (kind == SpatialBurstKind.spark) {
      _paintSpark(canvas, burst, tile, centerAt);
    } else if (kind == SpatialBurstKind.beam ||
        kind == SpatialBurstKind.rain ||
        kind == SpatialBurstKind.shards ||
        kind == SpatialBurstKind.flame ||
        kind == SpatialBurstKind.cross ||
        kind == SpatialBurstKind.poison ||
        kind == SpatialBurstKind.skull ||
        kind == SpatialBurstKind.summon ||
        kind == SpatialBurstKind.pillar) {
      paintTypedBurst(canvas, burst, tile, centerAt);
    } else {
      _paintDiscBurst(canvas, burst, tile, centerAt);
    }
    if (burst.paintId != null) {
      _paintAbilityOverlay(canvas, burst, tile, centerAt);
    }
    if (burst.paintId == AbilityId.powerWordBarrier ||
        burst.paintId == AbilityId.ironbark) {
      _paintDomeShell(canvas, burst, tile, centerAt);
    }
    if (burst.crisp) {
      final crispAlpha = (burst.life / SpellVfx.bigImpactLife).clamp(0.0, 1.0);
      AbilityVfxPaint.paintCrispCore(
        canvas,
        centerAt(burst.x, burst.y),
        tile * burst.radius * 0.42,
        crispAlpha,
      );
    }
  }

  static void paintTypedBurst(
    Canvas canvas,
    SpatialBurst burst,
    double tile,
    Offset Function(double, double) centerAt,
  ) {
    final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
    final c = centerAt(burst.x, burst.y);
    final r = tile * burst.radius * (0.78 + (1 - alpha) * 0.32);
    final color = Color(burst.argb);
    final ink = _strokeC(
      const Color(0xE6100C08).withValues(alpha: alpha),
      math.max(3.4, tile * 0.13),
      cap: StrokeCap.round,
    );
    final ramp = _rampForBurst(burst, color);
    switch (burst.kind) {
      case SpatialBurstKind.beam:
        final end = burst.x2 != null && burst.y2 != null
            ? centerAt(burst.x2!, burst.y2!)
            : Offset(c.dx, c.dy - r * 2.4);
        _paintZigBeam(canvas, c, end, r, alpha, ramp, ink, tile, burst.paintId);
      case SpatialBurstKind.rain:
        if (burst.paintId == AbilityId.meteor) {
          _paintMeteorStrike(canvas, c, r, alpha, ramp, tile);
        } else if (burst.paintId == AbilityId.healingSurge) {
          _paintWaterSwirl(canvas, c, r, alpha, ramp, tile);
        } else {
          _paintRain(canvas, c, r, alpha, ramp, tile);
        }
      case SpatialBurstKind.shards:
        _paintShards(canvas, c, r, alpha, ramp);
      case SpatialBurstKind.flame:
        _paintFlamePetals(canvas, c, r, alpha, ramp);
      case SpatialBurstKind.cross:
        _paintCross(canvas, c, r, alpha, ramp, ink, tile);
      case SpatialBurstKind.poison:
        _paintPoisonDrips(canvas, c, r, alpha, ramp);
      case SpatialBurstKind.skull:
        _paintShadowSwirl(canvas, c, r, alpha, ramp, tile);
      case SpatialBurstKind.summon:
        _paintSummonRise(canvas, c, r, alpha, ramp, tile, burst.paintId);
      case SpatialBurstKind.pillar:
        _paintLightPillar(canvas, c, r, alpha, ramp, tile, burst.paintId);
      default:
        break;
    }
    SpellVfxLayers.impactSparks(canvas, c, r * 0.55, ramp, alpha * 0.85);
  }

  static SpellSchoolRamp _rampForBurst(SpatialBurst burst, Color fallback) {
    if (burst.paintId != null) {
      final def = ClassKits.defFor(burst.paintId!);
      if (def != null) {
        return SpellSchoolRamp.forStyle(def.boltStyle ?? SpellBoltStyle.weapon);
      }
    }
    return SpellSchoolRamp.forStyle(_styleFromArgb(fallback));
  }

  static SpellBoltStyle _styleFromArgb(Color c) {
    final v = c.toARGB32();
    if (v & 0x00FF0000 > 0x00C00000) return SpellBoltStyle.fire;
    if (v & 0x0000FFFF > 0x0000C0C0) return SpellBoltStyle.frost;
    if (v & 0x00FF00FF > 0x00C000C0) return SpellBoltStyle.arcane;
    if (v & 0x00FFFFFF > 0x00F0F0E0) return SpellBoltStyle.holy;
    return SpellBoltStyle.shadow;
  }

  static void paintGroundDisc(
    Canvas canvas,
    Offset c,
    double r,
    Color color,
    double frac,
    double tile,
    SpatialGroundFxKind kind,
    double life,
  ) {
    switch (kind) {
      case SpatialGroundFxKind.holy:
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset(c.dx + math.cos(a) * r * 0.2, c.dy + math.sin(a) * r * 0.2),
            Offset(c.dx + math.cos(a) * r * 0.92, c.dy + math.sin(a) * r * 0.92),
            _strokeC(
              const Color(0xAAFFF6C0).withValues(alpha: 0.55 * frac),
              math.max(1.2, tile * 0.045),
              cap: StrokeCap.round,
            ),
          );
        }
        canvas.drawCircle(
          c,
          r * 0.38,
          _strokeC(
            const Color(0x66FFF0A0).withValues(alpha: 0.45 * frac),
            math.max(1.4, tile * 0.05),
          ),
        );
      case SpatialGroundFxKind.frost:
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + life * 0.4;
          final p = _path
            ..reset()
            ..moveTo(c.dx + math.cos(a) * r * 0.25, c.dy + math.sin(a) * r * 0.25)
            ..lineTo(c.dx + math.cos(a) * r * 0.88, c.dy + math.sin(a) * r * 0.88)
            ..lineTo(c.dx + math.cos(a + 0.22) * r * 0.55, c.dy + math.sin(a + 0.22) * r * 0.55)
            ..close();
          canvas.drawPath(p, _fillC(const Color(0x88C8F0FF).withValues(alpha: 0.45 * frac)));
        }
      case SpatialGroundFxKind.fire:
        for (var i = 0; i < 4; i++) {
          final a = i * 1.7 + life;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(
                c.dx + math.cos(a) * r * 0.35,
                c.dy + math.sin(a) * r * 0.28,
              ),
              width: r * 0.55,
              height: r * 0.38,
            ),
            _fillC(const Color(0x66FF5018).withValues(alpha: 0.4 * frac)),
          );
        }
      case SpatialGroundFxKind.nature:
        for (var i = 0; i < 5; i++) {
          final a = i * 1.26 + 0.3;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(
                c.dx + math.cos(a) * r * 0.55,
                c.dy + math.sin(a) * r * 0.55,
              ),
              width: r * 0.28,
              height: r * 0.16,
            ),
            _fillC(const Color(0x882EAA55).withValues(alpha: 0.5 * frac)),
          );
        }
      case SpatialGroundFxKind.shadow:
        canvas.drawCircle(c, r * 0.55, _fillC(const Color(0x55201040).withValues(alpha: 0.5 * frac)));
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.72),
          life,
          2.2,
          false,
          _strokeC(
            const Color(0xAA9050D0).withValues(alpha: 0.55 * frac),
            math.max(2, tile * 0.07),
            cap: StrokeCap.round,
          ),
        );
      case SpatialGroundFxKind.disc:
        canvas.drawCircle(
          c,
          r * 0.85,
          _strokeC(color.withValues(alpha: 0.55 * frac), math.max(1.8, tile * 0.06)),
        );
      default:
        canvas.drawCircle(c, r * 0.5, _fillC(color.withValues(alpha: 0.35 * frac)));
    }
  }

  /// Mid-animation preview tile for ability contact sheets.
  static void paintAbilityShowcase(
    Canvas canvas, {
    required Rect tileRect,
    required ClassAbilityDef def,
    double life = 0.28,
  }) {
    final id = def.id;
    final tile = tileRect.width / 3.2;
    final cx = tileRect.center.dx;
    final cy = tileRect.center.dy - tile * 0.15;
    Offset at(double tx, double ty) => Offset(cx + tx * tile, cy + ty * tile);
    final style = def.boltStyle ?? SpellBoltStyle.weapon;
    final argb = SpatialCombat.burstArgbForStyle(style);
    final kind = SpellVfx.burstKindFor(
      style: style,
      shape: def.aoeShape,
      id: id,
    );
    final travelBeam = _showcaseWantsBeamTravel(id, kind);
    AbilityShowcaseMotion.paintPhase(
      canvas,
      tileRect: tileRect,
      def: def,
      life: life / 0.95,
    );
    final burst = SpatialBurst(
      x: 0,
      y: 0,
      life: life,
      argb: argb,
      radius: 0.95,
      kind: kind,
      angle: kind == SpatialBurstKind.cone ? -math.pi / 2 : null,
      x2: travelBeam ? 0 : null,
      y2: travelBeam ? -2.4 : null,
      crisp: SpellVfx.isBig(id),
      paintId: id,
    );
    paintWorldBurst(canvas, burst, tile, at);

    if (id == AbilityId.meteor) {
      paintGroundDisc(
        canvas,
        at(0, 0.62),
        tile * 1.25,
        const Color(0xFF5A2818),
        0.82,
        tile,
        SpatialGroundFxKind.fire,
        1.6,
      );
    }

    if (def.vfx?.groundDisc == true) {
      final gkind = SpellVfx.groundKindFor(style: style, id: id);
      paintGroundDisc(
        canvas,
        at(0, 0.55),
        tile * 1.1,
        Color(def.vfx?.groundArgb ?? argb),
        0.75,
        tile,
        gkind,
        1.2,
      );
    }

    if (id == AbilityId.entanglingRoots) {
      _paintVineTendrils(canvas, at(0, 0.35), tile * 1.35, 0.85);
    }

    if (_showcaseWantsTravelBolt(def)) {
      _paintShowcaseBolt(
        canvas,
        center: Offset(cx + tile * 0.55, cy),
        label: def.shortLabel,
        style: style,
        color: Color(argb),
        tile: tile,
      );
    }
  }

  /// Test hook: contact-sheet traveling bolts (not in-fight floaters).
  @visibleForTesting
  static bool showcaseWantsTravelBolt(ClassAbilityDef def) =>
      _showcaseWantsTravelBolt(def);

  static bool hasCustomBoltLabel(String? label) => _hasCustomBoltLabel(label);

  static bool _showcaseWantsBeamTravel(AbilityId id, SpatialBurstKind kind) {
    if (kind != SpatialBurstKind.beam) return false;
    return switch (id) {
      AbilityId.arcaneBarrage ||
      AbilityId.crashLightning ||
      AbilityId.bindingShot ||
      AbilityId.harpoonSurvival ||
      AbilityId.killShotMm ||
      AbilityId.killShotBm ||
      AbilityId.starsurge ||
      AbilityId.armsCharge =>
        true,
      _ => false,
    };
  }

  static bool _hasCustomBoltLabel(String? label) => switch (label) {
        'Barrage' ||
        'SWD' ||
        'Surge' ||
        'HFire' ||
        'SFire' ||
        'FOrb' ||
        'KillSh' ||
        'Cone' ||
        'Breath' ||
        'Prism' ||
        'Meteor' ||
        'Claw' ||
        'Crash' ||
        'Chain' ||
        'Bind' ||
        'Harp' ||
        'WBomb' ||
        'Stamp' ||
        'Infer' ||
        'Star' ||
        'Roots' ||
        'ERW' ||
        'Chrg' ||
        'Barrie' =>
          true,
        _ => false,
      };

  static bool _showcaseWantsTravelBolt(ClassAbilityDef def) {
    if (def.effect != AbilityEffectKind.damage &&
        def.effect != AbilityEffectKind.aoe) {
      return false;
    }
    if (def.boltStyle == SpellBoltStyle.weapon) return false;
    final kind = SpellVfx.burstKindFor(
      style: def.boltStyle ?? SpellBoltStyle.weapon,
      shape: def.aoeShape,
      id: def.id,
    );
    if (kind == SpatialBurstKind.slash ||
        kind == SpatialBurstKind.ring ||
        kind == SpatialBurstKind.summon ||
        kind == SpatialBurstKind.leaf) {
      return false;
    }
    return _hasCustomBoltLabel(def.shortLabel);
  }

  /// Non-orb traveling shapes keyed by HUD shortLabel. Paint-only.
  static bool paintCustomTravelingBolt(
    Canvas canvas, {
    required String? label,
    required SpellBoltStyle style,
    required Color color,
    required double thick,
    required double len,
    required double angle,
    required bool showTrails,
  }) {
    if (label == null) return false;
    final custom = switch (label) {
      'Barrage' => _BoltShape.arcaneDarts,
      'SWD' => _BoltShape.shadowSpike,
      'Surge' => _BoltShape.starLance,
      'HFire' => _BoltShape.holyPillar,
      'SFire' => _BoltShape.felComet,
      'FOrb' => _BoltShape.frostOrb,
      'KillSh' => _BoltShape.pierceArrow,
      'Cone' => _BoltShape.frostCone,
      'Breath' => _BoltShape.dragonBreath,
      'Prism' => _BoltShape.crystalShell,
      'Meteor' => _BoltShape.fallingMeteor,
      'Claw' => _BoltShape.clawRake,
      'Crash' => _BoltShape.lightningFork,
      'Chain' => _BoltShape.lightningFork,
      'Bind' => _BoltShape.bindingShackle,
      'Harp' => _BoltShape.harpoonSpear,
      'WBomb' => _BoltShape.incendiaryGlob,
      'Stamp' => _BoltShape.stampedeTracks,
      'Infer' => _BoltShape.infernalChunk,
      'Star' => _BoltShape.starLance,
      'Roots' => _BoltShape.vineLash,
      'ERW' => _BoltShape.runeAxeGlow,
      'Chrg' => _BoltShape.chargeWedge,
      'Barrie' => _BoltShape.holyWall,
      _ => null,
    };
    if (custom == null) return false;
    canvas.save();
    canvas.rotate(angle);
    switch (custom) {
      case _BoltShape.arcaneDarts:
        for (var i = 0; i < 3; i++) {
          final ox = -len * 0.35 + i * len * 0.22;
          final p = _path
            ..reset()
            ..moveTo(ox + thick * 0.4, 0)
            ..lineTo(ox + len * 0.35, -thick * 0.55)
            ..lineTo(ox + len * 0.55, 0)
            ..lineTo(ox + len * 0.35, thick * 0.55)
            ..close();
          canvas.drawPath(p, _fillC(color.withValues(alpha: 0.92)));
        }
      case _BoltShape.shadowSpike:
        final p = _path
          ..reset()
          ..moveTo(len * 0.45, 0)
          ..lineTo(-len * 0.2, -thick * 1.2)
          ..lineTo(-len * 0.05, 0)
          ..lineTo(-len * 0.2, thick * 1.2)
          ..close();
        canvas.drawPath(p, _fillC(const Color(0xFF100C08).withValues(alpha: 0.85)));
        canvas.drawPath(p, _fillC(color));
      case _BoltShape.starLance:
        canvas.drawLine(
          Offset(-len * 0.5, 0),
          Offset(len * 0.55, 0),
          _strokeC(color, thick * 0.55, cap: StrokeCap.round),
        );
        for (var s = -1; s <= 1; s += 2) {
          canvas.drawLine(
            Offset(len * 0.15, s * thick * 0.15),
            Offset(len * 0.45, s * thick * 0.65),
            _strokeC(Colors.white.withValues(alpha: 0.9), thick * 0.22),
          );
        }
      case _BoltShape.holyPillar:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: thick * 1.1, height: len * 1.1),
            Radius.circular(thick * 0.35),
          ),
          _fillC(color.withValues(alpha: 0.75)),
        );
        canvas.drawLine(
          Offset(0, -len * 0.55),
          Offset(0, len * 0.35),
          _strokeC(Colors.white, thick * 0.35, cap: StrokeCap.round),
        );
      case _BoltShape.felComet:
        final head = _path
          ..reset()
          ..moveTo(len * 0.5, 0)
          ..lineTo(-len * 0.3, -thick * 0.9)
          ..lineTo(-len * 0.15, 0)
          ..lineTo(-len * 0.3, thick * 0.9)
          ..close();
        canvas.drawPath(head, _fillC(color));
        canvas.drawPath(
          _path
            ..reset()
            ..moveTo(-len * 0.55, 0)
            ..lineTo(-len * 0.95, -thick * 0.35)
            ..lineTo(-len * 0.7, 0)
            ..lineTo(-len * 0.95, thick * 0.35)
            ..close(),
          _fillC(const Color(0xAA70FF40).withValues(alpha: 0.7)),
        );
      case _BoltShape.frostOrb:
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          canvas.drawLine(
            Offset.zero,
            Offset(math.cos(a) * thick * 1.35, math.sin(a) * thick * 1.35),
            _strokeC(color, thick * 0.28, cap: StrokeCap.round),
          );
        }
        canvas.drawCircle(Offset.zero, thick * 0.45, _fillC(Colors.white.withValues(alpha: 0.85)));
      case _BoltShape.pierceArrow:
        canvas.drawLine(
          Offset(-len * 0.65, 0),
          Offset(len * 0.55, 0),
          _strokeC(const Color(0xFF8A6230), thick * 0.55, cap: StrokeCap.round),
        );
        final head = _path
          ..reset()
          ..moveTo(len * 0.55, 0)
          ..lineTo(len * 0.2, -thick * 0.9)
          ..lineTo(len * 0.28, 0)
          ..lineTo(len * 0.2, thick * 0.9)
          ..close();
        canvas.drawPath(head, _fillC(Colors.white.withValues(alpha: 0.95)));
        canvas.drawLine(
          Offset(-len * 0.15, 0),
          Offset(len * 0.5, 0),
          _strokeC(color, thick * 0.35, cap: StrokeCap.round),
        );
      case _BoltShape.frostCone:
        final wedge = _path
          ..reset()
          ..moveTo(-len * 0.35, 0)
          ..lineTo(len * 0.45, -thick * 1.5)
          ..lineTo(len * 0.45, thick * 1.5)
          ..close();
        canvas.drawPath(wedge, _fillC(color.withValues(alpha: 0.55)));
      case _BoltShape.dragonBreath:
        final wedge = _path
          ..reset()
          ..moveTo(-len * 0.4, 0)
          ..quadraticBezierTo(len * 0.1, -thick * 1.6, len * 0.55, -thick * 0.35)
          ..lineTo(len * 0.55, thick * 0.35)
          ..quadraticBezierTo(len * 0.1, thick * 1.6, -len * 0.4, 0)
          ..close();
        canvas.drawPath(wedge, _fillC(color.withValues(alpha: 0.65)));
      case _BoltShape.crystalShell:
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          canvas.drawLine(
            Offset(math.cos(a) * thick * 0.5, math.sin(a) * thick * 0.5),
            Offset(math.cos(a) * thick * 1.25, math.sin(a) * thick * 1.25),
            _strokeC(color, thick * 0.25, cap: StrokeCap.round),
          );
        }
      case _BoltShape.fallingMeteor:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(len * 0.1, -thick * 0.5),
            width: thick * 2.2,
            height: thick * 1.6,
          ),
          _fillC(const Color(0xFFFF4010)),
        );
        for (var i = 0; i < 5; i++) {
          canvas.drawLine(
            Offset(-len * 0.25, thick * (0.3 + i * 0.22)),
            Offset(len * 0.45, thick * (1.0 + i * 0.22)),
            _strokeC(const Color(0xFFFF8040).withValues(alpha: 0.8 - i * 0.12), thick * 0.18),
          );
        }
      case _BoltShape.clawRake:
        for (var i = -1; i <= 1; i++) {
          canvas.drawLine(
            Offset(-len * 0.1, i * thick * 0.35),
            Offset(len * 0.45, i * thick * 0.85),
            _strokeC(color, thick * 0.35, cap: StrokeCap.round),
          );
        }
      case _BoltShape.lightningFork:
        final zig = _path
          ..reset()
          ..moveTo(-len * 0.5, thick * 0.2)
          ..lineTo(len * 0.15, -thick * 0.9)
          ..lineTo(-len * 0.05, 0)
          ..lineTo(len * 0.45, thick * 0.55);
        canvas.drawPath(zig, _strokeC(color, thick * 0.55, cap: StrokeCap.round));
        canvas.drawPath(zig, _strokeC(Colors.white, thick * 0.22, cap: StrokeCap.round));
      case _BoltShape.bindingShackle:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(len * 0.1, 0), width: thick * 2.6, height: thick * 2.6),
          -0.3,
          2.0,
          false,
          _strokeC(color, thick * 0.65, cap: StrokeCap.round),
        );
        canvas.drawLine(
          Offset(-len * 0.35, thick * 0.55),
          Offset(len * 0.35, -thick * 0.55),
          _strokeC(Colors.white.withValues(alpha: 0.85), thick * 0.35),
        );
      case _BoltShape.harpoonSpear:
        canvas.drawLine(
          Offset(-len * 0.65, 0),
          Offset(len * 0.4, 0),
          _strokeC(const Color(0xFF8A6230), thick * 0.55, cap: StrokeCap.round),
        );
        final barb = _path
          ..reset()
          ..moveTo(len * 0.48, 0)
          ..lineTo(len * 0.25, -thick * 1.35)
          ..lineTo(len * 0.32, 0)
          ..lineTo(len * 0.25, thick * 1.35)
          ..close();
        canvas.drawPath(barb, _fillC(color));
      case _BoltShape.incendiaryGlob:
        canvas.drawOval(
          Rect.fromCenter(center: Offset(len * 0.15, 0), width: thick * 2.4, height: thick * 1.9),
          _fillC(color),
        );
        canvas.drawPath(
          _path
            ..reset()
            ..moveTo(-len * 0.55, thick * 0.15)
            ..quadraticBezierTo(-len * 0.75, thick * 0.85, -len * 0.35, thick * 0.55)
            ..lineTo(-len * 0.55, thick * 0.15),
          _fillC(const Color(0xCCFF6010).withValues(alpha: 0.75)),
        );
      case _BoltShape.stampedeTracks:
        for (var t = 0; t < 4; t++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(-len * 0.35 + t * len * 0.22, thick * (0.35 - t * 0.15)),
              width: thick * 0.85,
              height: thick * 0.45,
            ),
            _fillC(const Color(0xFF6A5040).withValues(alpha: 0.85)),
          );
        }
      case _BoltShape.infernalChunk:
        canvas.drawOval(
          Rect.fromCenter(center: Offset(len * 0.05, -thick * 0.25), width: thick * 2.5, height: thick * 2.0),
          _fillC(const Color(0xFF402018)),
        );
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(
            Offset(-len * 0.1, thick * (0.2 + i * 0.28)),
            Offset(len * 0.55, thick * (0.8 + i * 0.22)),
            _strokeC(const Color(0xFFFF5020).withValues(alpha: 0.75), thick * 0.22),
          );
        }
      case _BoltShape.vineLash:
        final vine = _path
          ..reset()
          ..moveTo(-len * 0.45, thick * 0.2)
          ..quadraticBezierTo(len * 0.05, -thick * 1.3, len * 0.55, thick * 0.4);
        canvas.drawPath(vine, _strokeC(color, thick * 0.45, cap: StrokeCap.round));
        for (var i = 0; i < 3; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(-len * 0.15 + i * len * 0.22, -thick * (0.2 + i * 0.35)),
              width: thick * 0.65,
              height: thick * 0.35,
            ),
            _fillC(const Color(0xFF2EAA55).withValues(alpha: 0.9)),
          );
        }
      case _BoltShape.runeAxeGlow:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: thick * 1.6, height: len * 0.95),
            Radius.circular(thick * 0.25),
          ),
          _fillC(const Color(0xFFB8F0FF).withValues(alpha: 0.65)),
        );
        canvas.drawLine(
          Offset(-len * 0.2, 0),
          Offset(len * 0.35, 0),
          _strokeC(color, thick * 0.55, cap: StrokeCap.round),
        );
      case _BoltShape.chargeWedge:
        final wedge = _path
          ..reset()
          ..moveTo(-len * 0.5, 0)
          ..lineTo(len * 0.45, -thick * 1.25)
          ..lineTo(len * 0.45, thick * 1.25)
          ..close();
        canvas.drawPath(wedge, _fillC(color.withValues(alpha: 0.7)));
      case _BoltShape.holyWall:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(len * 0.05, 0), width: thick * 1.8, height: len * 1.15),
            Radius.circular(thick * 0.2),
          ),
          _fillC(color.withValues(alpha: 0.55)),
        );
        canvas.drawLine(
          Offset(0, -len * 0.45),
          Offset(0, len * 0.45),
          _strokeC(Colors.white.withValues(alpha: 0.85), thick * 0.35, cap: StrokeCap.round),
        );
    }
    canvas.restore();
    return true;
  }

  static void _paintShowcaseBolt(
    Canvas canvas, {
    required Offset center,
    required String label,
    required SpellBoltStyle style,
    required Color color,
    required double tile,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final thick = math.max(3.0, tile * 0.11);
    final len = tile * 1.15;
    if (!paintCustomTravelingBolt(
      canvas,
      label: label,
      style: style,
      color: color,
      thick: thick,
      len: len,
      angle: 0,
      showTrails: true,
    )) {
      SpellBoltStylePaint.drawStyleBolt(
        canvas,
        style: style,
        color: color,
        thick: thick,
        len: len,
        showTrails: true,
      );
    }
    canvas.restore();
  }

  // —— burst helpers ——

  static void _paintSlash(
    Canvas canvas,
    SpatialBurst burst,
    double tile,
    Offset Function(double, double) centerAt,
  ) {
    final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
    final c = centerAt(burst.x, burst.y);
    final sweep = 1.45;
    final start = (burst.angle ?? (burst.life * 9)) - sweep * 0.5;
    final r = tile * burst.radius * (0.75 + (1 - alpha) * 0.4);
    final rect = Rect.fromCircle(center: c, radius: r);
    final sweepDraw = sweep * alpha.clamp(0.45, 1.0);
    canvas.drawArc(rect, start, sweepDraw, false, _strokeC(const Color(0xE6100C08).withValues(alpha: alpha), math.max(5.5, tile * 0.32), cap: StrokeCap.round));
    canvas.drawArc(rect, start, sweepDraw, false, _strokeC(Color(burst.argb).withValues(alpha: alpha), math.max(3.2, tile * 0.2), cap: StrokeCap.round));
  }

  static void _paintRing(
    Canvas canvas,
    SpatialBurst burst,
    double tile,
    Offset Function(double, double) centerAt,
  ) {
    final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
    final c = centerAt(burst.x, burst.y);
    final r = tile * burst.radius * (0.55 + (1 - alpha) * 0.7);
    final ramp = _rampForBurst(burst, Color(burst.argb));
    SpellVfxLayers.softGlow(canvas, c, r, ramp, alpha * 0.55);
    for (var i = 0; i < 3; i++) {
      final rr = r * (0.92 - i * 0.14);
      canvas.drawCircle(
        c,
        rr,
        _strokeC(ramp.lerp(0.2 + i * 0.25).withValues(alpha: alpha * (0.95 - i * 0.15)), math.max(3.6 - i * 0.6, tile * 0.11)),
      );
    }
    canvas.drawCircle(c, r * 0.35, _fillC(ramp.hot.withValues(alpha: alpha * 0.75)));
  }

  static void _paintCone(
    Canvas canvas,
    SpatialBurst burst,
    double tile,
    Offset Function(double, double) centerAt,
  ) {
    final alpha = (burst.life / 0.45).clamp(0.0, 1.0);
    final c = centerAt(burst.x, burst.y);
    final r = tile * burst.radius * (0.85 + (1 - alpha) * 0.35);
    final sweep = burst.paintId == AbilityId.lightOfDawn ? 1.35 : 1.15;
    final start = burst.angle! - sweep * 0.5;
    final ramp = _rampForBurst(burst, Color(burst.argb));
    final path = _path
      ..reset()
      ..moveTo(c.dx, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: r), start, sweep, false)
      ..close();
    final fill = burst.paintId == AbilityId.lightOfDawn
        ? ramp.bright.withValues(alpha: alpha * 0.55)
        : Color(burst.argb).withValues(alpha: alpha * 0.45);
    canvas.drawPath(path, _fillC(fill));
    canvas.drawPath(path, _strokeC(ramp.hot.withValues(alpha: alpha * 0.92), math.max(2.4, tile * 0.1)));
    if (burst.paintId == AbilityId.lightOfDawn) {
      for (var wave = 0; wave < 3; wave++) {
        final wr = r * (0.55 + wave * 0.22);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: wr),
          start + 0.08,
          sweep - 0.16,
          false,
          _strokeC(
            ramp.light.withValues(alpha: alpha * (0.85 - wave * 0.2)),
            math.max(2.0, tile * 0.07),
            cap: StrokeCap.round,
          ),
        );
      }
    }
  }

  static void _paintLeaf(
    Canvas canvas,
    SpatialBurst burst,
    double tile,
    Offset Function(double, double) centerAt,
  ) {
    final alpha = (burst.life / 0.5).clamp(0.0, 1.0);
    final c = centerAt(burst.x, burst.y);
    final r = tile * burst.radius * (0.55 + alpha * 0.35);
    if (burst.paintId == AbilityId.innervateDruid) {
      _paintManaLeafRain(canvas, c, r, alpha, tile);
      return;
    }
    for (var i = 0; i < 5; i++) {
      final a = i * 1.26 + burst.life * 2;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx + math.cos(a) * r * 0.7, c.dy + math.sin(a) * r * 0.7),
          width: r * 0.55,
          height: r * 0.28,
        ),
        _fillC(Color(burst.argb).withValues(alpha: alpha * 0.9)),
      );
    }
  }

  static void _paintSpark(
    Canvas canvas,
    SpatialBurst burst,
    double tile,
    Offset Function(double, double) centerAt,
  ) {
    final alpha = (burst.life / 0.5).clamp(0.0, 1.0);
    final c = centerAt(burst.x, burst.y);
    final r = tile * burst.radius * (0.4 + alpha * 0.4);
    canvas.drawCircle(c, r, _fillC(Color(burst.argb).withValues(alpha: alpha * 0.9)));
    canvas.drawCircle(c, r * 0.4, _fillC(Colors.white.withValues(alpha: alpha)));
  }

  static void _paintDiscBurst(
    Canvas canvas,
    SpatialBurst burst,
    double tile,
    Offset Function(double, double) centerAt,
  ) {
    final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
    final c = centerAt(burst.x, burst.y);
    final r = tile * burst.radius * (1.15 - alpha * 0.28);
    canvas.drawCircle(c, r, _fillC(const Color(0xAA100C08).withValues(alpha: alpha * 0.85)));
    canvas.drawCircle(c, r * 0.82, _fillC(Color(burst.argb).withValues(alpha: alpha * 0.7)));
    canvas.drawCircle(c, r * 0.42, _fillC(Colors.white.withValues(alpha: alpha * 0.9)));
  }

  static void _paintZigBeam(
    Canvas canvas,
    Offset c,
    Offset end,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    Paint ink,
    double tile,
    AbilityId? id,
  ) {
    if (id == AbilityId.armsCharge) {
      _paintChargeDustStreak(canvas, c, end, r, alpha, ramp, tile);
      return;
    }
    if (id == AbilityId.killShotMm) {
      _paintPierceShotBeam(canvas, c, end, r, alpha, ramp, ink, tile);
      return;
    }
    final chain = id == AbilityId.arcaneBarrage ||
        id == AbilityId.chainLightning ||
        id == AbilityId.crashLightning ||
        id == AbilityId.bindingShot;
    if (!chain) {
      SpellVfxLayers.taperBeam(canvas, c, end, ramp, alpha, tile);
      return;
    }
    final dx = end.dx - c.dx;
    final dy = end.dy - c.dy;
    final len = math.sqrt(dx * dx + dy * dy) + 0.001;
    final nx = -dy / len;
    final ny = dx / len;
    final zig = _path..reset()..moveTo(c.dx, c.dy);
    for (var i = 1; i <= 5; i++) {
      final t = i / 6;
      final side = (i.isOdd ? 1.0 : -1.0) * r * (chain ? 0.55 : 0.42);
      zig.lineTo(c.dx + dx * t + nx * side, c.dy + dy * t + ny * side);
    }
    zig.lineTo(end.dx, end.dy);
    canvas.drawPath(zig, ink);
    canvas.drawPath(
      zig,
      _strokeC(ramp.bright.withValues(alpha: alpha * 0.95), math.max(2.8, tile * 0.1), cap: StrokeCap.round, join: StrokeJoin.round),
    );
    canvas.drawPath(
      zig,
      _strokeC(ramp.hot.withValues(alpha: alpha * 0.9), math.max(1.2, tile * 0.045), cap: StrokeCap.round, join: StrokeJoin.round),
    );
    if (chain) {
      for (var b = 0; b < 3; b++) {
        final t = 0.25 + b * 0.22;
        final px = c.dx + dx * t;
        final py = c.dy + dy * t;
        canvas.drawLine(
          Offset(px, py),
          Offset(px + nx * r * 0.35, py + ny * r * 0.35),
          _strokeC(ramp.light.withValues(alpha: alpha * 0.8), math.max(1.6, tile * 0.05), cap: StrokeCap.round),
        );
      }
    }
    canvas.drawCircle(end, r * 0.38, _fillC(ramp.hot.withValues(alpha: alpha)));
  }

  static void _paintRain(
    Canvas canvas,
    Offset c,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    double tile,
  ) {
    SpellVfxLayers.softGlow(canvas, c, r * 0.85, ramp, alpha * 0.35);
    for (var i = 0; i < 9; i++) {
      final a = i * 0.74;
      final ox = math.cos(a) * r * 0.8;
      final oy = math.sin(a) * r * 0.35;
      final fall = (1 - alpha) * r * 0.85;
      final trail = Offset(c.dx + ox - r * 0.08, c.dy + oy - r * 0.55 + fall);
      final tip = Offset(c.dx + ox, c.dy + oy - r * 1.15 + fall);
      canvas.drawLine(trail, tip, _strokeC(ramp.ink.withValues(alpha: alpha * 0.7), math.max(2.8, tile * 0.09), cap: StrokeCap.round));
      canvas.drawLine(trail, tip, _strokeC(ramp.light.withValues(alpha: alpha * 0.92), math.max(1.4, tile * 0.05), cap: StrokeCap.round));
      canvas.drawCircle(tip, math.max(1.5, tile * 0.05), _fillC(ramp.bright.withValues(alpha: alpha)));
    }
  }

  static void _paintMeteorStrike(
    Canvas canvas,
    Offset c,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    double tile,
  ) {
    final rockCenter = Offset(c.dx - r * 0.12, c.dy - r * 0.95);
    final rock = _path
      ..reset()
      ..moveTo(rockCenter.dx - r * 0.42, rockCenter.dy + r * 0.18)
      ..lineTo(rockCenter.dx - r * 0.08, rockCenter.dy - r * 0.38)
      ..lineTo(rockCenter.dx + r * 0.35, rockCenter.dy - r * 0.2)
      ..lineTo(rockCenter.dx + r * 0.48, rockCenter.dy + r * 0.25)
      ..lineTo(rockCenter.dx + r * 0.05, rockCenter.dy + r * 0.42)
      ..close();
    canvas.drawPath(rock, _fillC(const Color(0xFF3A2820).withValues(alpha: alpha)));
    canvas.drawPath(rock, _strokeC(const Color(0xFF9A7868).withValues(alpha: alpha * 0.9), math.max(2.4, tile * 0.08)));
    for (var i = 0; i < 7; i++) {
      final t = i / 6.0;
      final tail = Offset(c.dx - r * (0.15 + t * 0.55), c.dy - r * (0.35 + t * 1.45));
      final tip = Offset(c.dx - r * (0.05 + t * 0.35), c.dy - r * (0.65 + t * 1.65));
      canvas.drawLine(
        tail,
        tip,
        _strokeC(
          Color.lerp(const Color(0xFFFF6020), const Color(0xFFFFE060), t)!.withValues(alpha: alpha * (0.95 - t * 0.25)),
          math.max(2.6 - t * 0.8, tile * 0.07),
          cap: StrokeCap.round,
        ),
      );
    }
    canvas.drawCircle(c, r * 0.42, _fillC(ramp.hot.withValues(alpha: alpha * 0.65)));
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        c,
        Offset(c.dx + math.cos(a) * r * 0.78, c.dy + math.sin(a) * r * 0.32),
        _strokeC(const Color(0xFF5A2818).withValues(alpha: alpha * 0.75), math.max(1.8, tile * 0.06), cap: StrokeCap.round),
      );
    }
    canvas.drawCircle(
      c,
      r * 0.88,
      _strokeC(const Color(0x88FF4818).withValues(alpha: alpha * 0.55), math.max(2.2, tile * 0.07)),
    );
  }

  static void _paintShards(
    Canvas canvas,
    Offset c,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
  ) {
    SpellVfxLayers.softGlow(canvas, c, r, ramp, alpha * 0.4);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + (1 - alpha) * 0.4;
      final p = _path
        ..reset()
        ..moveTo(c.dx + math.cos(a) * r * 1.25, c.dy + math.sin(a) * r * 1.25)
        ..lineTo(c.dx + math.cos(a + 0.28) * r * 0.22, c.dy + math.sin(a + 0.28) * r * 0.22)
        ..lineTo(c.dx + math.cos(a - 0.28) * r * 0.22, c.dy + math.sin(a - 0.28) * r * 0.22)
        ..close();
      canvas.drawPath(p, _fillC(ramp.ink.withValues(alpha: alpha * 0.75)));
      canvas.drawPath(p, _fillC(ramp.lerp(0.35 + i * 0.08).withValues(alpha: alpha)));
      canvas.drawPath(p, _strokeC(ramp.hot.withValues(alpha: alpha * 0.65), math.max(1.2, r * 0.04)));
    }
  }

  static void _paintFlamePetals(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp) {
    SpellVfxLayers.softGlow(canvas, c, r, ramp, alpha * 0.55);
    for (var i = 0; i < 5; i++) {
      final a = -1.15 + i * 0.55 + (1 - alpha) * 0.2;
      final lift = r * 0.35 * (1 - alpha);
      final p = _path
        ..reset()
        ..moveTo(c.dx, c.dy + r * 0.15)
        ..quadraticBezierTo(
          c.dx + math.cos(a + 0.35) * r * 0.45,
          c.dy + math.sin(a + 0.35) * r * 0.45 - lift,
          c.dx + math.cos(a) * r * 1.2,
          c.dy + math.sin(a) * r * 1.2 - lift,
        )
        ..quadraticBezierTo(
          c.dx + math.cos(a - 0.35) * r * 0.45,
          c.dy + math.sin(a - 0.35) * r * 0.45 - lift,
          c.dx,
          c.dy + r * 0.15,
        );
      canvas.drawPath(p, _fillC(ramp.mid.withValues(alpha: alpha * 0.75)));
      canvas.drawPath(p, _fillC(ramp.bright.withValues(alpha: alpha * 0.92)));
    }
  }

  static void _paintCross(
    Canvas canvas,
    Offset c,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    Paint ink,
    double tile,
  ) {
    final arm = r * 1.15;
    SpellVfxLayers.softGlow(canvas, c, arm, ramp, alpha * 0.45);
    canvas.drawLine(Offset(c.dx, c.dy - arm), Offset(c.dx, c.dy + arm * 0.55), ink);
    canvas.drawLine(Offset(c.dx - arm * 0.75, c.dy - arm * 0.12), Offset(c.dx + arm * 0.75, c.dy - arm * 0.12), ink);
    final mid = _strokeC(ramp.mid.withValues(alpha: alpha * 0.85), math.max(4.0, tile * 0.14), cap: StrokeCap.round);
    final hot = _strokeC(ramp.hot.withValues(alpha: alpha), math.max(2.0, tile * 0.07), cap: StrokeCap.round);
    canvas.drawLine(Offset(c.dx, c.dy - arm), Offset(c.dx, c.dy + arm * 0.55), mid);
    canvas.drawLine(Offset(c.dx - arm * 0.75, c.dy - arm * 0.12), Offset(c.dx + arm * 0.75, c.dy - arm * 0.12), mid);
    canvas.drawLine(Offset(c.dx, c.dy - arm * 0.92), Offset(c.dx, c.dy + arm * 0.35), hot);
    canvas.drawLine(Offset(c.dx - arm * 0.62, c.dy - arm * 0.12), Offset(c.dx + arm * 0.62, c.dy - arm * 0.12), hot);
  }

  static void _paintPoisonDrips(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp) {
    SpellVfxLayers.softGlow(canvas, c, r * 0.75, ramp, alpha * 0.35);
    for (var i = 0; i < 5; i++) {
      final a = -0.4 + i * 0.55;
      final fall = r * 0.45 * (1 - alpha);
      final drip = Offset(c.dx + math.sin(a) * r * 0.55, c.dy + math.cos(a) * r * 0.15 + fall);
      canvas.drawOval(Rect.fromCenter(center: drip, width: r * 0.24, height: r * 0.5), _fillC(ramp.mid.withValues(alpha: alpha * 0.8)));
      canvas.drawOval(Rect.fromCenter(center: drip.translate(0, -r * 0.08), width: r * 0.16, height: r * 0.22), _fillC(ramp.bright.withValues(alpha: alpha * 0.9)));
    }
  }

  static void _paintShadowSwirl(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp, double tile) {
    SpellVfxLayers.softGlow(canvas, c, r, ramp, alpha * 0.55);
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * (0.55 + i * 0.22)),
        -0.4 + i * 0.4,
        2.6,
        false,
        _strokeC(ramp.mid.withValues(alpha: alpha * (0.9 - i * 0.15)), math.max(2.6, tile * 0.1), cap: StrokeCap.round),
      );
    }
    canvas.drawCircle(c, r * 0.25, _fillC(ramp.hot.withValues(alpha: alpha * 0.8)));
  }

  static void _paintLightPillar(
    Canvas canvas,
    Offset c,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    double tile,
    AbilityId? id,
  ) {
    final h = r * 2.6;
    final w = r * 0.55;
    final rect = Rect.fromCenter(center: Offset(c.dx, c.dy - h * 0.15), width: w, height: h);
    SpellVfxLayers.softGlow(canvas, rect.center, h * 0.45, ramp, alpha * 0.65);
    final gradient = ui.Gradient.linear(
      rect.topCenter,
      rect.bottomCenter,
      [
        ramp.hot.withValues(alpha: alpha * 0.15),
        ramp.bright.withValues(alpha: alpha * 0.55),
        ramp.mid.withValues(alpha: alpha * 0.85),
        ramp.hot.withValues(alpha: alpha * 0.35),
      ],
      const [0.0, 0.32, 0.72, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = gradient);
    canvas.drawRect(
      Rect.fromCenter(center: rect.center, width: w * 0.35, height: h * 0.92),
      Paint()..color = ramp.hot.withValues(alpha: alpha * 0.85),
    );
    if (id == AbilityId.soulFireDemo) {
      canvas.drawRect(
        rect.inflate(r * 0.08),
        _strokeC(const Color(0xFF70FF40).withValues(alpha: alpha * 0.45), math.max(1.4, tile * 0.05)),
      );
    }
    if (id == AbilityId.darkTransformation) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.55), width: r * 1.35, height: r * 0.42),
        _fillC(const Color(0x6638FF68).withValues(alpha: alpha * 0.55)),
      );
      for (var i = 0; i < 6; i++) {
        final a = i * 1.05;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(c.dx + math.cos(a) * r * 0.42, c.dy + math.sin(a) * r * 0.18 + r * 0.52),
            width: r * 0.22,
            height: r * 0.14,
          ),
          _fillC(const Color(0xAA70FF90).withValues(alpha: alpha * 0.7)),
        );
      }
    }
  }

  static void _paintAbilityOverlay(
    Canvas canvas,
    SpatialBurst burst,
    double tile,
    Offset Function(double, double) centerAt,
  ) {
    final id = burst.paintId!;
    final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
    final c = centerAt(burst.x, burst.y);
    final r = tile * burst.radius * (0.85 + (1 - alpha) * 0.25);
    final ramp = _rampForBurst(burst, Color(burst.argb));
    switch (id) {
      case AbilityId.colossusSmash:
        _paintGroundShockCracks(canvas, c, r, alpha, tile);
      case AbilityId.claw:
        _paintClawRakes(canvas, c, r, alpha, ramp, tile);
      case AbilityId.executeFury:
        _paintImpactStar(canvas, c, r * 0.65, alpha, ramp, tile);
        _paintBloodSplatter(canvas, c, r, alpha);
      case AbilityId.kidneyShotAssa:
      case AbilityId.maim:
        _paintStunStars(canvas, c, r, alpha, tile);
        _paintImpactStar(canvas, c, r * 0.55, alpha, ramp, tile);
      case AbilityId.adrenalineRush:
        _paintSpeedAura(canvas, c, r, alpha, tile);
      case AbilityId.revealingStrike:
        _paintImpactStar(canvas, c, r * 0.75, alpha, ramp, tile);
      case AbilityId.secretTechnique:
        _paintShadowCloneSlashes(canvas, c, r, alpha, tile);
      case AbilityId.hammerOfJusticeHoly:
      case AbilityId.hammerOfJusticeRet:
        _paintFallingHammer(canvas, c, r, alpha, ramp, tile);
      case AbilityId.wordOfGloryProt:
      case AbilityId.wordOfGloryRet:
        _paintRisingGlyph(canvas, c, r, alpha, ramp, tile);
      case AbilityId.prayerOfMendingHoly:
        _paintBouncingFeather(canvas, c, r, alpha, tile);
      case AbilityId.soulReaper:
        _paintScytheArc(canvas, c, r, alpha, ramp, tile);
      case AbilityId.darkSoul:
        _paintOrbitingSouls(canvas, c, r, alpha, tile);
      case AbilityId.howlOfTerror:
        _paintScreamRing(canvas, c, r, alpha, tile);
      case AbilityId.healingTideTotem:
        _paintTotemRipple(canvas, c, r, alpha, const Color(0xFF60C8F0));
      case AbilityId.earthbindTotem:
        _paintTotemRipple(canvas, c, r, alpha, const Color(0xFF8A7058));
      case AbilityId.manaTideTotem:
        _paintTotemRipple(canvas, c, r, alpha, const Color(0xFFB070F0));
      case AbilityId.dieByTheSword:
        _paintCrossedBlades(canvas, c, r, alpha, ramp, tile);
      case AbilityId.piercingHowl:
        _paintSonicRings(canvas, c, r, alpha, tile);
      case AbilityId.ardentDefender:
        _paintWingShield(canvas, c, r, alpha, ramp, tile);
      case AbilityId.consecrationRet:
        _paintHolyGroundFlame(canvas, c, r, alpha, tile);
      case AbilityId.stampede:
        _paintHoofDust(canvas, c, r, alpha, tile);
      case AbilityId.killShotBm:
        _paintArrowVolley(canvas, c, r, alpha, tile);
      case AbilityId.bindingShot:
        _paintBindingRoots(canvas, c, r, alpha, tile);
      case AbilityId.wildfireBomb:
        _paintFireBombBloom(canvas, c, r, alpha, ramp, tile);
      case AbilityId.harpoonSurvival:
        _paintHarpoonLine(canvas, c, r, alpha, tile);
      case AbilityId.crimsonVial:
        _paintCrimsonMist(canvas, c, r, alpha, tile);
      case AbilityId.halo:
        _paintRadiantHalo(canvas, c, r, alpha, ramp, tile);
      case AbilityId.shadowfiendDisc:
      case AbilityId.shadowfiendShadow:
        _paintShadowRift(canvas, c, r, alpha, tile);
      case AbilityId.holyWordSanctify:
        _paintSanctifyDisk(canvas, c, r, alpha, ramp, tile);
      case AbilityId.shadowWordDeath:
        _paintDeathSpikeGlyph(canvas, c, r, alpha, tile);
      case AbilityId.frozenOrb:
        _paintFrozenOrb(canvas, c, r, alpha, tile);
      case AbilityId.breathOfSindragosa:
        _paintFrostBreathCone(canvas, c, r, alpha, tile);
      case AbilityId.empowerRuneWeapon:
        _paintRuneWeaponGlow(canvas, c, r, alpha, tile);
      case AbilityId.darkTransformation:
        _paintUnholyPulse(canvas, c, r, alpha, tile);
      case AbilityId.fireElemental:
        _paintFireCoreRise(canvas, c, r, alpha, ramp, tile);
      case AbilityId.crashLightning:
        _paintLightningFork(canvas, c, r, alpha, ramp, tile);
      case AbilityId.healingSurge:
        break;
      case AbilityId.arcaneBarrage:
        _paintArcaneDartFan(canvas, c, r, alpha, ramp, tile);
      case AbilityId.prismaticBarrier:
        _paintPrismShell(canvas, c, r, alpha, tile);
      case AbilityId.evocation:
        _paintEvocationSwirl(canvas, c, r, alpha, ramp, tile);
      case AbilityId.meteor:
        _paintScorchDecal(canvas, c, r, alpha, tile);
      case AbilityId.iceBarrierFrost:
        _paintFrostWallShards(canvas, c, r, alpha, tile);
      case AbilityId.frostMageConeOfCold:
        _paintColdShardFan(canvas, c, r, alpha, tile);
      case AbilityId.callDreadstalkers:
        _paintTwinImpPortals(canvas, c, r, alpha, tile);
      case AbilityId.soulFireDemo:
        _paintFelFlameWash(canvas, c, r, alpha, tile);
      case AbilityId.summonInfernal:
        _paintInfernalGate(canvas, c, r, alpha, tile);
      case AbilityId.shadowburn:
        _paintFelSkullFlame(canvas, c, r, alpha, tile);
      case AbilityId.starsurge:
        _paintStarLance(canvas, c, r, alpha, ramp, tile);
      case AbilityId.forceOfNature:
        _paintRootBurst(canvas, c, r, alpha, tile);
      case AbilityId.ironbark:
        _paintBarkGrowth(canvas, c, r, alpha, tile);
      case AbilityId.innervateDruid:
        break;
      case AbilityId.entanglingRoots:
        break;
      case AbilityId.armsCharge:
      case AbilityId.killShotMm:
        break;
      case AbilityId.holyFire:
        _paintHolyFireEmbers(canvas, c, r, alpha, ramp, tile);
      case AbilityId.powerWordBarrier:
      case AbilityId.lightOfDawn:
        break;
      default:
        break;
    }
  }

  static void _paintGroundShockCracks(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final end = Offset(c.dx + math.cos(a) * r * 1.05, c.dy + math.sin(a) * r * 0.45);
      canvas.drawLine(
        c,
        end,
        _strokeC(const Color(0xFF6A5040).withValues(alpha: alpha * 0.9), math.max(2.6, tile * 0.09), cap: StrokeCap.round),
      );
      canvas.drawLine(
        c,
        end,
        _strokeC(const Color(0xFFFFE0A0).withValues(alpha: alpha * 0.65), math.max(1.2, tile * 0.05), cap: StrokeCap.round),
      );
    }
  }

  static void _paintClawRakes(
    Canvas canvas,
    Offset c,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    double tile,
  ) {
    for (var i = -1; i <= 1; i++) {
      final claw = _path
        ..reset()
        ..moveTo(c.dx - r * 0.15, c.dy + r * 0.35)
        ..quadraticBezierTo(
          c.dx + i * r * 0.22,
          c.dy - r * 0.15,
          c.dx + i * r * 0.55,
          c.dy - r * 0.72,
        );
      canvas.drawPath(claw, _strokeC(ramp.ink.withValues(alpha: alpha), math.max(4.0, tile * 0.15), cap: StrokeCap.round));
      canvas.drawPath(claw, _strokeC(ramp.bright.withValues(alpha: alpha), math.max(2.2, tile * 0.08), cap: StrokeCap.round));
    }
  }

  static void _paintStunStars(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = 0; i < 4; i++) {
      final p = Offset(
        c.dx + math.cos(i * 1.57) * r * 0.62,
        c.dy + math.sin(i * 1.57) * r * 0.45 - r * 0.08,
      );
      for (var s = 0; s < 4; s++) {
        final a = s * math.pi / 2;
        canvas.drawLine(
          p,
          Offset(p.dx + math.cos(a) * r * 0.22, p.dy + math.sin(a) * r * 0.22),
          _strokeC(const Color(0xFFFFF6C0).withValues(alpha: alpha), math.max(2.2, tile * 0.07), cap: StrokeCap.round),
        );
      }
    }
  }

  static void _paintImpactStar(
    Canvas canvas,
    Offset c,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    double tile,
  ) {
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final len = i.isEven ? r : r * 0.45;
      canvas.drawLine(
        c,
        Offset(c.dx + math.cos(a) * len, c.dy + math.sin(a) * len),
        _strokeC(ramp.hot.withValues(alpha: alpha), math.max(2.4, tile * 0.08), cap: StrokeCap.round),
      );
    }
  }

  static void _paintSpeedAura(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = 0; i < 10; i++) {
      final a = -0.4 + i * 0.25;
      final len = r * (0.85 + (i % 3) * 0.15);
      canvas.drawLine(
        Offset(c.dx - len * 0.9, c.dy + math.sin(a) * r * 0.35),
        Offset(c.dx + len * 0.55, c.dy + math.sin(a) * r * 0.15),
        _strokeC(const Color(0xFFFFE040).withValues(alpha: alpha * 0.9), math.max(2.0, tile * 0.07), cap: StrokeCap.round),
      );
    }
  }

  static void _paintShadowCloneSlashes(Canvas canvas, Offset c, double r, double alpha, double tile) {
    final shadow = const Color(0xFF7040B0);
    for (var i = 0; i < 3; i++) {
      final ox = (i - 1) * r * 0.38;
      final arc = Rect.fromCircle(center: Offset(c.dx + ox, c.dy + r * 0.1), radius: r * 0.72);
      canvas.drawArc(
        arc,
        -2.4 + i * 0.15,
        1.35,
        false,
        _strokeC(shadow.withValues(alpha: alpha * (0.95 - i * 0.15)), math.max(3.0, tile * 0.11), cap: StrokeCap.round),
      );
    }
  }

  static void _paintBloodSplatter(Canvas canvas, Offset c, double r, double alpha) {
    for (var i = 0; i < 5; i++) {
      final a = i * 1.25;
      canvas.drawCircle(
        Offset(c.dx + math.cos(a) * r * 0.55, c.dy + math.sin(a) * r * 0.35),
        r * 0.08,
        _fillC(const Color(0xFF901818).withValues(alpha: alpha * 0.85)),
      );
    }
  }

  static void _paintFallingHammer(
    Canvas canvas,
    Offset c,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    double tile,
  ) {
    final head = Rect.fromCenter(
      center: Offset(c.dx, c.dy - r * 0.55),
      width: r * 0.95,
      height: r * 0.42,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(head, Radius.circular(r * 0.08)),
      _fillC(ramp.mid.withValues(alpha: alpha)),
    );
    canvas.drawLine(
      Offset(c.dx, c.dy - r * 0.25),
      Offset(c.dx, c.dy + r * 0.35),
      _strokeC(ramp.ink.withValues(alpha: alpha), math.max(3.0, tile * 0.1), cap: StrokeCap.round),
    );
    _paintStunStars(canvas, c.translate(0, r * 0.25), r * 0.55, alpha, tile);
  }

  static void _paintRisingGlyph(
    Canvas canvas,
    Offset c,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    double tile,
  ) {
    final lift = (1 - alpha) * r * 0.35;
    final glyph = _path
      ..reset()
      ..moveTo(c.dx, c.dy + r * 0.45 - lift)
      ..lineTo(c.dx - r * 0.35, c.dy - r * 0.15 - lift)
      ..lineTo(c.dx, c.dy - r * 0.55 - lift)
      ..lineTo(c.dx + r * 0.35, c.dy - r * 0.15 - lift)
      ..close();
    canvas.drawPath(glyph, _fillC(ramp.bright.withValues(alpha: alpha * 0.85)));
    canvas.drawPath(glyph, _strokeC(ramp.hot.withValues(alpha: alpha), math.max(2.0, tile * 0.07)));
  }

  static void _paintBouncingFeather(Canvas canvas, Offset c, double r, double alpha, double tile) {
    final bounce = math.sin(alpha * math.pi * 2) * r * 0.25;
    final feather = Offset(c.dx + r * 0.15, c.dy - bounce);
    final path = _path
      ..reset()
      ..moveTo(feather.dx, feather.dy + r * 0.25)
      ..quadraticBezierTo(feather.dx - r * 0.35, feather.dy, feather.dx, feather.dy - r * 0.55)
      ..quadraticBezierTo(feather.dx + r * 0.45, feather.dy + r * 0.05, feather.dx, feather.dy + r * 0.25);
    canvas.drawPath(path, _fillC(const Color(0xFFFFF0C0).withValues(alpha: alpha * 0.9)));
    canvas.drawCircle(feather.translate(r * 0.05, -r * 0.1), r * 0.08, _fillC(const Color(0xFFFFE080).withValues(alpha: alpha)));
    canvas.drawPath(path, _strokeC(const Color(0xFFE8C878).withValues(alpha: alpha * 0.7), math.max(1.4, tile * 0.05)));
  }

  static void _paintWaterSwirl(
    Canvas canvas,
    Offset c,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    double tile,
  ) {
    SpellVfxLayers.softGlow(canvas, c, r, ramp, alpha * 0.45);
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * (0.45 + i * 0.22)),
        i * 0.6,
        4.2,
        false,
        _strokeC(const Color(0xFF70D0F8).withValues(alpha: alpha * (0.9 - i * 0.15)), math.max(2.6, tile * 0.09), cap: StrokeCap.round),
      );
    }
  }

  static void _paintScytheArc(
    Canvas canvas,
    Offset c,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    double tile,
  ) {
    canvas.drawArc(
      Rect.fromCircle(center: c.translate(-r * 0.15, r * 0.05), radius: r * 1.05),
      -2.2,
      2.35,
      false,
      _strokeC(ramp.ink.withValues(alpha: alpha), math.max(5.0, tile * 0.16), cap: StrokeCap.round),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c.translate(-r * 0.15, r * 0.05), radius: r * 1.05),
      -2.2,
      2.35,
      false,
      _strokeC(const Color(0xFFB8F0B0).withValues(alpha: alpha * 0.75), math.max(2.2, tile * 0.08), cap: StrokeCap.round),
    );
  }

  static void _paintOrbitingSouls(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = 0; i < 4; i++) {
      final a = i * 1.57 + alpha * 2.2;
      final p = Offset(c.dx + math.cos(a) * r * 0.62, c.dy + math.sin(a) * r * 0.42);
      canvas.drawOval(
        Rect.fromCenter(center: p, width: r * 0.22, height: r * 0.34),
        _fillC(const Color(0xAAE8F0FF).withValues(alpha: alpha * 0.75)),
      );
      canvas.drawCircle(Offset(p.dx, p.dy - r * 0.06), r * 0.05, _fillC(const Color(0xFF90A8C8).withValues(alpha: alpha)));
    }
  }

  static void _paintScreamRing(Canvas canvas, Offset c, double r, double alpha, double tile) {
    canvas.drawCircle(
      c,
      r * 0.78,
      _strokeC(const Color(0xFF6030A0).withValues(alpha: alpha * 0.85), math.max(3.0, tile * 0.1)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 0.55, height: r * 0.32),
      _fillC(const Color(0xFF301050).withValues(alpha: alpha * 0.75)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx - r * 0.18, c.dy - r * 0.05), width: r * 0.12, height: r * 0.16),
      _fillC(const Color(0xFFFFE8F0).withValues(alpha: alpha)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx + r * 0.18, c.dy - r * 0.05), width: r * 0.12, height: r * 0.16),
      _fillC(const Color(0xFFFFE8F0).withValues(alpha: alpha)),
    );
    final mouth = _path
      ..reset()
      ..moveTo(c.dx - r * 0.2, c.dy + r * 0.08)
      ..quadraticBezierTo(c.dx, c.dy + r * 0.28, c.dx + r * 0.2, c.dy + r * 0.08);
    canvas.drawPath(mouth, _strokeC(const Color(0xFFFFB0C0).withValues(alpha: alpha), math.max(2.0, tile * 0.07), cap: StrokeCap.round));
  }

  static void _paintTotemRipple(Canvas canvas, Offset c, double r, double alpha, Color tint) {
    canvas.drawLine(
      Offset(c.dx, c.dy - r * 0.45),
      Offset(c.dx, c.dy + r * 0.55),
      _strokeC(tint.withValues(alpha: alpha * 0.55), math.max(2.0, r * 0.05)),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.45), width: r * (0.55 + i * 0.28), height: r * (0.14 + i * 0.06)),
        _strokeC(tint.withValues(alpha: alpha * (0.75 - i * 0.2)), math.max(1.6, r * 0.04)),
      );
    }
  }

  static void _paintManaLeafRain(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = 0; i < 12; i++) {
      final fall = (1 - alpha) * r * 0.55 + i * r * 0.04;
      final p = Offset(c.dx + math.sin(i * 1.1) * r * 0.65, c.dy - r * 0.25 + fall);
      canvas.drawOval(
        Rect.fromCenter(center: p, width: r * 0.14, height: r * 0.22),
        _fillC(const Color(0xFF78D070).withValues(alpha: alpha * 0.9)),
      );
      canvas.drawCircle(Offset(p.dx, p.dy - r * 0.18), r * 0.05, _fillC(const Color(0xFFB8F0B8).withValues(alpha: alpha * 0.8)));
    }
  }

  static void _paintChargeDustStreak(
    Canvas canvas,
    Offset c,
    Offset end,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    double tile,
  ) {
    final dx = end.dx - c.dx;
    final dy = end.dy - c.dy;
    for (var i = 0; i < 6; i++) {
      final t = i / 5.0;
      final p = Offset(c.dx + dx * t, c.dy + dy * t + math.sin(t * 5) * r * 0.12);
      canvas.drawOval(
        Rect.fromCenter(center: p, width: r * 0.35, height: r * 0.16),
        _fillC(const Color(0x88C8B098).withValues(alpha: alpha * (0.65 - t * 0.25))),
      );
    }
    canvas.drawLine(
      c,
      end,
      _strokeC(ramp.mid.withValues(alpha: alpha * 0.85), math.max(4.0, tile * 0.14), cap: StrokeCap.round),
    );
  }

  static void _paintPierceShotBeam(
    Canvas canvas,
    Offset c,
    Offset end,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    Paint ink,
    double tile,
  ) {
    canvas.drawLine(c, end, ink);
    canvas.drawLine(
      c,
      end,
      _strokeC(ramp.mid.withValues(alpha: alpha), math.max(3.2, tile * 0.11), cap: StrokeCap.round),
    );
    final dx = end.dx - c.dx;
    final dy = end.dy - c.dy;
    final len = math.sqrt(dx * dx + dy * dy) + 0.001;
    final ux = dx / len;
    final uy = dy / len;
    final tip = Offset(end.dx + ux * r * 0.35, end.dy + uy * r * 0.35);
    final head = _path
      ..reset()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(end.dx - uy * r * 0.22, end.dy + ux * r * 0.22)
      ..lineTo(end.dx + uy * r * 0.22, end.dy - ux * r * 0.22)
      ..close();
    canvas.drawPath(head, _fillC(ramp.bright.withValues(alpha: alpha)));
    _paintImpactStar(canvas, end, r * 0.35, alpha, ramp, tile);
  }

  static void _paintCrossedBlades(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp, double tile) {
    for (final side in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(c.dx - side * r * 0.55, c.dy + r * 0.35),
        Offset(c.dx + side * r * 0.15, c.dy - r * 0.55),
        _strokeC(ramp.mid.withValues(alpha: alpha), math.max(3.6, tile * 0.12), cap: StrokeCap.round),
      );
    }
    canvas.drawCircle(c, r * 0.28, _strokeC(ramp.hot.withValues(alpha: alpha * 0.75), math.max(2.0, tile * 0.07)));
  }

  static void _paintSonicRings(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = 0; i < 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * (1.1 + i * 0.35), height: r * (0.45 + i * 0.12)),
        _strokeC(const Color(0xFF6090C0).withValues(alpha: alpha * (0.85 - i * 0.22)), math.max(2.4, tile * 0.08)),
      );
    }
  }

  static void _paintWingShield(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp, double tile) {
    final wing = _path
      ..reset()
      ..moveTo(c.dx - r * 0.15, c.dy + r * 0.25)
      ..quadraticBezierTo(c.dx - r * 0.95, c.dy - r * 0.15, c.dx - r * 0.35, c.dy - r * 0.65)
      ..lineTo(c.dx + r * 0.35, c.dy - r * 0.65)
      ..quadraticBezierTo(c.dx + r * 0.95, c.dy - r * 0.15, c.dx + r * 0.15, c.dy + r * 0.25)
      ..close();
    canvas.drawPath(wing, _fillC(ramp.light.withValues(alpha: alpha * 0.45)));
    canvas.drawPath(wing, _strokeC(ramp.bright.withValues(alpha: alpha), math.max(2.2, tile * 0.08)));
  }

  static void _paintHolyGroundFlame(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawLine(
        c,
        Offset(c.dx + math.cos(a) * r * 0.75, c.dy + math.sin(a) * r * 0.35),
        _strokeC(const Color(0xFFFFA040).withValues(alpha: alpha * 0.8), math.max(1.8, tile * 0.06), cap: StrokeCap.round),
      );
    }
    canvas.drawOval(Rect.fromCenter(center: c.translate(0, r * 0.2), width: r * 1.05, height: r * 0.28), _fillC(const Color(0x66FF6820).withValues(alpha: alpha * 0.65)));
  }

  static void _paintHoofDust(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = 0; i < 4; i++) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx - r * 0.55 + i * r * 0.28, c.dy + r * 0.35), width: r * 0.35, height: r * 0.12),
        _fillC(const Color(0x88A89880).withValues(alpha: alpha * (0.75 - i * 0.12))),
      );
    }
  }

  static void _paintArrowVolley(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = 0; i < 5; i++) {
      final ox = (i - 2) * r * 0.22;
      final top = Offset(c.dx + ox, c.dy - r * 0.85);
      final bot = Offset(c.dx + ox * 0.5, c.dy + r * 0.15);
      canvas.drawLine(top, bot, _strokeC(const Color(0xFFD8C8A8).withValues(alpha: alpha), math.max(2.0, tile * 0.07), cap: StrokeCap.round));
      canvas.drawLine(bot, Offset(bot.dx - r * 0.08, bot.dy + r * 0.12), _strokeC(const Color(0xFF8A7048).withValues(alpha: alpha), math.max(1.4, tile * 0.05)));
    }
  }

  static void _paintBindingRoots(Canvas canvas, Offset c, double r, double alpha, double tile) {
    canvas.drawCircle(c, r * 0.55, _strokeC(const Color(0xFF88C060).withValues(alpha: alpha * 0.85), math.max(2.4, tile * 0.08)));
    for (var i = 0; i < 4; i++) {
      final a = i * 1.57;
      canvas.drawLine(c, Offset(c.dx + math.cos(a) * r * 0.72, c.dy + math.sin(a) * r * 0.72), _strokeC(const Color(0xFF5A9038).withValues(alpha: alpha), math.max(1.6, tile * 0.05), cap: StrokeCap.round));
    }
  }

  static void _paintFireBombBloom(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp, double tile) {
    canvas.drawCircle(c, r * 0.25, _fillC(const Color(0xFF4A2818).withValues(alpha: alpha)));
    for (var i = 0; i < 5; i++) {
      final a = i * 1.26 - 0.6;
      final petal = _path
        ..reset()
        ..moveTo(c.dx, c.dy)
        ..quadraticBezierTo(
          c.dx + math.cos(a + 0.3) * r * 0.55,
          c.dy + math.sin(a + 0.3) * r * 0.55 - r * 0.05,
          c.dx + math.cos(a) * r * 0.95,
          c.dy + math.sin(a) * r * 0.55,
        )
        ..quadraticBezierTo(
          c.dx + math.cos(a - 0.3) * r * 0.55,
          c.dy + math.sin(a - 0.3) * r * 0.55 + r * 0.05,
          c.dx,
          c.dy,
        );
      canvas.drawPath(petal, _fillC(ramp.mid.withValues(alpha: alpha * 0.75)));
    }
  }

  static void _paintHarpoonLine(Canvas canvas, Offset c, double r, double alpha, double tile) {
    canvas.drawLine(Offset(c.dx - r * 0.85, c.dy + r * 0.25), Offset(c.dx + r * 0.35, c.dy - r * 0.15), _strokeC(const Color(0xFFA8B8C8).withValues(alpha: alpha), math.max(2.2, tile * 0.08), cap: StrokeCap.round));
    canvas.drawCircle(Offset(c.dx + r * 0.35, c.dy - r * 0.15), r * 0.12, _fillC(const Color(0xFF708898).withValues(alpha: alpha)));
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + r * 0.55, c.dy + r * 0.35), width: r * 0.45, height: r * 0.18), _fillC(const Color(0x6688D0F0).withValues(alpha: alpha * 0.75)));
  }

  static void _paintCrimsonMist(Canvas canvas, Offset c, double r, double alpha, double tile) {
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - r * 0.15), width: r * 0.28, height: r * 0.55), _fillC(const Color(0xFFB02030).withValues(alpha: alpha * 0.85)));
    for (var i = 0; i < 6; i++) {
      final p = Offset(c.dx + math.sin(i * 1.2) * r * 0.45, c.dy + math.cos(i) * r * 0.25);
      canvas.drawCircle(p, r * 0.09, _fillC(const Color(0x66FF3040).withValues(alpha: alpha)));
    }
  }

  static void _paintRadiantHalo(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp, double tile) {
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.78), -math.pi, math.pi, false, _strokeC(ramp.bright.withValues(alpha: alpha), math.max(3.0, tile * 0.1), cap: StrokeCap.round));
    for (var i = 0; i < 8; i++) {
      final a = -math.pi + i * math.pi / 4;
      canvas.drawLine(Offset(c.dx + math.cos(a) * r * 0.55, c.dy + math.sin(a) * r * 0.55), Offset(c.dx + math.cos(a) * r * 0.95, c.dy + math.sin(a) * r * 0.35), _strokeC(ramp.light.withValues(alpha: alpha * 0.75), math.max(1.4, tile * 0.05), cap: StrokeCap.round));
    }
  }

  static void _paintShadowRift(Canvas canvas, Offset c, double r, double alpha, double tile) {
    final rift = _path
      ..reset()
      ..moveTo(c.dx - r * 0.12, c.dy + r * 0.55)
      ..lineTo(c.dx - r * 0.35, c.dy - r * 0.15)
      ..lineTo(c.dx + r * 0.08, c.dy - r * 0.55)
      ..lineTo(c.dx + r * 0.32, c.dy + r * 0.12)
      ..close();
    canvas.drawPath(rift, _fillC(const Color(0xCC281050).withValues(alpha: alpha * 0.9)));
    canvas.drawPath(rift, _strokeC(const Color(0xAA9040E0).withValues(alpha: alpha), math.max(1.6, tile * 0.06)));
  }

  static void _paintSanctifyDisk(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp, double tile) {
    canvas.drawCircle(c, r * 0.62, _strokeC(ramp.bright.withValues(alpha: alpha * 0.85), math.max(2.4, tile * 0.08)));
    canvas.drawCircle(c, r * 0.32, _fillC(ramp.light.withValues(alpha: alpha * 0.35)));
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawLine(c, Offset(c.dx + math.cos(a) * r * 0.45, c.dy + math.sin(a) * r * 0.45), _strokeC(ramp.hot.withValues(alpha: alpha * 0.65), math.max(1.2, tile * 0.04)));
    }
  }

  static void _paintDeathSpikeGlyph(Canvas canvas, Offset c, double r, double alpha, double tile) {
    final spike = _path..reset()..moveTo(c.dx, c.dy - r * 0.75)..lineTo(c.dx + r * 0.22, c.dy + r * 0.35)..lineTo(c.dx - r * 0.22, c.dy + r * 0.35)..close();
    canvas.drawPath(spike, _fillC(const Color(0xFF381850).withValues(alpha: alpha)));
    canvas.drawPath(spike, _strokeC(const Color(0xFFB070E0).withValues(alpha: alpha), math.max(2.0, tile * 0.07)));
  }

  static void _paintFrozenOrb(Canvas canvas, Offset c, double r, double alpha, double tile) {
    canvas.drawCircle(c, r * 0.42, _fillC(const Color(0xFF9AD8F8).withValues(alpha: alpha * 0.85)));
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * (0.55 + i * 0.18)), alpha * 3 + i, 1.8, false, _strokeC(const Color(0xFFD0F0FF).withValues(alpha: alpha), math.max(1.4, tile * 0.05), cap: StrokeCap.round));
    }
  }

  static void _paintFrostBreathCone(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(Offset(c.dx, c.dy + r * 0.2), Offset(c.dx + (i - 2) * r * 0.25, c.dy - r * 0.75), _strokeC(const Color(0xFFB0E8FF).withValues(alpha: alpha * (0.9 - i * 0.12)), math.max(2.0, tile * 0.07), cap: StrokeCap.round));
    }
  }

  static void _paintRuneWeaponGlow(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (final side in [-1.0, 1.0]) {
      canvas.drawLine(Offset(c.dx - side * r * 0.12, c.dy + r * 0.4), Offset(c.dx - side * r * 0.42, c.dy - r * 0.55), _strokeC(const Color(0xFF80E8FF).withValues(alpha: alpha), math.max(2.8, tile * 0.1), cap: StrokeCap.round));
    }
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.05), r * 0.18, _fillC(const Color(0xFF40D0F0).withValues(alpha: alpha * 0.85)));
  }

  static void _paintUnholyPulse(Canvas canvas, Offset c, double r, double alpha, double tile) {
    canvas.drawCircle(c, r * (0.55 + alpha * 0.25), _strokeC(const Color(0xAA40FF68).withValues(alpha: alpha * 0.65), math.max(2.2, tile * 0.07)));
  }

  static void _paintFireCoreRise(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp, double tile) {
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - r * 0.25), width: r * 0.55, height: r * 0.95), _fillC(ramp.mid.withValues(alpha: alpha * 0.55)));
    SpellVfxLayers.impactSparks(canvas, Offset(c.dx, c.dy - r * 0.55), r * 0.35, ramp, alpha, count: 4);
  }

  static void _paintLightningFork(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp, double tile) {
    final bolt = _path..reset()..moveTo(c.dx - r * 0.15, c.dy - r * 0.65)..lineTo(c.dx + r * 0.08, c.dy - r * 0.05)..lineTo(c.dx - r * 0.05, c.dy + r * 0.35);
    canvas.drawPath(bolt, _strokeC(ramp.hot.withValues(alpha: alpha), math.max(3.2, tile * 0.11), cap: StrokeCap.round, join: StrokeJoin.round));
    canvas.drawPath(bolt, _strokeC(const Color(0xFFE8F0FF).withValues(alpha: alpha * 0.85), math.max(1.2, tile * 0.045), cap: StrokeCap.round, join: StrokeJoin.round));
  }

  static void _paintArcaneDartFan(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp, double tile) {
    for (var i = 0; i < 5; i++) {
      final a = -0.4 + i * 0.2;
      canvas.drawLine(c, Offset(c.dx + math.sin(a) * r * 0.25 + r * 0.55, c.dy + math.cos(a) * r * 0.55 - r * 0.45), _strokeC(ramp.bright.withValues(alpha: alpha), math.max(2.0, tile * 0.07), cap: StrokeCap.round));
    }
  }

  static void _paintPrismShell(Canvas canvas, Offset c, double r, double alpha, double tile) {
    final shell = _path..reset()..moveTo(c.dx, c.dy - r * 0.65)..lineTo(c.dx + r * 0.45, c.dy)..lineTo(c.dx, c.dy + r * 0.65)..lineTo(c.dx - r * 0.45, c.dy)..close();
    canvas.drawPath(shell, _fillC(const Color(0x44D0F0FF).withValues(alpha: alpha)));
    canvas.drawPath(shell, _strokeC(const Color(0xFFB0E8FF).withValues(alpha: alpha), math.max(2.0, tile * 0.07)));
  }

  static void _paintEvocationSwirl(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp, double tile) {
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.65), alpha * 4, 5.5, false, _strokeC(ramp.mid.withValues(alpha: alpha), math.max(2.6, tile * 0.09), cap: StrokeCap.round));
    canvas.drawCircle(c, r * 0.2, _fillC(ramp.hot.withValues(alpha: alpha * 0.85)));
  }

  static void _paintScorchDecal(Canvas canvas, Offset c, double r, double alpha, double tile) {
    canvas.drawOval(Rect.fromCenter(center: c.translate(0, r * 0.35), width: r * 1.05, height: r * 0.32), _strokeC(const Color(0x885A2818).withValues(alpha: alpha * 0.85), math.max(2.0, tile * 0.07)));
  }

  static void _paintFrostWallShards(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = -2; i <= 2; i++) {
      final shard = _path..reset()..moveTo(c.dx + i * r * 0.22, c.dy + r * 0.45)..lineTo(c.dx + i * r * 0.28, c.dy - r * 0.55)..lineTo(c.dx + i * r * 0.14, c.dy - r * 0.15)..close();
      canvas.drawPath(shard, _fillC(const Color(0xAAE0F8FF).withValues(alpha: alpha)));
    }
  }

  static void _paintColdShardFan(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(c, Offset(c.dx + (i - 1.5) * r * 0.32, c.dy - r * 0.75), _strokeC(const Color(0xFFC0F0FF).withValues(alpha: alpha), math.max(2.2, tile * 0.08), cap: StrokeCap.round));
    }
  }

  static void _paintTwinImpPortals(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (final ox in [-0.45, 0.45]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + ox * r, c.dy + r * 0.15), width: r * 0.32, height: r * 0.55), _fillC(const Color(0xAA5020A0).withValues(alpha: alpha * 0.85)));
    }
  }

  static void _paintFelFlameWash(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(Offset(c.dx - r * 0.15, c.dy - r * 0.55 + i * r * 0.2), Offset(c.dx + r * 0.15, c.dy + r * 0.15 + i * r * 0.1), _strokeC(const Color(0xFF70FF40).withValues(alpha: alpha * (0.85 - i * 0.15)), math.max(2.0, tile * 0.07), cap: StrokeCap.round));
    }
  }

  static void _paintInfernalGate(Canvas canvas, Offset c, double r, double alpha, double tile) {
    canvas.drawArc(Rect.fromCircle(center: c.translate(0, r * 0.2), radius: r * 0.75), math.pi, math.pi, false, _strokeC(const Color(0xFFFF5020).withValues(alpha: alpha), math.max(3.0, tile * 0.1), cap: StrokeCap.round));
    canvas.drawOval(Rect.fromCenter(center: c.translate(0, r * 0.35), width: r * 0.55, height: r * 0.22), _fillC(const Color(0x66FF3010).withValues(alpha: alpha * 0.75)));
  }

  static void _paintFelSkullFlame(Canvas canvas, Offset c, double r, double alpha, double tile) {
    canvas.drawCircle(Offset(c.dx, c.dy - r * 0.15), r * 0.28, _fillC(const Color(0xFF301030).withValues(alpha: alpha)));
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.35), width: r * 0.65, height: r * 0.38), _fillC(const Color(0x88FF6020).withValues(alpha: alpha * 0.75)));
  }

  static void _paintStarLance(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp, double tile) {
    canvas.drawLine(Offset(c.dx + r * 0.15, c.dy - r * 0.95), Offset(c.dx + r * 0.15, c.dy + r * 0.15), _strokeC(ramp.bright.withValues(alpha: alpha), math.max(3.0, tile * 0.1), cap: StrokeCap.round));
    _paintImpactStar(canvas, Offset(c.dx + r * 0.15, c.dy - r * 0.55), r * 0.35, alpha, ramp, tile);
  }

  static void _paintRootBurst(Canvas canvas, Offset c, double r, double alpha, double tile) {
    for (var i = -2; i <= 2; i++) {
      final vine = _path..reset()..moveTo(c.dx + i * r * 0.12, c.dy + r * 0.4)..quadraticBezierTo(c.dx + i * r * 0.38, c.dy, c.dx + i * r * 0.25, c.dy - r * 0.55);
      canvas.drawPath(vine, _strokeC(const Color(0xFF3A8840).withValues(alpha: alpha), math.max(2.2, tile * 0.08), cap: StrokeCap.round));
    }
  }

  static void _paintBarkGrowth(Canvas canvas, Offset c, double r, double alpha, double tile) {
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.72), -0.8, 2.8, false, _strokeC(const Color(0xFF6A5038).withValues(alpha: alpha), math.max(3.0, tile * 0.1), cap: StrokeCap.round));
    canvas.drawArc(Rect.fromCircle(center: c.translate(0, r * 0.12), radius: r * 0.55), -0.6, 2.4, false, _strokeC(const Color(0xFF8A6848).withValues(alpha: alpha * 0.85), math.max(2.0, tile * 0.07), cap: StrokeCap.round));
  }

  static void _paintHolyFireEmbers(Canvas canvas, Offset c, double r, double alpha, SpellSchoolRamp ramp, double tile) {
    for (var i = 0; i < 8; i++) {
      final p = Offset(c.dx + math.sin(i * 1.4) * r * 0.22, c.dy - r * 0.55 + i * r * 0.08);
      canvas.drawCircle(p, r * 0.06, _fillC(ramp.bright.withValues(alpha: alpha * (0.95 - i * 0.08))));
    }
  }

  static void _paintSummonRise(
    Canvas canvas,
    Offset c,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    double tile,
    AbilityId? id,
  ) {
    SpellVfxLayers.softGlow(canvas, c, r, ramp, alpha * 0.5);
    final motif = switch (id) {
      AbilityId.shadowfiendDisc || AbilityId.shadowfiendShadow => _SummonMotif.shadowImp,
      AbilityId.healingTideTotem => _SummonMotif.waterTotem,
      AbilityId.earthbindTotem => _SummonMotif.earthTotem,
      AbilityId.manaTideTotem => _SummonMotif.manaTotem,
      AbilityId.fireElemental => _SummonMotif.fireElemental,
      AbilityId.summonInfernal => _SummonMotif.infernal,
      AbilityId.callDreadstalkers => _SummonMotif.felImp,
      AbilityId.forceOfNature => _SummonMotif.treant,
      AbilityId.stampede => _SummonMotif.stampede,
      _ => _SummonMotif.spark,
    };
    _drawSummonMotif(canvas, c, r, alpha, ramp, motif, tile);
  }

  static void _drawSummonMotif(
    Canvas canvas,
    Offset c,
    double r,
    double alpha,
    SpellSchoolRamp ramp,
    _SummonMotif motif,
    double tile,
  ) {
    final ink = ramp.ink.withValues(alpha: alpha);
    final body = ramp.mid.withValues(alpha: alpha);
    final edge = ramp.bright.withValues(alpha: alpha);
    switch (motif) {
      case _SummonMotif.shadowImp:
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.05), width: r * 0.62, height: r * 0.78), _fillC(ink));
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - r * 0.28), width: r * 0.48, height: r * 0.42), _fillC(body));
        canvas.drawCircle(Offset(c.dx - r * 0.12, c.dy - r * 0.32), r * 0.06, _fillC(const Color(0xFFFF6080).withValues(alpha: alpha)));
        canvas.drawCircle(Offset(c.dx + r * 0.12, c.dy - r * 0.32), r * 0.06, _fillC(const Color(0xFFFF6080).withValues(alpha: alpha)));
        for (final horn in [-1.0, 1.0]) {
          canvas.drawLine(
            Offset(c.dx + horn * r * 0.18, c.dy - r * 0.42),
            Offset(c.dx + horn * r * 0.32, c.dy - r * 0.72),
            _strokeC(edge, math.max(1.8, tile * 0.06), cap: StrokeCap.round),
          );
        }
        final wing = _path
          ..reset()
          ..moveTo(c.dx - r * 0.22, c.dy - r * 0.05)
          ..lineTo(c.dx - r * 0.72, c.dy - r * 0.42)
          ..lineTo(c.dx - r * 0.28, c.dy + r * 0.18);
        canvas.drawPath(wing, _fillC(ramp.shadowMid(alpha)));
        canvas.drawPath(
          _path
            ..reset()
            ..moveTo(c.dx + r * 0.22, c.dy - r * 0.05)
            ..lineTo(c.dx + r * 0.72, c.dy - r * 0.42)
            ..lineTo(c.dx + r * 0.28, c.dy + r * 0.18),
          _fillC(ramp.shadowMid(alpha)),
        );
        canvas.drawLine(
          Offset(c.dx, c.dy + r * 0.32),
          Offset(c.dx + r * 0.35, c.dy + r * 0.62),
          _strokeC(edge, math.max(1.4, tile * 0.05), cap: StrokeCap.round),
        );
      case _SummonMotif.waterTotem:
        canvas.drawRect(Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.05), width: r * 0.22, height: r * 0.95), _fillC(const Color(0xFF5088A8).withValues(alpha: alpha)));
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - r * 0.38), width: r * 0.55, height: r * 0.28), _fillC(const Color(0xFF70D0F8).withValues(alpha: alpha)));
        _paintTotemRipple(canvas, c.translate(0, r * 0.15), r, alpha, const Color(0xFF60C8F0));
      case _SummonMotif.earthTotem:
        canvas.drawRect(Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.05), width: r * 0.32, height: r * 0.92), _fillC(const Color(0xFF6A5848).withValues(alpha: alpha)));
        for (var i = -1; i <= 1; i++) {
          canvas.drawLine(
            Offset(c.dx + i * r * 0.22, c.dy + r * 0.38),
            Offset(c.dx + i * r * 0.42, c.dy + r * 0.72),
            _strokeC(const Color(0xFF4A3828).withValues(alpha: alpha), math.max(1.6, tile * 0.05), cap: StrokeCap.round),
          );
        }
      case _SummonMotif.manaTotem:
        canvas.drawRect(Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.05), width: r * 0.24, height: r * 0.88), _fillC(const Color(0xFF504070).withValues(alpha: alpha)));
        final crystal = _path
          ..reset()
          ..moveTo(c.dx, c.dy - r * 0.62)
          ..lineTo(c.dx + r * 0.28, c.dy - r * 0.18)
          ..lineTo(c.dx, c.dy + r * 0.12)
          ..lineTo(c.dx - r * 0.28, c.dy - r * 0.18)
          ..close();
        canvas.drawPath(crystal, _fillC(const Color(0xFFB070F0).withValues(alpha: alpha)));
        for (var i = 0; i < 4; i++) {
          final a = i * 1.57;
          canvas.drawCircle(
            Offset(c.dx + math.cos(a) * r * 0.35, c.dy - r * 0.05 + math.sin(a) * r * 0.25),
            r * 0.06,
            _fillC(const Color(0xFFE8C0FF).withValues(alpha: alpha)),
          );
        }
      case _SummonMotif.fireElemental:
        canvas.drawOval(Rect.fromCenter(center: c, width: r * 1.1, height: r * 1.45), _fillC(body));
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - r * 0.62), width: r * 0.75, height: r * 0.62), _fillC(edge));
        for (var i = -1; i <= 1; i++) {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(c.dx + i * r * 0.42, c.dy + r * 0.55), width: r * 0.35, height: r * 0.22),
            _fillC(ramp.bright.withValues(alpha: alpha * 0.8)),
          );
        }
      case _SummonMotif.infernal:
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.25), width: r * 1.35, height: r * 1.05), _fillC(const Color(0xFF301810).withValues(alpha: alpha)));
        final horn = _path
          ..reset()
          ..moveTo(c.dx - r * 0.35, c.dy - r * 0.35)
          ..lineTo(c.dx - r * 0.55, c.dy - r * 0.95)
          ..lineTo(c.dx - r * 0.15, c.dy - r * 0.45);
        canvas.drawPath(horn, _fillC(const Color(0xFF6A3820).withValues(alpha: alpha)));
        canvas.drawPath(horn, _strokeC(const Color(0xFFFF5820).withValues(alpha: alpha * 0.85), math.max(1.6, tile * 0.05)));
        canvas.drawPath(
          _path
            ..reset()
            ..moveTo(c.dx + r * 0.35, c.dy - r * 0.35)
            ..lineTo(c.dx + r * 0.55, c.dy - r * 0.95)
            ..lineTo(c.dx + r * 0.15, c.dy - r * 0.45),
          _fillC(const Color(0xFF6A3820).withValues(alpha: alpha)),
        );
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(
            Offset(c.dx - r * 0.5 + i * r * 0.28, c.dy + r * 0.45),
            Offset(c.dx - r * 0.2 + i * r * 0.32, c.dy + r * 0.95),
            _strokeC(const Color(0xFFFF4010).withValues(alpha: alpha * 0.75), math.max(1.5, tile * 0.05)),
          );
        }
      case _SummonMotif.felImp:
        canvas.drawOval(Rect.fromCenter(center: c, width: r * 0.75, height: r * 0.95), _fillC(body));
        final wing = _path
          ..reset()
          ..moveTo(c.dx - r * 0.25, c.dy - r * 0.1)
          ..lineTo(c.dx - r * 0.85, c.dy - r * 0.35)
          ..lineTo(c.dx - r * 0.35, c.dy + r * 0.2);
        canvas.drawPath(wing, _fillC(ramp.shadowMid(alpha)));
        canvas.drawPath(
          _path
            ..reset()
            ..moveTo(c.dx + r * 0.25, c.dy - r * 0.1)
            ..lineTo(c.dx + r * 0.85, c.dy - r * 0.35)
            ..lineTo(c.dx + r * 0.35, c.dy + r * 0.2),
          _fillC(ramp.shadowMid(alpha)),
        );
        canvas.drawLine(Offset(c.dx, c.dy - r * 0.52), Offset(c.dx, c.dy - r * 0.82), _strokeC(edge, math.max(1.2, tile * 0.05)));
      case _SummonMotif.treant:
        canvas.drawRect(Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.1), width: r * 0.55, height: r * 1.05), _fillC(const Color(0xFF4A3020).withValues(alpha: alpha)));
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - r * 0.42), width: r * 1.2, height: r * 0.95), _fillC(body));
        for (var i = -2; i <= 2; i++) {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(c.dx + i * r * 0.28, c.dy - r * 0.65), width: r * 0.42, height: r * 0.28),
            _fillC(edge),
          );
        }
      case _SummonMotif.stampede:
        for (var i = 0; i < 3; i++) {
          final ox = (i - 1) * r * 0.55;
          canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + ox, c.dy + r * 0.15), width: r * 0.85, height: r * 0.55), _fillC(const Color(0xFF6A5040).withValues(alpha: alpha)));
          canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + ox + r * 0.25, c.dy - r * 0.25), width: r * 0.55, height: r * 0.45), _fillC(const Color(0xFF8A7058).withValues(alpha: alpha)));
        }
      case _SummonMotif.spark:
        canvas.drawCircle(c, r * 0.45, _fillC(edge));
    }
  }

  static void _paintDomeShell(
    Canvas canvas,
    SpatialBurst burst,
    double tile,
    Offset Function(double, double) centerAt,
  ) {
    final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
    final c = centerAt(burst.x, burst.y);
    final r = tile * burst.radius * 1.05;
    final ramp = _rampForBurst(burst, Color(burst.argb));
    final dome = _path
      ..reset()
      ..addArc(Rect.fromCircle(center: c.translate(0, r * 0.15), radius: r), math.pi, math.pi);
    canvas.drawPath(dome, _fillC(ramp.light.withValues(alpha: alpha * 0.22)));
    canvas.drawPath(dome, _strokeC(ramp.bright.withValues(alpha: alpha * 0.85), math.max(2.4, tile * 0.09)));
    canvas.drawPath(dome, _strokeC(ramp.hot.withValues(alpha: alpha * 0.55), math.max(1.0, tile * 0.04)));
  }

  static void _paintVineTendrils(Canvas canvas, Offset c, double r, double alpha) {
    for (var i = 0; i < 4; i++) {
      final vine = _path
        ..reset()
        ..moveTo(c.dx + (i - 2) * r * 0.18, c.dy + r * 0.35)
        ..quadraticBezierTo(
          c.dx + (i - 1.5) * r * 0.42,
          c.dy - r * 0.15,
          c.dx + (i - 1) * r * 0.55,
          c.dy - r * 0.55,
        );
      canvas.drawPath(vine, _strokeC(const Color(0xFF2E6A38).withValues(alpha: alpha * 0.9), math.max(2.2, r * 0.06), cap: StrokeCap.round));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx + (i - 1) * r * 0.5, c.dy - r * 0.58), width: r * 0.22, height: r * 0.14),
        _fillC(const Color(0xFF78D070).withValues(alpha: alpha)),
      );
    }
  }
}

enum _SummonMotif {
  shadowImp,
  waterTotem,
  earthTotem,
  manaTotem,
  fireElemental,
  infernal,
  felImp,
  treant,
  stampede,
  spark,
}

extension on SpellSchoolRamp {
  Color shadowMid(double alpha) => Color.lerp(mid, rim, 0.35)!.withValues(alpha: alpha);
}

enum _BoltShape {
  arcaneDarts,
  shadowSpike,
  starLance,
  holyPillar,
  felComet,
  frostOrb,
  pierceArrow,
  frostCone,
  dragonBreath,
  crystalShell,
  fallingMeteor,
  clawRake,
  lightningFork,
  bindingShackle,
  harpoonSpear,
  incendiaryGlob,
  stampedeTracks,
  infernalChunk,
  vineLash,
  runeAxeGlow,
  chargeWedge,
  holyWall,
}

/// Fallback bolt silhouettes by school when no custom shortLabel applies.
abstract final class SpellBoltStylePaint {
  static void drawStyleBolt(
    Canvas canvas, {
    required SpellBoltStyle style,
    required Color color,
    required double thick,
    required double len,
    required bool showTrails,
  }) {
    switch (style) {
      case SpellBoltStyle.lightning:
        final zig = Path()
          ..moveTo(-len * 0.55, -thick * 0.2)
          ..lineTo(-len * 0.1, thick * 0.9)
          ..lineTo(len * 0.05, -thick * 0.6)
          ..lineTo(len * 0.55, thick * 0.15);
        canvas.drawPath(zig, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = thick * 1.6..strokeCap = StrokeCap.round);
        canvas.drawPath(zig, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = thick * 0.55..strokeCap = StrokeCap.round);
      case SpellBoltStyle.arrow:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-len * 0.65, -thick * 0.28, len * 1.05, thick * 0.56),
            Radius.circular(thick * 0.2),
          ),
          Paint()..color = const Color(0xFF8A6230),
        );
        final head = Path()
          ..moveTo(len * 0.55, 0)
          ..lineTo(len * 0.15, -thick * 1.05)
          ..lineTo(len * 0.2, 0)
          ..lineTo(len * 0.15, thick * 1.05)
          ..close();
        canvas.drawPath(head, Paint()..color = const Color(0xFFD0D4D8));
      case SpellBoltStyle.frost:
        final ice = Path()
          ..moveTo(len * 0.55, 0)
          ..lineTo(-len * 0.35, -thick * 1.1)
          ..lineTo(-len * 0.15, 0)
          ..lineTo(-len * 0.35, thick * 1.1)
          ..close();
        canvas.drawPath(ice, Paint()..color = color);
      case SpellBoltStyle.weapon:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-len * 0.35, -thick * 0.55, len * 0.75, thick * 1.1),
            Radius.circular(thick * 0.45),
          ),
          Paint()..color = color,
        );
      default:
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: thick * 2.1, height: thick * 1.6),
          Paint()..color = color,
        );
    }
  }
}