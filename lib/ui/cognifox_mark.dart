import 'package:flutter/material.dart';

import '../assets/custom_assets.dart';
import '../core/story_lore.dart';
import 'game_theme.dart';
import 'kenney_sprite.dart';

/// Shared Cognifox Studio lockup (loading + boot intro).
class CognifoxStudioMark extends StatelessWidget {
  const CognifoxStudioMark({
    super.key,
    this.logoSize = 112,
    this.nameSize = 15,
    this.showName = true,
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
          KenneySprite(asset: CustomAssets.studioLogo, size: logoSize),
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
