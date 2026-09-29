import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../meta/play_games_section.dart';
import '../web_click_bridge.dart';

/// Hub-map shortcut for season ranks. Same corner family as SCROLLS.
class HubRanksFab extends StatelessWidget {
  const HubRanksFab({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return WebClickScope(
      label: 'RANKS',
      onPressed: onOpen,
      child: Semantics(
        button: true,
        label: 'RANKS. Season boards',
        onTap: onOpen,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(GameTheme.radiusMd),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: GameTheme.minTouch,
                minHeight: GameTheme.minTouch,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: GameTheme.primaryTouch,
                      height: GameTheme.primaryTouch,
                      child: DecoratedBox(
                        decoration: MenuChrome.hubPanel(selected: true),
                        child: const Center(
                          child: GameIcon.asset(UiIcon.trophy, size: 26),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'RANKS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.body(
                        size: 10,
                        color: GameTheme.torchHot,
                      ),
                    ),
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

/// Season list with KEY / GAUNTLET / GR switch.
/// Full height, same top edge as GEAR / GOLD — the hub does not peek above.
Future<void> openHubRanksSheet(
  BuildContext context,
  GameDirector director,
) async {
  WebClickBridge.pushLayer();
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: MenuChrome.scrim,
      // Drop the Material 3 sheet cap (max width 640) so the panel is edge to edge.
      constraints: const BoxConstraints(maxWidth: double.infinity),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: director,
          builder: (ctx, _) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: SizedBox.expand(
                key: const Key('hub-ranks-sheet'),
                child: Material(
                  color: GameTheme.panel,
                  child: DecoratedBox(
                    decoration: MenuChrome.panel(
                      borderRadius: BorderRadius.zero,
                      opaque: true,
                    ),
                    child: MenuChrome.playSafeArea(
                      bottom: true,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const GameIcon.asset(UiIcon.trophy, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'RANKS',
                                    style: GameTheme.menuTitle(size: 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'KEY, Gauntlet, Ranked GR, or party power.',
                              style: GameTheme.body(
                                size: 12,
                                color: GameTheme.parchmentDim,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: PlayGamesBoardsSection(
                                  director: director,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GameButton(
                              label: 'BACK',
                              style: GameButtonStyle.grey,
                              dense: true,
                              onPressed: () => Navigator.of(ctx).pop(),
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
        );
      },
    );
  } finally {
    WebClickBridge.popLayer();
  }
}
