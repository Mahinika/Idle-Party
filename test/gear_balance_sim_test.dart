import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/dungeon_generator.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

/// Printable gear balance board + soft gates after lean itemization.
void main() {
  test('gear balance board + combat uplift', () {
    final report = StringBuffer();
    void log(String line) {
      report.writeln(line);
      // ignore: avoid_print
      print(line);
    }

    log('=== Gear balance sims (lean Primary / Secondary) ===');

    for (final pass in [
      (bn: 6, dung: 'sandy', label: 'EARLY rare F6 sandy'),
      (bn: 18, dung: 'sandy', label: 'MID rare F18 sandy'),
      (bn: 18, dung: 'crystal', label: 'MID rare F18 crystal'),
    ]) {
      log('\n-- ROLE SHEETS · ${pass.label}');
      log(
        '${'Role'.padRight(8)} ${'ATK'.padLeft(5)} ${'DEF'.padLeft(5)} '
        '${'HP'.padLeft(6)} ${'Crit'.padLeft(5)} ${'Haste'.padLeft(5)} '
        '${'dATK%'.padLeft(6)} ${'dHP%'.padLeft(6)}',
      );
      final atks = <int>[];
      final defs = <int>[];
      final dAtks = <double>[];
      final meta = _blankMeta();
      for (final role in HeroRole.values) {
        final naked = _heroFor(role);
        final geared = _withGear(
          naked,
          _fullSet(
            role: role,
            battleNumber: pass.bn,
            dungeonId: pass.dung,
          ),
        );
        final nAtk = meta.effectiveHeroAttack(naked);
        final nHp = meta.effectiveHeroMaxHp(naked);
        final gAtk = meta.effectiveHeroAttack(geared);
        final gDef = meta.effectiveHeroDefense(geared);
        final gHp = meta.effectiveHeroMaxHp(geared);
        final dAtk = nAtk <= 0 ? 0.0 : (gAtk - nAtk) * 100.0 / nAtk;
        final dHp = nHp <= 0 ? 0.0 : (gHp - nHp) * 100.0 / nHp;
        atks.add(gAtk);
        defs.add(gDef);
        dAtks.add(dAtk);
        log(
          '${role.name.padRight(8)} ${gAtk.toString().padLeft(5)} '
          '${gDef.toString().padLeft(5)} ${gHp.toString().padLeft(6)} '
          '${geared.gearCritChance.toString().padLeft(5)} '
          '${geared.gearAttackSpeedBonus.toString().padLeft(5)} '
          '${dAtk.toStringAsFixed(0).padLeft(5)}% '
          '${dHp.toStringAsFixed(0).padLeft(5)}%',
        );
      }
      final sorted = [...atks]..sort();
      final median = sorted[sorted.length ~/ 2];
      log(
        'ATK vs median $median: '
        '${[
          for (var i = 0; i < HeroRole.values.length; i++)
            '${HeroRole.values[i].name} ${((atks[i] - median) * 100 / median).toStringAsFixed(0)}%',
        ].join(' · ')}',
      );
      if (pass.bn == 18 && pass.dung == 'sandy') {
        // DPS pair (mage vs rogue) should be in the same ballpark.
        final mage = atks[HeroRole.mage.index];
        final rogue = atks[HeroRole.rogue.index];
        final dpsSpread =
            ((mage - rogue).abs() * 100.0) / max(1, (mage + rogue) ~/ 2);
        expect(dpsSpread, lessThan(40), reason: 'mage vs rogue ATK spread');
        expect(
          defs[HeroRole.warrior.index],
          greaterThan(defs[HeroRole.rogue.index]),
          reason: 'plate tank ARMOR must beat leather rogue',
        );
        for (var i = 0; i < HeroRole.values.length; i++) {
          final role = HeroRole.values[i];
          if (role == HeroRole.warrior) {
            // Tank sheet ATK can trail DPS; HP uplift is the fantasy.
            expect(dAtks[i], greaterThan(40));
            continue;
          }
          expect(dAtks[i], greaterThan(40), reason: '$role gear ATK uplift');
          expect(dAtks[i], lessThan(320), reason: '$role gear ATK cap');
        }
      }
    }

    log('\n-- SECONDARY vs PRIMARY (mid rare full set)');
    for (final role in HeroRole.values) {
      final gear = _fullSet(role: role, battleNumber: 18, seed: 11);
      var pri = 0;
      var sec = 0;
      for (final item in gear.values) {
        pri += item.strengthBonus +
            item.agilityBonus +
            item.resolvedStamina +
            item.intellectBonus +
            item.spiritBonus +
            item.spellPowerBonus +
            item.resolvedArmor;
        sec += item.critChanceBonus +
            item.attackSpeedBonus +
            item.mp5Bonus +
            item.moveSpeedBonus;
      }
      final secPct = (pri + sec) == 0 ? 0.0 : sec * 100.0 / (pri + sec);
      log(
        '${role.name.padRight(8)} primary=$pri secondary=$sec '
        'secShare=${secPct.toStringAsFixed(1)}%',
      );
      // Secondaries are sparse ratings — should stay minority of raw points.
      expect(secPct, lessThan(35), reason: role.name);
    }

    log('\n-- COMBAT naked vs geared (sandy F5, 8 trials)');
    final nakedClears = _combatTrials(geared: false, floor: 5, trials: 8);
    final gearedClears = _combatTrials(geared: true, floor: 5, trials: 8);
    log(
      'naked  clear=${nakedClears.clears}/8 avgSec=${nakedClears.avgSec.toStringAsFixed(1)} '
      'wipe=${nakedClears.wipes}',
    );
    log(
      'geared clear=${gearedClears.clears}/8 avgSec=${gearedClears.avgSec.toStringAsFixed(1)} '
      'wipe=${gearedClears.wipes}',
    );
    expect(gearedClears.clears, greaterThanOrEqualTo(nakedClears.clears));
    if (nakedClears.clears > 0 && gearedClears.clears > 0) {
      expect(gearedClears.avgSec, lessThan(nakedClears.avgSec * 0.95));
    }

    log('\n-- PUSH depth geared F12-ilvl (sandy, 6 trials)');
    for (final floor in [1, 5, 10, 15]) {
      final r = _combatTrials(geared: true, floor: floor, trials: 6, bn: 12);
      log(
        'F$floor clears=${r.clears}/6 avgSec=${r.avgSec.toStringAsFixed(1)} wipe=${r.wipes}',
      );
    }

    log('\n-- STAT LINE CENSUS');
    var sec2 = 0;
    for (var seed = 0; seed < 40; seed++) {
      EquipmentFactory.random = Random(seed);
      final piece = EquipmentFactory.create(
        slot: _fullSlots[seed % _fullSlots.length],
        rarity: LootRarity.rare,
        battleNumber: 12,
        bias: HeroRole.values[seed % 4],
        dungeonId: 'sandy',
      );
      final sec = [
        if (piece.critChanceBonus > 0) 1,
        if (piece.attackSpeedBonus > 0) 1,
        if (piece.mp5Bonus > 0) 1,
        if (piece.moveSpeedBonus > 0) 1,
      ].length;
      expect(sec, lessThanOrEqualTo(2));
      expect(piece.moveSpeedBonus, 0);
      if (sec == 2) sec2++;
    }
    log('rare drops with 2 secondaries: $sec2/40');
    expect(report.isNotEmpty, isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));
}

