import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/blessing_constellation.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/god_hand_mastery.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/local_season.dart';
import 'package:idle_party/core/mission_board.dart';
import 'package:idle_party/core/party_power.dart';
import 'package:idle_party/core/world_boss.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  test('endgame bounty ladder extends past 1000', () {
    expect(MissionBoard.bountyTargetsEndgame.last, 25000);
    expect(MissionBoard.bountyRungMax(endgame: true), 5);
    final md = const MetaDepthState(bountyRung: 5);
    expect(md.bountyRung, 5);
  });

  test('month pass ready when monthly KEY met', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
      metaDepth: state.metaDepth.copyWith(
        monthPassKey: '2026-08',
        monthlyBestTimedKey: 8,
        claimedMonthGoals: const [],
      ),
    );
    final month = LocalSeasonCatalog.forMonthKey('2026-08');
    expect(LocalSeasonCatalog.monthPassReady(state, month), isTrue);
    final chase = HubChase.forState(state);
    expect(chase.kind, HubChaseKind.monthGoal);
    expect(chase.urgency, HubChaseUrgency.ready);
    final claimed = GameLogic.claimMonthPass(state);
    expect(
      LocalSeasonCatalog.monthPassReady(claimed, month),
      isFalse,
    );
  });

  test('party power and constellation gate', () {
    final state = GameLogic.createInitialState();
    expect(PartyPower.score(state), greaterThanOrEqualTo(0));
    expect(BlessingConstellation.unlocked(state), isFalse);
    final al20 = state.copyWith(ascensionLevel: GameLogic.maxAscensionLevel);
    expect(BlessingConstellation.unlocked(al20), isTrue);
  });

  test('world boss week resets tickets', () {
    final state = WorldBoss.ensureWeek(
      GameLogic.createInitialState(),
      now: DateTime.utc(2026, 8, 24),
    );
    expect(state.metaDepth.worldBossTickets, WorldBoss.ticketsPerWeek);
  });

  test('god hand mastery smash milestone', () {
    var state = GameLogic.createInitialState().copyWith(
      metaDepth: const MetaDepthState(godHandSmashCount: 100),
    );
    expect(GodHandMastery.ready(state, 'gh_smash_100'), isTrue);
    state = GodHandMastery.claim(state, 'gh_smash_100');
    expect(GodHandMastery.ready(state, 'gh_smash_100'), isFalse);
  });
}
