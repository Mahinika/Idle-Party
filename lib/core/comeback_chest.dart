import 'dart:math';

import 'game_state.dart';

/// One chest after a long absence. The highest band wins. It waits until claimed.
class ComebackPayout {
  const ComebackPayout({
    required this.tier,
    this.essence = 0,
    this.gold = 0,
    this.embers = 0,
    this.cinders = 0,
  });

  final int tier;
  final int essence;
  final int gold;
  final int embers;
  final int cinders;

  String get prize {
    final parts = <String>[];
    if (essence > 0) parts.add('+${_comma(essence)} essence');
    if (gold > 0) parts.add('+${_comma(gold)} gold');
    if (embers > 0) parts.add('+${_comma(embers)} Embers');
    if (cinders > 0) parts.add('+${_comma(cinders)} Cinders');
    return parts.join(' · ');
  }

  String get line => 'Away $tier days · a chest is waiting · $prize.';
}

abstract final class ComebackChest {
  static const int day3Sec = 3 * 86400;
  static const int day7Sec = 7 * 86400;
  static const int day14Sec = 14 * 86400;

  static int tierFor(int awaySeconds) {
    if (awaySeconds >= day14Sec) return 14;
    if (awaySeconds >= day7Sec) return 7;
    if (awaySeconds >= day3Sec) return 3;
    return 0;
  }

  static bool isPending(GameState state) => state.metaDepth.comebackTier != 0;

  /// Stamps the band once. A chest already waiting is left alone.
  static GameState noteAbsence(GameState state, int awaySeconds) {
    if (state.metaDepth.comebackTier != 0) return state;
    final tier = tierFor(awaySeconds);
    if (tier == 0) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(comebackTier: tier),
    );
  }

  static ComebackPayout payout({
    required int tier,
    required int sanctuaryCost,
    required int zoneScale,
  }) {
    final zone = max(1, zoneScale);
    final camp = max(0, sanctuaryCost);
    return switch (tier) {
      3 => ComebackPayout(
        tier: 3,
        essence: max(100, camp * 4),
        gold: 2000 * zone,
      ),
      7 => ComebackPayout(
        tier: 7,
        essence: max(250, camp * 8),
        gold: 6000 * zone,
        embers: 8,
      ),
      _ => ComebackPayout(
        tier: 14,
        essence: max(400, camp * 12),
        gold: 10000 * zone,
        embers: 16,
        cinders: 4,
      ),
    };
  }

  static String waitingLine(GameState state, {required int sanctuaryCost}) {
    final tier = state.metaDepth.comebackTier;
    if (tier == 0) return '';
    return payout(
      tier: tier,
      sanctuaryCost: sanctuaryCost,
      zoneScale: state.highestDungeonCleared + 1,
    ).line;
  }

  static GameState claim(GameState state, {required int sanctuaryCost}) {
    final tier = state.metaDepth.comebackTier;
    if (tier == 0) return state;
    if (tier != 3 && tier != 7 && tier != 14) {
      return state.copyWith(
        metaDepth: state.metaDepth.copyWith(comebackTier: 0),
      );
    }
    final pay = payout(
      tier: tier,
      sanctuaryCost: sanctuaryCost,
      zoneScale: state.highestDungeonCleared + 1,
    );
    return state.copyWith(
      gold: state.gold + pay.gold,
      essence: state.essence + pay.essence,
      metaDepth: state.metaDepth.copyWith(
        comebackTier: 0,
        embers: state.metaDepth.embers + pay.embers,
        cinders: min(9999, state.metaDepth.cinders + pay.cinders),
      ),
    );
  }
}

String _comma(int n) {
  final negative = n < 0;
  final s = n.abs().toString();
  final buf = StringBuffer();
  if (negative) buf.write('-');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
