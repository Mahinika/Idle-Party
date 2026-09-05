import 'package:flutter/material.dart';

import 'game_theme.dart';
import 'web_click_bridge.dart';

enum GameButtonStyle { brown, grey, red, ghost }

/// Action button. Prefer this name; [KenneyButton] is the same widget.
class GameButton extends StatelessWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = GameButtonStyle.brown,
    this.expanded = true,
    this.primary = false,
    this.dense = false,
    this.tip,
  });

  final String label;
  final VoidCallback? onPressed;
  final GameButtonStyle style;
  final bool expanded;

  /// Material-sized primary CTA (ENTER / Ascend / MERGE).
  final bool primary;

  /// Tighter padding for cramped phone sheets (GEAR actions, CLOSE).
  /// Still meets [GameTheme.minTouch].
  final bool dense;

  /// Long-press / hover hint (phone + accessibility).
  final String? tip;

  ({Color top, Color bottom, Color border, Color text, Color glow})
  get _palette => switch (style) {
    GameButtonStyle.brown => (
      top: GameTheme.buttonBrownTop,
      bottom: GameTheme.buttonBrownBottom,
      border: GameTheme.borderLit.withValues(alpha: 0.75),
      text: GameTheme.parchment,
      glow: GameTheme.torch.withValues(alpha: 0.22),
    ),
    GameButtonStyle.grey => (
      top: GameTheme.buttonGreyTop,
      bottom: GameTheme.buttonGreyBottom,
      border: GameTheme.border.withValues(alpha: 0.95),
      text: GameTheme.parchment,
      glow: Colors.transparent,
    ),
    GameButtonStyle.red => (
      top: GameTheme.buttonRedTop,
      bottom: GameTheme.buttonRedBottom,
      border: GameTheme.bloodLit.withValues(alpha: 0.85),
      text: GameTheme.torchHot,
      glow: GameTheme.bloodLit.withValues(alpha: 0.2),
    ),
    GameButtonStyle.ghost => (
      top: GameTheme.panelInset.withValues(alpha: 0.55),
      bottom: GameTheme.panelInset.withValues(alpha: 0.35),
      border: GameTheme.border.withValues(alpha: 0.75),
      text: GameTheme.torchHot,
      glow: Colors.transparent,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final palette = _palette;
    final radius = BorderRadius.circular(GameTheme.radiusSm);
    final padH = dense ? 10.0 : 14.0;
    final padV = dense ? 6.0 : 11.0;
    final fontSize = dense
        ? (label.length > 14 ? 14.0 : 15.0)
        : (label.length > 14 ? 17.0 : 19.0);
    final child = Padding(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GameTheme.button(
          size: fontSize,
          color: enabled ? palette.text : GameTheme.buttonDisabledText,
        ),
      ),
    );

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        onLongPress: tip == null || !enabled
            ? null
            : () {
                final messenger = ScaffoldMessenger.maybeOf(context);
                messenger?.hideCurrentSnackBar();
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text(tip!),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: enabled
                  ? [palette.top, palette.bottom]
                  : [
                      GameTheme.buttonDisabledTop,
                      GameTheme.buttonDisabledBottom,
                    ],
            ),
            border: Border.all(
              color: enabled
                  ? palette.border
                  : GameTheme.buttonDisabledBorder,
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
                      color: GameTheme.shadowSoft,
                      offset: Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: dense
                  ? GameTheme.minTouch
                  : (primary ? GameTheme.primaryTouch : GameTheme.minTouch),
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
        label: tip == null ? label : '$label. $tip',
        onTap: onPressed,
        excludeSemantics: true,
        child: tip == null
            ? button
            : Tooltip(message: tip!, preferBelow: false, child: button),
      ),
    );
  }
}

/// Old name — same widget as [GameButton].
typedef KenneyButton = GameButton;

/// Old name — same enum as [GameButtonStyle].
typedef KenneyButtonStyle = GameButtonStyle;
