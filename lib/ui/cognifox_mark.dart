import 'package:flutter/material.dart';

import '../assets/custom_assets.dart';
import '../core/story_lore.dart';

/// Shared Cognifox Studio lockup (loading + boot intro).
///
/// Uses the real studio mark (not a pixel conversion). Smooth filtering —
/// this is brand art, not a Kenney tile.
class CognifoxStudioMark extends StatelessWidget {
  const CognifoxStudioMark({
    super.key,
    this.logoSize = 168,
  });

  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final cache = (logoSize * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(128, 512);
    return Semantics(
      header: true,
      label: StoryLore.studioName,
      child: Image.asset(
        CustomAssets.studioLogo,
        width: logoSize,
        height: logoSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        isAntiAlias: true,
        cacheWidth: cache,
      ),
    );
  }
}
