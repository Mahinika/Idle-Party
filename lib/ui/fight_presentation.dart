import 'package:flutter/widgets.dart';

/// Android “Remove animations” / [MediaQuery.disableAnimations] — fight
/// picture only (floaters, idle bob, ambient motes). Never [combat_loop].
bool fightPresentationCalm(BuildContext? context) {
  if (context == null) return false;
  return MediaQuery.disableAnimationsOf(context);
}