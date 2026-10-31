import 'package:flutter/material.dart';

import '../game_theme.dart';

/// Last floor payoffs, oldest at the top. Text only — no banner.
class DungeonLootLog extends StatelessWidget {
  const DungeonLootLog({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Semantics(
        container: true,
        label: 'Recent loot. ${lines.last}',
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines.length; i++)
                Text(
                  lines[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      GameTheme.body(
                        size: 15,
                        color: _color(i, lines.length),
                      ).copyWith(
                        shadows: const [
                          Shadow(
                            color: GameTheme.lootInkShadow,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _color(int index, int count) {
    if (count <= 1) return GameTheme.parchment.withValues(alpha: 0.9);
    final newest = index == count - 1;
    final t = index / (count - 1);
    return (newest ? GameTheme.parchment : GameTheme.parchmentDim).withValues(
      alpha: 0.34 + 0.56 * t,
    );
  }
}
