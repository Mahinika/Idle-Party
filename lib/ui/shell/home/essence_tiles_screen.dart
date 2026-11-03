import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../../core/gold_income.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../apex_forge_panel.dart';
import '../../confirm_dialogs.dart';
import '../../game_theme.dart';
import '../../kenney_button.dart';
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
            padding: const EdgeInsets.all(12),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              _tile(
                context,
                'BLESSING',
                MenuTabs.showKeep(state),
                'Opens after the first hour.',
                () {
                  router.essencePanel = EssencePanel.keep;
                  router.pushSub();
                },
              ),
              _tile(
                context,
                'RELICS',
                MenuTabs.showRelics(state),
                'Opens after the first hour.',
                () {
                  router.essencePanel = EssencePanel.relics;
                  router.pushSub();
                },
              ),
              _tile(
                context,
                'PETS',
                MenuTabs.showBeast(state),
                'Opens at Ascend, or when you can hatch.',
                () {
                  router.essencePanel = EssencePanel.pets;
                  router.pushSub();
                },
              ),
              _tile(
                context,
                'CODEX',
                MenuTabs.showCodex(state),
                'Clear a floor first.',
                () {
                  router.open(MenuRoute.more, more: MoreSection.info, infoPane: 1);
                  router.pushSub();
                },
              ),
              _tile(
                context,
                'APEX',
                MenuTabs.showCraft(state),
                'Opens after the first hour.',
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
    String locked,
    VoidCallback onTap,
  ) {
    return Semantics(
      button: open,
      label: open ? label : '$label. $locked',
      child: InkWell(
        onTap: open ? onTap : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GameTheme.card,
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            border: Border.all(color: GameTheme.borderLit.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              open ? label : '$label\n$locked',
              textAlign: TextAlign.center,
              style: GameTheme.body(
                size: 12,
                color: open ? GameTheme.parchment : GameTheme.parchmentDim,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(BuildContext context, GameState state) {
    final gold = GoldIncome.perMinuteLabel(GoldIncome.hubGoldPerMinute(state));
    final essence = GoldIncome.essenceDue(60, state.sanctuaryPowerLevel);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$gold · essence $essence/min',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          Text(
            'Boss on F${GameLogic.bossFloorFor(state)}',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          if (GameLogic.canAscend(state))
            GameButton(
              label: 'ASCEND',
              style: GameButtonStyle.brown,
              onPressed: () => confirmAscend(context, director),
            ),
        ],
      ),
    );
  }
}
