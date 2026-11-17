import 'package:flutter/widgets.dart';

/// How far the round FIGHT rises over lists that end at the bottom nav.
/// Scrollable lists under it add this to their bottom padding so the last
/// card and its buy button scroll clear of the button. Zero elsewhere.
class NavClearance extends InheritedWidget {
  const NavClearance({super.key, required this.bottom, required super.child});

  final double bottom;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavClearance>()?.bottom ?? 0;

  @override
  bool updateShouldNotify(NavClearance oldWidget) =>
      oldWidget.bottom != bottom;
}
