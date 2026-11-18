import 'package:flutter/material.dart';

import 'game_theme.dart';
import 'web_click_bridge.dart';

/// [gold]: a purchase you can afford (muted buy gold, like the price chips
/// on FORGE / CAMP / MARKET cards). Brown stays for non-buys.
/// brown = neutral action, gold = buy, go = start / enter / claim (amber),
/// essence = an essence spend, grey = secondary, red = leave, ghost = quiet.
enum GameButtonStyle { brown, grey, red, ghost, gold, go, essence }

/// Action button.
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

  ({Color top, Color bottom, Color border, Color text, Color glow, Color edge})
  get _palette => switch (style) {
    GameButtonStyle.brown => (
      top: GameTheme.buttonBrownTop,
      bottom: GameTheme.buttonBrownBottom,
      border: GameTheme.borderLit.withValues(alpha: 0.75),
      text: GameTheme.parchment,
      glow: GameTheme.torch.withValues(alpha: 0.22),
      edge: GameTheme.buyGoldEdge,
    ),
    GameButtonStyle.grey => (
      top: GameTheme.buttonGreyTop,
      bottom: GameTheme.buttonGreyBottom,
      border: GameTheme.border.withValues(alpha: 0.95),
      text: GameTheme.parchment,
      glow: Colors.transparent,
      edge: GameTheme.buyGreyEdge,
    ),
    GameButtonStyle.red => (
      top: GameTheme.buttonRedTop,
      bottom: GameTheme.buttonRedBottom,
      border: GameTheme.bloodLit.withValues(alpha: 0.85),
      text: GameTheme.torchHot,
      glow: GameTheme.bloodLit.withValues(alpha: 0.2),
      edge: GameTheme.chunkyRedEdge,
    ),
    GameButtonStyle.gold => (
      top: GameTheme.buyGoldTop,
      bottom: GameTheme.buyGoldBottom,
      border: GameTheme.buyGoldShine,
      text: GameTheme.buyGoldText,
      glow: GameTheme.torch.withValues(alpha: 0.22),
      edge: GameTheme.buyGoldEdge,
    ),
    GameButtonStyle.go => (
      top: GameTheme.goTop,
      bottom: GameTheme.goBottom,
      border: GameTheme.goShine,
      text: GameTheme.goText,
      glow: GameTheme.torch.withValues(alpha: 0.26),
      edge: GameTheme.buyGoldEdge,
    ),
    GameButtonStyle.essence => (
      top: GameTheme.essenceBuyTop,
      bottom: GameTheme.essenceBuyBottom,
      border: GameTheme.essenceBuyShine,
      text: GameTheme.essenceBuyText,
      glow: GameTheme.levelAccent.withValues(alpha: 0.22),
      edge: GameTheme.essenceBuyEdge,
    ),
    GameButtonStyle.ghost => (
      top: GameTheme.panelInset.withValues(alpha: 0.55),
      bottom: GameTheme.panelInset.withValues(alpha: 0.35),
      border: GameTheme.border.withValues(alpha: 0.75),
      text: GameTheme.torchHot,
      glow: Colors.transparent,
      edge: GameTheme.border.withValues(alpha: 0.75),
    ),
  };

  /// Invisible tap margin above and below the painted face.
  static const double _facePad = 3;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final palette = _palette;
    final radius = BorderRadius.circular(GameTheme.radiusSm);
    final padH = dense ? 10.0 : 14.0;
    final padV = dense ? 4.0 : 7.0;
    final fontSize = dense ? GameTheme.typeButtonDense : GameTheme.typeButton;
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
        borderRadius: radius,
        // The painted face is [_facePad] shorter on each side than the tap
        // area, so the button reads lighter and still meets 44/48 dp.
        child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _facePad),
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
            // Chunky face: dark rim, a hard drop shadow when it can be
            // pressed, and a light top edge (see [ChunkyFace]).
            border: Border.all(
              color: enabled ? palette.edge : GameTheme.border,
              width: GameTheme.chunkyRim,
            ),
            boxShadow: enabled && style != GameButtonStyle.ghost
                ? const [
                    BoxShadow(
                      color: GameTheme.chunkyShadow,
                      offset: Offset(0, GameTheme.chunkyDepth),
                    ),
                  ]
                : null,
          ),
          child: _ShineEdge(
            color: enabled && style != GameButtonStyle.ghost
                ? palette.border
                : null,
            child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (dense
                      ? GameTheme.minTouch
                      : (primary ? GameTheme.primaryTouch : GameTheme.minTouch)) -
                  2 * _facePad,
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
        ),
      ),
    );

    final tipped = tip == null || !enabled
        ? button
        : Tooltip(
            message: tip!,
            triggerMode: TooltipTriggerMode.longPress,
            preferBelow: false,
            child: button,
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
        child: tipped,
      ),
    );
  }
}

/// A 2 px light line along the top inside edge. Null [color] paints none.
class _ShineEdge extends StatelessWidget {
  const _ShineEdge({required this.color, required this.child});

  final Color? color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = color;
    if (c == null) return child;
    return Stack(
      children: [
        child,
        Positioned(
          left: 3,
          right: 3,
          top: 1,
          height: 1,
          child: IgnorePointer(child: ColoredBox(color: c)),
        ),
      ],
    );
  }
}
