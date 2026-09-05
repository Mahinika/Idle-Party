import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_contract.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';

void main() {
  OfflineProgressResult result({
    int bosses = 0,
    int floors = 0,
    int rooms = 0,
    int gold = 0,
    int essence = 0,
    int seconds = 120,
    int levels = 0,
    int gear = 0,
  }) {
    final state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 8));
    return OfflineProgressResult(
      state: state,
      secondsApplied: seconds,
      goldGained: gold,
      essenceGained: essence,
      roomsCleared: rooms,
      highestFloorDelta: floors,
      bossDelta: bosses,
      levelsGained: levels,
      gearFinds: gear,
    );
  }

  test('hasSummary shows gold/clears under 20s; other rewards need 20s', () {
    expect(result(gold: 10, seconds: 5).hasSummary, isTrue);
    expect(result(rooms: 1, seconds: 8).hasSummary, isTrue);
    expect(result(essence: 3, seconds: 10).hasSummary, isFalse);
    expect(result(essence: 3, seconds: 20).hasSummary, isTrue);
    expect(result(seconds: 60).hasSummary, isFalse);
  });

  test('banner headline is wow + away, not a number dump', () {
    final r = result(bosses: 2, gold: 500, essence: 12, rooms: 4);
    expect(r.headline, startsWith('Bosses fell'));
    expect(r.headline, contains('Away'));
    expect(r.headline, isNot(contains('+500g')));
    expect(r.headline, isNot(contains('ess')));
  });

  test('welcomeLead prioritizes bosses over floors', () {
    final r = result(bosses: 1, floors: 3, rooms: 5, gold: 99);
    expect(r.welcomeLead.toLowerCase(), contains('boss'));
    expect(r.welcomeLead.toLowerCase(), isNot(contains('rooms')));
  });

  test('welcomeLead prefers party levels over rooms when no boss', () {
    final r = result(levels: 2, floors: 3, rooms: 8, gold: 40);
    expect(r.welcomeLead.toLowerCase(), contains('level'));
    expect(r.headline, startsWith('Party grew'));
    expect(r.highlightRows.first.$1, 'Party levels');
  });

  test('highlightRows caps at 3 and ranks bosses first', () {
    final r = result(
      bosses: 2,
      floors: 3,
      rooms: 8,
      essence: 10,
      gold: 400,
    );
    expect(r.highlightRows.length, OfflineProgressResult.maxHighlightRows);
    expect(r.highlightRows.first.$1, 'Bosses defeated');
    expect(r.highlightRows.map((e) => e.$1), isNot(contains('Gold earned')));
  });

  test('sanctuary AFK uses calm lead and gold/essence rows', () {
    final r = result(gold: 80, essence: 5);
    expect(r.foughtWhileAway, isFalse);
    expect(r.welcomeLead.toLowerCase(), contains('sanctuary'));
    expect(r.headline, startsWith('Sanctuary earned'));
    expect(r.highlightRows.length, lessThanOrEqualTo(3));
  });

  test('Up next kind matches ChaseContract for same state', () {
    final r = result(gold: 10);
    final contract = ChaseContract.fromState(r.state);
    expect(contract.kind, isNot(HubChaseKind.claimDailyVault));
    expect(contract.upNextLine, startsWith('Up next'));
  });
}
