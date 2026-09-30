import 'package:flutter/material.dart';

import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../visual/body_family.dart';
import '../visual/equipment_visual_resolver.dart';
import '../visual/owned_gear_assets.dart';
import '../assets/kenney_assets.dart';
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
    final heroClass = hero == null ? null : HeroSpecs.def(hero!.specId).classId;
    final owned = EquipmentVisualResolver.ownedIconPathFor(
      item,
      family: family,
      heroClass: heroClass,
    );
    final kenney = KenneyAssets.kenneyEquipmentIconFor(item);
    if (owned == null) {
      return KenneySprite(asset: kenney, size: size);
    }
    final resolved = EquipmentVisualResolver.resolveId(item);
    Widget picture = Image.asset(
      owned,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      errorBuilder: (_, _, _) => KenneySprite(asset: kenney, size: size),
    );
    final tint = EquipmentVisualResolver.rarityTint(
      resolved,
      rarityTier: item.rarity.index,
    );
    if (tint != null) {
      picture = ColorFiltered(
        colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
        child: picture,
      );
    }
    final dye = EquipmentVisualResolver.clothDyeFor(item);
    final dyeFamily =
        family ?? BodyFamilyCatalog.familyForAffinity(item.affinity);
    final mask = dye == null
        ? null
        : OwnedGearAssets.clothDyeMaskPath(
            visualSetId: resolved,
            family: dyeFamily,
            armorType: item.armorType,
          );
    if (mask != null && dye != null) {
      picture = Stack(
        alignment: Alignment.center,
        children: [
          picture,
          ColorFiltered(
            colorFilter: ColorFilter.mode(dye, BlendMode.modulate),
            child: Image.asset(
              mask.replaceFirst('_dye.png', '_dye_icon.png'),
              width: size,
              height: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              isAntiAlias: false,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      );
    }
    return picture;
  }
}
