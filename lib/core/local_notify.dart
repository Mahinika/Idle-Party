import 'local_notify_stub.dart'
    if (dart.library.io) 'local_notify_io.dart' as impl;
import 'local_reminders.dart';

/// Device reminders. No-op on web / tests / non-Android.
abstract final class LocalNotify {
  static Future<void> init() => impl.init();

  static Future<bool> requestPermission() => impl.requestPermission();

  static Future<void> schedule(List<LocalPing> pings) => impl.schedule(pings);

  static Future<void> cancelAll() => impl.cancelAll();
}
