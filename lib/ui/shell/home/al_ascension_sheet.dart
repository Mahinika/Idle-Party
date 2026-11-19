import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_router.dart';
import '../../../core/meta_systems.dart';
import '../shell_common.dart';
import '../../confirm_dialogs.dart';
import '../../game_button.dart';
import '../../game_theme.dart';
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';

abstract final class AlAscensionSheetKeys {
  static const capture = ValueKey<String>('al-ascension-sheet-capture');
}

/// Second HUD line under the AL pill — bosses this run, ready, or MAX at cap.
String? alPillSubLine(GameState state) {
  if (GameLogic.isMaxAscension(state)) return 'MAX';
  final track = GameLogic.ascendTrackLabel(state);
  if (track.isEmpty) return null;
  if (track == 'Ascend ready') return track;
  final bossProgress = RegExp(r'^Ascend (\d+/\d+)$').firstMatch(track);
  if (bossProgress != null) return bossProgress.group(1);
  return track;
}

/// Plain sheet copy: current AL bonuses and what the next Ascend needs.
List<String> alAscensionSheetLines(GameState state) {
  final al = state.ascensionLevel;
  final max = GameLogic.maxAscensionLevel;
  final lines = <String>[
    'Ascend resets gold, gear, market, and this run\'s floors. '
    'Essence, pets, relics, and CAMP tracks stay.',
    'AL $al adds +${state.ascensionAttackBonus} AP, '
    '+${state.ascensionDefenseBonus} Armor, '
    '+${state.ascensionVitalityBonus} STA, '
    'and +${state.ascensionGoldBonusPercent}% gold.',
  ];
  if (GameLogic.isMaxAscension(state)) {
    lines.add('AL $al / $max — cap reached.');
  } else {
    final need = GameLogic.bossesRequiredForAscension(al);
    final next = al + 1;
    final essence =
        GameLogic.ascendEssenceReward(next) +
        MetaSystems.ascendMilestoneReward(al, next) +
        MetaSystems.ascendStreakEssence(state);
    lines.add(
      'AL $al / $max · $need boss${need == 1 ? '' : 'es'} this run to Ascend. '
      'Next pays +${formatCount(essence)} essence and ${ascendBlessingStackPhrase()}.',
    );
  }
  return lines;
}

Future<void> showAlAscensionSheet(
  BuildContext context, {
  required GameDirector director,
  required MenuRouter router,
}) async {
  WebClickBridge.pushLayer();
  try {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => ListenableBuilder(
        listenable: director,
        builder: (ctx, _) {
          final state = director.state;
          final lines = alAscensionSheetLines(state);
          final canGo = !GameLogic.isMaxAscension(state);
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: RepaintBoundary(
                key: AlAscensionSheetKeys.capture,
                child: Material(
                  color: MenuChrome.sheet,
                  borderRadius: MenuChrome.sheetRadius,
                  clipBehavior: Clip.antiAlias,
                  child: MenuChrome.playSafeArea(
                  bottom: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MenuChrome.sheetHandle(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Ascension Level',
                                style: GameTheme.title(),
                              ),
                            ),
                            MenuChrome.sheetCloseX(ctx),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < lines.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == lines.length - 1 ? 12 : 8,
                            ),
                            child: Text(
                              lines[i],
                              textAlign: TextAlign.center,
                              style: GameTheme.hint(color: GameTheme.parchmentDim),
                            ),
                          ),
                        if (canGo)
                          GameButton(
                            label: GameLogic.canAscend(state)
                                ? 'ASCEND'
                                : 'OPEN ESSENCE',
                            style: GameButtonStyle.brown,
                            dense: true,
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              if (GameLogic.canAscend(state)) {
                                confirmAscend(context, director);
                              } else {
                                router.open(MenuRoute.essence);
                                router.essencePanel = EssencePanel.keep;
                                if (!router.homeAtSub) router.pushSub();
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          );
        },
      ),
    );
  } finally {
    WebClickBridge.popLayer();
  }
}