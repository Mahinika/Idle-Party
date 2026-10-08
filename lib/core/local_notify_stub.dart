import 'local_reminders.dart';

Future<void> init() async {}

Future<bool> requestPermission() async => false;

Future<void> present({
  required List<LocalPing> pings,
  ChestTray? tray,
}) async {}

Future<void> cancelAll() async {}
