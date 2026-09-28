import '../models/loot.dart';
import 'gear_service.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'hub_chase.dart';
import 'keystone.dart';
import 'market_listings_service.dart';
import 'menu_router.dart';
import 'meta_systems.dart';

/// One "something is waiting here" mark for a menu button.
class MenuAlert {
  const MenuAlert({this.count = 0, this.star = false, this.reason = ''});

  final int count;
  final bool star;
  final String reason;

  static const MenuAlert quiet = MenuAlert();

  /// Compact “new” mark for nav badges — UI paints [UiIcon.star], not this glyph.
  static const String starMark = '★';

  bool get isQuiet => count <= 0 && !star;

  String get badge => star
      ? starMark
      : count > 0
      ? '$count'
      : '';
}

/// Menu attention marks — one source for hub buttons and the bottom nav.
class MenuAlerts {
  const MenuAlerts({
    required this.gear,
    required this.gold,
    required this.shop,
    required this.essence,
    required this.key,
    required this.more,
  });

  final MenuAlert gear;
  final MenuAlert gold;
  final MenuAlert shop;
  final MenuAlert essence;
  final MenuAlert key;
  final MenuAlert more;

  static const MenuAlerts none = MenuAlerts(
    gear: MenuAlert.quiet,
    gold: MenuAlert.quiet,
    shop: MenuAlert.quiet,
    essence: MenuAlert.quiet,
    key: MenuAlert.quiet,
    more: MenuAlert.quiet,
  );

  static MenuAlerts forState(GameState state) => MenuAlerts(
    gear: gearAlert(state),
    gold: goldAlert(state),
    shop: MenuAlert.quiet,
    essence: essenceAlert(state),
    key: keyAlert(state),
    more: moreAlert(state),
  );

  /// Dungeon bottom-nav marks — badge only, no reason ticker (wipe/GEAR own copy).
  static MenuAlerts forDungeon(GameState state) {
    final upgrades = bagUpgradeCount(state);
    if (upgrades <= 0) return none;
    return MenuAlerts(
      gear: MenuAlert(count: upgrades, reason: ''),
      gold: MenuAlert.quiet,
      shop: MenuAlert.quiet,
      essence: MenuAlert.quiet,
      key: MenuAlert.quiet,
      more: MenuAlert.quiet,
    );
  }

