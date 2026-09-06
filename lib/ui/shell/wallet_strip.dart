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
    final gap = dense ? 4.0 : 6.0;
    return Semantics(
      container: true,
      label: 'Gold ${formatCount(gold)}, Essence ${formatCount(essence)}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MenuChrome.chip(
            icon: UiIcon.gold,
            label: formatCount(gold),
            tone: GameTheme.torchHot,
          ),
          SizedBox(width: gap),
          MenuChrome.chip(
            icon: UiIcon.essence,
            label: formatCount(essence),
            tone: GameTheme.borderLit,
          ),
        ],
      ),
    );
  }
}
