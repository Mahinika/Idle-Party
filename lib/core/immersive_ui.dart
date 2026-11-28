import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// True only after the player has answered the ad-consent form with yes.
abstract final class ImmersiveGate {
  static bool allowed = false;
}

/// Hide phone status / nav chrome after consent. Before that, bars stay.
/// Swipe from an edge reveals them briefly; [SystemUiMode.immersiveSticky]
/// re-hides. Call again after AdMob / UMP forms restore system bars.
Future<void> lockImmersiveUi() async {
  if (kIsWeb) return;
  await SystemChrome.setEnabledSystemUIMode(
    ImmersiveGate.allowed
        ? SystemUiMode.immersiveSticky
        : SystemUiMode.edgeToEdge,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      systemNavigationBarColor: Color(0x00000000),
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}
