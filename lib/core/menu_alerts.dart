import '../models/loot.dart';
import 'gear_service.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'hub_chase.dart';
import 'market_listings_service.dart';
import 'meta_systems.dart';

/// Which bottom-nav destination an alert belongs to.
enum MenuPillar { gear, power, quests, key, more }

/// One "something is waiting here" mark for a menu button.
class MenuAlert {
  const MenuAlert({this.count = 0, this.star = false, this.reason = ''});

  final int count;
  final bool star;
  final String reason;

  static const MenuAlert quiet = MenuAlert();

  bool get isQuiet => count <= 0 && !star;

  String get badge => star
      ? '★'
      : count > 0
      ? '$count'
      : '';
}

/// Menu attention marks — one source for hub buttons and the bottom nav.
class MenuAlerts {
  const MenuAlerts({
    required this.gear,
    required this.power,
    required this.quests,
    required this.key,
    required this.more,
  });

  final MenuAlert gear;
  final MenuAlert power;
  final MenuAlert quests;
  final MenuAlert key;
  final MenuAlert more;

  MenuAlert of(MenuPillar pillar) => switch (pillar) {
    MenuPillar.gear => gear,
    MenuPillar.power => power,
    MenuPillar.quests => quests,
    MenuPillar.key => key,
    MenuPillar.more => more,
  };

  static const MenuAlerts none = MenuAlerts(
    gear: MenuAlert.quiet,
    power: MenuAlert.quiet,
    quests: MenuAlert.quiet,
    key: MenuAlert.quiet,
    more: MenuAlert.quiet,
  );

  static MenuAlerts forState(GameState state) => MenuAlerts(
    gear: gearAlert(state),
    power: powerAlert(state),
    quests: questsAlert(state),
    key: keyAlert(state),
    more: moreAlert(state),
  );

  /// Dungeon bottom-nav marks — keep fight chrome quiet.
  static MenuAlerts forDungeon(GameState state) {
    final upgrades = bagUpgradeCount(state);
    if (upgrades <= 0) return none;
    return MenuAlerts(
      gear: MenuAlert(
        count: upgrades,
        reason: upgrades == 1
            ? '1 better item for the party — open GEAR · EQUIP'
            : '$upgrades better items for the party — open GEAR · EQUIP',
      ),
      power: MenuAlert.quiet,
      quests: MenuAlert.quiet,
      key: MenuAlert.quiet,
      more: MenuAlert.quiet,
    );
  }

  /// Hub bottom nav — quiet badges when TODAY owns the next step.
  static MenuAlerts forHub(
    GameState state, {
    HubChaseKind? chaseKind,
    HubChaseUrgency urgency = HubChaseUrgency.normal,
  }) {
    if (GameLogic.plainPlayerChrome(state)) {
      final upgrades = bagUpgradeCount(state);
      if (upgrades <= 0) return none;
      return MenuAlerts(
        gear: MenuAlert(
          count: upgrades,
          reason: upgrades == 1
              ? '1 better item — open GEAR'
              : '$upgrades better items — open GEAR',
        ),
        power: MenuAlert.quiet,
        quests: MenuAlert.quiet,
        key: MenuAlert.quiet,
        more: MenuAlert.quiet,
      );
    }
    if (urgency == HubChaseUrgency.ready && chaseKind != null) {
      return switch (chaseKind) {
        HubChaseKind.equipBag || HubChaseKind.meetHero => MenuAlerts(
          gear: gearAlert(state),
          power: MenuAlert.quiet,
          quests: MenuAlert.quiet,
          key: MenuAlert.quiet,
          more: MenuAlert.quiet,
        ),
        HubChaseKind.marketUpgrade => MenuAlerts(
          gear: MenuAlert.quiet,
          power: powerAlert(state),
          quests: MenuAlert.quiet,
          key: MenuAlert.quiet,
          more: MenuAlert.quiet,
        ),
        HubChaseKind.claimMissions ||
        HubChaseKind.claimDailyVault ||
        HubChaseKind.dailyVaultProgress => MenuAlerts(
          gear: MenuAlert.quiet,
          power: MenuAlert.quiet,
          quests: questsAlert(state),
          key: MenuAlert.quiet,
          more: MenuAlert.quiet,
        ),
        _ => forState(state),
      };
    }
    return forState(state);
  }

