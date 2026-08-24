import '../models/loot.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'market_listings_service.dart';
import 'meta_systems.dart';

/// Which bottom-nav pillar an alert belongs to.
enum MenuPillar { party, power, meta }

/// One "something is waiting here" mark for a menu button.
///
/// Counts beat stars: `PARTY 3` is more useful than a dot. [reason] is the
/// plain English line shown inside the menu so a new player knows what to do.
class MenuAlert {
  const MenuAlert({this.count = 0, this.star = false, this.reason = ''});

  /// Number of things the player can act on right now (0 = quiet).
  final int count;

  /// Something new to read rather than to count (What's New).
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
///
/// Same idea as [ChaseContract] for TODAY: selection lives here, every surface
/// reads the same words instead of inventing its own badge rules.
class MenuAlerts {
  const MenuAlerts({
    required this.party,
    required this.power,
    required this.meta,
  });

  final MenuAlert party;
  final MenuAlert power;
  final MenuAlert meta;

  MenuAlert of(MenuPillar pillar) => switch (pillar) {
    MenuPillar.party => party,
    MenuPillar.power => power,
    MenuPillar.meta => meta,
  };

  static const MenuAlerts none = MenuAlerts(
    party: MenuAlert.quiet,
    power: MenuAlert.quiet,
    meta: MenuAlert.quiet,
  );

  static MenuAlerts forState(GameState state) => MenuAlerts(
    party: partyAlert(state),
    power: powerAlert(state),
    meta: metaAlert(state),
  );

  /// PARTY: new heroes to meet, then bag upgrades, then a full bag.
  static MenuAlert partyAlert(GameState state) {
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
            ? '1 better item for the party — tap EQUIP 1'
            : '$upgrades better items for the party — tap EQUIP $upgrades',
      );
    }
    if (isBagFull(state)) {
      return MenuAlert(
        star: true,
        reason: bagStatusLine(state),
      );
    }
    return MenuAlert.quiet;
  }

  /// POWER: gold or essence that is clearly piling up unspent.
  ///
  /// Gold is always trickling in, so the mark needs real surplus (3 steps'
  /// worth) — a badge that never turns off teaches players to ignore badges.
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

  /// META: What's New first, then claims waiting.
  static MenuAlert metaAlert(GameState state) {
    if (MetaSystems.hasUnseenChangelog(state)) {
      return const MenuAlert(
        star: true,
        reason: "What's New is unread — GUIDE tab",
      );
    }
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

  /// Cheapest next Sanctuary track level (gold / power / stamina / lore).
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

  /// How many bag items Auto Equip would actually put on someone.
  ///
  /// The plan itself is memoized in [GameLogic.planBiSAssignments], so the
  /// badge can ask on every chrome repaint (~10 Hz in a live dungeon).
  static int bagUpgradeCount(GameState state) {
    if (state.gearStash.isEmpty) return 0;
    return GameLogic.planBiSAssignments(state).length;
  }

  /// Subset of [bagUpgradeCount] that would land on [heroIndex].
  static int bagUpgradeCountForHero(GameState state, int heroIndex) {
    if (state.gearStash.isEmpty) return 0;
    if (heroIndex < 0 || heroIndex >= state.heroes.length) return 0;
    var n = 0;
    for (final step in GameLogic.planBiSAssignments(state)) {
      if (step.heroIndex == heroIndex) n++;
    }
    return n;
  }

  /// Full-bag line when nothing is an Auto Equip upgrade (shared across PARTY UI).
  static String bagStatusLine(GameState state) {
    if (bagUpgradeCount(state) > 0) return '';
    if (!isBagFull(state)) return '';
    if (state.gearStash.isEmpty) return 'Bag is full — CLEAN BAG';
    return 'Bag full — backups kept; CLEAN BAG or merge';
  }

  /// Pending kit unlock — nudge toward ROSTER, not GEAR doll.
  static String meetRosterHint(GameState state) {
    if (state.metaDepth.pendingHeroReveals.isEmpty) return '';
    return 'New kit — open ROSTER tab';
  }

  /// GEAR-tab line: don't imply every upgrade is for the doll you are staring at.
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
          ? '1 better item for another hero — tap EQUIP 1'
          : '$total better items for other heroes — tap EQUIP $total';
    }
    if (forHero == total) {
      return forHero == 1
          ? '1 better item for this hero — tap EQUIP 1'
          : '$forHero better items for this hero — tap EQUIP $forHero';
    }
    return '$forHero for this hero · $total party — tap EQUIP $total';
  }
}

/// Progressive menus: hide advanced tabs until they can do something.
///
/// A brand new player sees PARTY · GEAR/BAG, POWER · FORGE/MARKET,
/// META · QUESTS/GUIDE/SETTINGS. Tabs appear as the systems behind them unlock.
abstract final class MenuTabs {
  static bool _clearedAFloor(GameState s) =>
      s.highestFloorCleared >= 1 ||
      s.metaDepth.lifetimeFloorClears >= 1 ||
      s.ascensionLevel >= 1;

  // PARTY
  static bool showMerge(GameState s) =>
      s.ascensionLevel >= 1 || s.highestDungeonCleared >= 0;
  static bool showRoster(GameState s) =>
      s.ascensionLevel >= 1 || s.metaDepth.pendingHeroReveals.isNotEmpty;

  // POWER
  static bool showCamp(GameState s) => s.ascensionLevel >= 1 || s.essence > 0;
  static bool showShop(GameState s) => s.ascensionLevel >= 1;

  // META
  static bool showKey(GameState s) => GameLogic.showKeystoneJargon(s);
  static bool showBeast(GameState s) =>
      s.ascensionLevel >= 1 ||
      s.ownedPets.isNotEmpty ||
      s.essence >= GameLogic.hatchPetCost(s);
  static bool showCodex(GameState s) => _clearedAFloor(s);
}
