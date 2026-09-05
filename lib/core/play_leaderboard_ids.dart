/// Google Play Games leaderboard IDs per calendar month (`yyyy-MM`).
///
/// Create matching boards in Play Console (Play Games Services → Leaderboards),
/// then paste the Android IDs here. Empty string = soft-fail (no submit / show).
abstract final class PlayLeaderboardIds {
  /// Snapshot name for Play Games Saved Games (must match [PlayGamesBridge]).
  static const String cloudSaveName = 'idle_party_save_v2';

  /// Month → (timed KEY, gauntlet, greater Rift board ids).
  ///
  /// Play Console boards for season 2026-08 (Idle Party Games project 986358854278).
  /// Paste Greater Rift Android ID when the Console board exists.
  static const Map<String, ({String timedKey, String gauntlet, String greaterRift})>
      byMonth =
      <String, ({String timedKey, String gauntlet, String greaterRift})>{
        '2026-08': (
          timedKey: 'CgkIhuXGvNocEAIQAA',
          gauntlet: 'CgkIhuXGvNocEAIQAQ',
          greaterRift: '',
        ),
        // Reuse Aug KEY/Gauntlet until Console creates distinct Sep boards.
        // Greater Rift stays empty (soft-fail) until a Sep GR board ID exists.
        '2026-09': (
          timedKey: 'CgkIhuXGvNocEAIQAA',
          gauntlet: 'CgkIhuXGvNocEAIQAQ',
          greaterRift: '',
        ),
      };

  static String timedKeyId(String monthKey) =>
      byMonth[monthKey]?.timedKey ?? '';

  static String gauntletId(String monthKey) =>
      byMonth[monthKey]?.gauntlet ?? '';

  static String greaterRiftId(String monthKey) =>
      byMonth[monthKey]?.greaterRift ?? '';

  static bool hasBoards(String monthKey) {
    final row = byMonth[monthKey];
    if (row == null) return false;
    return row.timedKey.isNotEmpty &&
        !row.timedKey.contains('XXXX') &&
        row.gauntlet.isNotEmpty &&
        !row.gauntlet.contains('YYYY');
  }

  static bool hasGreaterRiftBoard(String monthKey) {
    final id = greaterRiftId(monthKey);
    return id.isNotEmpty && !id.contains('XXXX');
  }
}
