import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_contract.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/market_listings_service.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/models/loot.dart';

void main() {
  const nowMs = 1_750_000_000_000;

  GameState al20({int gold = 500_000}) {
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 22));
    state = GameLogic.enterDungeon(state, dungeonId: 'brass');
    return GameLogic.ensureMarketListings(
      state.copyWith(
        ascensionLevel: 20,
        gold: gold,
        hardmodeLevel: 12,
        highestFloorCleared: 40,
        highestDungeonCleared: 14,
        bossVictories: 99,
      ),
      nowMs: nowMs,
    );
  }

  test('affordable MARKET upgrade becomes TODAY chase when bag is quiet', () {
    final state = al20();
    expect(
      MarketListingsService.hasAffordableUpgradeListing(state),
      isTrue,
      reason: 'seeded AL20 should have at least one affordable upgrade',
    );
    final chase = HubChase.forState(state);
    expect(chase.kind, HubChaseKind.marketUpgrade);
    expect(chase.urgency, HubChaseUrgency.ready);
    expect(chase.title.toLowerCase(), contains('market'));
    final contract = ChaseContract.fromState(state);
    expect(contract.isClaimable, isTrue);
    expect(contract.readyActionLabel, 'MARKET');
  });

  test('BAG equip beats MARKET in chase priority', () {
    var state = al20();
    state = state.copyWith(
      gearStash: [
        EquipmentItem(
          id: 'up_weapon',
          name: 'Test Blade',
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.epic,
          attackBonus: 80,
          strengthBonus: 60,
          itemLevel: 120,
        ),
      ],
    );
    expect(MenuAlerts.bagUpgradeCount(state), greaterThan(0));
    final chase = HubChase.forState(state);
    expect(chase.kind, HubChaseKind.equipBag);
    expect(chase.urgency, HubChaseUrgency.ready);
  });
}
