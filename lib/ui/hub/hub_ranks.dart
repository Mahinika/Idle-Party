import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../game_icon.dart';
import '../game_theme.dart';
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

/// Season list with KEY / GAUNTLET / GR switch, kept on the hub.
Future<void> openHubRanksSheet(
  BuildContext context,
  GameDirector director,
) async {
  WebClickBridge.pushLayer();
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.72;
        return ListenableBuilder(
          listenable: director,
          builder: (ctx, _) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxH,
                    maxWidth: MediaQuery.sizeOf(ctx).width,
                  ),
                  child: Material(
                    color: MenuChrome.sheet,
                    borderRadius: MenuChrome.sheetRadius,
                    clipBehavior: Clip.antiAlias,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: MenuChrome.sheetRadius,
                        border: Border.all(
                          color: GameTheme.borderLit.withValues(alpha: 0.45),
                        ),
                      ),
                      child: MenuChrome.playSafeArea(
                        bottom: true,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              MenuChrome.sheetHandle(),
                              Row(
                                children: [
                                  const GameIcon.asset(
                                    UiIcon.trophy,
                                    size: 18,
                                  ),
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
                                'Switch KEY, Gauntlet, or Ranked GR.',
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
                            ],
                          ),
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
