import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/hero.dart';
import '../models/loot.dart';
import 'decoded_image_cache.dart';
import 'hero_doll_sprite.dart';

/// Kenney Roguelike Characters atlas (16×16 tiles, 1px margin).
class RoguelikeCharAtlas {
  RoguelikeCharAtlas._();

  static const String assetPath =
      'assets/kenney/roguelike_char/roguelikeChar_transparent.png';

  static const int tileSize = 16;
  static const int stride = 17;

  static Rect src(int col, int row) => Rect.fromLTWH(
        col * stride.toDouble(),
        row * stride.toDouble(),
        tileSize.toDouble(),
        tileSize.toDouble(),
      );
}

/// One layer cell in the paper-doll stack (back → front).
class DollLayer {
  const DollLayer(this.col, this.row);
  final int col;
  final int row;
}

/// Resolves equipped gear into layered Roguelike Character tiles.
///
/// Unequipped slots are omitted → naked body (+ hair for identity).
class HeroPaperDoll {
  HeroPaperDoll._();

  /// Skin row on body columns 0–1.
  static int skinRowFor(PartyHero hero, int partyIndex) {
    return switch (hero.role) {
      HeroRole.warrior => 0,
      HeroRole.healer => 1,
      HeroRole.mage => 2,
      HeroRole.rogue => 3,
    };
  }

  /// Hair style when not wearing a helmet.
  static DollLayer hairFor(PartyHero hero) {
    // cols 19–22 are top hair; rows by color bands.
    return switch (hero.role) {
      HeroRole.warrior => const DollLayer(19, 0), // brown short
      HeroRole.healer => const DollLayer(21, 8), // white — Disc Priest
      HeroRole.mage => const DollLayer(20, 8),
      HeroRole.rogue => const DollLayer(19, 4), // dark
    };
  }

  static int _rarityTier(LootRarity? rarity) => rarity?.index ?? 0;

  /// Pants / legs — boots slot.
  static DollLayer? pantsFor(PartyHero hero) {
    final boots = hero.itemIn(EquipmentSlot.boots);
    if (boots == null) return null;
    // cols 3–4 pants overlays; row picks color/tier.
    final row = switch (_rarityTier(boots.rarity)) {
      0 => 1, // dark
      1 => 2, // brown
      2 => 3, // light
      _ => 0, // black
    };
    return DollLayer(3, row);
  }

  /// Torso / cloak slot. Also draws light cloth for cloak.
  static DollLayer? torsoFor(PartyHero hero) {
    final cloak = hero.itemIn(EquipmentSlot.cloak);
    if (cloak == null) return null;
    final tier = _rarityTier(cloak.rarity);
    // Armor columns 6–17: pick role palette × rarity.
    return switch (hero.role) {
      HeroRole.warrior => DollLayer(
          tier >= 2 ? 10 : 6,
          tier >= 2 ? 5 : tier.clamp(0, 4).toInt(),
        ),
      HeroRole.healer => DollLayer(7, tier >= 2 ? 5 : tier.clamp(0, 4).toInt()),
      HeroRole.mage => DollLayer(9, tier >= 2 ? 4 : 2),
      HeroRole.rogue => DollLayer(12, tier >= 2 ? 3 : 1),
    };
  }

  /// Optional cape when cloak is uncommon+.
  static DollLayer? capeFor(PartyHero hero) {
    final cloak = hero.itemIn(EquipmentSlot.cloak);
    if (cloak == null || cloak.rarity.index < LootRarity.uncommon.index) {
      return null;
    }
    return switch (hero.role) {
      HeroRole.warrior => const DollLayer(28, 7),
      HeroRole.healer => const DollLayer(29, 7),
      HeroRole.mage => const DollLayer(30, 7),
      HeroRole.rogue => const DollLayer(31, 7),
    };
  }

  static DollLayer? headFor(PartyHero hero) {
    final head = hero.itemIn(EquipmentSlot.head);
    if (head == null) return null;
    final tier = _rarityTier(head.rarity);
    // Helmets / hats in cols 28–31.
    if (tier >= 2) {
      return switch (hero.role) {
        HeroRole.warrior => const DollLayer(28, 6), // heavy
        HeroRole.healer => const DollLayer(29, 8), // hat
        HeroRole.mage => const DollLayer(30, 8),
        HeroRole.rogue => const DollLayer(31, 8),
      };
    }
    return switch (hero.role) {
      HeroRole.warrior => const DollLayer(28, 0),
      HeroRole.healer => const DollLayer(29, 0),
      HeroRole.mage => const DollLayer(30, 0),
      HeroRole.rogue => const DollLayer(31, 0),
    };
  }

  static DollLayer? shieldFor(PartyHero hero) {
    final shield = hero.itemIn(EquipmentSlot.offHand);
    if (shield == null ||
        shield.offHandKind == OffHandKind.frill ||
        shield.offHandKind == OffHandKind.weapon) {
      return null;
    }
    final tier = _rarityTier(shield.rarity);
    // Shields cols 33–40.
    return switch (tier) {
      0 => const DollLayer(33, 1), // wood
      1 => const DollLayer(37, 1), // metal
      2 => const DollLayer(37, 5), // patterned
      _ => const DollLayer(39, 7), // fancy
    };
  }

