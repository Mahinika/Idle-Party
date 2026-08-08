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

  ({Color top, Color bottom, Color border, Color text}) get _palette =>
      switch (style) {
        KenneyButtonStyle.brown => (
          top: const Color(0xFF5A4028),
          bottom: const Color(0xFF3A2818),
          border: GameTheme.borderLit,
          text: GameTheme.parchment,
        ),
        KenneyButtonStyle.grey => (
          top: const Color(0xFF3A3834),
          bottom: const Color(0xFF242220),
          border: const Color(0xFF8A8478),
          text: GameTheme.parchment,
        ),
        KenneyButtonStyle.red => (
          top: const Color(0xFF8A3A2A),
          bottom: const Color(0xFF5A2018),
          border: const Color(0xFFE08060),
          text: GameTheme.torchHot,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final palette = _palette;
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GameTheme.button(
          size: label.length > 14 ? 17 : 20,
          color: enabled ? palette.text : const Color(0xFF6A6458),
        ),
      ),
    );

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: enabled
                  ? [palette.top, palette.bottom]
                  : [
                      const Color(0xFF1A1816),
                      const Color(0xFF121110),
                    ],
            ),
            border: Border.all(
              color: enabled
                  ? palette.border
                  : const Color(0xFF4A443C),
              width: 2,
            ),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x66000000),
                      offset: Offset(0, 2),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  primary ? GameTheme.primaryTouch : GameTheme.minTouch,
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
