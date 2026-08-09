import 'package:flutter/material.dart';

import 'game_theme.dart';

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

  /// Kept for call-site compatibility; painted panels no longer use 9-slices.
  final Rect centerSlice;

  ({Color fillTop, Color fillBottom, Color border}) get _palette =>
      switch (style) {
        KenneyPanelStyle.brown => (
          fillTop: GameTheme.panel.withValues(alpha: 0.72),
          fillBottom: GameTheme.stoneDeep.withValues(alpha: 0.78),
          border: GameTheme.borderLit.withValues(alpha: 0.4),
        ),
        KenneyPanelStyle.beige => (
          fillTop: const Color(0x992A2218),
          fillBottom: const Color(0x9918100C),
          border: GameTheme.borderLit.withValues(alpha: 0.5),
        ),
        KenneyPanelStyle.inset => (
          fillTop: GameTheme.panelInset.withValues(alpha: 0.75),
          fillBottom: GameTheme.ink.withValues(alpha: 0.7),
          border: GameTheme.border.withValues(alpha: 0.75),
        ),
        KenneyPanelStyle.border => (
          fillTop: GameTheme.stone.withValues(alpha: 0.7),
          fillBottom: GameTheme.stoneDeep.withValues(alpha: 0.75),
          border: GameTheme.borderLit.withValues(alpha: 0.45),
        ),
      };

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.fillTop, palette.fillBottom],
        ),
        borderRadius: BorderRadius.circular(GameTheme.radiusMd),
        border: Border.all(color: palette.border, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
