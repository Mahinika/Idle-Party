import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../apex_forge_panel.dart';
import '../../confirm_dialogs.dart';
import '../../game_theme.dart';
import '../../kenney_button.dart';
import '../../menu_chrome.dart';
import '../../meta/codex_overlay.dart';
import '../beast_overlay.dart';
import '../essence_keep_panel.dart';
import '../relics_overlay.dart';

/// ESSENCE tiles. CAMP upgrades stay in the fight panel.
class EssenceTilesScreen extends StatelessWidget {
  const EssenceTilesScreen({super.key, required this.director, required this.router});

  final GameDirector director;
  final MenuRouter router;

  @override
  Widget build(BuildContext context) {
    if (router.homeAtSub) return _open(context);
    final state = director.state;
    return Column(
      children: [
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.4,
            children: [
              _tile(
                context,
                'BLESSING',
                MenuTabs.showKeep(state),
                'After first hour',
                () {
                  router.essencePanel = EssencePanel.keep;
                  router.pushSub();
                },
              ),
              _tile(
                context,
                'RELICS',
                MenuTabs.showRelics(state),
                'After first hour',
                () {
                  router.essencePanel = EssencePanel.relics;
                  router.pushSub();
                },
              ),
              _tile(
                context,
                'PETS',
                MenuTabs.showBeast(state),
                'Ascend or hatch',
                () {
                  router.essencePanel = EssencePanel.pets;
                  router.pushSub();
                },
              ),
              _tile(
                context,
                'CODEX',
                MenuTabs.showCodex(state),
                'Clear a floor',
                () {
                  router.open(MenuRoute.more, more: MoreSection.info, infoPane: 1);
                  router.pushSub();
                },
              ),
              _tile(
                context,
                'APEX',
                MenuTabs.showCraft(state),
                'After first hour',
                () {
                  router.open(MenuRoute.more, more: MoreSection.craft);
                  router.pushSub();
                },
              ),
            ],
          ),
        ),
        _summary(context, state),
      ],
    );
  }

  Widget _open(BuildContext context) {
    final panel = router.essencePanel;
    final body = switch (panel) {
      EssencePanel.keep => EssenceKeepPanel(director: director),
      EssencePanel.relics => RelicsOverlay(director: director),
      EssencePanel.pets => BeastOverlay(director: director),
      EssencePanel.tracks => CodexOverlay(director: director),
    };
    if (router.route == MenuRoute.more &&
        router.moreSection == MoreSection.craft) {
      return ApexHubPanel(director: director);
    }
    return SingleChildScrollView(child: body);
  }

  Widget _tile(
    BuildContext context,
    String label,
    bool open,
    String lockedHint,
    VoidCallback onTap,
  ) {
    return Semantics(
      button: open,
      label: open ? label : '$label. $lockedHint',
      child: InkWell(
        onTap: open ? onTap : null,
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
        child: DecoratedBox(
          decoration: MenuChrome.listCard(
            selected: false,
            borderColor: open ? GameTheme.borderLit : GameTheme.border,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.menuTitle(
                    size: 13,
                    color: open ? GameTheme.parchment : GameTheme.parchmentDim,
                  ),
                ),
                if (!open) ...[
                  const SizedBox(height: 2),
                  Text(
                    lockedHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.body(
                      size: 10,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(BuildContext context, GameState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Boss on F${GameLogic.bossFloorFor(state)}',
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
          if (GameLogic.canAscend(state)) ...[
            const SizedBox(height: 6),
            GameButton(
              label: 'ASCEND',
              style: GameButtonStyle.brown,
              dense: true,
              onPressed: () => confirmAscend(context, director),
            ),
          ],
        ],
      ),
    );
  }
}
