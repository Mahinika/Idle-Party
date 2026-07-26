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
      fill: GameTheme.panel,
      border: GameTheme.border,
      highlight: GameTheme.borderLit.withValues(alpha: 0.35),
    ),
    KenneyPanelStyle.beige => (
      fill: const Color(0xFF2E2618),
      border: GameTheme.borderLit,
      highlight: GameTheme.torch.withValues(alpha: 0.25),
    ),
    KenneyPanelStyle.inset => (
      fill: GameTheme.panelInset,
      border: const Color(0xFF4A4030),
      highlight: const Color(0x22000000),
    ),
    KenneyPanelStyle.border => (
      fill: GameTheme.stone,
      border: GameTheme.borderLit,
      highlight: GameTheme.torch.withValues(alpha: 0.2),
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
            offset: const Offset(0, 0),
          ),
          const BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
