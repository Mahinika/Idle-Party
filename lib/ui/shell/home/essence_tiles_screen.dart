import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../../core/relics.dart';
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
import '../shell_common.dart';

/// ESSENCE tiles. CAMP upgrades stay in the fight panel.
class EssenceTilesScreen extends StatelessWidget {
  /// Icon tile on each ESSENCE tile (fits the 1.15x touch CRAFT row).
  static const double iconTile = 36;

  /// Gold "can buy" dot on an ESSENCE tile.
  static const Key buyDotKey = ValueKey('essence-tile-buy-dot');

  static String blessingStatus(GameState s) =>
      'Hand Lv${s.godHandLevel} · next '
      '${formatCount(GameLogic.godHandUpgradeCost(s.godHandLevel))}e';

  static String relicStatus(GameState s) {
    final owned = s.unlockedRelics.length;
    return '$owned/${RelicCatalog.all.length} · next '
        '${RelicCatalog.discoverCost(owned)} embers';
  }

  /// Padlock on a locked ESSENCE tile.
  static const Key lockKey = ValueKey('essence-tile-lock');

  /// Rim width of the active (last opened) tile.
  static const double activeRim = 2;

  /// Same height the old 2.4 grid aspect gave at 1.0 on a 360 dp phone.
  static const double gridTileMinHeight = 70;

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
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            children: [
              // Rows of two that grow with their text: a fixed grid aspect
              // cut the locked hints and overflowed CRAFT at 1.45.
              _tileRow(
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
                  active: router.essenceHubLit == EssencePanel.keep,
                  status: EssenceTilesScreen.blessingStatus(state),
                  canBuy:
                      state.essence >=
                      GameLogic.godHandUpgradeCost(state.godHandLevel),
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
                  active: router.essenceHubLit == EssencePanel.relics,
                  status: EssenceTilesScreen.relicStatus(state),
                  canBuy:
                      state.metaDepth.embers >=
                      RelicCatalog.discoverCost(state.unlockedRelics.length),
                ),
              ),
              const SizedBox(height: 6),
              _tileRow(
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
                  active: router.essenceHubLit == EssencePanel.pets,
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
                  active: router.essenceHubLit == EssencePanel.tracks,
                ),
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
    bool active = false,
    String? status,
    bool canBuy = false,
  }) {
    // The panel the ESSENCE tab reopens: amber rim and a soft glow (the
    // selected-toggle amber), so the hub shows where you were.
    final lit = active && open;
    final tile = Semantics(
      button: open,
      selected: lit,
      label: open ? label : '$label. $lockedHint',
      child: InkWell(
        onTap: open ? onTap : null,
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
        child: DecoratedBox(
          decoration: lit
              ? MenuChrome.listCard(selected: true).copyWith(
                  border: Border.all(
                    color: GameTheme.toggleOnAccent,
                    width: activeRim,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: GameTheme.toggleOnAccent.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ],
                )
              : MenuChrome.listCard(
                  selected: false,
                  borderColor: open ? GameTheme.borderLit : GameTheme.border,
                ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                // Locked tiles get a padlock, like ENDGAME cards (F095).
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UpgradeIconTile(
                      icon: icon,
                      accent: accent,
                      size: iconTile,
                      dim: !open,
                    ),
                    if (!open)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: DecoratedBox(
                          key: EssenceTilesScreen.lockKey,
                          decoration: BoxDecoration(
                            color: GameTheme.stoneDeep,
                            shape: BoxShape.circle,
                            border: Border.all(color: GameTheme.border),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: GameIcon.glyph(
                              UiGlyph.lock,
                              size: 11,
                              color: GameTheme.parchment,
                            ),
                          ),
                        ),
                      ),
                  ],
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
                          color: lit
                              ? GameTheme.torchHot
                              : open
                              ? GameTheme.parchment
                              : GameTheme.parchmentDim,
                        ),
                      ),
                      // Level / owned and the next price, plus a gold dot
                      // when it is affordable (audit F051).
                      if (open && status != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                status,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GameTheme.hint(
                                  color: GameTheme.parchmentDim,
                                ),
                              ),
                            ),
                            if (canBuy) ...[
                              const SizedBox(width: 4),
                              Container(
                                key: EssenceTilesScreen.buyDotKey,
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: GameTheme.torchHot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (!open) ...[
                        const SizedBox(height: 2),
                        Text(
                          lockedHint,
                          maxLines: 3,
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: fullWidth ? GameTheme.minTouch * 1.15 : gridTileMinHeight,
      ),
      child: tile,
    );
  }

  /// Two tiles side by side, both as tall as the taller one.
  Widget _tileRow(Widget a, Widget b) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: 6),
          Expanded(child: b),
        ],
      ),
    );
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
