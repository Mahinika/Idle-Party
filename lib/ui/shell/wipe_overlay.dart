import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/wipe_advice.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// Wipe modal — scene is not the owner of this overlay chrome.
class DungeonWipePanel extends StatelessWidget {
  const DungeonWipePanel({
    super.key,
    required this.director,
    required this.farm,
    required this.dailyEcho,
  });

  final GameDirector director;
  final bool farm;
  final bool dailyEcho;

  static bool bagNearlyFull(GameState state) {
    final cap = GameLogic.maxGearStashFor(state);
    return state.gearStash.length >= (cap - 2).clamp(1, cap);
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    return ColoredBox(
      color: MenuChrome.scrim,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: DecoratedBox(
            decoration: MenuChrome.hubPanel(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PARTY WIPED',
                    style: GameTheme.pixel(
                      size: 12,
                      color: GameTheme.bloodLit,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    state.inGauntlet
                        ? 'Gauntlet run ends here. PB F${state.metaDepth.gauntletBestFloor}. Return to hub to climb again.'
                        : state.inGreaterRift
                        ? 'Greater Rift ends here. Best tier ${state.metaDepth.grBestTier}. Return to hub to climb again.'
                        : state.inRift
                        ? 'Rift run ends here. Best tier ${state.metaDepth.riftBestTier}. Return to hub to try again.'
                        : dailyEcho
                        ? 'RETRY this floor · HUB ends run'
                        : farm
                        ? 'RETRY restarts this floor (F${state.currentRoom.floorNumber}). HUB ends the run.'
                        : () {
                            final safe = state.highestFloorCleared.clamp(
                              1,
                              999,
                            );
                            final cur = state.currentRoom.floorNumber;
                            if (safe >= cur) {
                              return 'RETRY restarts this floor (F$cur, still PUSH). HUB ends the run.';
                            }
                            return 'RETRY retreats to F$safe (last cleared, still PUSH). HUB ends the run.';
                          }(),
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 15,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                  if (dailyEcho) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Claim needs a clear',
                      textAlign: TextAlign.center,
                      style: GameTheme.body(
                        size: 12,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ],
                  if (state.wipeAdviceLine.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      state.wipeAdviceLine,
                      textAlign: TextAlign.center,
                      style: GameTheme.body(
                        size: 15,
                        color: GameTheme.torchHot,
                      ),
                    ),
                    if (WipeAdvice.hubHintFor(state.wipeAdviceLine) !=
                        null) ...[
                      const SizedBox(height: 6),
                      Text(
                        WipeAdvice.hubHintFor(state.wipeAdviceLine)!,
                        textAlign: TextAlign.center,
                        style: GameTheme.body(
                          size: 13,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      WipeAdvice.timingFootnote,
                      textAlign: TextAlign.center,
                      style: GameTheme.body(
                        size: 12,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (!state.inGauntlet && !state.inAnyRiftMode)
                    KenneyButton(
                      label: (farm || dailyEcho)
                          ? 'RETRY FLOOR'
                          : () {
                              final safe = state.highestFloorCleared.clamp(
                                1,
                                999,
                              );
                              final cur = state.currentRoom.floorNumber;
                              return safe < cur
                                  ? 'RETRY → F$safe'
                                  : 'RETRY FLOOR';
                            }(),
                      tip: (farm || dailyEcho)
                          ? 'Restarts this floor'
                          : () {
                              final safe = state.highestFloorCleared.clamp(
                                1,
                                999,
                              );
                              final cur = state.currentRoom.floorNumber;
                              return safe < cur
                                  ? 'Retreats to last cleared floor (PUSH)'
                                  : 'Restarts this floor (still PUSH)';
                            }(),
                      primary: true,
                      onPressed: director.retryAfterWipe,
                    ),
                  if (!state.inGauntlet &&
                      !state.inAnyRiftMode &&
                      bagNearlyFull(state)) ...[
                    const SizedBox(height: 8),
                    KenneyButton(
                      label:
                          state.gearStash.length >=
                              GameLogic.maxGearStashFor(state)
                          ? 'CLEAN BAG'
                          : 'CLEAN BAG (near full)',
                      tip:
                          'Sells junk / scraps leftovers so new drops fit',
                      style: KenneyButtonStyle.grey,
                      onPressed: director.cleanBagJunk,
                    ),
                  ],
                  if (!state.inGauntlet && !state.inAnyRiftMode)
                    const SizedBox(height: 8),
                  () {
                    final fixLabel =
                        WipeAdvice.hubCtaLabelFor(state.wipeAdviceLine);
                    final fixNav =
                        WipeAdvice.hubNavFor(state.wipeAdviceLine);
                    if (fixLabel == null || fixNav == null) {
                      return KenneyButton(
                        label: state.inGauntlet || state.inAnyRiftMode
                            ? 'END RUN → HUB'
                            : 'RETURN TO HUB',
                        style: KenneyButtonStyle.grey,
                        primary: true,
                        onPressed: director.hubAfterWipe,
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KenneyButton(
                          label: fixLabel,
                          tip: WipeAdvice.hubHintFor(state.wipeAdviceLine),
                          style: KenneyButtonStyle.grey,
                          onPressed: () =>
                              director.hubAfterWipe(openMenu: fixNav),
                        ),
                        const SizedBox(height: 8),
                        KenneyButton(
                          label: state.inGauntlet || state.inAnyRiftMode
                              ? 'END RUN → HUB'
                              : 'RETURN TO HUB',
                          style: KenneyButtonStyle.grey,
                          primary: true,
                          onPressed: director.hubAfterWipe,
                        ),
                      ],
                    );
                  }(),
                  if (WipeAdvice.godHandHintFor(state) != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'After RETRY: ${WipeAdvice.godHandHintFor(state)!}',
                      textAlign: TextAlign.center,
                      style: GameTheme.body(
                        size: 13,
                        color: GameTheme.mossLit,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
