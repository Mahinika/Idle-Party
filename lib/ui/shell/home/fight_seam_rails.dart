import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_router.dart';
import '../../../core/remote_tune.dart';
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
    // Town: no rail; the buildings and MENU are the entry points (F100).
    final town = RemoteTune.townSquareActive(state.inDungeon);
    final out = <HomeEntry>[
      ...HomeCatalog.of(HomePlace.leftRail, town: town),
      ...HomeCatalog.of(HomePlace.rightRail, town: town),
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
            colors: [GameTheme.panel, GameTheme.panel.withValues(alpha: 0)],
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
    final scale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, GameTheme.typeScaleMax);
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_stackedFits(context, entries, state, constraints.maxWidth)) {
              return _stackedRow(entries, state);
            }
            return _scrollRow(entries, state);
          },
        ),
      ),
    );
  }

  static const double _pad = 8;
  static const double _gap = 6;

  String _labelOf(HomeEntry entry, GameState state) {
    final timer = entry.timer?.call(state);
    return timer != null && timer.isNotEmpty
        ? '${entry.label} $timer'
        : entry.label;
  }

  double _textWidth(BuildContext context, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: GameTheme.readable()),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  /// Inline chips scroll sideways once they outgrow the seam, so at large
  /// text the last one (DAILY) ends cut at the edge. When the chips do not
  /// fit but every label fits over its icon in an equal slot, show them all.
  bool _stackedFits(
    BuildContext context,
    List<HomeEntry> entries,
    GameState state,
    double width,
  ) {
    if (!width.isFinite) return false;
    var inline = _pad * 2 + _gap * (entries.length - 1);
    var widest = 0.0;
    for (final e in entries) {
      final w = _textWidth(context, _labelOf(e, state));
      inline += math.max(GameTheme.minTouch, 16 + GameTheme.iconList + 4 + w);
      widest = math.max(widest, w);
    }
    if (inline <= width) return false;
    final slot =
        (width - _pad * 2 - _gap * (entries.length - 1)) / entries.length;
    return slot >= GameTheme.minTouch && widest + 8 <= slot;
  }

  Widget _stackedRow(List<HomeEntry> entries, GameState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _pad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(
              child: RailButton(
                entry: entries[i],
                state: state,
                director: widget.director,
                router: widget.router,
                compact: true,
                stacked: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scrollRow(List<HomeEntry> entries, GameState state) {
    return Stack(
      children: [
        ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: _pad),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(width: _gap),
          itemBuilder: (context, i) => RailButton(
            entry: entries[i],
            state: state,
            director: widget.director,
            router: widget.router,
            compact: true,
          ),
        ),
        if (_scrollable) ...[
          Positioned(left: 0, top: 0, bottom: 0, child: _edgeFade(start: true)),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _edgeFade(start: false),
          ),
        ],
      ],
    );
  }
}
