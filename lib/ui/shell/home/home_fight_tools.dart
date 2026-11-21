import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_state.dart';
import '../../../core/ui_feedback.dart';
import '../../menu_chrome.dart';
import '../boost_ad_button.dart';
import '../dungeon_loot_log.dart';
import '../rift_progress_hud.dart';
import '../scroll_buff_stack.dart';
import '../wisp_gift_overlay.dart';

/// Fight readouts the classic top HUD owned. They sit on the cave picture.
/// The seam, dock, and nav stay where they are.
class HomeFightTools extends StatelessWidget {
  const HomeFightTools({
    super.key,
    required this.director,
    this.seamClearance = 96,
  });

  final GameDirector director;

  /// Bottom inset so the loot log sits above the fight seam.
  final double seamClearance;

  /// Dims loot, the lantern, and WATCH AD while the wipe panel is up.
  static const Key wipeScrimKey = ValueKey('home-fight-wipe-scrim');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: director,
      builder: (context, _) {
        final state = director.state;
        final wiped = director.awaitingWipeChoice;
        final lines = [
          for (final line in director.lootLog)
            if (!wiped || !UiFeedback.isFloorClearLine(line)) line,
        ];
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            IgnorePointer(
              ignoring: wiped,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: _tools(state, lines),
              ),
            ),
            if (wiped)
              const ColoredBox(
                key: wipeScrimKey,
                color: MenuChrome.scrim,
              ),
          ],
        );
      },
    );
  }

  List<Widget> _tools(GameState state, List<String> lines) {
    return [
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
              bottom: seamClearance,
              child: DungeonLootLog(lines: lines),
            ),
            Positioned(
              right: 6,
              bottom: seamClearance,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  BoostAdButton(director: director),
                  ScrollBuffStack(
                    meta: state.metaDepth,
                    maxRows: 3,
                    maxHeight: 120,
                  ),
                ],
              ),
            ),
            WispGiftOverlay(director: director),
    ];
  }
}
