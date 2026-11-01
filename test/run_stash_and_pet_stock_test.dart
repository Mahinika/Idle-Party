import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gear/gear_stash.dart';
import 'package:idle_party/core/pet_errand_stock.dart';
import 'package:idle_party/core/pet_service.dart';
import 'package:idle_party/core/run_stash_shop.dart';
import 'package:idle_party/models/pet.dart';

void main() {
  final now = DateTime.utc(2026, 11, 1, 12);

  test('gold and cinder bag buys increase cap and persist fields', () {
    var state = GameLogic.createInitialState(now: now).copyWith(
      gold: 500000,
      metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
            cinders: 50,
          ),
    );
    final baseCap = GearStash.maxGearStashFor(state);
    expect(RunStashShop.canBuyGold(state), isTrue);
    state = RunStashShop.buyGoldExpansion(state);
    expect(state.metaDepth.stashGoldBuys, 1);
    expect(GearStash.maxGearStashFor(state), baseCap + 5);
    state = RunStashShop.buyGoldExpansion(state);
    expect(state.metaDepth.stashGoldBuys, 2);
    expect(RunStashShop.canBuyGold(state), isFalse);
    state = RunStashShop.buyCinderExpansion(state);
    expect(state.metaDepth.stashCinderBuys, 1);
    expect(state.metaDepth.cinders, 25);
    expect(GearStash.maxGearStashFor(state), baseCap + 10 + 10);
  });

  test('pet errand stock rolls UTC day and consumes sends', () {
    var state = GameLogic.createInitialState(now: now).copyWith(
      ownedPets: const [
        Pet(
          id: 'cave_bat_1',
          name: 'Cave Bat',
          attackBonus: 3,
          speciesId: 'cave_bat',
        ),
      ],
      metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
            petErrandStockUtcDay: '',
            petErrandStockRemaining: 0,
          ),
    );
    expect(PetErrandStock.creditsRemaining(state, now: now), 3);
    state = PetService.sendErrand(state, 'cave_bat_1', 4, now: now);
    expect(PetErrandStock.creditsRemaining(state, now: now), 2);
    final tomorrow = now.add(const Duration(days: 1));
    expect(PetErrandStock.creditsRemaining(state, now: tomorrow), 3);
  });

  test('bigger shipment raises daily cap and costs cinders', () {
    var state = GameLogic.createInitialState(now: now).copyWith(
      metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
            cinders: 11,
            petShipmentBonus: 0,
          ),
    );
    expect(PetErrandStock.canBuyShipmentBonus(state), isFalse);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(cinders: 12),
    );
    expect(PetErrandStock.canBuyShipmentBonus(state), isTrue);
    state = PetErrandStock.buyShipmentBonus(state, now: now);
    expect(state.metaDepth.petShipmentBonus, 1);
    expect(PetErrandStock.maxCredits(state.metaDepth), 4);
  });
}
