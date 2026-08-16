import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/dungeon_def.dart';

/// A save file is the one thing a player can lose for good.
///
/// The fixtures under `test/fixtures/` are frozen on purpose: they are what old
/// builds actually wrote. If a change to `GameState` breaks them, it breaks
/// someone's party — the test has to fail before the release does.
void main() {
  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/$name').readAsStringSync())
          as Map<String, dynamic>;

  test('a v1 save still loads with its party, gold and progress', () {
    final state = GameLogic.stateFromJson(fixture('save_v1.json'));

    expect(state.heroes.map((h) => h.name), ['Bram', 'Sela', 'Ivy', 'Nyx']);
    expect(state.heroes.first.level, 7);
    expect(state.gold, 1450);
    // Achievements that the old save never tracked fire once on load and may
    // bump essence — never *lose* what was written.
    expect(state.essence, greaterThanOrEqualTo(12));
    expect(state.bossVictories, 1);
    expect(state.attackBonus, 4);
    expect(state.unlockedRelics, contains('war_banner'));
    // v1 had no rooms: the migration rebuilds a floor from `battleNumber`.
    expect(state.enemies, isNotEmpty);
    expect(state.currentRoom.floorNumber, 9);
    expect(state.missions, isNotEmpty);
    // Every active hero must still be in the roster, or PARTY renders blanks.
    for (final id in state.activeHeroIds) {
      expect(state.heroRoster.any((h) => h.id == id), isTrue, reason: id);
    }
  });

  test('save version is read from the file, not guessed', () {
    expect(GameLogic.saveVersionOf(fixture('save_v1.json')), 1);
    expect(
      GameLogic.saveVersionOf(
        GameLogic.createInitialState(now: DateTime(2026, 8, 16)).toJson(),
      ),
      GameState.saveVersion,
    );
    // Missing field, modern shape: treated as the room-based format, not v1.
    expect(GameLogic.saveVersionOf(<String, dynamic>{'enemies': []}), 2);
  });

  test('a save without lifetime gold keeps the zones it already opened', () {
    final fen = DungeonCatalog.byId('fen');
    final base = GameLogic.createInitialState(now: DateTime(2026, 8, 16));
    final deep = base.copyWith(
      highestDungeonCleared: fen.number,
      lifetimeGoldEarned: fen.unlockPrice + 5000,
      gold: 900,
    );

    // Old saves (and hand-edited ones) can be missing the field entirely.
    final json = deep.toJson()..remove('lifetimeGoldEarned');
    final loaded = GameLogic.stateFromJson(json);

    expect(loaded.lifetimeGoldEarned, greaterThanOrEqualTo(fen.unlockPrice));
    expect(
      DungeonCatalog.isUnlocked(
        'fen',
        loaded.lifetimeGoldEarned,
        loaded.highestDungeonCleared,
      ),
      isTrue,
    );
    // Wallet gold is a floor too: you cannot hold gold you never earned.
    final poor = GameLogic.stateFromJson(
      base.copyWith(gold: 4200).toJson()..remove('lifetimeGoldEarned'),
    );
    expect(poor.lifetimeGoldEarned, greaterThanOrEqualTo(4200));
  });

  test('a full round trip changes nothing the player can see', () {
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 8, 16)),
      dungeonId: 'sandy',
    ).copyWith(gold: 777, essence: 42, lifetimeGoldEarned: 9001);

    expect(state.inDungeon, isTrue, reason: 'sandy is always unlocked');

    final again = GameLogic.stateFromJson(
      jsonDecode(GameLogic.exportSaveJson(state)) as Map<String, dynamic>,
    );

    expect(again.gold, state.gold);
    expect(again.essence, greaterThanOrEqualTo(state.essence));
    expect(again.lifetimeGoldEarned, state.lifetimeGoldEarned);
    expect(again.dungeonId, state.dungeonId);
    expect(again.inDungeon, isTrue);
    expect(again.heroes.map((h) => h.id), state.heroes.map((h) => h.id));
    for (final id in again.activeHeroIds) {
      expect(again.heroRoster.any((h) => h.id == id), isTrue, reason: id);
    }
    expect(again.metaDepth.ascendBlessings, state.metaDepth.ascendBlessings);
  });

  test('changing who is in the party goes through withActiveParty', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 16));
    final solo = state.withActiveParty([state.heroes.first]);

    expect(solo.heroes.length, 1);
    expect(solo.heroRoster.length, state.heroRoster.length);
    // Same-party data updates stay on copyWith.
    final healed = solo.copyWith(
      heroes: [solo.heroes.first.copyWith(currentHp: 3)],
    );
    expect(healed.heroes.single.currentHp, 3);
    expect(
      () => solo.copyWith(heroes: state.heroes),
      throwsA(isA<AssertionError>()),
    );
  });
}
