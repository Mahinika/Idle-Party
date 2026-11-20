import 'package:flutter/material.dart';

import '../assets/custom_assets.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import 'game_icon.dart';
import 'game_theme.dart';

/// Pixel role mark for tight fight rows: shield / cross / bow.
class PartyRoleIcon extends StatelessWidget {
  const PartyRoleIcon({
    super.key,
    required this.bucket,
    this.size = 10,
    this.color,
  });

  final PartyRoleBucket bucket;
  final double size;
  final Color? color;

  static String semanticsLabel(PartyRoleBucket bucket) => switch (bucket) {
        PartyRoleBucket.tank => 'Tank',
        PartyRoleBucket.healer => 'Healer',
        PartyRoleBucket.dps => 'DPS',
      };

  static Key keyFor(PartyRoleBucket bucket) =>
      ValueKey('party-role-icon-${bucket.name}');

  @override
  Widget build(BuildContext context) {
    final label = semanticsLabel(bucket);
    final tint = color ?? GameTheme.torchHot;
    final mark = switch (bucket) {
      PartyRoleBucket.tank => GameIcon.asset(
          CustomAssets.iconShieldRound,
          size: size,
          color: tint,
        ),
      PartyRoleBucket.healer => GameIcon.glyph(
          UiGlyph.healerCross,
          size: size,
          color: tint,
        ),
      PartyRoleBucket.dps => GameIcon.asset(
          CustomAssets.iconBow,
          size: size,
          color: tint,
        ),
    };
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          key: keyFor(bucket),
          width: size,
          height: size,
          child: mark,
        ),
      ),
    );
  }
}

/// Maps [SpecRoleTag] to the fixed party [PartyRoleBucket].
PartyRoleBucket partyRoleBucketFor(PartyHero hero) =>
    HeroSpecs.partyRole(hero.specId);