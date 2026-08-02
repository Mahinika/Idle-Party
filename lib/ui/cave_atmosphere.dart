import 'package:flutter/material.dart';

import 'game_theme.dart';

/// Shared “painted cave” presentation used by intro / hub / dungeon chrome.
abstract final class CaveAtmosphere {
  /// Full-bleed pixel scene under game chrome.
  static Widget fullBleedScene(
    String asset, {
    Alignment alignment = Alignment.center,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: GameTheme.ink),
        Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: alignment,
          filterQuality: FilterQuality.none,
          isAntiAlias: false,
          gaplessPlayback: true,
          // Cap decode size — painted scenes are huge on disk.
          cacheWidth: 960,
          cacheHeight: 960,
        ),
      ],
    );
  }

  /// Darkens edges so HUD / brand stay readable over painted art.
  static Widget readabilityScrim({double top = 0.55, double bottom = 0.45}) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(5, 4, 3, top),
              const Color(0x00050403),
              const Color(0x00050403),
              Color.fromRGBO(5, 4, 3, bottom),
            ],
            stops: const [0.0, 0.22, 0.62, 1.0],
          ),
        ),
      ),
    );
  }

  /// Soft warm torch bloom (animated by caller via [intensity] 0..1).
  static Widget torchBloom({
    required double intensity,
    Alignment alignment = const Alignment(0, 0.35),
    double sizeFactor = 0.55,
  }) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide * sizeFactor * intensity;
          return Align(
            alignment: alignment,
            child: Container(
              width: side,
              height: side * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    GameTheme.torch.withValues(alpha: 0.2 * intensity),
                    GameTheme.torch.withValues(alpha: 0.05 * intensity),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
