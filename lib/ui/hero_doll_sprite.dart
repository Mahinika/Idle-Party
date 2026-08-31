import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/hero.dart';
import '../visual/anchor_table.dart';
import '../visual/body_family.dart';
import '../visual/character_visual_painter.dart';
import '../visual/hero_anim_state.dart';
import 'decoded_image_cache.dart';
import 'hero_paper_doll.dart';
import 'kenney_assets.dart';
import 'kenney_sprite.dart';

/// GEAR / HUD hero preview: denser owned body + anchored gear overlays.
///
/// Falls back to class PNG (+ overlays when atlas is ready), then plain
/// [KenneySprite] if decode fails.
class HeroDollSprite extends StatefulWidget {
  const HeroDollSprite({
    super.key,
    required this.hero,
    this.partyIndex = 0,
    this.size = 32,
    this.walkFrame = 0,
  });

  final PartyHero hero;
  final int partyIndex;
  final double size;

  /// Reserved for future walk-frame previews (dungeon HUD idle for now).
  final int walkFrame;

  @override
  State<HeroDollSprite> createState() => _HeroDollSpriteState();
}

class _HeroDollSpriteState extends State<HeroDollSprite> {
  ui.Image? _body;
  ui.Image? _fallback;
  ui.Image? _atlas;
  String? _fallbackPath;
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant HeroDollSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hero.id != widget.hero.id ||
        oldWidget.hero.specId != widget.hero.specId ||
        oldWidget.hero.gearAffinity != widget.hero.gearAffinity ||
        !_sameEquipKeys(oldWidget.hero, widget.hero)) {
      _reload();
    }
  }

  static bool _sameEquipKeys(PartyHero a, PartyHero b) {
    if (a.equipped.length != b.equipped.length) return false;
    for (final e in a.equipped.entries) {
      if (b.equipped[e.key]?.id != e.value.id) return false;
    }
    return true;
  }

  Future<void> _reload() async {
    final gen = ++_loadGen;
    final bodyPath =
        BodyFamilyCatalog.assetFor(widget.hero, HeroAnimKind.idle);
    final fallbackPath = KenneyAssets.heroSpriteForSpec(widget.hero.specId);
    final decodeW = (widget.size * 3).ceil().clamp(64, 256);

    ui.Image? body;
    ui.Image? fallback;
    ui.Image? atlas;
    try {
      body = await DecodedImageCache.load(bodyPath, targetWidth: decodeW);
    } catch (_) {}
    try {
      fallback =
          await DecodedImageCache.load(fallbackPath, targetWidth: decodeW);
    } catch (_) {}
    try {
      atlas = await DecodedImageCache.load(RoguelikeCharAtlas.assetPath);
    } catch (_) {}

    if (!mounted || gen != _loadGen) return;
    setState(() {
      _body = body;
      _fallback = fallback;
      _atlas = atlas;
      _fallbackPath = fallbackPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final alive = widget.hero.currentHp > 0;
    final body = _body;
    final atlas = _atlas;
    final fallback = _fallback;

    Widget child;
    if (body != null || (fallback != null && atlas != null)) {
      child = CustomPaint(
        size: Size.square(widget.size),
        painter: _HeroDollPainter(
          body: body,
          fallback: body == null ? fallback : null,
          atlas: atlas,
          hero: widget.hero,
          partyIndex: widget.partyIndex,
          tint: body == null
              ? KenneyAssets.heroTintForSpec(widget.hero.specId)
              : null,
        ),
      );
    } else {
      // Still loading or decode failed — plain class PNG.
      final asset = _fallbackPath ??
          KenneyAssets.heroSpriteForSpec(widget.hero.specId);
      final tint = KenneyAssets.heroTintForSpec(widget.hero.specId);
      Widget sprite = KenneySprite(asset: asset, size: widget.size);
      if (tint != null) {
        sprite = ColorFiltered(
          colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
          child: sprite,
        );
      }
      child = sprite;
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Opacity(opacity: alive ? 1 : 0.35, child: child),
    );
  }
}

class _HeroDollPainter extends CustomPainter {
  _HeroDollPainter({
    required this.body,
    required this.fallback,
    required this.atlas,
    required this.hero,
    required this.partyIndex,
    required this.tint,
  });

  final ui.Image? body;
  final ui.Image? fallback;
  final ui.Image? atlas;
  final PartyHero hero;
  final int partyIndex;
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final drawSize = size.shortestSide;
    final img = body ?? fallback;
    if (img != null) {
      final paint = Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false;
      if (tint != null) {
        paint.colorFilter = ColorFilter.mode(tint!, BlendMode.modulate);
      }
      final dst = Rect.fromCenter(
        center: center,
        width: drawSize,
        height: drawSize,
      );
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        paint,
      );
    }

    final a = atlas;
    if (a != null) {
      CharacterVisualPainter.paintGearOverlays(
        canvas,
        a,
        center,
        drawSize,
        hero: hero,
        signals: const HeroAnimSignals(),
        partyIndex: partyIndex,
        cacheId: 'gear_preview_${hero.id}',
        anchorProfile: BodyAnchorProfile.owned,
      );
    } else if (img == null) {
      // Absolute last resort: full Kenney doll if somehow nothing loaded.
    }
  }

  @override
  bool shouldRepaint(covariant _HeroDollPainter oldDelegate) {
    return !identical(body, oldDelegate.body) ||
        !identical(fallback, oldDelegate.fallback) ||
        !identical(atlas, oldDelegate.atlas) ||
        hero.id != oldDelegate.hero.id ||
        tint != oldDelegate.tint ||
        partyIndex != oldDelegate.partyIndex ||
        hero.equipped.length != oldDelegate.hero.equipped.length;
  }
}
