import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/spell_bolt_style.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

/// Styles that already lived on the ability and beat the id switch.
const _overrides = <AbilityId, SpellBoltStyle>{
  AbilityId.bloodBoil: SpellBoltStyle.shadow,
  AbilityId.boneShield: SpellBoltStyle.shadow,
  AbilityId.obliterate: SpellBoltStyle.frost,
  AbilityId.bloodBoilUnholy: SpellBoltStyle.shadow,
  AbilityId.starfire: SpellBoltStyle.arcane,
  AbilityId.moonfire: SpellBoltStyle.arcane,
  AbilityId.starfall: SpellBoltStyle.arcane,
  AbilityId.chimeraShot: SpellBoltStyle.nature,
  AbilityId.blackArrow: SpellBoltStyle.shadow,
  AbilityId.hemorrhage: SpellBoltStyle.shadow,
  AbilityId.backstab: SpellBoltStyle.shadow,
};

void main() {
  test('catalog bolt style matches the id switch unless already set', () {
    for (final id in AbilityId.values) {
      final fromSwitch = spellBoltStyleForAbilityId(id);
      if (fromSwitch == null) continue;
      final def = ClassKits.defFor(id);
      expect(def, isNotNull, reason: id.name);
      final catalog = def!.vfx?.boltStyle ?? def.boltStyle;
      expect(catalog, _overrides[id] ?? fromSwitch, reason: id.name);
    }
  });

  test('ground disc life still comes from the same table', () {
    expect(SpatialCombat.groundDiscLifeFor(AbilityId.consecration), 6.0);
    expect(SpatialCombat.groundDiscLifeFor(AbilityId.swipe), 1.5);
    expect(SpatialCombat.groundDiscLifeFor(AbilityId.fireball), isNull);
  });
}
