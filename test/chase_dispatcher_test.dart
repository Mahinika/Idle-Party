import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_dispatcher.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  final now = DateTime.utc(2026, 8, 29);

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

  test('prestige catalog ownedCount is zero on a fresh meta blob', () {
    const meta = MetaDepthState();
    expect(PrestigeShopCatalog.ownedCount(meta, 'stash_slot'), 0);
    expect(PrestigeShopCatalog.atCap(meta, 'stash_slot'), isFalse);
  });
}
