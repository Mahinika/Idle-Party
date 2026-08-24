import '../spatial/spatial_combat.dart';
import 'game_state.dart';
import 'market_listings_service.dart';
import 'menu_alerts.dart';

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

/// Player-facing wipe hint. Returns null when the sim cannot prove a deficit.
abstract final class WipeAdvice {
  /// FORGE tips wait for two wipes on the same floor (was three).
  static const int streakNeeded = 2;

  /// High-confidence tips safe on the first wipe (bag, floor gap, early melt).
  static bool isImmediate(String line) =>
      line.startsWith('Equip') ||
      line.contains('too far') ||
      line == 'Upgrade DEF in FORGE' ||
      line.contains('MARKET has an upgrade');

  /// Short nudge under the wipe advice when the fix lives in hub menus.
  static String? hubHintFor(String adviceLine) {
    if (adviceLine.isEmpty) return null;
    if (adviceLine.contains('MARKET') ||
        adviceLine.startsWith('Equip') ||
        adviceLine.contains('FORGE')) {
      return 'Tap HUB when safe to fix gear';
    }
    return null;
  }

  static String _forgeOrMarket(GameState state, String forgeLine) {
    if (MarketListingsService.hasAffordableUpgradeListing(state)) {
      return 'POWER → MARKET has an upgrade';
    }
    return forgeLine;
  }

  /// Nudge God Hand after repeated wipes on the same floor (commit path — no redesign).
  static String? godHandHintFor(GameState state) {
    if (state.wipeStreakCount < 2 || state.inGauntlet || state.inRift) {
      return null;
    }
    return 'Before retry: tap God Hand — steer party + AOE smash';
  }

  /// English line for the dungeon wipe panel, or null if we must stay quiet.
  static String? lineFor({
    required GameState state,
    required WipeFightSnapshot fight,
  }) {
    final upgrades = MenuAlerts.bagUpgradeCount(state);
    if (upgrades > 0) {
      return upgrades == 1
          ? 'Equip the better item in PARTY'
          : 'Equip better gear in PARTY';
    }

    if (fight.elapsedSec < 2 || fight.waveHp < 1 || fight.damageDealt < 1) {
      return null;
    }

    final leftover = fight.leftover;
    final floor = state.currentRoom.floorNumber;
    if (!state.inGauntlet &&
        floor > state.highestFloorCleared + 2 &&
        leftover >= 0.45) {
      return 'This floor is too far — retry a lower floor';
    }

    // Melted before the pack moved: incoming damage, not a long DPS check.
    if (fight.elapsedSec <= 6 && leftover >= 0.50) {
      return _forgeOrMarket(state, 'Upgrade DEF in FORGE');
    }

    final dps = fight.damageDealt / fight.elapsedSec;
    final ttk = fight.waveHp / dps;
    final atkGap = ttk / fight.elapsedSec;
    if (atkGap >= 1.35 && leftover >= 0.35) {
      return _forgeOrMarket(state, 'Upgrade ATK in FORGE');
    }

    // DPS was enough to nearly finish; they ran out of body.
    if (atkGap <= 0.75 && leftover < 0.40 && fight.partyMaxHp > 0) {
      final overkill = fight.damageTaken / fight.partyMaxHp;
      if (overkill >= 1.20) {
        return _forgeOrMarket(state, 'Upgrade DEF in FORGE');
      }
      if (overkill <= 1.08) {
        return _forgeOrMarket(state, 'Upgrade STA in FORGE');
      }
    }
    return null;
  }
}
