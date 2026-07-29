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

  ({Color fill, Color border, Color highlight}) get _palette => switch (style) {
        KenneyPanelStyle.brown => (
          fill: GameTheme.panel.withValues(alpha: 0.55),
          border: GameTheme.borderLit.withValues(alpha: 0.8),
          highlight: GameTheme.torch.withValues(alpha: 0.14),
        ),
        KenneyPanelStyle.beige => (
          fill: const Color(0x992E2618),
          border: GameTheme.borderLit.withValues(alpha: 0.85),
          highlight: GameTheme.torch.withValues(alpha: 0.18),
        ),
        KenneyPanelStyle.inset => (
          fill: GameTheme.panelInset.withValues(alpha: 0.62),
          border: GameTheme.border.withValues(alpha: 0.7),
          highlight: const Color(0x22000000),
        ),
        KenneyPanelStyle.border => (
          fill: GameTheme.stone.withValues(alpha: 0.58),
          border: GameTheme.borderLit.withValues(alpha: 0.85),
          highlight: GameTheme.torch.withValues(alpha: 0.12),
        ),
      };

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: palette.highlight,
            blurRadius: 0,
            spreadRadius: 1,
            offset: Offset.zero,
          ),
          const BoxShadow(
            color: Color(0x55000000),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
