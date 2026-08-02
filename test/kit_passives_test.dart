import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('every non-legacy kit passive sets a real combat mul', () {
    final legacy = {
      HeroSpecId.protection,
      HeroSpecId.discipline,
      HeroSpecId.fire,
      HeroSpecId.combat,
    };
    for (final specId in HeroSpecId.values) {
      if (legacy.contains(specId)) continue;
      final passive = ClassKits.forSpec(specId).firstWhere(
        (d) => d.effect == AbilityEffectKind.passive,
      );
      final state = _soloSpecParty(specId, level: 15);
      var world = SpatialCombat.build(state);
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      final hero = world.heroes.firstWhere((h) => !h.isPet);
      final changed = hero.kitOutMul != 1.0 ||
          hero.kitInMul != 1.0 ||
          hero.kitHealMul != 1.0 ||
          hero.kitHasteMul != 1.0 ||
          hero.kitRootBonus != 0.0;
      expect(
        changed,
        isTrue,
        reason: '${passive.name} ($specId) left all kit muls at defaults '
            '(out=${hero.kitOutMul} in=${hero.kitInMul} heal=${hero.kitHealMul} '
            'haste=${hero.kitHasteMul} root=${hero.kitRootBonus})',
      );
    }
  });

  test('legacy Arcane Intellect sets fire mage kitOutMul', () {
    final state = _soloSpecParty(HeroSpecId.fire, level: 5);
    var world = SpatialCombat.build(state);
    world = SpatialCombat.step(world, state, dt: 0.1).world;
    final mage = world.heroes.firstWhere((h) => !h.isPet);
    expect(mage.kitOutMul, closeTo(1.02, 0.001));
  });

  test('Inner Fire sets disc heal mul', () {
    final state = _soloSpecParty(HeroSpecId.discipline, level: 5);
    var world = SpatialCombat.build(state);
    world = SpatialCombat.step(world, state, dt: 0.1).world;
    final priest = world.heroes.firstWhere((h) => !h.isPet);
    expect(priest.innerFireActive, isTrue);
    expect(priest.kitHealMul, greaterThan(1.0));
  });
}

GameState _soloSpecParty(HeroSpecId specId, {required int level}) {
  var state = GameLogic.createInitialState(now: DateTime(2026, 8, 1));
  state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
  final base = state.heroes.first;
  var hero = base.copyWith(specId: specId, role: HeroSpecs.def(specId).legacyRole);
  while (hero.level < level) {
    hero = hero.levelUp();
  }
  return state.copyWith(heroes: [hero]);
}
