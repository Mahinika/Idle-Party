import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/check_in.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  final now = DateTime.utc(2026, 8, 9, 12);

  GameState ready(
    DateTime clock, {
    int bosses = 1,
    int day = 1,
    int zone = 0,
  }) {
    final month = GameLogic.isoMonthKey(clock);
    return GameLogic.createInitialState(now: clock).copyWith(
      bossVictories: bosses,
      highestDungeonCleared: zone,
      metaDepth: MetaDepthState(
        dailyVaultDate: MetaSystems.dailyDateKey(clock),
        dailyVaultClears: 1,
        dailyVaultClaimed: false,
        checkInDay: day,
        claimedSeasonRewards: [month],
      ),
    );
  }

  test('days 1–6 pay a large prize and day 7 pays the jackpot', () {
    final day1 = GameLogic.claimDailyVault(ready(now), now: now);
    expect(day1.metaDepth.checkInDay, 2);
    expect(day1.essence - ready(now).essence, greaterThanOrEqualTo(100));
    expect(day1.gold, ready(now).gold);

    final day2 = GameLogic.claimDailyVault(ready(now, day: 2), now: now);
    expect(day2.gold - ready(now, day: 2).gold, 2000);
    expect(day2.metaDepth.checkInDay, 3);

    final day3 = GameLogic.claimDailyVault(ready(now, day: 3), now: now);
    expect(day3.metaDepth.embers, 8);

    final day4 = GameLogic.claimDailyVault(ready(now, day: 4), now: now);
    expect(day4.metaDepth.cinders, 5);

    final day5 = GameLogic.claimDailyVault(ready(now, day: 5), now: now);
    expect(day5.metaDepth.adTickets, 6);

    final before6 = ready(now, day: 6);
    final day6 = GameLogic.claimDailyVault(before6, now: now);
    expect(day6.essence - before6.essence, day1.essence - ready(now).essence);
    expect(day6.gold - before6.gold, 2000);

    final before7 = ready(now, day: 7, zone: 2);
    final day7 = GameLogic.claimDailyVault(before7, now: now);
    final gain1 = day1.essence - ready(now).essence;
    expect(day7.metaDepth.checkInDay, 1);
    expect(day7.essence - before7.essence, greaterThan(gain1));
    expect(day7.gold - before7.gold, 30000);
    expect(day7.metaDepth.embers, 24);
    expect(day7.metaDepth.cinders, 13);
    expect(day7.metaDepth.adTickets, 12);
    expect(day7.lifetimeGoldEarned, before7.lifetimeGoldEarned + 30000);
  });

  test('a missed day does not reset the row', () {
    final later = DateTime.utc(2026, 8, 12, 12);
    var state = GameLogic.claimDailyVault(ready(now, day: 3), now: now);
    expect(state.metaDepth.checkInDay, 4);
    state = GameLogic.ensureDailyVault(state, now: later);
    expect(state.metaDepth.dailyVaultClaimed, isFalse);
    expect(state.metaDepth.checkInDay, 4);
    expect(GameLogic.checkInWelcomeLine(state), contains('Check-in 4/7'));
    expect(GameLogic.checkInWelcomeLine(state), contains('Cinders'));
    expect(GameLogic.checkInWelcomeLine(state).toLowerCase(), contains('one cave'));
    expect(
      GameLogic.checkInWelcomeLine(state).toLowerCase(),
      isNot(contains('waits on the vault')),
    );
  });

  test('first-hour vault claim does not start check-in', () {
    final state = ready(now, bosses: 0);
    expect(GameLogic.checkInActive(state), isFalse);
    expect(GameLogic.checkInWelcomeLine(state), isEmpty);
    final claimed = GameLogic.claimDailyVault(state, now: now);
    final bossBase = ready(now, bosses: 1);
    expect(claimed.metaDepth.checkInDay, 1);
    expect(claimed.gold, state.gold);
    expect(claimed.metaDepth.embers, 0);
    expect(claimed.metaDepth.cinders, 1);
    expect(
      GameLogic.dailyVaultClaimPreviewEssence(state, now: now),
      GameLogic.dailyVaultClaimEssence(state),
    );
    expect(
      GameLogic.dailyVaultClaimPreviewEssence(bossBase, now: now),
      GameLogic.dailyVaultClaimEssence(bossBase) + 100,
    );
  });

  test('hub names the prize and tomorrow after the claim', () {
    final state = ready(now, day: 7);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.claimDailyVault);
    expect(chase.title, 'Claim Daily Vault');
    expect(chase.detail, contains('Check-in 7/7 jackpot'));
    expect(chase.detail, contains('Ad Tickets'));
    expect(GameLogic.checkInWelcomeLine(state), contains('waits on the vault'));

    final claimed = GameLogic.claimDailyVault(state, now: now);
    expect(GameLogic.checkInWelcomeLine(claimed), startsWith('Tomorrow · Check-in 1/7'));
    expect(
      GameLogic.dailyVaultClaimPreviewEssence(state, now: now),
      GameLogic.dailyVaultClaimEssence(state) + CheckIn.payout(
        day: 7,
        sanctuaryCost: GameLogic.cheapestSanctuaryNextCost(state),
        zoneScale: 1,
      ).essence,
    );
  });

  test('legacy saves start on day 1 and the day round-trips', () {
    final legacy = MetaDepthState.fromJson(<String, dynamic>{});
    expect(legacy.checkInDay, 1);
    final odd = MetaDepthState.fromJson(<String, dynamic>{'checkInDay': 0});
    expect(odd.checkInDay, 1);
    final saved = ready(now, day: 6).metaDepth;
    final round = MetaDepthState.fromJson(saved.toJson());
    expect(round.checkInDay, 6);
  });
}
