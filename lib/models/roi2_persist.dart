/// Extra save fields for the approved ROI round-2 pass.
///
/// Missing on old saves. [fromJson] fills defaults, and an Ad-free purchase
/// that predates the VIP split keeps the old perks ([vipPass]).
class Roi2Persist {
  const Roi2Persist({
    this.vipPass = false,
    this.vipPerkSplit = false,
    this.goldLanternReady = false,
    this.highestWallMs = 0,
    this.lastSessionWallMs = 0,
    this.lastSessionUptimeMs = 0,
    this.dayKeysAreLocal = false,
    this.tzOffsetMinutes = unsetOffset,
    this.tzHonoredDay = '',
    this.tzPinnedDay = '',
    this.dailyRefillHoldUntilMs = 0,
    this.clockJumpSuppressDay = '',
    this.consentPrompted = false,
    this.batterySaver = false,
    this.readableType = false,
    this.lastGoodSnapshotMs = 0,
  });

  /// Sentinel: this save has not recorded a time-zone offset yet.
  static const int unsetOffset = -100000;

  /// VIP perks (5 tickets, auto lantern gold, Welcome ×3, CAMP, rerolls).
  final bool vipPass;

  /// True once this save has been through the Ad-free / VIP split.
  ///
  /// Absent on old JSON. An old save with Ad-free and no split flag is
  /// grandfathered into [vipPass]. A new purchase sets this true and leaves
  /// [vipPass] false.
  final bool vipPerkSplit;

  /// Gold lantern is waiting for a tap. The daily cap still applies.
  final bool goldLanternReady;

  /// Highest wall-clock millis this save has seen. A clock set backwards
  /// does not lower it.
  final int highestWallMs;

  /// Wall clock at the end of the previous session.
  final int lastSessionWallMs;

  /// `elapsedRealtime` at the end of the previous session. 0 if unknown.
  final int lastSessionUptimeMs;

  /// Day keys in this save are local calendar days, not UTC.
  final bool dayKeysAreLocal;

  /// Offset in minutes when [tzHonoredDay] was recorded.
  final int tzOffsetMinutes;

  /// Local day on which a time-zone change was already honoured.
  final String tzHonoredDay;

  /// Day key kept after a second time-zone change on the same day.
  final String tzPinnedDay;

  /// Until this UTC millis, daily refills stay on [tzPinnedDay].
  final int dailyRefillHoldUntilMs;

  /// Calendar day produced by a clock jump. Refills for that day are skipped.
  final String clockJumpSuppressDay;

  /// UMP has been offered once (after the first fight).
  final bool consentPrompted;

  /// Fewer ambient particles. The fight sim is unchanged.
  final bool batterySaver;

  /// Body text uses the bundled OFL VT323 face.
  final bool readableType;

  /// Wall millis of the last rotating backup copy.
  final int lastGoodSnapshotMs;

  Roi2Persist copyWith({
    bool? vipPass,
    bool? vipPerkSplit,
    bool? goldLanternReady,
    int? highestWallMs,
    int? lastSessionWallMs,
    int? lastSessionUptimeMs,
    bool? dayKeysAreLocal,
    int? tzOffsetMinutes,
    String? tzHonoredDay,
    String? tzPinnedDay,
    int? dailyRefillHoldUntilMs,
    String? clockJumpSuppressDay,
    bool? consentPrompted,
    bool? batterySaver,
    bool? readableType,
    int? lastGoodSnapshotMs,
  }) {
    return Roi2Persist(
      vipPass: vipPass ?? this.vipPass,
      vipPerkSplit: vipPerkSplit ?? this.vipPerkSplit,
      goldLanternReady: goldLanternReady ?? this.goldLanternReady,
      highestWallMs: highestWallMs ?? this.highestWallMs,
      lastSessionWallMs: lastSessionWallMs ?? this.lastSessionWallMs,
      lastSessionUptimeMs: lastSessionUptimeMs ?? this.lastSessionUptimeMs,
      dayKeysAreLocal: dayKeysAreLocal ?? this.dayKeysAreLocal,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      tzHonoredDay: tzHonoredDay ?? this.tzHonoredDay,
      tzPinnedDay: tzPinnedDay ?? this.tzPinnedDay,
      dailyRefillHoldUntilMs:
          dailyRefillHoldUntilMs ?? this.dailyRefillHoldUntilMs,
      clockJumpSuppressDay: clockJumpSuppressDay ?? this.clockJumpSuppressDay,
      consentPrompted: consentPrompted ?? this.consentPrompted,
      batterySaver: batterySaver ?? this.batterySaver,
      readableType: readableType ?? this.readableType,
      lastGoodSnapshotMs: lastGoodSnapshotMs ?? this.lastGoodSnapshotMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'vipPass': vipPass,
    'vipPerkSplit': vipPerkSplit,
    'goldLanternReady': goldLanternReady,
    'highestWallMs': highestWallMs,
    'lastSessionWallMs': lastSessionWallMs,
    'lastSessionUptimeMs': lastSessionUptimeMs,
    'dayKeysAreLocal': dayKeysAreLocal,
    'tzOffsetMinutes': tzOffsetMinutes,
    'tzHonoredDay': tzHonoredDay,
    'tzPinnedDay': tzPinnedDay,
    'dailyRefillHoldUntilMs': dailyRefillHoldUntilMs,
    'clockJumpSuppressDay': clockJumpSuppressDay,
    'consentPrompted': consentPrompted,
    'batterySaver': batterySaver,
    'readableType': readableType,
    'lastGoodSnapshotMs': lastGoodSnapshotMs,
  };

  /// [adFree] is the legacy purchase flag on the same save object.
  static Roi2Persist fromJson(Object? raw, {required bool adFree}) {
    if (raw is! Map) {
      return Roi2Persist(vipPass: adFree, vipPerkSplit: true);
    }
    final json = Map<String, dynamic>.from(raw);
    final hasSplit = json.containsKey('vipPerkSplit');
    var vip = json['vipPass'] == true;
    if (!hasSplit && adFree) vip = true;
    return Roi2Persist(
      vipPass: vip,
      vipPerkSplit: hasSplit ? json['vipPerkSplit'] == true : true,
      goldLanternReady: json['goldLanternReady'] == true,
      highestWallMs: _nonNeg(json['highestWallMs']),
      lastSessionWallMs: _nonNeg(json['lastSessionWallMs']),
      lastSessionUptimeMs: _nonNeg(json['lastSessionUptimeMs']),
      dayKeysAreLocal: json['dayKeysAreLocal'] == true,
      tzOffsetMinutes: (json['tzOffsetMinutes'] as num?)?.toInt() ?? unsetOffset,
      tzHonoredDay: (json['tzHonoredDay'] as String?) ?? '',
      tzPinnedDay: (json['tzPinnedDay'] as String?) ?? '',
      dailyRefillHoldUntilMs: _nonNeg(json['dailyRefillHoldUntilMs']),
      clockJumpSuppressDay: (json['clockJumpSuppressDay'] as String?) ?? '',
      consentPrompted: json['consentPrompted'] == true,
      batterySaver: json['batterySaver'] == true,
      readableType: json['readableType'] == true,
      lastGoodSnapshotMs: _nonNeg(json['lastGoodSnapshotMs']),
    );
  }

  static int _nonNeg(Object? raw) {
    final n = (raw as num?)?.toInt() ?? 0;
    return n < 0 ? 0 : n;
  }
}
