import 'package:shared_preferences/shared_preferences.dart';

import 'app_analytics.dart';
import 'funnel_analytics.dart';

/// Once-per-install boot screens. Lives outside the save: a player who
/// quits on the title never has a [GameState] to stamp.
abstract final class BootFunnel {
  static const prefsKey = 'idle_party_boot_funnel';

  static Future<void> note(String name) async {
    if (!FunnelAnalytics.bootNames.contains(name)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(prefsKey) ?? const <String>[];
      if (seen.contains(name)) return;
      await prefs.setStringList(prefsKey, <String>[...seen, name]);
      await AppAnalytics.logEvent(name);
    } catch (_) {
      // Missing prefs (tests without the mock, or a broken store) stays quiet.
    }
  }
}
