import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/gear_loadout.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/market_listing.dart';

/// Flat JSON keys Ascend zeros. A renamed or nested key fails this list.
const ascendResetKeys = <String>{
  'gold',
  'attackBonus',
  'defenseBonus',
  'vitalityBonus',
  'moveSpeedBonus',
  'attackSpeedBonus',
  'critBonus',
  'masteryBonus',
  'recentLoot',
  'equipped',
  'gearStash',
  'marketListings',
  'loadouts',
  'highestFloorCleared',
  'lastFloorClearSec',
};

/// Flat JSON keys Ascend copies through unchanged.
const ascendKeepKeys = <String>{
  'partyName',
  'lifetimeGoldEarned',
  'unlockedRelics',
  'highestDungeonCleared',
  'ownedPets',
  'sanctuaryGoldLevel',
  'sanctuaryPowerLevel',
  'sanctuaryVitalityLevel',
  'sanctuaryDefenseLevel',
  'godHandLevel',
  'soundMuted',
  'sfxVolume',
  'ambienceVolume',
  'musicVolume',
  'codexEnemies',
  'codexItems',
  'colorblindMode',
  'hideHealFloaters',
  'compactCombatNumbers',
  'alwaysShowEnemyHp',
  'uiTextScale',
  'hapticsEnabled',
  'keepScreenAwake',
  'sessionTelemetryOptIn',
};

void main() {
  test('Ascend keep and reset keys stay flat on toJson', () {
    final item = EquipmentItem(
      id: 'helm-1',
      name: 'Test Helm',
      slot: EquipmentSlot.head,
      rarity: LootRarity.common,
    );
    final before = GameLogic.createInitialState(
      now: DateTime.utc(2026, 9, 1),
      partyName: 'The Ember Guard',
    ).copyWith(
      bossVictories: 1,
      gold: 4321,
      lifetimeGoldEarned: 9000,
      essence: 40,
      attackBonus: 3,
      defenseBonus: 4,
      vitalityBonus: 5,
      moveSpeedBonus: 2,
      attackSpeedBonus: 2,
      critBonus: 1,
      masteryBonus: 6,
      highestFloorCleared: 4,
      lastFloorClearSec: 80,
      highestDungeonCleared: 2,
      godHandLevel: 2,
      gearStash: [item],
      marketListings: [
        MarketListing(
          id: 'm1',
          item: item,
          priceGold: 50,
          targetHeroIndex: -1,
          slot: EquipmentSlot.head,
        ),
      ],
      loadouts: [
        const GearLoadout(
          id: 'l1',
          name: 'Farm',
          heroSlotItemIds: [<String, String>{}],
        ),
      ],
      recentLoot: [
        const LootDrop(name: 'scrap', amount: 1, rarity: LootRarity.common),
      ],
      equipped: {EquipmentSlot.head: item},
    );

    final beforeJson = before.toJson();
    expect(beforeJson.containsKey('run'), isFalse);
    expect(beforeJson.containsKey('runBag'), isFalse);
    expect(beforeJson.keys.toSet(), containsAll(ascendResetKeys));
    expect(beforeJson.keys.toSet(), containsAll(ascendKeepKeys));
    expect(ascendResetKeys.intersection(ascendKeepKeys), isEmpty);

    final ascended = GameLogic.ascend(before, now: DateTime.utc(2026, 9, 2));
    final afterJson = ascended.toJson();

    expect(afterJson.keys.toSet(), beforeJson.keys.toSet());
    expect(afterJson.containsKey('run'), isFalse);
    expect(afterJson['gold'], 0);
    expect(afterJson['attackBonus'], 0);
    expect(afterJson['defenseBonus'], 0);
    expect(afterJson['vitalityBonus'], 0);
    expect(afterJson['moveSpeedBonus'], 0);
    expect(afterJson['attackSpeedBonus'], 0);
    expect(afterJson['critBonus'], 0);
    expect(afterJson['masteryBonus'], 0);
    expect(afterJson['recentLoot'], isEmpty);
    expect(afterJson['equipped'], isEmpty);
    expect(afterJson['gearStash'], isEmpty);
    expect(afterJson['marketListings'], isEmpty);
    expect(afterJson['loadouts'], isEmpty);
    expect(afterJson['highestFloorCleared'], 0);
    expect(afterJson['lastFloorClearSec'], 0);

    for (final key in ascendKeepKeys) {
      expect(afterJson[key], beforeJson[key], reason: key);
    }

    expect(afterJson['ascensionLevel'], 1);
    expect(afterJson['bossVictories'], 0);
    expect(ascended.essence, greaterThan(before.essence));

    final roundTrip = GameState.fromJson(afterJson).toJson();
    expect(roundTrip.keys.toSet(), afterJson.keys.toSet());
    expect(roundTrip['gold'], 0);
    expect(roundTrip['partyName'], 'The Ember Guard');
    expect(roundTrip['lifetimeGoldEarned'], 9000);
  });
}
