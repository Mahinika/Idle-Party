import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart' as test_env;
import 'local_reminders.dart';

const _channelId = 'idle_party_away';
const _channelName = 'Away reminders';
const _channelDesc =
    'Gold and cave reminders while you are away. At most a couple a day.';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _tzReady = false;
bool _pluginReady = false;

bool get _androidLive {
  if (test_env.inFlutterTestProcess()) return false;
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

void _ensureTz() {
  if (_tzReady) return;
  tzdata.initializeTimeZones();
  _tzReady = true;
}

Future<void> init() async {
  if (!_androidLive || _pluginReady) return;
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _plugin.initialize(const InitializationSettings(android: android));
  _pluginReady = true;
}

Future<bool> requestPermission() async {
  if (!_androidLive) return false;
  await init();
  final android = _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android == null) return false;
  try {
    final already = await android.areNotificationsEnabled();
    if (already == true) return true;
    final ok = await android.requestNotificationsPermission();
    return ok ?? false;
  } catch (e, st) {
    debugPrint('notify permission: $e\n$st');
    return false;
  }
}

Future<void> schedule(List<LocalPing> pings) async {
  if (!_androidLive) return;
  await init();
  _ensureTz();
  await _plugin.cancelAll();
  if (pings.isEmpty) return;
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: false,
      category: AndroidNotificationCategory.reminder,
    ),
  );
  final nowUtc = tz.TZDateTime.now(tz.UTC);
  for (final ping in pings) {
    final when = tz.TZDateTime.from(ping.fireAt.toUtc(), tz.UTC);
    if (!when.isAfter(nowUtc)) continue;
    await _plugin.zonedSchedule(
      ping.id,
      ping.title,
      ping.body,
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}

Future<void> cancelAll() async {
  if (!_androidLive || !_pluginReady) return;
  await _plugin.cancelAll();
}
