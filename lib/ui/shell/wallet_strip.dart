import 'package:flutter/material.dart';

import '../game_icon.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';
import 'shell_common.dart';

/// Glanceable gold + essence at the top of hub, dungeon HUD, and menu sheets.
class WalletStrip extends StatelessWidget {
  const WalletStrip({
    super.key,
    required this.gold,
    required this.essence,
    this.dense = false,
  });

  final int gold;
  final int essence;

  /// Tighter padding for the combat top HUD.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    // Match bottom-tab / button weight — thin body next to IDLE PARTY reads
    // as "pyttelite" on phone even when the logical size is fine.
    final gap = dense ? 6.0 : 8.0;
    final iconSize = dense ? 20.0 : 24.0;
    final textSize = dense ? 18.0 : 22.0;
    return Semantics(
      container: true,
      label: 'Gold ${formatCount(gold)}, Essence ${formatCount(essence)}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WalletChip(
            icon: UiIcon.gold,
            label: formatCount(gold),
            tone: GameTheme.torchHot,
            iconSize: iconSize,
            textSize: textSize,
            dense: dense,
          ),
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
  });

  final String icon;
  final String label;
  final Color tone;
  final double iconSize;
  final double textSize;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            label,
            style: GameTheme.button(size: textSize, color: tone),
          ),
        ],
      ),
    );
  }
}
