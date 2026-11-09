import 'funnel_analytics.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'meta_systems.dart';
import 'return_week.dart';

/// The appointment to open again tomorrow.
///
/// Before the first boss, the cave says the party keeps fighting, and the
/// hub says gold only gathers there. After the boss, the hub names
/// tomorrow's check-in prize for the rest of that UTC day. A tap does not
/// clear it. The next UTC day hides it.
abstract final class AwayFightTip {
  static const String line =
      'Close the app anytime. Your party keeps fighting.';

  /// Hub, after they have entered once and before the first boss.
  /// Fighting continues only in the cave.
  static const String hubLine =
      'Leave them in the cave and they keep fighting. On the hub, gold gathers.';

  /// [inCave] is the live dungeon, including floor 1. [bossStairs] is the
  /// walk to the stairs after the first boss, before the hub opens.
  static bool shouldShow(
    GameState state, {
    required bool bossStairs,
    bool inCave = false,
    DateTime? now,
  }) {
    if (state.metaDepth.awayFightTipSeen) return false;
    final armed = state.metaDepth.awayPromiseUtc;
    if (armed.isNotEmpty) {
      final clock = (now ?? DateTime.now()).toUtc();
      if (armed != MetaSystems.dailyDateKey(clock)) return false;
    }
    if (GameLogic.showDailyChase(state)) return true;
    if (!GameLogic.firstBossPending(state)) return false;
    if (inCave || bossStairs) return true;
    return FunnelAnalytics.has(state, FunnelAnalytics.firstEnter);
  }

  /// Death card owns the cave. "Keeps fighting" is a lie while the party is dead.
  ///
  /// [climb] is the first-fight / first-claim line. It wins until that boss
  /// dies. The away promise stays on the hub for the same climb.
  /// [firstBoss] still picks the away line when no climb line is set.
  static String? caveCoach({
    required bool wiped,
    required String? godhand,
    required String? away,
    required String? farm,
    bool firstBoss = false,
    String? climb,
  }) {
    if (wiped) return null;
    if (climb != null && climb.isNotEmpty) return climb;
    if (firstBoss && away != null) return away;
    return godhand ?? away ?? farm;
  }

  /// The hub card already says tomorrow. A second line under it repeats that.
  static bool hubCardOwns(String title, String detail) {
    final lower = detail.toLowerCase();
    if (title.startsWith('Tomorrow') && lower.contains('tomorrow')) return true;
    // The return-week card already names the cave, the shelf, and the away.
    return lower.contains('keeps fighting') &&
        (lower.contains('camp') ||
            lower.contains('forge') ||
            lower.contains('scrolls') ||
            lower.contains('relics'));
  }

  /// Prize first, so a one-line hub clip still names what waits.
  /// [onHub] picks the gold line before check-in exists.
  ///
  /// An unclaimed vault is wiped at the UTC day roll, so that prize is
  /// today or it is gone. Tomorrow is named only after the claim.
  static String lineFor(GameState state, {bool onHub = false}) {
    if (GameLogic.canClaimDailyVault(state)) {
      if (ReturnWeek.active(state)) {
        final pay = GameLogic.checkInPayout(state);
        return 'Tap CLAIM before the day ends. ${ReturnWeek.spendSentence(pay)}';
      }
      return 'Tap CLAIM before the day ends.';
    }
    if (!GameLogic.checkInActive(state)) return onHub ? hubLine : line;
    final pay = GameLogic.checkInPayout(state);
    if (ReturnWeek.active(state)) {
      final cave = ReturnWeek.caveName(state);
      if (state.metaDepth.dailyVaultClaimed) {
        return 'Tomorrow: $cave pays ${pay.hookPrize}. '
            '${ReturnWeek.spendSentence(pay)}';
      }
      return 'One cave, $cave, fills the vault. ${ReturnWeek.spendSentence(pay)}';
    }
    if (state.metaDepth.dailyVaultClaimed) {
      return 'Tomorrow pays ${pay.hookPrize}.';
    }
    return 'One cave fills the vault.';
  }

  /// Stamp today the first time the appointment can show. Later days hide it.
  static GameState arm(GameState state, DateTime now) {
    if (state.metaDepth.awayFightTipSeen) return state;
    if (state.metaDepth.awayPromiseUtc.isNotEmpty) return state;
    if (!GameLogic.showDailyChase(state)) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        awayPromiseUtc: MetaSystems.dailyDateKey(now.toUtc()),
      ),
    );
  }

  static GameState markSeen(GameState state) {
    if (state.metaDepth.awayFightTipSeen) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(awayFightTipSeen: true),
    );
  }
}
