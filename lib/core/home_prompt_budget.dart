import 'game_state.dart';

/// At most one growth modal (notify / Discord / review) per sitting for the
/// first three sittings. Patch Notes and Welcome Back stay outside this budget.
abstract final class HomePromptBudget {
  static const int maxSessions = 3;
  static const String tipPrefix = 'home_modal_session_';

  static String tipForSession(int sessionCount) => '$tipPrefix$sessionCount';

  static bool applies(GameState state) {
    final n = state.metaDepth.sessionCount;
    return n >= 1 && n <= maxSessions;
  }

  static bool consumed(GameState state) =>
      state.seenTips.any((t) => t.startsWith(tipPrefix));

  static bool canSpend(GameState state) =>
      applies(state) && !consumed(state);
}