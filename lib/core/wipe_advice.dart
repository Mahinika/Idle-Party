import '../models/loot.dart';
import '../models/meta_depth.dart';
import '../spatial/spatial_combat.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'market_listings_service.dart';
import 'menu_alerts.dart';
import 'menu_router.dart';
import 'nav_intent.dart';

/// Fight numbers from SpatialCombat at the wipe frame.
class WipeFightSnapshot {
  const WipeFightSnapshot({
    required this.waveHp,
    required this.remainingHp,
    required this.damageDealt,
    required this.damageTaken,
    required this.partyMaxHp,
    required this.elapsedSec,
  });

  /// Awake (non-dormant) enemy max HP this floor, including dead ones.
  final int waveHp;
  final int remainingHp;
  final int damageDealt;
  final int damageTaken;
  final int partyMaxHp;
  final double elapsedSec;

  double get leftover => waveHp <= 0 ? 0 : remainingHp / waveHp;

  factory WipeFightSnapshot.fromWorld(SpatialWorld world) {
    var waveHp = 0;
    var remaining = 0;
    for (final e in world.enemies) {
      if (e.dormant) continue;
      waveHp += e.maxHp;
      if (e.hp > 0) remaining += e.hp;
    }
    var dealt = 0;
    var taken = 0;
    var maxHp = 0;
    for (final h in world.heroes) {
      dealt += h.damageDealt;
      taken += h.damageTaken;
      maxHp += h.maxHp;
    }
    return WipeFightSnapshot(
      waveHp: waveHp,
      remainingHp: remaining,
      damageDealt: dealt,
      damageTaken: taken,
      partyMaxHp: maxHp,
      elapsedSec: world.combatElapsed,
    );
  }
}

/// Player-facing wipe hint.
///
/// GOLD / bag / KEY lines only fire when fight numbers (or bag state) prove a
/// gap. Stay quiet otherwise — no guess after repeated wipes.
abstract final class WipeAdvice {
  /// GOLD ATK/STA track tips wait for two wipes on the same floor.
  static const int streakNeeded = 2;

  /// First-hour stand-in when GOLD tracks are still hidden (DEF, wipe 1).
  static const String gearWearLine = 'Wear loot in GEAR';

  /// High-confidence tips safe on the first wipe (bag, floor gap, early melt).
  static bool isImmediate(String line) =>
      line.startsWith('Equip') ||
      line == gearWearLine ||
      line.contains('too far') ||
      line == 'Upgrade DEF in GOLD' ||
      line.contains('MARKET has an upgrade') ||
      line.contains('Shop has an upgrade') ||
      line.startsWith('MARKET:') ||
      line.startsWith('GOLD:') ||
      line.startsWith('SHOP:');

  /// Short nudge under the wipe advice when the fix lives in hub menus.
  static String? hubHintFor(String adviceLine) {
    if (adviceLine.isEmpty) return null;
    if (adviceLine.contains('dial down') ||
        adviceLine.contains('may be high')) {
      return 'HUB → KEY to lower the dial';
    }
    if (adviceLine.contains('MARKET') ||
        adviceLine.contains('SHOP') ||
        adviceLine.contains('Shop') ||
        adviceLine.startsWith('GOLD:')) {
      return 'HUB → GOLD → MARKET for the listing';
    }
    if (adviceLine.startsWith('Equip')) {
      return 'HUB → BAG to equip the upgrade';
    }
    if (adviceLine == gearWearLine || adviceLine.contains(' in GEAR')) {
      return 'HUB → GEAR to wear loot';
    }
    if (adviceLine.contains(' in GOLD') ||
        adviceLine.contains('Upgrade ATK') ||
        adviceLine.contains('Upgrade DEF') ||
        adviceLine.contains('Upgrade STA')) {
      return 'HUB → GOLD tracks for run power';
    }
    return null;
  }

