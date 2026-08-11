import 'package:flutter/material.dart';

import '../models/hero.dart';
import 'kenney_assets.dart';
import 'kenney_sprite.dart';

/// Painted custom hero sprite (intro-matched). Replaces Kenney paper-doll in HUD/equip.
class HeroDollSprite extends StatelessWidget {
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
  final int walkFrame;

  @override
  Widget build(BuildContext context) {
    final asset = KenneyAssets.heroSpriteForSpec(hero.specId);
    final tint = KenneyAssets.heroTintForSpec(hero.specId);
    final alive = hero.currentHp > 0;
    Widget sprite = KenneySprite(asset: asset, size: size);
    if (tint != null) {
      sprite = ColorFiltered(
        colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
        child: sprite,
      );
    }
    return Opacity(
      opacity: alive ? 1 : 0.35,
      child: sprite,
    );
  }
}