  /// Hub bottom nav — quiet badges when TODAY owns the next step.
  static MenuAlerts forHub(
    GameState state, {
    HubChaseKind? chaseKind,
    HubChaseUrgency urgency = HubChaseUrgency.normal,
    bool enterPrimary = false,
  }) {
    if (!enterPrimary && urgency != HubChaseUrgency.ready) {
      final upgrades = bagUpgradeCount(state);
      if (upgrades <= 0) return none;
      return MenuAlerts(
        gear: MenuAlert(count: upgrades, reason: ''),
        gold: MenuAlert.quiet,
        shop: MenuAlert.quiet,
        essence: MenuAlert.quiet,
        key: MenuAlert.quiet,
        more: MenuAlert.quiet,
      );
    }
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
        gold: MenuAlert.quiet,
        shop: MenuAlert.quiet,
        essence: MenuAlert.quiet,
        key: MenuAlert.quiet,
        more: MenuAlert.quiet,
      );
    }
    if (urgency == HubChaseUrgency.ready && chaseKind != null) {
      return switch (chaseKind) {
        HubChaseKind.equipBag || HubChaseKind.meetHero => () {
          final g = gearAlert(state);
          // Badge only — TODAY / EQUIP CTA already names the job (#16).
          return MenuAlerts(
            gear: MenuAlert(count: g.count, star: g.star),
            gold: MenuAlert.quiet,
            shop: MenuAlert.quiet,
            essence: MenuAlert.quiet,
            key: MenuAlert.quiet,
            more: MenuAlert.quiet,
          );
        }(),
        HubChaseKind.marketUpgrade => MenuAlerts(
          gear: MenuAlert.quiet,
          gold: marketAlert(state),
          shop: MenuAlert.quiet,
          essence: MenuAlert.quiet,
          key: MenuAlert.quiet,
          more: MenuAlert.quiet,
        ),
        HubChaseKind.claimMissions ||
        HubChaseKind.claimDailyVault ||
        HubChaseKind.dailyVaultProgress => MenuAlerts(
          gear: MenuAlert.quiet,
          gold: MenuAlert.quiet,
          shop: MenuAlert.quiet,
          essence: MenuAlert.quiet,
          key: MenuAlert.quiet,
          more: moreAlert(
            state,
            omitVault:
                chaseKind == HubChaseKind.claimDailyVault ||
                chaseKind == HubChaseKind.dailyVaultProgress,
          ),
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

  static MenuAlert goldAlert(GameState state) => forgeAlert(state);

  static MenuAlert forgeAlert(GameState state) {
    final forgeType =
        PartyUpgradeType.values[GameLogic.recommendedForgeUpgrade(state)];
    final cost = GameLogic.upgradeCostFor(state, forgeType);
    if (state.gold >= cost) {
      return MenuAlert(
        count: 1,
        reason: 'BEST ${forgeType.name.toUpperCase()} affordable',
      );
    }
    return MenuAlert.quiet;
  }

  /// Flasks / listings under GOLD → MARKET.
  static MenuAlert marketAlert(GameState state) {
    var count = 0;
    final reasons = <String>[];
    final hasFlask = state.heroes.any(
      (h) => h.itemIn(EquipmentSlot.consumable) != null,
    );
    if (!hasFlask &&
        !state.challengeNoFlask &&
        state.gold >= GameLogic.marketFlaskCost(state)) {
      count++;
      reasons.add('gold for a flask');
    }
    if (MarketListingsService.hasAffordableUpgradeListing(state)) {
      count++;
      reasons.add('gold for an upgrade');
    }
    if (count <= 0) return MenuAlert.quiet;
    return MenuAlert(count: count, reason: 'Market: ${reasons.join(' · ')}');
  }

  static MenuAlert essenceAlert(GameState state) {
    if (!MenuTabs.showCamp(state)) return MenuAlert.quiet;
    final cheapest = cheapestCampLevel(state);
    final cost = GameLogic.sanctuaryCost(cheapest);
    if (state.essence >= cost) {
      return MenuAlert(count: 1, reason: 'Camp track affordable');
    }
    return MenuAlert.quiet;
  }

  static MenuAlert questsAlert(GameState state, {bool omitVault = false}) {
    var count = 0;
    final reasons = <String>[];
    final jobs = state.missions.where((m) => m.canClaim).length;
    if (jobs > 0) {
      count += jobs;
      reasons.add(jobs == 1 ? '1 quest done' : '$jobs quests done');
    }
    if (!omitVault && GameLogic.canClaimDailyVault(state)) {
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
    final unlocked = Keystone.maxForState(state);
    if (unlocked <= 0) return MenuAlert.quiet;
    final cap = unlocked < Keystone.campaignCap
        ? unlocked
        : Keystone.campaignCap;
    if (state.hardmodeLevel < cap) {
      return MenuAlert(
        count: 1,
        reason: 'KEY +${state.hardmodeLevel + 1} ready',
      );
    }
    return MenuAlert.quiet;
  }

  static MenuAlert moreAlert(GameState state, {bool omitVault = false}) {
    final quests = questsAlert(state, omitVault: omitVault);
    if (MetaSystems.hasUnseenChangelog(state)) {
      if (!quests.isQuiet) {
        return MenuAlert(
          star: true,
          count: quests.count,
          reason: '${quests.count} to claim · Patch Notes',
        );
      }
      return const MenuAlert(star: true, reason: 'Patch Notes unread');
    }
    if (!quests.isQuiet) {
      return MenuAlert(
        count: quests.count,
        reason: quests.count == 1
            ? '1 claim ready — QUESTS'
            : '${quests.count} claims ready — QUESTS',
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
      state.sanctuaryDefenseLevel,
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
      final mergeBit = MenuTabs.showMerge(state)
          ? '; CLEAN BAG or MERGE'
          : '; CLEAN BAG';
      return 'Nearly full — FILTERS may junk weak gear$mergeBit';
    }
    if (!isBagFull(state)) return '';
    if (state.gearStash.isEmpty) return 'Bag is full — CLEAN BAG';
    final merge = MenuTabs.showMerge(state) ? ' or MERGE' : '';
    return 'Bag full — backups kept; CLEAN BAG$merge';
  }

  /// BAG panel idle line. Empty in the first hour unless the bag is jammed.
  /// Essence scrap waits for the ESSENCE tab ([showCamp]).
  static String bagPanelHint(GameState state) {
    final status = bagStatusLine(state);
    if (status.isNotEmpty) return status;
    if (bagUpgradeCount(state) > 0) return '';
    final jammed = GearService.isBagJammed(state);
    final full = isBagFull(state);
    if (!jammed && !full) return '';
    if (MenuTabs.showCamp(state)) {
      return full
          ? 'CLEAN BAG: gold first, then essence from leftovers'
          : 'CLEAN BAG: sell for gold first, then scrap for essence';
    }
    return 'CLEAN BAG: sell for gold';
  }

  static String bagEquipIdleTip(GameState state) {
    if (state.gearStash.isEmpty) return 'Bag empty — farm for drops';
    final merge = MenuTabs.showMerge(state);
    if (GameLogic.plainPlayerChrome(state)) {
      return merge
          ? 'No upgrades in bag — CLEAN BAG or MERGE junk'
          : 'No upgrades in bag — CLEAN BAG';
    }
    return merge
        ? 'No BiS upgrades in bag — CLEAN BAG or MERGE junk'
        : 'No BiS upgrades in bag — CLEAN BAG';
  }

  static String bagCleanButtonTip(GameState state) {
    if (MenuTabs.showCamp(state)) {
      return 'Merge, then sell gold and scrap essence for whatever matches FILTERS';
    }
    if (MenuTabs.showMerge(state)) {
      return 'Merge, then sell whatever matches FILTERS';
    }
    return 'Sells stash items that match FILTERS';
  }

  static String bagFiltersButtonTip(GameState state, {required bool showing}) {
    if (showing) {
      return MenuTabs.showCamp(state)
          ? 'Hide auto-sell and scrap rules'
          : 'Hide auto-sell rules';
    }
    return MenuTabs.showCamp(state)
        ? 'When bag is near full: sell gold vs scrap essence'
        : 'When bag is near full: sell junk for gold';
  }

  static String meetRosterHint(GameState state, {GearPanel? panel}) {
    if (state.metaDepth.pendingHeroReveals.isEmpty) return '';
    if (!MenuTabs.showRoster(state)) return '';
    if (panel == GearPanel.roster) {
      return 'Tap ADD to put the new kit in the party';
    }
    return 'New kit — open ROSTER tab';
  }

  static String gearEquipHint(
    GameState state,
    int heroIndex, {
    GearPanel? panel,
  }) {
    final meet = meetRosterHint(state, panel: panel);
    if (meet.isNotEmpty) return meet;

    final total = bagUpgradeCount(state);
    if (total <= 0) {
      return bagStatusLine(state);
    }
    final forHero = bagUpgradeCountForHero(state, heroIndex);
    if (forHero <= 0) {
      return total == 1
          ? '1 better item for another hero — tap EQUIP'
          : '$total better items for other heroes — tap EQUIP';
    }
    if (forHero == total) {
      return forHero == 1
          ? '1 better item for this hero — tap EQUIP'
          : '$forHero better items for this hero — tap EQUIP';
    }
    return '$forHero for this hero · $total party — tap EQUIP';
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

  /// GOLD tab — after the first reward (loot / floor / boss).
  static bool showGold(GameState s) => GameLogic.earnedFirstReward(s);

  /// Real-money SHOP — after the first boss (or first Ascend).
  static bool showShop(GameState s) => GameLogic.showDailyChase(s);

  /// Hub SCROLLS glyph — same unlock as SHOP (first boss / Ascend).
  static bool showScrolls(GameState s) => showShop(s);

  /// Blessing / God Hand / REBORN — after first-hour plain chrome.
  static bool showKeep(GameState s) => !GameLogic.plainPlayerChrome(s);

  /// Relics / Craft tabs — after first-hour plain chrome (same as old KEEP/APEX).
  static bool showRelics(GameState s) => !GameLogic.plainPlayerChrome(s);
  static bool showCraft(GameState s) => !GameLogic.plainPlayerChrome(s);

  /// QUESTS row — after first floor (or a claim is waiting).
  static bool showQuests(GameState s) =>
      _clearedAFloor(s) ||
      GameLogic.showDailyChase(s) ||
      s.missions.any((m) => m.canClaim);

  static bool showKey(GameState s) => GameLogic.showKeystoneJargon(s);
  static bool showBeast(GameState s) =>
      s.ascensionLevel >= 1 ||
      s.ownedPets.isNotEmpty ||
      s.essence >= GameLogic.hatchPetCost(s);
  static bool showCodex(GameState s) => _clearedAFloor(s);

  /// SETTINGS + What's New stay in MORE from day one.
  static bool showSettings(GameState s) => true;
  static bool showWhatsNew(GameState s) => true;
}