  /// Menu to open after RETURN when the tip names a hub fix.
  static NavIntent? hubNavFor(String adviceLine) {
    if (adviceLine.isEmpty) return null;
    if (adviceLine.contains('dial down') ||
        adviceLine.contains('may be high')) {
      return const NavIntent(route: MenuRoute.key);
    }
    if (adviceLine.contains('MARKET') ||
        adviceLine.contains('SHOP') ||
        adviceLine.contains('Shop') ||
        adviceLine.startsWith('GOLD:')) {
      return NavIntent.market;
    }
    if (adviceLine.startsWith('Equip')) {
      return const NavIntent(route: MenuRoute.gear, gear: GearPanel.bag);
    }
    if (adviceLine == gearWearLine || adviceLine.contains(' in GEAR')) {
      return const NavIntent(route: MenuRoute.gear);
    }
    if (adviceLine.contains(' in GOLD') ||
        adviceLine.contains('Upgrade ATK') ||
        adviceLine.contains('Upgrade DEF') ||
        adviceLine.contains('Upgrade STA')) {
      return NavIntent.gold;
    }
    return null;
  }

  /// Short wipe-panel CTA when [hubNavFor] has a destination.
  static String? hubCtaLabelFor(String adviceLine) {
    final nav = hubNavFor(adviceLine);
    if (nav == null) return null;
    if (nav.route == MenuRoute.key) return 'OPEN KEY';
    if (nav.goldPanel == GoldPanel.market) return 'OPEN GOLD';
    if (nav.route == MenuRoute.shop) return 'OPEN SHOP';
    if (nav.gear == GearPanel.bag) return 'OPEN BAG';
    if (nav.route == MenuRoute.gear) return 'OPEN GEAR';
    if (nav.route == MenuRoute.gold) return 'OPEN GOLD';
    return null;
  }

  static String _forgeOrMarket(GameState state, String forgeLine) {
    if (!MenuTabs.showGold(state)) {
      // DEF stays first-wipe; ATK/STA still wait for streakNeeded.
      return forgeLine.contains('DEF') ? gearWearLine : 'Get stronger in GEAR';
    }
    final listing = MarketListingsService.bestAffordableUpgradeListing(state);
    if (listing != null) {
      return 'GOLD: ${listing.item.name} · ${listing.priceGold}g';
    }
    return forgeLine;
  }

  static String _slotLabel(EquipmentSlot slot) => switch (slot) {
        EquipmentSlot.weapon => 'weapon',
        EquipmentSlot.offHand => 'off-hand',
        EquipmentSlot.ranged => 'ranged',
        EquipmentSlot.head => 'helm',
        EquipmentSlot.chest => 'chest',
        EquipmentSlot.boots => 'boots',
        EquipmentSlot.ring || EquipmentSlot.ring2 => 'ring',
        EquipmentSlot.trinket || EquipmentSlot.trinket2 => 'trinket',
        _ => slot.name,
      };

  static String? _bagUpgradeLine(GameState state) {
    final upgrades = MenuAlerts.bagUpgradeCount(state);
    if (upgrades <= 0) return null;
    final plan = GameLogic.planBiSAssignments(state);
    if (plan.isEmpty) {
      return upgrades == 1
          ? 'Equip the better item in BAG'
          : 'Equip better gear in BAG';
    }
    final first = plan.first;
    final heroName =
        first.heroIndex >= 0 && first.heroIndex < state.heroes.length
            ? state.heroes[first.heroIndex].name
            : 'a hero';
    final slotName = _slotLabel(first.slot);
    if (upgrades == 1) {
      return 'Equip better $slotName on $heroName (BAG)';
    }
    return 'Equip better gear on $heroName +${upgrades - 1} more (BAG)';
  }

  /// Nudge God Hand after repeated wipes on the same floor (commit path — no redesign).
  static String? godHandHintFor(GameState state) {
    if (state.wipeStreakCount < 2 ||
        state.inGauntlet ||
        state.inAnyRiftMode) {
      return null;
    }
    return GameLogic.plainPlayerChrome(state)
        ? 'Tap the fight — steer party + smash'
        : 'Tap God Hand — steer party + AOE smash';
  }

  /// English line for the dungeon wipe panel, or null if we must stay quiet.
  ///
  /// GOLD ATK/STA still wait for [streakNeeded] via [GameLogic.notePartyWipe].
  static String? lineFor({
    required GameState state,
    required WipeFightSnapshot fight,
    int? wipeStreak,
  }) {
    assert(wipeStreak == null || wipeStreak >= 0);
    return _provenLineFor(state: state, fight: fight);
  }

