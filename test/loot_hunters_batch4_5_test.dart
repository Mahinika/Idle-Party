import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ability_mastery.dart';
import 'package:idle_party/core/farm_intensity.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/shop_billing.dart';
import 'package:idle_party/core/shop_catalog.dart';
import 'package:idle_party/core/shop_hub_offer.dart';
import 'package:idle_party/models/dungeon_mode.dart';

void main() {
  test('spellcraft level scales with lifetime casts', () {
    var state = GameLogic.createInitialState();
    expect(AbilityMastery.level(state), 0);
    expect(AbilityMastery.damageMul(state), 1.0);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(lifetimeAbilityCasts: 700),
    );
    expect(AbilityMastery.level(state), 2);
    expect(AbilityMastery.damageMul(state), closeTo(1.01, 0.001));
  });

  test('farm intensity applies on farm below highest clear', () {
    var state = GameLogic.createInitialState().copyWith(
      inDungeon: true,
      dungeonMode: DungeonMode.farm,
      ascensionLevel: 1,
      highestFloorCleared: 5,
      metaDepth: GameLogic.createInitialState().metaDepth.copyWith(
            farmIntensity: 4,
          ),
    );
    state = state.copyWith(
      currentRoom: state.currentRoom.copyWith(floorNumber: 3),
    );
    expect(FarmIntensity.applies(state), isTrue);
    expect(FarmIntensity.threatMult(state), 4.0);
  });

  test('shop hub offer window starts once SHOP unlocks', () {
    var state = GameLogic.createInitialState().copyWith(bossVictories: 1);
    expect(state.metaDepth.shopOfferStartedMs, 0);
    state = ShopHubOffer.ensureWindow(state, now: DateTime.utc(2026, 11, 1));
    expect(state.metaDepth.shopOfferStartedMs, greaterThan(0));
    expect(ShopHubOffer.showHubBadge(state, now: DateTime.utc(2026, 11, 1)), isTrue);
  });

  test('cinder pouch first buy doubles grant', () {
    final item = ShopCatalog.byId['cinder_pouch']!;
    var state = GameLogic.createInitialState();
    state = ShopBilling.applyPurchase(state, item);
    expect(state.metaDepth.cinders, 16);
    expect(state.metaDepth.cinderPouchDoubled, isTrue);
    final again = ShopBilling.applyPurchase(state, item);
    expect(again.metaDepth.cinders, 24);
  });
}