  static MenuAlert gearAlert(GameState state) {
    final meets = state.metaDepth.pendingHeroReveals.length;
    if (meets > 0) {
      return MenuAlert(
        count: meets,
        reason: meets == 1
            ? 'A new hero joined — put them in the party'
            : '$meets new heroes joined — put them in the party',
      );
    }
    final upgrades = bagUpgradeCount(state);
    if (upgrades > 0) {
      return MenuAlert(
        count: upgrades,
        reason: upgrades == 1
            ? '1 better item for the party — open GEAR · EQUIP'
            : '$upgrades better items for the party — open GEAR · EQUIP',
      );
    }
    if (isBagFull(state)) {
      return MenuAlert(star: true, reason: bagStatusLine(state));
    }
    return MenuAlert.quiet;
  }

  /// Backward-compatible alias used by inventory hints.
  static MenuAlert partyAlert(GameState state) => gearAlert(state);

  static MenuAlert powerAlert(GameState state) {
    var count = 0;
    final reasons = <String>[];
    final forgeType =
        PartyUpgradeType.values[GameLogic.recommendedForgeUpgrade(state)];
    if (state.gold >= GameLogic.upgradeCostFor(state, forgeType) * 3) {
      count++;
      reasons.add('gold for FORGE');
    }
    if (state.essence >= GameLogic.sanctuaryCost(cheapestCampLevel(state))) {
      count++;
      reasons.add('essence for CAMP');
    }
    final hasFlask = state.heroes.any(
      (h) => h.itemIn(EquipmentSlot.consumable) != null,
    );
    if (!hasFlask &&
        !state.challengeNoFlask &&
        state.gold >= GameLogic.marketFlaskCost(state)) {
      count++;
      reasons.add('gold for a MARKET flask');
    }
    if (MarketListingsService.hasAffordableUpgradeListing(state)) {
      count++;
      reasons.add('gold for MARKET upgrade');
    }
    if (count <= 0) return MenuAlert.quiet;
    return MenuAlert(count: count, reason: 'You have ${reasons.join(' · ')}');
  }

  static MenuAlert questsAlert(GameState state) {
    var count = 0;
    final reasons = <String>[];
    final jobs = state.missions.where((m) => m.canClaim).length;
    if (jobs > 0) {
      count += jobs;
      reasons.add(jobs == 1 ? '1 quest done' : '$jobs quests done');
    }
    if (GameLogic.canClaimDailyVault(state)) {
      count++;
      reasons.add('daily vault ready');
    }
    if (count <= 0) return MenuAlert.quiet;
    return MenuAlert(count: count, reason: 'Claim: ${reasons.join(' · ')}');
  }

  static MenuAlert keyAlert(GameState state) {
    if (!GameLogic.endgameUnlocked(state) || !MenuTabs.showKey(state)) {
      return MenuAlert.quiet;
    }
    final cap = state.ascensionLevel.clamp(0, GameLogic.maxAscensionLevel);
    if (state.hardmodeLevel < cap) {
      return MenuAlert(
        count: 1,
        reason: 'KEY +${state.hardmodeLevel + 1} ready',
      );
    }
    return MenuAlert.quiet;
  }

  static MenuAlert moreAlert(GameState state) {
    if (MetaSystems.hasUnseenChangelog(state)) {
      return const MenuAlert(
        star: true,
        reason: "What's New is unread — MORE · INFO",
      );
    }
    return MenuAlert.quiet;
  }

