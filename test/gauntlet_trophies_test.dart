import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/gauntlet_anomaly.dart';
import 'package:idle_party/core/gauntlet_pact.dart';
import 'package:idle_party/core/gauntlet_trophies.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/logic_notices.dart';
import 'package:idle_party/core/meta_systems.dart';

void main() {
  final now = DateTime.utc(2026, 10, 13);

  test('the first squeeze pays once, a row titles, all 12 grant a STAR', () {
    LogicNotices.takeMetaPayoffs();
    var state = GameLogic.createInitialState(now: now).copyWith(
      inGauntlet: true,
      gauntletPact: GauntletPact.might.name,
    );
    final before = state.essence;
    state = GauntletTrophies.onSqueezeClear(state, floor: 1);
    expect(
      state.metaDepth.spireTrophies,
      [GauntletTrophies.keyFor(GauntletPact.might, GauntletAnomaly.tightCorridors)],
    );
    expect(state.essence, before + GauntletTrophies.firstEssence);
    expect(LogicNotices.takeMetaPayoffs().join(' '), contains('TIGHT'));

    final again = GauntletTrophies.onSqueezeClear(state, floor: 1);
    expect(again.essence, state.essence);
    expect(again.metaDepth.spireTrophies, state.metaDepth.spireTrophies);

    final boss = GauntletTrophies.onSqueezeClear(state, floor: 5);
    expect(boss.metaDepth.spireTrophies, state.metaDepth.spireTrophies);

    state = GauntletTrophies.onSqueezeClear(state, floor: 2);
    state = GauntletTrophies.onSqueezeClear(state, floor: 3);
    state = GauntletTrophies.onSqueezeClear(state, floor: 4);
    expect(state.metaDepth.titles, contains('Mightbound'));
    expect(GauntletTrophies.rowComplete(state.metaDepth.spireTrophies, GauntletPact.might), isTrue);

    for (final pact in [GauntletPact.ward, GauntletPact.greed]) {
      var climb = state.copyWith(gauntletPact: pact.name);
      for (var floor = 1; floor <= 4; floor++) {
        climb = GauntletTrophies.onSqueezeClear(climb, floor: floor);
      }
      state = climb;
    }
    expect(state.metaDepth.spireTrophies, hasLength(12));
    expect(state.metaDepth.titles, containsAll(['Mightbound', 'Wardbound', 'Greedbound']));
    final stars = state.metaDepth.constellationPointsEarned;
    expect(stars, 1);
    final extra = GauntletTrophies.onSqueezeClear(state, floor: 1);
    expect(extra.metaDepth.constellationPointsEarned, stars);
    LogicNotices.takeMetaPayoffs();
  });

  test('an old save has no trophies, and Ascend keeps them', () {
    final fresh = GameLogic.createInitialState(now: now);
    final json = fresh.toJson();
    final meta = Map<String, dynamic>.from(json['metaDepth'] as Map);
    meta.remove('spireTrophies');
    json['metaDepth'] = meta;
    expect(GameLogic.stateFromJson(json).metaDepth.spireTrophies, isEmpty);

    final held = fresh.copyWith(
      bossVictories: GameLogic.bossesRequiredForAscension(0),
      essence: 9999,
      metaDepth: fresh.metaDepth.copyWith(
        spireTrophies: const ['might:tightCorridors'],
      ),
    );
    expect(
      GameLogic.ascend(held).metaDepth.spireTrophies,
      ['might:tightCorridors'],
    );
  });

  test('TODAY names the next missing trophy when Gauntlet is the chase', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
      hardmodeLevel: GameLogic.maxAscensionLevel,
      metaDepth: state.metaDepth.copyWith(dailyVaultClaimed: true),
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
      achievements: [for (var i = 0; i < 160; i++) 'ach_$i'],
      highestDungeonCleared: 8,
      lifetimeGoldEarned: 5000000,
    );
    state = _maxParty(state);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.gauntletMilestone);
    expect(chase.detail, contains('Next trophy: MIGHT · TIGHT'));
  });
}

GameState _maxParty(GameState state) {
  return state.copyWith(
    heroRoster: [
      for (final hero in state.heroRoster)
        hero.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
    ],
  );
}
