import 'package:flutter/material.dart';

import 'kenney_assets.dart';

enum KenneyPanelStyle { brown, beige, inset, border }

class KenneyPanel extends StatelessWidget {
  const KenneyPanel({
    super.key,
    required this.child,
    required this.padding,
    this.style = KenneyPanelStyle.brown,
    this.centerSlice = const Rect.fromLTWH(12, 12, 8, 8),
  });

  final Widget child;
  final EdgeInsets padding;
  final KenneyPanelStyle style;
  final Rect centerSlice;

  String get _asset => switch (style) {
    KenneyPanelStyle.brown => KenneyAssets.panelBrown,
    KenneyPanelStyle.beige => KenneyAssets.panelBeige,
    KenneyPanelStyle.inset => KenneyAssets.panelInsetBrown,
    KenneyPanelStyle.border => KenneyAssets.panelBorder,
  };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(_asset),
          fit: BoxFit.fill,
          centerSlice: centerSlice,
          filterQuality: FilterQuality.none,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
