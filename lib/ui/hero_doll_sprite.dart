import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/hero.dart';
import '../visual/body_family.dart';
import '../visual/hero_anim_state.dart';
import 'decoded_image_cache.dart';
import 'kenney_assets.dart';
import 'kenney_sprite.dart';

/// GEAR / party HUD preview: owned denser body (`assets/custom/char/`).
///
/// Gear slots around the doll show what is equipped — the body is the class
/// silhouette only (no Kenney overlay junk). Dungeon combat uses the same
/// families with walk/attack clips in [SpatialDungeonView].
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

  /// Reserved for future walk-frame previews (idle in GEAR for now).
  final int walkFrame;

  @override
  State<HeroDollSprite> createState() => _HeroDollSpriteState();
}

class _HeroDollSpriteState extends State<HeroDollSprite> {
  ui.Image? _body;
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
    _fallbackPath = KenneyAssets.heroSpriteForSpec(widget.hero.specId);
    final decodeW = (widget.size * 3).ceil().clamp(64, 256);

    ui.Image? body;
    try {
      body = await DecodedImageCache.load(bodyPath, targetWidth: decodeW);
    } catch (_) {}

    if (!mounted || gen != _loadGen) return;
    setState(() => _body = body);
  }

  @override
  Widget build(BuildContext context) {
    final alive = widget.hero.currentHp > 0;
    final body = _body;

    Widget child;
    if (body != null) {
      child = CustomPaint(
        size: Size.square(widget.size),
        painter: _OwnedBodyPainter(body: body),
      );
    } else {
      final asset =
          _fallbackPath ?? KenneyAssets.heroSpriteForSpec(widget.hero.specId);
      final tint = KenneyAssets.heroTintForSpec(widget.hero.specId);
      child = KenneySprite(asset: asset, size: widget.size);
      if (tint != null) {
        child = ColorFiltered(
          colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
          child: child,
        );
      }
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Opacity(opacity: alive ? 1 : 0.35, child: child),
    );
  }
}

class _OwnedBodyPainter extends CustomPainter {
  const _OwnedBodyPainter({required this.body});

  final ui.Image body;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final drawSize = size.shortestSide;
    canvas.drawImageRect(
      body,
      Rect.fromLTWH(0, 0, body.width.toDouble(), body.height.toDouble()),
      Rect.fromCenter(center: center, width: drawSize, height: drawSize),
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(covariant _OwnedBodyPainter oldDelegate) =>
      !identical(body, oldDelegate.body);
}
