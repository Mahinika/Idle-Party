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
  /// Greater Rift Android ID is the Sep board (`Greater Rift 2026-09`).
  static const Map<String, ({String timedKey, String gauntlet, String greaterRift})>
      byMonth =
      <String, ({String timedKey, String gauntlet, String greaterRift})>{
        '2026-08': (
          timedKey: 'CgkIhuXGvNocEAIQAA',
          gauntlet: 'CgkIhuXGvNocEAIQAQ',
          greaterRift: '',
        ),
        // Reuse Aug KEY/Gauntlet until Console creates distinct Sep KEY/Gauntlet
        // boards. GR uses the Sep Console board (publish via Games Publishing).
        '2026-09': (
          timedKey: 'CgkIhuXGvNocEAIQAA',
          gauntlet: 'CgkIhuXGvNocEAIQAQ',
          greaterRift: 'CgkIhuXGvNocEAIQAw',
        ),
      };

  /// Player-facing honesty when boards cannot open a real Play leaderboard.
  static const String boardsNeedPlayMessage =
      'Boards need a Play install + sign-in';

  static String timedKeyId(String monthKey) =>
      byMonth[monthKey]?.timedKey ?? '';

  static String gauntletId(String monthKey) =>
      byMonth[monthKey]?.gauntlet ?? '';

  static String greaterRiftId(String monthKey) =>
      byMonth[monthKey]?.greaterRift ?? '';

  /// True when [id] is a real Console board id (not empty / placeholder).
  static bool isLiveBoardId(String id) {
    if (id.isEmpty) return false;
    if (id.contains('XXXX') || id.contains('YYYY')) return false;
    return true;
  }

  static bool hasBoards(String monthKey) {
    final row = byMonth[monthKey];
    if (row == null) return false;
    return isLiveBoardId(row.timedKey) && isLiveBoardId(row.gauntlet);
  }

  static bool hasGreaterRiftBoard(String monthKey) =>
      isLiveBoardId(greaterRiftId(monthKey));

  /// Live KEY / Gauntlet board chrome is meaningful only when Play Games can
  /// run and Console IDs are wired for [monthKey].
  ///
  /// Sideload / web / missing IDs → false (UI should show honesty, not dead
  /// board buttons). Sign-in is a separate gate for opening boards.
  static bool boardsAvailable(
    String monthKey, {
    required bool playGamesSupported,
  }) =>
      playGamesSupported && hasBoards(monthKey);
}
