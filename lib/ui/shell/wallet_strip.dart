import 'package:flutter/material.dart';

import '../game_icon.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';
import 'shell_common.dart';

/// Glanceable gold + essence at the top of hub, dungeon HUD, and menu sheets.
class WalletStrip extends StatelessWidget {
  const WalletStrip({
    super.key,
    required this.gold,
    required this.essence,
    this.dense = false,
    this.showEssence = true,
    this.goldRateSuffix,
    this.onGoldRateTap,
  });

  final int gold;
  final int essence;

  /// Tighter padding for the combat top HUD.
  final bool dense;

  /// First-hour saves hide essence until the ESSENCE tab means something.
  final bool showEssence;

  /// Hub-only compact rate (e.g. +42/m) — tap opens income sheet via [onGoldRateTap].
  final String? goldRateSuffix;
  final VoidCallback? onGoldRateTap;

  @override
  Widget build(BuildContext context) {
    // Match bottom-tab / button weight — thin body next to IDLE PARTY reads
    // as "pyttelite" on phone even when the logical size is fine.
    final gap = dense ? 6.0 : 8.0;
    final iconSize = dense ? 20.0 : 24.0;
    final textSize = dense ? 18.0 : 22.0;
    final goldLabel = 'Gold ${formatCount(gold)}';
    final label = showEssence
        ? '$goldLabel, Essence ${formatCount(essence)}'
        : goldLabel;
    return Semantics(
      container: true,
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WalletChip(
            icon: UiIcon.gold,
            label: formatCount(gold),
            suffix: goldRateSuffix,
            onTap: onGoldRateTap,
            tone: GameTheme.torchHot,
            iconSize: iconSize,
            textSize: textSize,
            dense: dense,
          ),
          if (showEssence) ...[
            SizedBox(width: gap),
            _WalletChip(
              icon: UiIcon.essence,
              label: formatCount(essence),
              tone: GameTheme.borderLit,
              iconSize: iconSize,
              textSize: textSize,
              dense: dense,
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletChip extends StatelessWidget {
  const _WalletChip({
    required this.icon,
    required this.label,
    required this.tone,
    required this.iconSize,
    required this.textSize,
    required this.dense,
    this.suffix,
    this.onTap,
  });

  final String icon;
  final String label;
  final Color tone;
  final double iconSize;
  final double textSize;
  final bool dense;
  final String? suffix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 5 : 6,
      ),
      decoration: MenuChrome.cardBox(inset: true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon.asset(icon, size: iconSize),
          SizedBox(width: dense ? 5 : 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GameTheme.button(size: textSize, color: tone),
              ),
              if (suffix != null && suffix!.isNotEmpty)
                Text(
                  suffix!,
                  style: GameTheme.body(
                    size: dense ? 9 : 10,
                    color: GameTheme.mossLit,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return WebClickScope(
      label: 'Show income details',
      onPressed: onTap,
      child: Semantics(
        button: true,
        label: 'Gold $label. $suffix',
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}
