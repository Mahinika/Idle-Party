import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../assets/custom_assets.dart';
import '../models/hero.dart';
import '../visual/body_family.dart';
import '../visual/character_visual_painter.dart';
import '../visual/character_visual_pose.dart';
import '../visual/hero_anim_state.dart';
import 'decoded_image_cache.dart';
import '../assets/kenney_assets.dart';
import 'kenney_sprite.dart';

/// GEAR / party HUD: owned body + same 128×128 gear overlays as dungeon.
///
/// Specs with [CustomAssets.hasUniqueHeroSprite] (Druid forms, Shadow) draw
/// the form PNG only — no undertunic or gear overlays.
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
  Map<String, ui.Image> _overlays = const {};
  String? _fallbackPath;
  String? _formPath;
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
        oldWidget.hero.race != widget.hero.race ||
        oldWidget.hero.sex != widget.hero.sex ||
        !_sameEquipKeys(oldWidget.hero, widget.hero)) {
      _reload();
    }
  }

  static bool _sameEquipKeys(PartyHero a, PartyHero b) {
    if (a.equipped.length != b.equipped.length) return false;
    for (final e in a.equipped.entries) {
      final other = b.equipped[e.key];
      if (other == null) return false;
      if (other.id != e.value.id ||
          other.visualSetId != e.value.visualSetId ||
          other.armorType != e.value.armorType ||
          other.rarity != e.value.rarity) {
        return false;
      }
    }
    return true;
  }

  Future<void> _reload() async {
    final gen = ++_loadGen;
    final useForm = CustomAssets.hasUniqueHeroSprite(widget.hero.specId);
    if (useForm) {
      final formPath = CustomAssets.heroForSpec(widget.hero.specId);
      ui.Image? form;
      try {
        form = await DecodedImageCache.load(formPath, targetWidth: 96);
      } catch (_) {}
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _formPath = formPath;
        _body = form;
        _overlays = const {};
        _fallbackPath = null;
      });
      return;
    }

    final bodyPath = BodyFamilyCatalog.assetFor(widget.hero, HeroAnimKind.idle);
    _fallbackPath = KenneyAssets.heroSpriteForSpec(widget.hero.specId);
    // Owned bodies/overlays are 128×128. Upscaling to 256 then painting with
    // FilterQuality.none made GEAR dolls softer than the dungeon.
    const decodeW = 128;

    ui.Image? body;
    final overlays = <String, ui.Image>{};
    try {
      body = await DecodedImageCache.load(bodyPath, targetWidth: decodeW);
      final pose = CharacterVisualPose.resolve(
        hero: widget.hero,
        anim: const HeroAnimPose(kind: HeroAnimKind.idle, frame: 0),
        partyIndex: widget.partyIndex,
        owned: true,
      );
      final paths = <String>{
        if (pose.bodyTintAsset != null) pose.bodyTintAsset!,
        for (final layer in pose.layers)
          if (layer.ownedAsset != null) layer.ownedAsset!,
      };
      for (final path in paths) {
        try {
          overlays[path] = await DecodedImageCache.load(
            path,
            targetWidth: decodeW,
          );
        } catch (_) {
          final idle = path.replaceFirst(
            RegExp(r'_(walk|attack)\.png$'),
            '_idle.png',
          );
          if (idle != path) {
            try {
              overlays[idle] = await DecodedImageCache.load(
                idle,
                targetWidth: decodeW,
              );
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    if (!mounted || gen != _loadGen) return;
    setState(() {
      _formPath = null;
      _body = body;
      _overlays = overlays;
    });
  }

  @override
  Widget build(BuildContext context) {
    final alive = widget.hero.currentHp > 0;
    final body = _body;
    final formPath = _formPath;

    Widget child;
    if (formPath != null) {
      // Unique form PNG — prefer decoded image; KenneySprite as soft fallback.
      if (body != null) {
        child = CustomPaint(
          size: Size.square(widget.size),
          painter: _FormDollPainter(image: body),
        );
      } else {
        child = KenneySprite(asset: formPath, size: widget.size);
      }
    } else if (body != null) {
      child = CustomPaint(
        size: Size.square(widget.size),
        painter: _OwnedDollPainter(
          body: body,
          overlays: _overlays,
          hero: widget.hero,
          partyIndex: widget.partyIndex,
        ),
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

class _FormDollPainter extends CustomPainter {
  const _FormDollPainter({required this.image});

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(covariant _FormDollPainter oldDelegate) =>
      !identical(image, oldDelegate.image);
}

class _OwnedDollPainter extends CustomPainter {
  const _OwnedDollPainter({
    required this.body,
    required this.overlays,
    required this.hero,
    required this.partyIndex,
  });

  final ui.Image body;
  final Map<String, ui.Image> overlays;
  final PartyHero hero;
  final int partyIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final pose = CharacterVisualPose.resolve(
      hero: hero,
      anim: const HeroAnimPose(kind: HeroAnimKind.idle, frame: 0),
      partyIndex: partyIndex,
      owned: true,
    );
    CharacterVisualPainter.paintOwnedHero(
      canvas,
      Offset(size.width / 2, size.height / 2),
      size.shortestSide,
      body: body,
      images: overlays,
      pose: pose,
    );
  }

  @override
  bool shouldRepaint(covariant _OwnedDollPainter oldDelegate) =>
      !identical(body, oldDelegate.body) ||
      !identical(overlays, oldDelegate.overlays) ||
      hero.id != oldDelegate.hero.id ||
      hero.equipped != oldDelegate.hero.equipped ||
      partyIndex != oldDelegate.partyIndex;
}
