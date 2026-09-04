import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_dispatcher.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/local_season.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  final now = DateTime.utc(2026, 8, 29);

  GameState endgameParty({MetaDepthState? meta}) {
    final base = GameLogic.createInitialState(now: now);
    final md = meta ??
        base.metaDepth.copyWith(
          dailyVaultClears: 0,
          dailyVaultClaimed: false,
          dailyBestTimedKey: 1,
        );
    return base.copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
      highestDungeonCleared: 14,
      heroRoster: [
        for (final h in base.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
      metaDepth: md,
    );
  }

  test('meet hero and bag map to GEAR intents', () {
    final state = GameLogic.createInitialState(now: now);
    final meet = ChaseDispatcher.plan(
      const HubChase(
        kind: HubChaseKind.meetHero,
        title: 'Meet',
        detail: '',
      ),
      state: state,
    );
    expect(meet.op, ChaseOp.navMeetHero);
    expect(
      ChaseDispatcher.navIntent(meet, state)?.gear,
      GearPanel.gear,
    );

    final bag = ChaseDispatcher.plan(
      const HubChase(
        kind: HubChaseKind.equipBag,
        title: 'Bag',
        detail: '',
      ),
      state: state,
    );
    expect(bag.label, 'OPEN BAG');
    expect(ChaseDispatcher.navIntent(bag, state)?.gear, GearPanel.bag);
  });

  test('market upgrade maps to POWER shop', () {
    final state = GameLogic.createInitialState(now: now);
    final plan = ChaseDispatcher.plan(
      const HubChase(
        kind: HubChaseKind.marketUpgrade,
        title: 'Shop',
        detail: '',
      ),
      state: state,
    );
    expect(plan.op, ChaseOp.navMarket);
    expect(ChaseDispatcher.navIntent(plan, state)?.power, PowerSegment.market);
  });

  test('vault halfway KEY +2 plans enterKey not bare ENTER', () {
    final state = endgameParty();
    expect(GameLogic.endgameUnlocked(state), isTrue);
    expect(GameLogic.showKeystoneJargon(state), isTrue);

    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.dailyVaultProgress);
    expect(chase.keyLevel, 2);
    expect(chase.urgency, HubChaseUrgency.almost);

    final plan = ChaseDispatcher.plan(
      chase,
      state: state,
      selectedZoneId: 'sandy',
    );
    expect(plan.op, ChaseOp.enterKey);
    expect(plan.keyLevel, 2);
    expect(plan.label, contains('ENTER KEY +2'));
  });

  test('month ALMOST KEY maps to enterKey; READY still claims', () {
    const monthKey = '2026-08';
    final month = LocalSeasonCatalog.forMonthKey(monthKey);
    expect(month.timedKeyTarget, greaterThan(0));

    final state = endgameParty(
      meta: MetaDepthState(
        monthPassKey: monthKey,
        monthlyBestTimedKey: month.timedKeyTarget - 1,
        dailyBestTimedKey: 0,
        dailyVaultClaimed: true,
      ),
    );

    final almostPlan = ChaseDispatcher.plan(
      const HubChase(
        kind: HubChaseKind.monthGoal,
        title: 'Almost',
        detail: '',
        urgency: HubChaseUrgency.almost,
      ),
      state: state,
      selectedZoneId: 'sandy',
    );
    expect(almostPlan.op, ChaseOp.enterKey);
    expect(almostPlan.keyLevel, month.timedKeyTarget);

    final readyPlan = ChaseDispatcher.plan(
      const HubChase(
        kind: HubChaseKind.monthGoal,
        title: 'Claim',
        detail: '',
        urgency: HubChaseUrgency.ready,
      ),
      state: state,
    );
    expect(readyPlan.op, ChaseOp.claimMonth);
    expect(readyPlan.label, 'CLAIM MONTH');
  });

  test('month ALMOST GR maps to Greater Rift confirm', () {
    String? tideKey;
    for (var y = 2026; y <= 2028; y++) {
      for (var m = 1; m <= 12; m++) {
        final k = '$y-${m.toString().padLeft(2, '0')}';
        if (LocalSeasonCatalog.forMonthKey(k).grTierTarget > 0) {
          tideKey = k;
          break;
        }
      }
      if (tideKey != null) break;
    }
    expect(tideKey, isNotNull);
    final month = LocalSeasonCatalog.forMonthKey(tideKey!);
    expect(month.grTierTarget, greaterThan(0));

    final state = endgameParty(
      meta: MetaDepthState(
        monthPassKey: tideKey,
        monthlyBestGrTier: month.grTierTarget - 1,
        dailyBestTimedKey: 0,
        dailyVaultClaimed: true,
      ),
    );

    final plan = ChaseDispatcher.plan(
      const HubChase(
        kind: HubChaseKind.monthGoal,
        title: 'Almost',
        detail: '',
        urgency: HubChaseUrgency.almost,
      ),
      state: state,
    );
    expect(plan.op, ChaseOp.confirmGreaterRift);
    expect(plan.label, contains('GREATER RIFT'));
  });

  test('week ALMOST timed KEY maps to enterKey', () {
    final week = LocalSeasonCatalog.weeks.firstWhere(
      (w) =>
          w.timedKeyTarget > 0 &&
          w.gauntletFloorTarget <= 0 &&
          w.weekKey != null,
    );
    final state = endgameParty(
      meta: MetaDepthState(
        weeklyKey: week.weekKey!,
        weeklyBestTimedKey: week.timedKeyTarget - 1,
        dailyBestTimedKey: 0,
        dailyVaultClaimed: true,
      ),
    );

    final plan = ChaseDispatcher.plan(
      const HubChase(
        kind: HubChaseKind.weekGoal,
        title: 'Almost',
        detail: '',
        urgency: HubChaseUrgency.almost,
      ),
      state: state,
      selectedZoneId: 'sandy',
    );
    expect(plan.op, ChaseOp.enterKey);
    expect(plan.keyLevel, week.timedKeyTarget);
  });

  test('prestige catalog ownedCount is zero on a fresh meta blob', () {
    const meta = MetaDepthState();
    expect(PrestigeShopCatalog.ownedCount(meta, 'stash_slot'), 0);
    expect(PrestigeShopCatalog.atCap(meta, 'stash_slot'), isFalse);
  });
}
