import 'app_analytics_stub.dart'
    if (dart.library.io) 'app_analytics_io.dart' as impl;

/// Soft Firebase Analytics facade. No-op on web / tests / missing config.
abstract final class AppAnalytics {
  /// Test hook — records every [logEvent] (including reserved `first_open`).
  static void Function(String name, Map<String, Object>? params)? debugSink;

  static Future<void> init() => impl.init();

  /// Re-read UMP after SETTINGS → AD PRIVACY.
  static Future<void> syncConsent() => impl.syncConsent();

  static Future<void> logEvent(
    String name, [
    Map<String, Object>? params,
  ]) async {
    debugSink?.call(name, params);
    await impl.logEvent(name, params);
  }

  static Future<void> enterDungeon({
    required String dungeonId,
    required int keyLevel,
    required int floor,
  }) =>
      logEvent('enter_dungeon', {
        'dungeon_id': dungeonId,
        'key_level': keyLevel,
        'floor': floor,
      });

  static Future<void> leaveDungeon({
    required String dungeonId,
    required int floor,
  }) =>
      logEvent('leave_dungeon', {
        'dungeon_id': dungeonId,
        'floor': floor,
      });

  static Future<void> partyWipe({
    required String dungeonId,
    required int floor,
    required int streak,
  }) =>
      logEvent('party_wipe', {
        'dungeon_id': dungeonId,
        'floor': floor,
        'streak': streak,
      });

  static Future<void> ascend({
    required int fromAl,
    required int toAl,
  }) =>
      logEvent('ascend', {
        'from_al': fromAl,
        'to_al': toAl,
      });
}
