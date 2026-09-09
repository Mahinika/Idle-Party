import 'package:flutter/material.dart';

import '../assets/custom_assets.dart';
import '../core/story_lore.dart';
import 'cave_atmosphere.dart';
import 'game_theme.dart';
import 'kenney_sprite.dart';

/// Cold-start splash while [GameDirector.boot] runs. No minimum dwell.
///
/// Kept visually aligned with the Android `launch_background` (ink + logo)
/// so the handoff from native → Flutter does not flash a different look.
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
            CaveAtmosphere.fullBleedScene(
              CustomAssets.introScene,
              alignment: const Alignment(0, -0.15),
            ),
            CaveAtmosphere.readabilityScrim(top: 0.62, bottom: 0.72),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KenneySprite(asset: CustomAssets.introLogo, size: 112),
                  const SizedBox(height: 16),
                  Text(
                    'IDLE PARTY',
                    textAlign: TextAlign.center,
                    style: GameTheme.pixel(
                      size: 26,
                      color: GameTheme.torchHot,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    StoryLore.introTagline,
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 12,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: GameTheme.torch.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading…',
                    style: GameTheme.body(
                      size: 13,
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
