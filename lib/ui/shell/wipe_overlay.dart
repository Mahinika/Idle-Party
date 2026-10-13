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
    final plain = GameLogic.plainPlayerChrome(state);
    final modeLine = WipeAdvice.modeLineFor(state);
    return ColoredBox(
      color: MenuChrome.scrim,
      child: Center(
        child: Material(
          color: Colors.transparent,
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
                  const SizedBox(height: 8),
                  Text(
                    state.inGauntlet
                        ? 'Climb ends. PB F${state.metaDepth.gauntletBestFloor}.'
                        : state.inGreaterRift
                        ? 'Ranked GR ends. Best GR${state.metaDepth.grBestTier}.'
                        : state.inRift
                        ? 'Farm Rift ends. Best R${state.metaDepth.riftBestTier}.'
                        : plain
                        ? 'They go again in a moment. HUB leaves the cave.'
                        : dailyEcho
                        ? 'RETRY this floor. HUB ends the run.'
                        : farm
                        ? 'RETRY restarts F${state.currentRoom.floorNumber}. HUB ends the run.'
                        : () {
                            final cur = state.currentRoom.floorNumber;
                            final uncleared =
                                cur > state.highestFloorCleared;
                            if (uncleared &&
                                state.wipeStreakCount >=
                                    GameLogic.pushWipesBeforeFarm) {
                              final safe = state.highestFloorCleared.clamp(
                                1,
                                999,
                              );
                              return 'Two wipes on F$cur. Farming F$safe, then back here.';
                            }
                            if (uncleared) {
                              return 'Same floor again. A second wipe farms the floor below.';
                            }
                            return 'RETRY restarts F$cur. HUB ends the run.';
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
                  if (modeLine != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      modeLine,
                      textAlign: TextAlign.center,
                      style: GameTheme.body(
                        size: 12,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ],
                  if (state.wipeAdviceLine.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 4),
                      initiallyExpanded: false,
                      title: Text(
                        'Why?',
                        textAlign: TextAlign.center,
                        style: GameTheme.body(
                          size: 14,
                          color: GameTheme.torchHot,
                        ),
                      ),
                      children: [
                        Text(
                          state.wipeAdviceLine,
                          textAlign: TextAlign.center,
                          style: GameTheme.body(
                            size: 14,
                            color: GameTheme.torchHot,
                          ),
                        ),
                        if (!plain)
                          if (WipeAdvice.shownScanLine(
                                saved: state.wipeScanLine,
                                live: director.spatial == null
                                    ? null
                                    : WipeFightSnapshot.fromWorld(
                                        director.spatial!,
                                      ),
                              )
                              case final scan?) ...[
                            const SizedBox(height: 6),
                            Text(
                              scan,
                              textAlign: TextAlign.center,
                              style: GameTheme.body(
                                size: 12,
                                color: GameTheme.parchmentDim,
                              ),
                            ),
                          ],
                        if (WipeAdvice.hubHintFor(state.wipeAdviceLine)
                            case final hint?) ...[
                          const SizedBox(height: 6),
                          Text(
                            hint,
                            textAlign: TextAlign.center,
                            style: GameTheme.body(
                              size: 13,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  ValueListenableBuilder<int>(
                    valueListenable: director.wipeAutoSeconds,
                    builder: (context, seconds, _) {
                      if (seconds <= 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Fighting again in $seconds',
                          textAlign: TextAlign.center,
                          style: GameTheme.body(
                            size: 13,
                            color: GameTheme.torchHot,
                          ),
                        ),
                      );
                    },
                  ),
                  if (!state.inGauntlet && !state.inAnyRiftMode)
                    GameButton(
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
                      tip: plain
                          ? 'Sends them in again'
                          : (farm || dailyEcho)
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
                    GameButton(
                      label:
                          state.gearStash.length >=
                              GameLogic.maxGearStashFor(state)
                          ? 'SELL JUNK'
                          : 'SELL JUNK (near full)',
                      tip:
                          'Clears weak drops so new loot can fit',
                      style: GameButtonStyle.grey,
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
                    if (fixLabel == null) {
                      return GameButton(
                        label: state.inGauntlet || state.inAnyRiftMode
                            ? 'HUB'
                            : 'HUB',
                        style: GameButtonStyle.grey,
                        primary: true,
                        onPressed: director.hubAfterWipe,
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GameButton(
                          label: fixLabel,
                          tip: WipeAdvice.hubHintFor(state.wipeAdviceLine),
                          style: GameButtonStyle.brown,
                          primary: true,
                          onPressed: () => director.hubAfterWipe(
                            openMenu: fixNav,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GameButton(
                          label: 'HUB',
                          style: GameButtonStyle.grey,
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
      ),
    );
  }
}
