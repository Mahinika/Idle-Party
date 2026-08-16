/// Google Play Games leaderboard IDs per calendar month (`yyyy-MM`).
///
/// Create matching boards in Play Console (Play Games Services → Leaderboards),
/// then paste the Android IDs here. Empty string = soft-fail (no submit / show).
abstract final class PlayLeaderboardIds {
  /// Snapshot name for Play Games Saved Games (must match [PlayGamesBridge]).
  static const String cloudSaveName = 'idle_party_save_v2';

  /// Month → (timed KEY board id, gauntlet board id).
  ///
  /// First season placeholders — replace after Console setup (see docs/PLAY_STORE.md).
  static const Map<String, ({String timedKey, String gauntlet})> byMonth =
      <String, ({String timedKey, String gauntlet})>{
    // Placeholder IDs until Play Console boards are created for 2026-08.
    '2026-08': (
      timedKey: 'CgkIXXXXXXXXXXXXXXXX',
      gauntlet: 'CgkIYYYYYYYYYYYYYYYY',
    ),
  };

  static String timedKeyId(String monthKey) =>
      byMonth[monthKey]?.timedKey ?? '';

  static String gauntletId(String monthKey) =>
      byMonth[monthKey]?.gauntlet ?? '';

  static bool hasBoards(String monthKey) {
    final row = byMonth[monthKey];
    if (row == null) return false;
    return row.timedKey.isNotEmpty &&
        !row.timedKey.contains('XXXX') &&
        row.gauntlet.isNotEmpty &&
        !row.gauntlet.contains('YYYY');
  }
}
