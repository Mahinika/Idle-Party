import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hide phone status / nav chrome (clock, wifi, battery, gesture bar).
/// Swipe from an edge reveals them briefly; [SystemUiMode.immersiveSticky]
/// re-hides. Call again after AdMob / UMP forms restore system bars.
Future<void> lockImmersiveUi() async {
  if (kIsWeb) return;
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      systemNavigationBarColor: Color(0x00000000),
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}
