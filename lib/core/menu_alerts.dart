import '../models/loot.dart';
import 'game_logic.dart';
import 'game_state.dart';
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
            ? '1 better item in the bag — tap EQUIP 1'
            : '$upgrades better items in the bag — tap EQUIP $upgrades',
      );
    }
    if (isBagFull(state)) {
      return const MenuAlert(
        star: true,
        reason: 'Bag is full — SELL JUNK or SCRAP in BAG',
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
    if (state.gold >= GameLogic.upgradeCostFor(state, forgeType) * 3 ||
        state.gold >= GameLogic.partyTrainingCostFor(state) * 3) {
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
    final jobs = state.missions.where((m) => m.isComplete).length;
    if (jobs > 0) {
      count += jobs;
      reasons.add(jobs == 1 ? '1 job done' : '$jobs jobs done');
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
}

/// Progressive menus: hide advanced tabs until they can do something.
///
/// A brand new player sees PARTY · GEAR/BAG, POWER · FORGE/MARKET,
/// META · JOBS/GUIDE/SET. Tabs appear as the systems behind them unlock.
abstract final class MenuTabs {
  static bool _clearedAFloor(GameState s) =>
      s.highestFloorCleared >= 1 ||
      s.metaDepth.lifetimeFloorClears >= 1 ||
      s.ascensionLevel >= 1;

  // PARTY
  static bool showMerge(GameState s) =>
      s.ascensionLevel >= 1 || s.highestDungeonCleared >= 0;
  static bool showLoadouts(GameState s) =>
      s.ascensionLevel >= 1 || s.highestDungeonCleared >= 1;
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
