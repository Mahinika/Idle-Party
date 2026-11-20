import 'package:flutter/material.dart';

import '../../core/gear/gear_upgrade_copy.dart';
import '../game_theme.dart';

/// Green upgrade chip on a bag tile or hero row.
class GearBagBadge extends StatelessWidget {
  const GearBagBadge({
    super.key,
    required this.isBest,
    required this.powerDelta,
  });

  final bool isBest;
  final int? powerDelta;

  static bool needsCompact(BuildContext context, int powerDelta) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    if (scale > GameTheme.typeScaleMax - 0.01) return true;
    final painter = TextPainter(
      text: TextSpan(
        text: GearUpgradeCopy.upgradeBadgeLabel(powerDelta, compact: false),
        style: GameTheme.hint(color: GameTheme.clear),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout(maxWidth: 52);
    final fits = !painter.didExceedMaxLines && painter.width <= 52;
    painter.dispose();
    return !fits;
  }

  static Widget _chip(Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
    decoration: BoxDecoration(
      color: GameTheme.mossChip,
      borderRadius: BorderRadius.circular(3),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    if (isBest) {
      return Semantics(
        label: 'Best upgrade in bag',
        child: ExcludeSemantics(
          child: _chip(
            Text(
              GearUpgradeCopy.bestBadgeLabel,
              style: GameTheme.hint(color: GameTheme.clear),
            ),
          ),
        ),
      );
    }
    final delta = powerDelta;
    if (delta == null || delta <= 0) return const SizedBox.shrink();
    final compact = needsCompact(context, delta);
    final semantics = GearUpgradeCopy.upgradeBadgeSemantics(delta);
    final style = GameTheme.hint(color: GameTheme.clear);
  if (compact) {
      return Semantics(
        label: semantics,
        child: ExcludeSemantics(
          child: _chip(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('+$delta', style: style),
                Text(' ↑', style: style),
              ],
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: semantics,
      child: ExcludeSemantics(
        child: _chip(
          Text(
            GearUpgradeCopy.upgradeBadgeLabel(delta, compact: false),
            style: style,
          ),
        ),
      ),
    );
  }
}