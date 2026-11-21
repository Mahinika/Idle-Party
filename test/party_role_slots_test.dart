import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/party_role_slots.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';

PartyHero _hero(String id, HeroSpecId spec) => PartyHero.starting(
      name: 'Test$id',
      specId: spec,
      id: id,
    );

void main() {
  test('migration maps first of each role into fixed slots', () {
    final roster = [
      _hero('d1', HeroSpecId.fire),
      _hero('t1', HeroSpecId.protection),
      _hero('h1', HeroSpecId.discipline),
      _hero('d2', HeroSpecId.combat),
    ];
    final migrated = PartyRoleSlots.migrateActiveHeroIds(
      raw: ['d1', 't1', 'h1', 'd2'],
      roster: roster,
      maxSlots: 4,
    );
    expect(migrated, ['t1', 'h1', 'd1', 'd2']);
  });

  test('duplicate tanks benches the second tank', () {
    final roster = [
      _hero('t1', HeroSpecId.protection),
      _hero('t2', HeroSpecId.blood),
      _hero('d1', HeroSpecId.fire),
    ];
    final migrated = PartyRoleSlots.migrateActiveHeroIds(
      raw: ['t1', 't2', 'd1'],
      roster: roster,
      maxSlots: 4,
    );
    expect(migrated[0], 't1');
    expect(migrated.contains('t2'), isFalse);
    expect(migrated[2], 'd1');
  });

  test('no healer leaves healer slot empty', () {
    final roster = [
      _hero('t1', HeroSpecId.protection),
      _hero('d1', HeroSpecId.fire),
      _hero('d2', HeroSpecId.combat),
      _hero('d3', HeroSpecId.fury),
    ];
    final migrated = PartyRoleSlots.migrateActiveHeroIds(
      raw: ['t1', 'd1', 'd2', 'd3'],
      roster: roster,
      maxSlots: 4,
    );
    expect(migrated[0], 't1');
    expect(migrated[1], '');
    expect(migrated[2], 'd1');
    expect(migrated[3], 'd2');
    expect(migrated.contains('d3'), isFalse);
  });

  test('five DPS caps at three DPS slots when slot 5 unlocked', () {
    final roster = [
      for (var i = 0; i < 5; i++)
        _hero('d$i', [
          HeroSpecId.fire,
          HeroSpecId.combat,
          HeroSpecId.fury,
          HeroSpecId.arms,
          HeroSpecId.shadow,
        ][i]),
    ];
    final migrated = PartyRoleSlots.migrateActiveHeroIds(
      raw: [for (var i = 0; i < 5; i++) 'd$i'],
      roster: roster,
      maxSlots: 5,
    );
    expect(migrated[0], '');
    expect(migrated[1], '');
    expect(migrated.sublist(2), ['d0', 'd1', 'd2']);
    expect(migrated.contains('d3'), isFalse);
    expect(migrated.contains('d4'), isFalse);
  });

  test('tank and dps are different role buckets', () {
    expect(
      HeroSpecs.partyRole(HeroSpecId.protection),
      PartyRoleBucket.tank,
    );
    expect(HeroSpecs.partyRole(HeroSpecId.fire), PartyRoleBucket.dps);
    expect(
      PartyRoleSlots.heroFitsSlot(
        _hero('d', HeroSpecId.fire),
        PartyRoleSlots.tankIndex,
      ),
      isFalse,
    );
  });

  test('new game save uses tank healer dps order', () {
    final state = GameLogic.createInitialState(
      partySpecs: [HeroSpecId.fire, HeroSpecId.protection, HeroSpecId.discipline],
    );
    expect(state.activeHeroIds.length, 4);
    final slots = PartyRoleSlots.slotHeroes(state);
    expect(slots[0]?.specId, HeroSpecId.protection);
    expect(slots[1]?.specId, HeroSpecId.discipline);
    expect(slots[2]?.specId, HeroSpecId.fire);
    expect(slots[3], isNull);
  });
}