import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/party_meter.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';

/// Dark capsule: icon left, number right, an optional green line under it.
/// Text ellipsizes; it never shrinks.
class HudPill extends StatelessWidget {
  const HudPill({
    super.key,
    required this.icon,
    required this.text,
    this.sub,
    this.edge = GameTheme.hudWellBorder,
    this.reserveSub = false,
  });

  final String icon;
  final String text;

  /// Small green rate line under [text] (gold per minute).
  final String? sub;
  final Color edge;

  /// Keeps an empty rate line so a pill matches a sibling that has [sub]
  /// (the HUD row reads as one height).
  final bool reserveSub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
      decoration: BoxDecoration(
        color: GameTheme.hudWell,
        borderRadius: BorderRadius.circular(GameTheme.radiusPill),
        border: Border.all(color: edge, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon.asset(icon, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.hint(color: GameTheme.parchment),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.hint(color: GameTheme.gainGreen),
                  )
                else if (reserveSub)
                  ExcludeSemantics(
                    child: Text(
                      ' ',
                      maxLines: 1,
                      style: GameTheme.hint(color: GameTheme.gainGreen),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Purple hexagon with the floor ("F4"). Level and progress use purple.
class HexBadge extends StatelessWidget {
  const HexBadge({super.key, required this.label, this.semanticLabel});

  final String label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: CustomPaint(
        painter: const _HexPainter(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 30, minHeight: 22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: GameTheme.hint(color: GameTheme.parchment),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  const _HexPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cut = (h / 2).clamp(0.0, w / 3);
    final path = Path()
      ..moveTo(cut, 0)
      ..lineTo(w - cut, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w - cut, h)
      ..lineTo(cut, h)
      ..lineTo(0, h / 2)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GameTheme.levelAccent, GameTheme.levelAccentDeep],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = GameTheme.buyGoldEdge,
    );
  }

  @override
  bool shouldRepaint(covariant _HexPainter oldDelegate) => false;
}

/// Party damage per second, live with the fight. Hidden before a hit lands.
class HudDpsPill extends StatelessWidget {
  const HudDpsPill({super.key, required this.director});

  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: director.combatFrame,
      builder: (context, _, _) {
        final world = director.spatial;
        if (world == null || world.combatElapsed <= 0.05) {
          return const SizedBox.shrink();
        }
        final snap = PartyMeter.fromHeroes(
          world.heroes,
          elapsed: world.combatElapsed,
        );
        if (snap.isEmpty || snap.chipLabel == '0 DPS') {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: GameTheme.hudWell,
            borderRadius: BorderRadius.circular(GameTheme.radiusPill),
            border: Border.all(color: GameTheme.hudWellBorder),
          ),
          child: Text(
            snap.chipLabel,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.combat(color: GameTheme.parchment, height: 1.2),
          ),
        );
      },
    );
  }
}
