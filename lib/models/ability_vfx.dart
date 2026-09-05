import 'spell_bolt_style.dart';

/// Optional per-ability visual overrides (cast / bolt / ground disc).
///
/// When null on [ClassAbilityDef], combat falls back to id maps + keywords.
class AbilityVfxSpec {
  const AbilityVfxSpec({
    this.boltStyle,
    this.castArgb,
    this.groundDisc = false,
    this.groundLife = 4.5,
    this.groundArgb,
    this.groundRadius,
  });

  /// Prefer over keyword / id-map bolt styling when set.
  final SpellBoltStyle? boltStyle;

  /// Soft cast burst tint (ARGB). Null → style-derived.
  final int? castArgb;

  /// Spawn a lasting ground disc under the caster (Consecration-style).
  final bool groundDisc;

  /// Seconds the ground disc remains.
  final double groundLife;

  /// Ground disc tint. Null → style-derived.
  final int? groundArgb;

  /// Override disc radius in tiles. Null → style default (~2.7).
  final double? groundRadius;
}
