import 'package:flutter/material.dart';

import 'game_theme.dart';
import 'web_click_bridge.dart';

enum KenneyButtonStyle { brown, grey, red }

class KenneyButton extends StatelessWidget {
  const KenneyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = KenneyButtonStyle.brown,
    this.expanded = true,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final KenneyButtonStyle style;
  final bool expanded;

  /// Material-sized primary CTA (ENTER / Ascend / MERGE).
  final bool primary;

  ({Color top, Color bottom, Color border, Color text, Color glow})
  get _palette => switch (style) {
    KenneyButtonStyle.brown => (
      top: const Color(0xFF6B4E2E),
      bottom: const Color(0xFF3E2A18),
      border: GameTheme.borderLit.withValues(alpha: 0.75),
      text: GameTheme.parchment,
      glow: GameTheme.torch.withValues(alpha: 0.22),
    ),
    KenneyButtonStyle.grey => (
      top: const Color(0xFF2A3340),
      bottom: const Color(0xFF171E28),
      border: GameTheme.border.withValues(alpha: 0.95),
      text: GameTheme.parchment,
      glow: Colors.transparent,
    ),
    KenneyButtonStyle.red => (
      top: const Color(0xFF9A4030),
      bottom: const Color(0xFF5A2018),
      border: GameTheme.bloodLit.withValues(alpha: 0.85),
      text: GameTheme.torchHot,
      glow: GameTheme.bloodLit.withValues(alpha: 0.2),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final palette = _palette;
    final radius = BorderRadius.circular(GameTheme.radiusSm);
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GameTheme.button(
          size: label.length > 14 ? 17 : 19,
          color: enabled ? palette.text : const Color(0xFF5A6270),
        ),
      ),
    );

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: enabled
                  ? [palette.top, palette.bottom]
                  : [const Color(0xFF151A22), const Color(0xFF0E1218)],
            ),
            border: Border.all(
              color: enabled ? palette.border : const Color(0xFF2A3340),
              width: 1.2,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: palette.glow,
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                    const BoxShadow(
                      color: Color(0x66000000),
                      offset: Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: primary ? GameTheme.primaryTouch : GameTheme.minTouch,
            ),
            child: expanded
                ? SizedBox(
                    width: double.infinity,
                    child: Center(child: child),
                  )
                : Center(child: child),
          ),
        ),
      ),
    );

    return WebClickScope(
      label: label,
      onPressed: onPressed,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: button,
      ),
    );
  }
}
