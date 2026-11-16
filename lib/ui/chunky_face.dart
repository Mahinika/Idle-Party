import 'package:flutter/material.dart';

import 'game_theme.dart';

/// One meaning per tone. Gold = buy / can afford. Grey = locked or cannot
/// afford. Rose = the picked toggle. Red = leave / danger. Stone = a plain
/// action that is neither. Orange = a live boost (2× speed).
enum ChunkyTone { gold, grey, rose, red, stone, orange }

/// Chunky pixel button face: dark outline, a light top edge, and a hard
/// drop shadow so it reads as pressable. Pure paint; callers own the tap,
/// the semantics, and the 44/48 dp floor (pass it as [minHeight]).
class ChunkyFace extends StatelessWidget {
  const ChunkyFace({
    super.key,
    required this.child,
    this.tone = ChunkyTone.stone,
    this.raised = true,
    this.highlight = false,
    this.minWidth = 0,
    this.minHeight = GameTheme.minTouch,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.radius = GameTheme.radiusSm,
  });

  final Widget child;
  final ChunkyTone tone;

  /// Hard shadow under the face. Off for disabled or pressed looks.
  final bool raised;

  /// Torch rim (BEST or the focused choice).
  final bool highlight;
  final double minWidth;
  final double minHeight;
  final EdgeInsets padding;
  final double radius;

  static (Color, Color, Color, Color) colorsFor(ChunkyTone tone) =>
      switch (tone) {
        ChunkyTone.gold => (
          GameTheme.buyGoldTop,
          GameTheme.buyGoldBottom,
          GameTheme.buyGoldShine,
          GameTheme.buyGoldEdge,
        ),
        ChunkyTone.grey => (
          GameTheme.buyGreyTop,
          GameTheme.buyGreyBottom,
          GameTheme.buyGreyShine,
          GameTheme.buyGreyEdge,
        ),
        ChunkyTone.rose => (
          GameTheme.toggleOnTop,
          GameTheme.toggleOnBottom,
          GameTheme.toggleOnShine,
          GameTheme.buyGoldEdge,
        ),
        ChunkyTone.red => (
          GameTheme.buttonRedTop,
          GameTheme.buttonRedBottom,
          GameTheme.bloodLit,
          GameTheme.buyGreyEdge,
        ),
        ChunkyTone.stone => (
          GameTheme.chunkyStoneTop,
          GameTheme.chunkyStoneBottom,
          GameTheme.buyGreyShine,
          GameTheme.buyGreyEdge,
        ),
        ChunkyTone.orange => (
          GameTheme.boostOrangeTop,
          GameTheme.boostOrangeBottom,
          GameTheme.buyGoldShine,
          GameTheme.buyGoldEdge,
        ),
      };

  /// Readable label color on [tone].
  static Color textOn(ChunkyTone tone) => switch (tone) {
    ChunkyTone.gold => GameTheme.buyGoldText,
    ChunkyTone.grey => GameTheme.buyGreyText,
    ChunkyTone.rose => GameTheme.toggleOnText,
    ChunkyTone.red => GameTheme.parchment,
    ChunkyTone.stone => GameTheme.parchment,
    ChunkyTone.orange => GameTheme.buyGoldText,
  };

  @override
  Widget build(BuildContext context) {
    final (top, bottom, shine, edge) = colorsFor(tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlight ? GameTheme.torchHot : edge,
          width: 2,
        ),
        boxShadow: raised
            ? const [
                BoxShadow(
                  color: GameTheme.chunkyShadow,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: minHeight),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Padding(
              padding: padding,
              child: Align(widthFactor: 1, heightFactor: 1, child: child),
            ),
            Positioned(
              top: 2,
              left: radius / 2 + 2,
              right: radius / 2 + 2,
              height: 2,
              child: IgnorePointer(child: ColoredBox(color: shine)),
            ),
          ],
        ),
      ),
    );
  }
}
