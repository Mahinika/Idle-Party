import 'dart:math';

/// Seven-claim prize on the Daily Vault. Days 1–6 are large. Day 7 is the
/// jackpot. The row advances only when the vault is claimed, so a missed
/// calendar day does not reset it.
class CheckInPayout {
  const CheckInPayout({
    required this.day,
    this.essence = 0,
    this.gold = 0,
    this.embers = 0,
    this.cinders = 0,
    this.adTickets = 0,
  });

  final int day;
  final int essence;
  final int gold;
  final int embers;
  final int cinders;
  final int adTickets;

  bool get jackpot => day == CheckIn.cycle;

  /// `Check-in 3/7` or `Check-in 7/7 jackpot`.
  String get name => jackpot ? 'Check-in 7/7 jackpot' : 'Check-in $day/7';

  /// Reward words only, no day label.
  String get prize {
    final parts = <String>[];
    if (essence > 0) parts.add('+${_comma(essence)} essence');
    if (gold > 0) parts.add('+${_comma(gold)} gold');
    if (embers > 0) parts.add('+${_comma(embers)} Embers');
    if (cinders > 0) parts.add('+${_comma(cinders)} Cinders');
    if (adTickets > 0) parts.add('+${_comma(adTickets)} Ad Tickets');
    return parts.join(' · ');
  }

  /// Hub and Welcome Back before today's vault is claimed.
  String get waitingLine => '$name waits on the vault · $prize.';

  /// After today's vault is already claimed.
  String get tomorrowLine => 'Tomorrow · $name · $prize.';
}

abstract final class CheckIn {
  static const int cycle = 7;

  static int normalize(int raw) => raw < 1 || raw > cycle ? 1 : raw;

  static int nextDay(int day) {
    final d = normalize(day);
    return d >= cycle ? 1 : d + 1;
  }

  /// [zoneScale] is 1 on Sandy and grows with the furthest cave cleared.
  /// [sanctuaryCost] is the cheapest next CAMP click, so late prizes still
  /// buy a few upgrades.
  static CheckInPayout payout({
    required int day,
    required int sanctuaryCost,
    required int zoneScale,
  }) {
    final d = normalize(day);
    final zone = max(1, zoneScale);
    final camp = max(0, sanctuaryCost);
    final largeEssence = max(100, camp * 4);
    final hugeEssence = max(400, camp * 12);
    final largeGold = 2000 * zone;
    final hugeGold = 10000 * zone;
    return switch (d) {
      1 => CheckInPayout(day: 1, essence: largeEssence),
      2 => CheckInPayout(day: 2, gold: largeGold),
      3 => const CheckInPayout(day: 3, embers: 8),
      4 => const CheckInPayout(day: 4, cinders: 4),
      5 => const CheckInPayout(day: 5, adTickets: 6),
      6 => CheckInPayout(day: 6, essence: largeEssence, gold: largeGold),
      _ => CheckInPayout(
        day: 7,
        essence: hugeEssence,
        gold: hugeGold,
        embers: 24,
        cinders: 12,
        adTickets: 12,
      ),
    };
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
