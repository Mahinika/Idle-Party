import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/greater_rift.dart';
import 'package:idle_party/core/rift.dart';

GameState _endgameParty() {
  final seed = GameLogic.createInitialState();
  return seed.copyWith(
    ascensionLevel: 20,
    heroRoster: [
      for (final hero in seed.heroRoster) hero.copyWith(level: 100),
    ],
  );
}

void main() {
  test('IP-402 LEAVE on Ranked GR names consolation essence', () async {
    final director = GameDirector.preview(initialState: _endgameParty());
    addTearDown(director.dispose);
    await director.boot();
    const tier = 72;
    director.enterGreaterRift(tier: tier);
    final before = director.state.essence;
    director.leaveDungeon();
    expect(
      director.state.essence,
      before + GreaterRift.failEssence(tier),
    );
    expect(director.toast, isNotNull);
    expect(director.toast!, contains('+24e'));
  });

  test('IP-402 LEAVE on Farm Rift names consolation essence', () async {
    final director = GameDirector.preview(initialState: _endgameParty());
    addTearDown(director.dispose);
    await director.boot();
    const tier = 96;
    director.enterRift(tier: tier);
    final before = director.state.essence;
    director.leaveDungeon();
    expect(director.state.essence, before + Rift.failEssence(tier));
    expect(director.toast, isNotNull);
    expect(director.toast!.toLowerCase(), contains('+24e'));
  });
}