import 'package:flutter/material.dart';

import '../../core/menu_router.dart';

/// Provides [MenuRouter] + enter-dungeon to overlays (offline welcome, etc.).
class PlayNav extends InheritedWidget {
  const PlayNav({
    super.key,
    required this.router,
    required this.onEnterDungeon,
    required super.child,
  });

  final MenuRouter router;
  final void Function(String dungeonId) onEnterDungeon;

  static PlayNav? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayNav>();

  @override
  bool updateShouldNotify(PlayNav old) =>
      router != old.router || onEnterDungeon != old.onEnterDungeon;
}
