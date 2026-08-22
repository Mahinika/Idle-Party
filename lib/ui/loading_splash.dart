import 'package:flutter/material.dart';

import 'custom_assets.dart';
import 'game_theme.dart';
import 'kenney_sprite.dart';

/// Cold-start splash while [GameDirector.boot] runs. No minimum dwell.
class LoadingSplash extends StatelessWidget {
  const LoadingSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.ink,
      body: Semantics(
        label: 'Loading Idle Party',
        liveRegion: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: GameTheme.ink),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KenneySprite(asset: CustomAssets.introLogo, size: 96),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: GameTheme.torch.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading…',
                    style: GameTheme.body(
                      size: 14,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