  static DollLayer? weaponFor(PartyHero hero) {
    final weapon = hero.itemIn(EquipmentSlot.weapon);
    if (weapon == null) return null;
    final tier = _rarityTier(weapon.rarity);
    final wt = weapon.weaponType;
    if (wt == WeaponType.staff ||
        wt == WeaponType.wand ||
        hero.role == HeroRole.mage ||
        hero.role == HeroRole.healer) {
      return switch (tier) {
        0 => const DollLayer(42, 0),
        1 => const DollLayer(44, 0),
        2 => const DollLayer(46, 0),
        _ => const DollLayer(47, 0),
      };
    }
    if (wt == WeaponType.dagger ||
        wt == WeaponType.fist ||
        hero.role == HeroRole.rogue) {
      return switch (tier) {
        0 => const DollLayer(48, 0),
        1 => const DollLayer(49, 0),
        2 => const DollLayer(50, 0),
        _ => const DollLayer(51, 0),
      };
    }
    // Swords / axes / maces — default melee.
    return switch (tier) {
      0 => const DollLayer(42, 4),
      1 => const DollLayer(44, 4),
      2 => const DollLayer(46, 4),
      _ => const DollLayer(47, 4),
    };
  }

  /// Back-to-front layers for [hero].
  ///
  /// [walkFrame] 0/1 picks body/pants pose column.
  static List<DollLayer> layersFor(
    PartyHero hero, {
    int partyIndex = 0,
    int walkFrame = 0,
  }) {
    final bodyCol = walkFrame.clamp(0, 1);
    final skin = skinRowFor(hero, partyIndex);
    final layers = <DollLayer>[
      DollLayer(bodyCol, skin),
    ];

    final cape = capeFor(hero);
    if (cape != null) layers.add(cape);

    final pants = pantsFor(hero);
    if (pants != null) {
      layers.add(DollLayer(bodyCol == 0 ? 3 : 4, pants.row));
    }

    final torso = torsoFor(hero);
    if (torso != null) layers.add(torso);

    final head = headFor(hero);
    if (head == null) {
      layers.add(hairFor(hero));
    } else {
      layers.add(head);
    }

    final shield = shieldFor(hero);
    if (shield != null) layers.add(shield);

    final weapon = weaponFor(hero);
    if (weapon != null) layers.add(weapon);

    return layers;
  }

  static void paint(
    Canvas canvas,
    ui.Image atlas,
    Offset center,
    double size, {
    required PartyHero hero,
    int partyIndex = 0,
    int walkFrame = 0,
    double alpha = 1,
  }) {
    final layers = layersFor(
      hero,
      partyIndex: partyIndex,
      walkFrame: walkFrame,
    );
    final dst = Rect.fromCenter(center: center, width: size, height: size);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..color = Color.fromRGBO(255, 255, 255, alpha);
    for (final layer in layers) {
      canvas.drawImageRect(
        atlas,
        RoguelikeCharAtlas.src(layer.col, layer.row),
        dst,
        paint,
      );
    }
  }
}

/// Equip-panel paper doll: layered Roguelike tiles from worn gear.
///
/// Falls back to the custom class sprite while the atlas loads.
class HeroPaperDollView extends StatelessWidget {
  const HeroPaperDollView({
    super.key,
    required this.hero,
    this.partyIndex = 0,
    this.size = 64,
    this.walkFrame = 0,
  });

  final PartyHero hero;
  final int partyIndex;
  final double size;
  final int walkFrame;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: DecodedImageCache.load(
        RoguelikeCharAtlas.assetPath,
        targetWidth: 512,
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return HeroDollSprite(
            hero: hero,
            partyIndex: partyIndex,
            size: size,
            walkFrame: walkFrame,
          );
        }
        return CustomPaint(
          size: Size(size, size),
          painter: _HeroPaperDollPainter(
            atlas: snap.data!,
            hero: hero,
            partyIndex: partyIndex,
            walkFrame: walkFrame,
          ),
        );
      },
    );
  }
}

class _HeroPaperDollPainter extends CustomPainter {
  const _HeroPaperDollPainter({
    required this.atlas,
    required this.hero,
    required this.partyIndex,
    required this.walkFrame,
  });

  final ui.Image atlas;
  final PartyHero hero;
  final int partyIndex;
  final int walkFrame;

  @override
  void paint(Canvas canvas, Size size) {
    HeroPaperDoll.paint(
      canvas,
      atlas,
      Offset(size.width / 2, size.height / 2),
      size.shortestSide,
      hero: hero,
      partyIndex: partyIndex,
      walkFrame: walkFrame,
    );
  }

  @override
  bool shouldRepaint(covariant _HeroPaperDollPainter old) =>
      old.atlas != atlas ||
      old.hero != hero ||
      old.partyIndex != partyIndex ||
      old.walkFrame != walkFrame;
}
