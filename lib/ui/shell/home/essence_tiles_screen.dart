import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../apex_forge_panel.dart';
import '../../confirm_dialogs.dart';
import '../../../assets/custom_assets.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../kenney_button.dart';
import '../../menu_chrome.dart';
import '../../meta/codex_overlay.dart';
import '../beast_overlay.dart';
import '../essence_keep_panel.dart';
import '../power_upgrade_row.dart';
import '../relics_overlay.dart';

/// ESSENCE tiles. CAMP upgrades stay in the fight panel.
class EssenceTilesScreen extends StatelessWidget {
  /// Icon tile on each ESSENCE tile (fits the 1.15x touch CRAFT row).
  static const double iconTile = 36;

  const EssenceTilesScreen({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

  @override
  Widget build(BuildContext context) {
    if (router.homeAtSub) return _open(context);
    final state = director.state;
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 1.45);
    final aspect = 2.4 / textScale;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: aspect,
                children: [
                  _tile(
                    context,
                    'BLESSING',
                    UiIcon.embers,
                    GameTheme.statMove,
                    MenuTabs.showKeep(state),
                    'After the first boss or Ascend',
                    () {
                      router.essencePanel = EssencePanel.keep;
                      router.pushSub();
                    },
                  ),
                  _tile(
                    context,
                    'RELICS',
                    CustomAssets.iconRelicPhoenixEmber,
                    GameTheme.statCrit,
                    MenuTabs.showRelics(state),
                    'After the first boss or Ascend',
                    () {
                      router.essencePanel = EssencePanel.relics;
                      router.pushSub();
                    },
                  ),
                  _tile(
                    context,
                    'PETS',
                    CustomAssets.petEgg,
                    GameTheme.statVitality,
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
                    CustomAssets.iconBook,
                    GameTheme.statArmor,
                    MenuTabs.showCodex(state),
                    'Clear a floor',
                    () {
                      router.essencePanel = EssencePanel.tracks;
                      router.pushSub();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _tile(
                context,
                'CRAFT',
                UiIcon.wand,
                GameTheme.statMastery,
                MenuTabs.showCraft(state),
                'After the first boss or Ascend',
                () {
                  router.open(MenuRoute.more, more: MoreSection.craft);
                  router.pushSub();
                },
                fullWidth: true,
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
    String icon,
    Color accent,
    bool open,
    String lockedHint,
    VoidCallback onTap, {
    bool fullWidth = false,
  }) {
    final tile = Semantics(
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                UpgradeIconTile(
                  icon: icon,
                  accent: accent,
                  size: iconTile,
                  dim: !open,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GameTheme.readable(
                          color: open
                              ? GameTheme.parchment
                              : GameTheme.parchmentDim,
                        ),
                      ),
                      if (!open) ...[
                        const SizedBox(height: 2),
                        Text(
                          lockedHint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GameTheme.hint(color: GameTheme.parchmentDim),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (fullWidth) {
      return SizedBox(height: GameTheme.minTouch * 1.15, child: tile);
    }
    return tile;
  }

  Widget _summary(BuildContext context, GameState state) {
    if (!GameLogic.canAscend(state)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: GameButton(
        label: 'ASCEND',
        style: GameButtonStyle.brown,
        dense: true,
        onPressed: () => confirmAscend(context, director),
      ),
    );
  }
}
