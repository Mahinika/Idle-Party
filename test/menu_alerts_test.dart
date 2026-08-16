import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/loot.dart';

/// Menu badges must be honest: a number only when there is something to do.
void main() {
  final now = DateTime.utc(2026, 8, 8, 12);

  EquipmentItem bigWeapon(String id) => EquipmentItem(
        id: id,
        name: 'Test Blade',
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.epic,
        attackBonus: 40,
        strengthBonus: 30,
        itemLevel: 90,
      );

  test('fresh save keeps PARTY quiet and META starred by What’s New', () {
    final state = GameLogic.createInitialState(now: now);
    final alerts = MenuAlerts.forState(state);
    expect(alerts.party.isQuiet, isTrue);
    expect(alerts.party.badge, isEmpty);
    // New games are marked as having seen the current changelog.
    expect(MetaSystems.hasUnseenChangelog(state), isFalse);
    expect(alerts.meta.isQuiet, isTrue);
  });

  test('bag upgrades count on PARTY and name the EQUIP action', () {
    final base = GameLogic.createInitialState(now: now);
    final state = base.copyWith(gearStash: [bigWeapon('up_1')]);
    final alert = MenuAlerts.partyAlert(state);
    expect(alert.count, greaterThan(0));
    expect(alert.badge, alert.count.toString());
    expect(alert.reason.toUpperCase(), contains('EQUIP'));
    expect(MenuAlerts.bagUpgradeCount(state), alert.count);
  });

  test('upgrade count follows the bag, not a stale cache', () {
    final base = GameLogic.createInitialState(now: now);
    final withItem = base.copyWith(gearStash: [bigWeapon('up_2')]);
    expect(MenuAlerts.bagUpgradeCount(withItem), greaterThan(0));
    final emptied = withItem.copyWith(gearStash: const []);
    expect(MenuAlerts.bagUpgradeCount(emptied), 0);
  });

  test('new hero to meet outranks gear on PARTY', () {
    final base = GameLogic.createInitialState(now: now);
    final state = base.copyWith(
      gearStash: [bigWeapon('up_3')],
      metaDepth: base.metaDepth.copyWith(
        pendingHeroReveals: const ['combat'],
      ),
    );
    final alert = MenuAlerts.partyAlert(state);
    expect(alert.count, 1);
    expect(alert.reason.toLowerCase(), contains('new hero'));
  });

  test('unseen What’s New stars META, claims count instead', () {
    final base = GameLogic.createInitialState(now: now);
    final unseen = base.copyWith(seenChangelogVersion: '0.0.1');
    expect(MenuAlerts.metaAlert(unseen).star, isTrue);

    var claim = GameLogic.ensureWeeklyContract(base, now: now);
    claim = claim.copyWith(
      metaDepth: claim.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
      ),
    );
    final alert = MenuAlerts.metaAlert(claim);
    expect(alert.star, isFalse);
    expect(alert.count, greaterThan(0));
    expect(alert.reason.toLowerCase(), contains('claim'));
  });

  test('first-hour menus hide advanced tabs, Ascend opens them', () {
    final fresh = GameLogic.createInitialState(now: now);
    expect(MenuTabs.showMerge(fresh), isFalse);
    expect(MenuTabs.showLoadouts(fresh), isFalse);
    expect(MenuTabs.showRoster(fresh), isFalse);
    expect(MenuTabs.showCamp(fresh), isFalse);
    expect(MenuTabs.showShop(fresh), isFalse);
    expect(MenuTabs.showKey(fresh), isFalse);
    expect(MenuTabs.showCodex(fresh), isFalse);

    final veteran = fresh.copyWith(
      ascensionLevel: 2,
      highestDungeonCleared: 2,
      highestFloorCleared: 12,
    );
    expect(MenuTabs.showMerge(veteran), isTrue);
    expect(MenuTabs.showLoadouts(veteran), isTrue);
    expect(MenuTabs.showRoster(veteran), isTrue);
    expect(MenuTabs.showCamp(veteran), isTrue);
    expect(MenuTabs.showShop(veteran), isTrue);
    expect(MenuTabs.showKey(veteran), isTrue);
    expect(MenuTabs.showBeast(veteran), isTrue);
    expect(MenuTabs.showCodex(veteran), isTrue);
  });
}