const _fullSlots = <EquipmentSlot>[
  EquipmentSlot.head,
  EquipmentSlot.shoulder,
  EquipmentSlot.chest,
  EquipmentSlot.waist,
  EquipmentSlot.legs,
  EquipmentSlot.boots,
  EquipmentSlot.wrist,
  EquipmentSlot.hands,
  EquipmentSlot.cloak,
  EquipmentSlot.neck,
  EquipmentSlot.ring,
  EquipmentSlot.ring2,
  EquipmentSlot.weapon,
  EquipmentSlot.offHand,
  EquipmentSlot.ranged,
];

PartyHero _heroFor(HeroRole role, {int level = 20}) {
  final id = switch (role) {
    HeroRole.warrior => HeroSpecId.protection,
    HeroRole.rogue => HeroSpecId.combat,
    HeroRole.mage => HeroSpecId.fire,
    HeroRole.healer => HeroSpecId.discipline,
  };
  return PartyHero.starting(name: role.name, specId: id, level: level);
}

Map<EquipmentSlot, EquipmentItem> _fullSet({
  required HeroRole role,
  required int battleNumber,
  String dungeonId = 'sandy',
  int seed = 1,
}) {
  EquipmentFactory.random = Random(seed);
  final preferred = switch (role) {
    HeroRole.warrior => ArmorType.plate,
    HeroRole.rogue => ArmorType.leather,
    HeroRole.mage || HeroRole.healer => ArmorType.cloth,
  };
  final roleTag = switch (role) {
    HeroRole.warrior => SpecRoleTag.tank,
    HeroRole.rogue => SpecRoleTag.meleeDps,
    HeroRole.mage => SpecRoleTag.caster,
    HeroRole.healer => SpecRoleTag.healer,
  };
  return {
    for (final slot in _fullSlots)
      slot: EquipmentFactory.create(
        slot: slot,
        rarity: LootRarity.rare,
        battleNumber: battleNumber,
        bias: role,
        preferredArmor: preferred,
        roleTag: roleTag,
        dungeonId: dungeonId,
      ),
  };
}

