import 'package:flutter/material.dart';

import '../assets/custom_assets.dart';
import '../core/story_lore.dart';
import 'game_theme.dart';

/// Shared Cognifox Studio lockup (loading + boot intro).
///
/// Uses the real studio mark (not a pixel conversion). Smooth filtering —
/// this is brand art, not a Kenney tile.
class CognifoxStudioMark extends StatelessWidget {
  const CognifoxStudioMark({
    super.key,
    this.logoSize = 168,
    this.nameSize = 15,
    this.showName = false,
  });

  final double logoSize;
  final double nameSize;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: StoryLore.studioName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            CustomAssets.studioLogo,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            isAntiAlias: true,
          ),
          if (showName) ...[
            const SizedBox(height: 18),
            Text(
              StoryLore.studioName.toUpperCase(),
              textAlign: TextAlign.center,
              style: GameTheme.menuTitle(
                size: nameSize,
                color: GameTheme.parchment,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
