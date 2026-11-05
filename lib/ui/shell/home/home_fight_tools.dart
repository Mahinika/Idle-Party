import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../boost_ad_button.dart';
import '../dungeon_loot_log.dart';
import '../rift_progress_hud.dart';
import '../scroll_buff_stack.dart';
import '../wisp_gift_overlay.dart';

/// Fight readouts the classic top HUD owned. They sit on the cave picture.
/// The seam, dock, and nav stay where they are.
class HomeFightTools extends StatelessWidget {
  const HomeFightTools({super.key, required this.director});

  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: director,
      builder: (context, _) {
        final state = director.state;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (state.inRift)
              Positioned(
                left: 8,
                right: 8,
                top: 4,
                child: IgnorePointer(
                  child: RiftProgressHud(
                    progress01: state.riftProgress01,
                    guardianActive: state.riftGuardianActive,
                    farm: true,
                    tier: state.riftTier,
                    timerMs: state.riftTimerMs,
                  ),
                ),
              ),
            if (state.inGreaterRift)
              Positioned(
                left: 8,
                right: 8,
                top: 4,
                child: IgnorePointer(
                  child: RiftProgressHud(
                    progress01: state.grProgress01,
                    guardianActive: state.grGuardianActive,
                    farm: false,
                    tier: state.grTier,
                    timerMs: state.grTimerMs,
                    parMs: state.grParMs,
                  ),
                ),
              ),
            Positioned(
              left: 8,
              right: 72,
              bottom: 4,
              child: DungeonLootLog(lines: director.lootLog),
            ),
            Positioned(
              right: 6,
              bottom: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  BoostAdButton(director: director),
                  ScrollBuffStack(meta: state.metaDepth, maxHeight: 120),
                ],
              ),
            ),
            WispGiftOverlay(director: director),
          ],
        );
      },
    );
  }
}
