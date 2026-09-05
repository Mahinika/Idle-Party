import 'package:flutter/material.dart';

import '../core/meta_systems.dart';
import 'cave_atmosphere.dart';
import '../assets/custom_assets.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';

/// Blocks cold start until the player updates a Play-installed build.
class PlayUpdateRequiredScreen extends StatelessWidget {
  const PlayUpdateRequiredScreen({
    super.key,
    required this.onUpdate,
    this.updating = false,
  });

  final VoidCallback onUpdate;
  final bool updating;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CaveAtmosphere.fullBleedScene(
            CustomAssets.introScene,
            alignment: const Alignment(0, -0.05),
          ),
          CaveAtmosphere.readabilityScrim(top: 0.7, bottom: 0.55),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  KenneySprite(asset: CustomAssets.introLogo, size: 72),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    label:
                        'Update required. A newer Idle Party is on Google Play. '
                        'Update to keep playing.',
                    child: Column(
                      children: [
                        Text(
                          'UPDATE REQUIRED',
                          textAlign: TextAlign.center,
                          style: GameTheme.menuTitle(size: 20),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'A newer Idle Party is on Google Play.\n'
                          'Update to keep playing.',
                          textAlign: TextAlign.center,
                          style: GameTheme.body(
                            size: 15,
                            color: GameTheme.parchment,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                  GameButton(
                    label: updating ? 'OPENING…' : 'UPDATE',
                    style: GameButtonStyle.brown,
                    primary: true,
                    onPressed: updating ? null : onUpdate,
                    tip: 'Update from Google Play',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    MetaSystems.currentVersion,
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
