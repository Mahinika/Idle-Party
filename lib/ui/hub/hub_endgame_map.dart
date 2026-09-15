import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/hub_endgame_act.dart';
import '../game_theme.dart';
import '../web_click_bridge.dart';
import 'hub_world_map.dart';

/// Hub-local PATH | ENDGAME switch — not a seventh bottom-bar tab.
class HubMapModeTabs extends StatelessWidget {
  const HubMapModeTabs({
    super.key,
    required this.showEndgame,
    required this.onSelectPath,
    required this.onSelectEndgame,
  });

  final bool showEndgame;
  final VoidCallback onSelectPath;
  final VoidCallback onSelectEndgame;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: GameTheme.minTouch,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: GameTheme.panelInset.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(GameTheme.radiusSm),
          border: Border.all(color: GameTheme.border.withValues(alpha: 0.75)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(GameTheme.radiusSm),
          child: Row(
            children: [
              Expanded(
                child: _tab(
                  label: HubEndgameAct.pathTabLabel,
                  selected: !showEndgame,
                  onTap: onSelectPath,
                ),
              ),
              Container(width: 1, color: GameTheme.border.withValues(alpha: 0.45)),
              Expanded(
                child: _tab(
                  label: HubEndgameAct.mapTitle,
                  selected: showEndgame,
                  onTap: onSelectEndgame,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return WebClickScope(
      label: label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: selected
              ? GameTheme.torch.withValues(alpha: 0.22)
              : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: GameTheme.body(
                  size: 12,
                  color: selected ? GameTheme.torchHot : GameTheme.parchmentDim,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Separate endgame board (four hunts). Not a footer under the 15-zone path.
class HubEndgameMap extends StatelessWidget {
  const HubEndgameMap({
    super.key,
    required this.selectedHunt,
    required this.onSelectHunt,
    this.pulse,
    this.grBestTier = 0,
  });

  final HubEndgameHunt? selectedHunt;
  final ValueChanged<HubEndgameHunt> onSelectHunt;
  final Animation<double>? pulse;
  final int grBestTier;

  /// Node centers (gauntlet / Ranked GR / Farm Rift / Ashen).
  static List<Offset> get markerNorm => [
        for (final n in HubEndgameAct.nodes) Offset(n.mapX, n.mapY),
      ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapW = constraints.maxWidth;
        final mapH = constraints.maxHeight;
        if (mapW < 8 || mapH < 8) return const SizedBox.shrink();
        final discSize = (mapW * 0.16).clamp(40.0, 52.0);
        final hitSize = math.max(discSize, GameTheme.minTouch);
        const statusH = 16.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(GameTheme.radiusSm),
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: const HubWorldContinentsPainter(dim: true),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          GameTheme.ink.withValues(alpha: 0.35),
                          Colors.transparent,
                          GameTheme.ink.withValues(alpha: 0.45),
                        ],
                        stops: const [0, 0.35, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _EndgameHuntPathPainter(
                      color: GameTheme.borderLit.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                top: 6,
                child: Text(
                  HubEndgameAct.mapUnlockLine,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(
                    size: 11,
                    color: GameTheme.parchmentDim,
                  ),
                ),
              ),
              for (final node in HubEndgameAct.nodes)
                _placedMarker(
                  node: node,
                  mapW: mapW,
                  mapH: mapH,
                  discSize: discSize,
                  hitSize: hitSize,
                  statusH: statusH,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _placedMarker({
    required HubEndgameNode node,
    required double mapW,
    required double mapH,
    required double discSize,
    required double hitSize,
    required double statusH,
  }) {
    final selected = selectedHunt == node.hunt;
    final statusWord = selected
        ? 'HERE'
        : HubEndgameAct.shortLabelFor(node.hunt, grBestTier: grBestTier);
    final labelH = statusWord.isEmpty ? 0.0 : statusH;
    final cx = node.mapX * mapW;
    final cy = node.mapY * mapH;
    final left = (cx - hitSize / 2).clamp(0.0, mapW - hitSize).toDouble();
    final top = (cy - hitSize / 2 - labelH)
        .clamp(0.0, math.max(0.0, mapH - hitSize - labelH))
        .toDouble();
    return Positioned(
      left: left,
      top: top,
      width: hitSize,
      height: hitSize + labelH,
      child: MapZoneMarker(
        name: HubEndgameAct.titleFor(node.hunt, grBestTier: grBestTier),
        portraitDungeonId: node.portraitDungeonId,
        discSize: discSize,
        hitSize: hitSize,
        unlocked: true,
        cleared: false,
        selected: selected,
        pulse: selected ? pulse : null,
        statusWord: statusWord,
        onTap: () => onSelectHunt(node.hunt),
      ),
    );
  }
}

class _EndgameHuntPathPainter extends CustomPainter {
  const _EndgameHuntPathPainter({required this.color});

  final Color color;

  Offset _pt(HubEndgameHunt hunt, Size size) {
    final n = HubEndgameAct.nodeFor(hunt);
    return Offset(n.mapX * size.width, n.mapY * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final g = _pt(HubEndgameHunt.gauntlet, size);
    final rift = _pt(HubEndgameHunt.farmRift, size);
    final gr = _pt(HubEndgameHunt.rankedGr, size);
    final ashen = _pt(HubEndgameHunt.ashen, size);
    final path = Path()
      ..moveTo(g.dx, g.dy)
      ..lineTo(rift.dx, rift.dy)
      ..moveTo(g.dx, g.dy)
      ..lineTo(gr.dx, gr.dy)
      ..moveTo(rift.dx, rift.dy)
      ..lineTo(ashen.dx, ashen.dy)
      ..moveTo(gr.dx, gr.dy)
      ..lineTo(ashen.dx, ashen.dy)
      ..moveTo(rift.dx, rift.dy)
      ..lineTo(gr.dx, gr.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EndgameHuntPathPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
