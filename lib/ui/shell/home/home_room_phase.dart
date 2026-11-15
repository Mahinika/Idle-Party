import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../spatial/spatial_combat.dart';

/// Where the current cave room is. Home chrome uses this to step aside
/// while heroes fight and come back between rooms.
enum HomeRoomPhase {
  /// No live foes: between rooms, stairs, treasure, or town.
  between,

  /// Foes are awake and the fight just started.
  started,

  /// The fight has run for [HomeRoomPhaseBuilder.underwayAfter].
  underway,
}

/// True when awake foes are in the room.
bool homeRoomFightActive(GameDirector director) {
  if (!director.state.inDungeon) return false;
  final world = director.spatial;
  if (world == null || world.awaitingExit || world.isTreasure) return false;
  return _awakeFoes(world);
}

bool _awakeFoes(SpatialWorld world) {
  for (final e in world.enemies) {
    if (e.hp > 0 && !e.dormant) return true;
  }
  return false;
}

/// Rebuilds only when the room phase flips, not on every combat frame.
class HomeRoomPhaseBuilder extends StatefulWidget {
  const HomeRoomPhaseBuilder({
    super.key,
    required this.director,
    required this.builder,
  });

  /// Fight time (seconds) before the room counts as underway.
  static const double underwayAfter = 1.5;

  final GameDirector director;
  final Widget Function(BuildContext context, HomeRoomPhase phase) builder;

  @override
  State<HomeRoomPhaseBuilder> createState() => _HomeRoomPhaseBuilderState();
}

class _HomeRoomPhaseBuilderState extends State<HomeRoomPhaseBuilder> {
  HomeRoomPhase _phase = HomeRoomPhase.between;
  SpatialWorld? _world;
  double? _fightStart;

  @override
  void initState() {
    super.initState();
    _listen(widget.director);
    _phase = _read();
  }

  @override
  void didUpdateWidget(covariant HomeRoomPhaseBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.director != widget.director) {
      _unlisten(oldWidget.director);
      _listen(widget.director);
      _fightStart = null;
      _phase = _read();
    }
  }

  @override
  void dispose() {
    _unlisten(widget.director);
    super.dispose();
  }

  void _listen(GameDirector d) {
    d.addListener(_onTick);
    d.combatFrame.addListener(_onTick);
  }

  void _unlisten(GameDirector d) {
    d.removeListener(_onTick);
    d.combatFrame.removeListener(_onTick);
  }

  HomeRoomPhase _read() {
    final world = widget.director.spatial;
    if (!homeRoomFightActive(widget.director) || world == null) {
      _fightStart = null;
      _world = world;
      return HomeRoomPhase.between;
    }
    if (!identical(world, _world)) {
      _world = world;
      _fightStart = null;
    }
    final start = _fightStart ??= world.combatElapsed;
    return world.combatElapsed - start >= HomeRoomPhaseBuilder.underwayAfter
        ? HomeRoomPhase.underway
        : HomeRoomPhase.started;
  }

  void _onTick() {
    if (!mounted) return;
    final next = _read();
    if (next == _phase) return;
    setState(() => _phase = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _phase);
}
