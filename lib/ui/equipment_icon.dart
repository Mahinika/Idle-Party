import 'package:flutter/material.dart';

import '../models/hero.dart';
import '../models/loot.dart';
import '../visual/body_family.dart';
import '../visual/owned_gear_assets.dart';
import 'kenney_assets.dart';
import 'kenney_sprite.dart';

/// Slot / bag icon: cropped doll overlay when we have one, else Kenney.
class EquipmentIcon extends StatelessWidget {
  const EquipmentIcon({
    super.key,
    required this.item,
    this.size = 28,
    this.hero,
  });

  final EquipmentItem item;
  final double size;
  final PartyHero? hero;

  @override
  Widget build(BuildContext context) {
    final family = hero != null ? BodyFamilyCatalog.familyFor(hero!) : null;
    final owned = OwnedGearAssets.iconPathFor(item, family: family);
    final kenney = KenneyAssets.kenneyEquipmentIconFor(item);
    if (owned == null) {
      return KenneySprite(asset: kenney, size: size);
    }
    return Image.asset(
      owned,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      errorBuilder: (_, _, _) => KenneySprite(asset: kenney, size: size),
    );
  }
}
