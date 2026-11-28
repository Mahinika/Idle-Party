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
          greaterRift: 'CgkIhuXGvNocEAIQAw',
        ),
        // Reuse Aug KEY/Gauntlet until Console creates distinct Sep KEY/Gauntlet
        // boards. GR uses the Sep Console board (publish via Games Publishing).
        '2026-09': (
          timedKey: 'CgkIhuXGvNocEAIQAA',
          gauntlet: 'CgkIhuXGvNocEAIQAQ',
          greaterRift: 'CgkIhuXGvNocEAIQAw',
        ),
        // Reuse Aug KEY/Gauntlet + Sep GR until Console creates distinct Oct boards.
        '2026-10': (
          timedKey: 'CgkIhuXGvNocEAIQAA',
          gauntlet: 'CgkIhuXGvNocEAIQAQ',
          greaterRift: 'CgkIhuXGvNocEAIQAw',
        ),
        // Nov+ reuse the newest wired boards until Console publishes new ids.
        '2026-11': (
          timedKey: 'CgkIhuXGvNocEAIQAA',
          gauntlet: 'CgkIhuXGvNocEAIQAQ',
          greaterRift: 'CgkIhuXGvNocEAIQAw',
        ),
        '2026-12': (
          timedKey: 'CgkIhuXGvNocEAIQAA',
          gauntlet: 'CgkIhuXGvNocEAIQAQ',
          greaterRift: 'CgkIhuXGvNocEAIQAw',
        ),
      };

  /// Newest month key in [byMonth] (lexicographic `yyyy-MM`).
  static String? get _newestMonthKey {
    if (byMonth.isEmpty) return null;
    final keys = byMonth.keys.toList()..sort();
    return keys.last;
  }

  /// Row for [monthKey], else newest month with live ids (soft-fail guard).
  static ({String timedKey, String gauntlet, String greaterRift})? _rowFor(
    String monthKey,
  ) {
    final direct = byMonth[monthKey];
    if (direct != null) return direct;
    final fallbackKey = _newestMonthKey;
    if (fallbackKey == null) return null;
    return byMonth[fallbackKey];
  }

  /// True when [monthKey] has no dedicated row and scores reuse [fallbackKey].
  static bool usesFallbackMonth(String monthKey) {
    if (byMonth.containsKey(monthKey)) return false;
    return _rowFor(monthKey) != null;
  }

  /// Soft honesty when this month reuses another month's Play board.
  static String? reusedBoardNotice(String monthKey) {
    if (byMonth.containsKey(monthKey)) {
      if (monthKey == '2026-09' || monthKey == '2026-10') {
        return 'This month shares KEY and Gauntlet boards with an earlier month.';
      }
      return null;
    }
    if (usesFallbackMonth(monthKey)) {
      return 'This month uses the latest Play boards until new ones are linked.';
    }
    return null;
  }

  /// Player-facing honesty when boards cannot open a real Play leaderboard.
  static const String boardsNeedPlayMessage =
      'Boards need a Play install + sign-in';

  /// Play can run, but this calendar month has no Console board ids yet.
  static const String monthBoardsPendingMessage =
      "This month's KEY, Gauntlet, and Ranked GR boards are not on Play yet.";

  /// Why RANKS cannot show the season lists. Party power is separate.
  static String unavailableMessage({
    required bool playGamesSupported,
    required String monthKey,
  }) {
    if (!playGamesSupported || hasBoards(monthKey)) {
      return boardsNeedPlayMessage;
    }
    return monthBoardsPendingMessage;
  }

  static String timedKeyId(String monthKey) => _rowFor(monthKey)?.timedKey ?? '';

  static String gauntletId(String monthKey) => _rowFor(monthKey)?.gauntlet ?? '';

  static String greaterRiftId(String monthKey) =>
      _rowFor(monthKey)?.greaterRift ?? '';

  /// True when [id] is a real Console board id (not empty / placeholder).
  static bool isLiveBoardId(String id) {
    if (id.isEmpty) return false;
    if (id.contains('XXXX') || id.contains('YYYY')) return false;
    return true;
  }

  static bool hasBoards(String monthKey) {
    final row = _rowFor(monthKey);
    if (row == null) return false;
    return isLiveBoardId(row.timedKey) && isLiveBoardId(row.gauntlet);
  }

  static bool hasGreaterRiftBoard(String monthKey) =>
      isLiveBoardId(greaterRiftId(monthKey));

  /// All-time party power. Not a monthly board.
  static const String partyPowerId = 'CgkIhuXGvNocEAIQBA';

  static bool get hasPartyPowerBoard => isLiveBoardId(partyPowerId);

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