  /// Deficit-backed tips only. Null when fight numbers do not prove a gap.
  static String? _provenLineFor({
    required GameState state,
    required WipeFightSnapshot fight,
  }) {
    final bag = _bagUpgradeLine(state);
    if (bag != null) return bag;

    if (state.gearStash.length >= GameLogic.maxGearStashFor(state) - 1) {
      return 'Bag nearly full — equip upgrades or CLEAN BAG';
    }

    if (state.inWorldBoss && fight.leftover >= 0.20) {
      return 'Ashen Crown hits hard — try PRACTICE free, then spend a ticket';
    }

    if (state.inGauntlet && fight.leftover >= 0.35) {
      final floor = state.currentRoom.floorNumber;
      final nextMilestone = GauntletMilestones.floors
          .where((f) => f > floor)
          .cast<int?>()
          .firstOrNull;
      if (nextMilestone != null) {
        return 'Spire climb is steep — PB F$floor; next milestone F$nextMilestone';
      }
      return 'Spire climb is steep — leave and retry from hub (lower floors)';
    }
    if (state.inGreaterRift && fight.leftover >= 0.35) {
      final tier = state.grTier > 0 ? state.grTier : state.metaDepth.grBestTier;
      return 'GR$tier may be high — dial down Ranked GR on KEY';
    }
    if (state.inRift && fight.leftover >= 0.35) {
      final tier = state.riftTier > 0 ? state.riftTier : state.metaDepth.riftBestTier;
      return 'Farm Rift R$tier may be high — dial down on KEY';
    }

    if (state.hardmodeLevel > 0 &&
        state.hardmodeLevel > state.ascensionLevel + 4 &&
        fight.leftover >= 0.35) {
      return 'KEY +${state.hardmodeLevel} may be high — dial down on KEY';
    }

    // Instant / early melt: prove DEF when the pack crushed the party fast.
    // Wide enough that sub-2s melts still tip (not silent panel).
    if (fight.waveHp >= 1 &&
        fight.leftover >= 0.40 &&
        fight.elapsedSec <= 8 &&
        fight.partyMaxHp > 0 &&
        fight.damageTaken >= fight.partyMaxHp * 0.4) {
      return _forgeOrMarket(state, 'Upgrade DEF in GOLD');
    }

    // Sub-half-second wipe with almost-full pack + real HP loss = melt.
    if (fight.elapsedSec < 0.5 &&
        fight.waveHp >= 1 &&
        fight.leftover >= 0.85 &&
        fight.partyMaxHp > 0 &&
        fight.damageTaken >= fight.partyMaxHp * 0.5) {
      return _forgeOrMarket(state, 'Upgrade DEF in GOLD');
    }

    if (fight.elapsedSec < 0.5 || fight.waveHp < 1 || fight.damageDealt < 1) {
      return null;
    }

    final leftover = fight.leftover;
    final floor = state.currentRoom.floorNumber;
    if (!state.inGauntlet &&
        floor > state.highestFloorCleared + 2 &&
        leftover >= 0.45) {
      return 'This floor is too far — retry a lower floor';
    }

    final dps = fight.damageDealt / fight.elapsedSec;
    final ttk = fight.waveHp / dps;
    final atkGap = ttk / fight.elapsedSec;
    if (atkGap >= 1.35 && leftover >= 0.35) {
      return _forgeOrMarket(state, 'Upgrade ATK in GOLD');
    }

    // DPS was enough to nearly finish; they ran out of body.
    if (atkGap <= 0.75 && leftover < 0.40 && fight.partyMaxHp > 0) {
      final overkill = fight.damageTaken / fight.partyMaxHp;
      if (overkill >= 1.20) {
        return _forgeOrMarket(state, 'Upgrade DEF in GOLD');
      }
      if (overkill <= 1.08) {
        return _forgeOrMarket(state, 'Upgrade STA in GOLD');
      }
    }
    return null;
  }
}
