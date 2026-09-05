import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hide phone status / nav chrome (clock, wifi, battery, gesture bar).
/// Swipe from an edge reveals them briefly; [SystemUiMode.immersiveSticky]
/// re-hides. Call again after AdMob / UMP forms restore system bars.
Future<void> lockImmersiveUi() {
  if (kIsWeb) return Future.value();
  return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}