PartyHero _withGear(PartyHero base, Map<EquipmentSlot, EquipmentItem> gear) =>
    base.copyWith(equipped: Map<EquipmentSlot, EquipmentItem>.from(gear));

GameState _blankMeta() =>
    GameLogic.createInitialState(now: DateTime(2026, 8, 11));

({int clears, int wipes, double avgSec}) _combatTrials({
  required bool geared,
  required int floor,
  required int trials,
  int bn = 10,
}) {
  final times = <double>[];
  var wipes = 0;
  for (var i = 0; i < trials; i++) {
    final base = geared ? _partyGeared(battleNumber: bn) : _partyNaked();
    final r = _simulateFloor(_forceFloor(base, dungeonId: 'sandy', floor: floor));
    if (r.wiped || r.timedOut) {
      wipes++;
    } else {
      times.add(r.seconds);
    }
  }
  final avg =
      times.isEmpty ? 0.0 : times.reduce((a, b) => a + b) / times.length;
  return (clears: times.length, wipes: wipes, avgSec: avg);
}

GameState _partyNaked() {
  var s = GameLogic.createInitialState(now: DateTime(2026, 8, 11));
  s = s.copyWith(gold: 50000);
  for (var i = 0; i < 5; i++) {
    s = GameLogic.trainParty(s);
  }
  return s;
}

GameState _partyGeared({required int battleNumber}) {
  var s = _partyNaked();
  final heroes = <PartyHero>[
    for (final h in s.heroes)
      _withGear(
        h,
        _fullSet(
          role: h.gearAffinity,
          battleNumber: battleNumber,
          seed: 3 + h.gearAffinity.index,
        ),
      ).healToFull(),
  ];
  return s.copyWith(heroes: heroes);
}

GameState _forceFloor(
  GameState base, {
  required String dungeonId,
  required int floor,
}) {
  var state = GameLogic.enterDungeon(base, dungeonId: dungeonId);
  state = GameLogic.setDungeonMode(state, DungeonMode.push);
  if (floor > state.highestFloorCleared) {
    state = state.copyWith(highestFloorCleared: floor);
  }
  if (GameLogic.canTravelToFloor(state, floor)) {
    return GameLogic.travelToFloor(state, floor);
  }
  final room = DungeonGenerator.generateFloor(
    floor,
    dungeonId: dungeonId,
    ascensionLevel: state.ascensionLevel,
  ).first;
  return state.copyWith(
    currentRoom: room,
    dungeonFloor: <DungeonRoom>[room],
    enemies: GameLogic.createEnemyGroup(room, dungeonId: dungeonId),
    dungeonId: dungeonId,
    inDungeon: true,
    layoutSeed: GameLogic.newLayoutSeed(),
  );
}

({bool wiped, bool timedOut, double seconds}) _simulateFloor(GameState state) {
  var world = SpatialCombat.build(state);
  var current = state;
  const dt = 1 / 30;
  var t = 0.0;
  const maxT = 90.0;
  while (t < maxT) {
    final step = SpatialCombat.step(world, current, dt: dt);
    world = step.world;
    current = step.state;
    t += dt;
    if (step.partyWiped) {
      return (wiped: true, timedOut: false, seconds: t);
    }
    if (step.roomCleared) {
      return (wiped: false, timedOut: false, seconds: t);
    }
  }
  return (wiped: false, timedOut: true, seconds: t);
}
