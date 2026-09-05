import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/party_meter.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

SpatialActor _hero({
  required String id,
  required HeroSpecId spec,
  int damageDealt = 0,
  int healingDone = 0,
  int damageTaken = 0,
  bool isPet = false,
}) {
  final def = HeroSpecs.def(spec);
  return SpatialActor(
    id: id,
    name: def.shortLabel,
    team: SpatialTeam.hero,
    x: 1,
    y: 1,
    hp: 100,
    maxHp: 100,
    attack: 10,
    defense: 5,
    moveSpeed: 2,
    attackRange: 1.2,
    attackCooldown: 1,
    heroSpecId: spec,
    heroRole: def.gearAffinity,
    isPet: isPet,
  )
    ..damageDealt = damageDealt
    ..healingDone = healingDone
    ..damageTaken = damageTaken;
}

void main() {
  test('PartyMeter bars normalize within the same unit only', () {
    final snap = PartyMeter.fromHeroes(
      [
        _hero(
          id: 'tank',
          spec: HeroSpecId.protection,
          damageTaken: 10000,
          damageDealt: 1000,
        ),
        _hero(id: 'dps', spec: HeroSpecId.fire, damageDealt: 5000),
        _hero(id: 'heal', spec: HeroSpecId.holyPriest, healingDone: 8000),
      ],
      elapsed: 10,
    );

    expect(snap.chipLabel, '500 dps'); // 5000/10
    final dpsRows = snap.rows.where((r) => r.unit == 'dps').toList();
    expect(dpsRows.length, 2); // fire + tank damage
    final topDps = dpsRows.firstWhere((r) => r.highlight);
    expect(topDps.bar, 1.0);
    expect(topDps.tag, 'FIRE');

    final dtps = snap.rows.where((r) => r.unit == 'dtps').single;
    expect(dtps.bar, 1.0);
    expect(dtps.rate, 1000); // 10000/10

    final hps = snap.rows.where((r) => r.unit == 'hps').single;
    expect(hps.bar, 1.0);
    expect(hps.rate, 800);
  });

  test('PartyMeter skips pets and zero rates', () {
    final snap = PartyMeter.fromHeroes(
      [
        _hero(
          id: 'pet',
          spec: HeroSpecId.beastMastery,
          damageDealt: 9999,
          isPet: true,
        ),
        _hero(id: 'idle', spec: HeroSpecId.fire),
      ],
      elapsed: 5,
    );
    expect(snap.chipLabel, '0 DPS');
    expect(snap.rows, isEmpty);
  });

  test('PartyMeter COMBAT short label is COM', () {
    expect(
      PartyMeter.heroTag(_hero(id: 'r', spec: HeroSpecId.combat)),
      'COM',
    );
  });

  test('HoT ticks credit healingDone to the caster, not the target', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 29));
    var world = SpatialCombat.build(state);
    expect(world.heroes.length, greaterThanOrEqualTo(2));

    final healer = world.heroes.firstWhere(
      (h) =>
          h.heroSpecId != null && HeroSpecs.def(h.heroSpecId!).isHealer,
      orElse: () => world.heroes.first,
    );
    final ally = world.heroes.firstWhere((h) => h.id != healer.id);
    ally.hp = ally.effectiveMaxHp - 40;
    ally.buffTimers['hot'] = 5;
    ally.hotHps = 20;
    ally.hotAcc = 0;
    ally.hotCasterId = healer.id;
    healer.healingDone = 0;
    ally.healingDone = 0;

    for (var i = 0; i < 40; i++) {
      final step = SpatialCombat.step(world, state, dt: 0.1);
      world = step.world;
    }

    final healerAfter = world.heroes.firstWhere((h) => h.id == healer.id);
    final allyAfter = world.heroes.firstWhere((h) => h.id == ally.id);
    expect(healerAfter.healingDone, greaterThan(0));
    expect(allyAfter.healingDone, 0);
  });
}