  /// Legacy META-style alert for surfaces that still ask "meta".
  static MenuAlert metaAlert(GameState state) {
    final more = moreAlert(state);
    if (!more.isQuiet) return more;
    final quests = questsAlert(state);
    if (!quests.isQuiet) return quests;
    return keyAlert(state);
  }

  static int cheapestCampLevel(GameState state) {
    var lowest = state.sanctuaryGoldLevel;
    for (final level in <int>[
      state.sanctuaryPowerLevel,
      state.sanctuaryVitalityLevel,
      state.metaDepth.sanctuaryXpLevel,
    ]) {
      if (level < lowest) lowest = level;
    }
    return lowest;
  }

  static bool isBagFull(GameState state) =>
      state.gearStash.length >= GameLogic.maxGearStashFor(state);

  static int bagUpgradeCount(GameState state) {
    if (state.gearStash.isEmpty) return 0;
    return GameLogic.planBiSAssignments(state).length;
  }

  static int bagUpgradeCountForHero(GameState state, int heroIndex) {
    if (state.gearStash.isEmpty) return 0;
    if (heroIndex < 0 || heroIndex >= state.heroes.length) return 0;
    var n = 0;
    for (final step in GameLogic.planBiSAssignments(state)) {
      if (step.heroIndex == heroIndex) n++;
    }
    return n;
  }

  static String bagStatusLine(GameState state) {
    if (bagUpgradeCount(state) > 0) return '';
    if (GearService.isBagJammed(state) && !isBagFull(state)) {
      return 'Nearly full — SETTINGS auto-sell may junk weak gear; CLEAN BAG or MERGE';
    }
    if (!isBagFull(state)) return '';
    if (state.gearStash.isEmpty) return 'Bag is full — CLEAN BAG';
    return 'Bag full — backups kept; CLEAN BAG or MERGE';
  }

  static String meetRosterHint(GameState state) {
    if (state.metaDepth.pendingHeroReveals.isEmpty) return '';
    return 'New kit — open ROSTER in GEAR';
  }

  static String gearEquipHint(GameState state, int heroIndex) {
    final meet = meetRosterHint(state);
    if (meet.isNotEmpty) return meet;

    final total = bagUpgradeCount(state);
    if (total <= 0) {
      return bagStatusLine(state);
    }
    final forHero = bagUpgradeCountForHero(state, heroIndex);
    if (forHero <= 0) {
      return total == 1
          ? '1 better item for another hero — use EQUIP'
          : '$total better items for other heroes — use EQUIP';
    }
    if (forHero == total) {
      return forHero == 1
          ? '1 better item for this hero — use EQUIP'
          : '$forHero better items for this hero — use EQUIP';
    }
    return '$forHero for this hero · $total party — use EQUIP';
  }
}

/// Progressive menus: hide advanced panels until they can do something.
abstract final class MenuTabs {
  static bool _clearedAFloor(GameState s) =>
      s.highestFloorCleared >= 1 ||
      s.metaDepth.lifetimeFloorClears >= 1 ||
      s.ascensionLevel >= 1;

  static bool showMerge(GameState s) =>
      s.ascensionLevel >= 1 || s.highestDungeonCleared >= 0;
  static bool showRoster(GameState s) =>
      s.ascensionLevel >= 1 || s.metaDepth.pendingHeroReveals.isNotEmpty;

  static bool showCamp(GameState s) => s.ascensionLevel >= 1 || s.essence > 0;
  static bool showShop(GameState s) => s.ascensionLevel >= 1;

  static bool showKey(GameState s) => GameLogic.showKeystoneJargon(s);
  static bool showBeast(GameState s) =>
      s.ascensionLevel >= 1 ||
      s.ownedPets.isNotEmpty ||
      s.essence >= GameLogic.hatchPetCost(s);
  static bool showCodex(GameState s) => _clearedAFloor(s);
}
