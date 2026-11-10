import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_router.dart';
import '../../game_theme.dart';
import 'home_catalog.dart';
import 'rail_button.dart';

/// SCROLLS, QUESTS, and the rest — under the party row, not over the cave.
class FightSeamRails extends StatefulWidget {
  const FightSeamRails({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

  static List<HomeEntry> visibleEntries(
    GameState state,
    GameDirector director,
  ) {
    final out = <HomeEntry>[
      ...HomeCatalog.of(HomePlace.leftRail),
      ...HomeCatalog.of(HomePlace.rightRail),
    ];
    out.retainWhere((e) => e.visible(state, director));
    return out;
  }

  @override
  State<FightSeamRails> createState() => _FightSeamRailsState();
}

class _FightSeamRailsState extends State<FightSeamRails> {
  final ScrollController _scroll = ScrollController();
  var _scrollable = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncScrollable);
  }

  @override
  void dispose() {
    _scroll.removeListener(_syncScrollable);
    _scroll.dispose();
    super.dispose();
  }

  void _syncScrollable() {
    if (!_scroll.hasClients) return;
    final next = _scroll.position.maxScrollExtent > 0;
    if (next == _scrollable) return;
    setState(() => _scrollable = next);
  }

  Widget _edgeFade({required bool start}) {
    return IgnorePointer(
      child: Container(
        width: 12,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: start ? Alignment.centerLeft : Alignment.centerRight,
            end: start ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              GameTheme.panel,
              GameTheme.panel.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final entries = FightSeamRails.visibleEntries(state, widget.director);
    if (entries.isEmpty) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context)
        .scale(1)
        .clamp(1.0, GameTheme.typeScaleMax);
    final slot = math.max(GameTheme.minTouch, GameTheme.minTouch * scale);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollable());
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: GameTheme.border.withValues(alpha: 0.45)),
        ),
      ),
      child: SizedBox(
        height: slot,
        child: Stack(
          children: [
            ListView.separated(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, i) => RailButton(
                entry: entries[i],
                state: state,
                director: widget.director,
                router: widget.router,
                compact: true,
              ),
            ),
            if (_scrollable) ...[
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _edgeFade(start: true),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _edgeFade(start: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
