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
        alignment: Alignment.center,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        isAntiAlias: true,
        cacheWidth: cache,
      ),
    );
  }
}

/// Ink stage for loading + boot studio card.
///
/// First Flutter frames can be 0×0 (`Width is zero`); a [Column] + [Spacer]
/// then parks the mark at the top-left until the view sizes. Skip painting
/// the logo until we have a real box, then pin it with [Align].
class CognifoxSplashStage extends StatelessWidget {
  const CognifoxSplashStage({
    super.key,
    this.logo,
    this.footer,
  });

  /// Defaults to the studio mark. Boot intro wraps it in a fade.
  final Widget? logo;
  final Widget? footer;

  /// Same vertical slot as the old Spacer(2)+mark+Spacer(3) column.
  static const Alignment markAlignment = Alignment(0, -0.2);

  static const double _minBox = 32;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ready = constraints.maxWidth >= _minBox &&
            constraints.maxHeight >= _minBox;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              Align(
                alignment: markAlignment,
                child: logo ?? const CognifoxStudioMark(logoSize: 196),
              ),
            if (ready && footer != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: footer,
              ),
          ],
        );
      },
    );
  }
}
