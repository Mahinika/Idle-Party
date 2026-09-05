import 'game_state.dart';
import 'meta_systems.dart' show MetaSystems;

/// Local, opt-in session notes — no network, no analytics servers.
abstract final class SessionTelemetry {
  static const int maxEvents = 80;

  static GameState setOptIn(GameState state, bool value) {
    if (value == state.sessionTelemetryOptIn) return state;
    var next = state.copyWith(sessionTelemetryOptIn: value);
    if (value) {
      next = append(next, 'settings', 'opt_in');
    }
    return next;
  }

  static GameState append(GameState state, String kind, [String detail = '']) {
    if (!state.sessionTelemetryOptIn) return state;
    final stamp = DateTime.now().toUtc().toIso8601String();
    final line = detail.isEmpty ? '$stamp|$kind' : '$stamp|$kind|$detail';
    final log = [...state.sessionTelemetryLog, line];
    if (log.length > maxEvents) {
      log.removeRange(0, log.length - maxEvents);
    }
    return state.copyWith(sessionTelemetryLog: log);
  }

  static GameState clearLog(GameState state) =>
      state.copyWith(sessionTelemetryLog: const <String>[]);

  static String exportText(GameState state) {
    if (state.sessionTelemetryLog.isEmpty) {
      return 'Idle Party session log (empty)\n'
          'AL${state.ascensionLevel} · opt-in ${state.sessionTelemetryOptIn}\n';
    }
    final header =
        'Idle Party session log · AL${state.ascensionLevel} · ${MetaSystems.currentVersion}\n';
    return '$header${state.sessionTelemetryLog.join('\n')}\n';
  }
}
