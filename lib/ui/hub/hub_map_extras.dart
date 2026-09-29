import 'package:flutter/material.dart';

import '../../models/meta_depth.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../shell/scroll_buff_stack.dart';
import '../web_click_bridge.dart';

/// One map-corner control for buffs, ranks, and scrolls.
class HubMapExtrasFab extends StatelessWidget {
  const HubMapExtrasFab({
    super.key,
    required this.meta,
    required this.showPowerups,
    required this.onRanks,
    required this.onPowerups,
  });

  final MetaDepthState meta;
  final bool showPowerups;
  final VoidCallback onRanks;
  final VoidCallback onPowerups;

  @override
  Widget build(BuildContext context) {
    return WebClickScope(
      label: 'Map extras',
      onPressed: () => _openSheet(context),
      child: Semantics(
        button: true,
        label: 'Map extras. Buffs, ranks, scrolls',
        onTap: () => _openSheet(context),
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openSheet(context),
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
                          child: GameIcon.asset(UiIcon.star, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'EXTRA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.body(
                        size: 10,
                        color: GameTheme.parchmentDim,
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

  Future<void> _openSheet(BuildContext context) async {
    WebClickBridge.pushLayer();
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: MenuChrome.scrim,
        builder: (ctx) => Align(
          alignment: Alignment.bottomCenter,
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
                    Text(
                      'On the map',
                      textAlign: TextAlign.center,
                      style: GameTheme.menuTitle(size: 16),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: ScrollBuffStack(meta: meta, maxHeight: 120),
                    ),
                    const SizedBox(height: 12),
                    GameButton(
                      label: 'RANKS',
                      style: GameButtonStyle.brown,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onRanks();
                      },
                    ),
                    if (showPowerups) ...[
                      const SizedBox(height: 6),
                      GameButton(
                        label: 'SCROLLS',
                        style: GameButtonStyle.grey,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onPowerups();
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    GameButton(
                      label: 'CLOSE',
                      style: GameButtonStyle.grey,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      WebClickBridge.popLayer();
    }
  }
}
