import 'package:flutter/material.dart';

import '../game_theme.dart';

/// Last floor payoffs, oldest at the top. Text only — no banner.
class DungeonLootLog extends StatefulWidget {
  const DungeonLootLog({super.key, required this.lines});

  final List<String> lines;

  @override
  State<DungeonLootLog> createState() => _DungeonLootLogState();
}

class _DungeonLootLogState extends State<DungeonLootLog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rise;
  String? _seen;

  @override
  void initState() {
    super.initState();
    _rise = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _seen = widget.lines.isEmpty ? null : widget.lines.last;
  }

  @override
  void didUpdateWidget(DungeonLootLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.lines.isEmpty ? null : widget.lines.last;
    if (next != null && next != _seen) {
      _seen = next;
      _rise.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  static bool _rare(String line) {
    return RegExp(
      r'\b(rare|epic|legendary)\b',
      caseSensitive: false,
    ).hasMatch(line);
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.lines;
    if (lines.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Semantics(
        container: true,
        label: 'Recent loot. ${lines.last}',
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _rise,
            builder: (context, _) {
              final lift = (1 - _rise.value) * 8;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < lines.length; i++)
                    _line(lines[i], i, lines.length, i == lines.length - 1 ? lift : 0),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _line(String text, int index, int count, double lift) {
    final rare = _rare(text);
    return Transform.translate(
      offset: Offset(0, lift),
      child: Text(
        text,
        maxLines: rare ? 2 : 1,
        overflow: rare ? TextOverflow.fade : TextOverflow.ellipsis,
        style: GameTheme.readable(color: _color(index, count, rare)).copyWith(
          shadows: const [
            Shadow(
              color: GameTheme.lootInkShadow,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
    );
  }

  static Color _color(int index, int count, bool rare) {
    if (rare) return GameTheme.torchHot;
    if (count <= 1) return GameTheme.parchment.withValues(alpha: 0.9);
    final newest = index == count - 1;
    final t = index / (count - 1);
    return (newest ? GameTheme.parchment : GameTheme.parchmentDim).withValues(
      alpha: 0.34 + 0.56 * t,
    );
  }
}
