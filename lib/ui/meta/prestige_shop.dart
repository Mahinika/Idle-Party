
import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../models/meta_depth.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// AL-gated essence sinks that survive Ascend.
class PrestigeShopOverlay extends StatelessWidget {
  const PrestigeShopOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.ascensionLevel < 3) ...[
          Text(
            'Buying unlocks at AL3+.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 14, color: GameTheme.torchHot),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Permanent upgrades · ${state.essence}e · AL${state.ascensionLevel}',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < PrestigeShopCatalog.offered.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final item = PrestigeShopCatalog.offered[i];
              final locked = state.ascensionLevel < item.minAl;
              final ownedCount = PrestigeShopCatalog.ownedCount(
                state.metaDepth,
                item.id,
              );
              final atCap = PrestigeShopCatalog.atCap(
                state.metaDepth,
                item.id,
              );
              final canBuy = !locked && !atCap && state.essence >= item.cost;
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: MenuChrome.listCard(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.name,
                      style: GameTheme.body(
                        size: 15,
                        color: locked
                            ? GameTheme.parchmentDim
                            : GameTheme.torchHot,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: GameTheme.body(
                        size: 14,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final have = _prestigeHaveLine(state, item.id);
                        if (have.isEmpty) return const SizedBox.shrink();
                        return Text(
                          have,
                          style: GameTheme.body(
                            size: 12,
                            color: GameTheme.mossLit,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            locked
                                ? 'Needs AL${item.minAl}'
                                : atCap
                                ? 'MAX'
                                : '${item.cost}e'
                                      '${ownedCount > 0 ? ' · x$ownedCount' : ''}',
                            style: GameTheme.body(
                              size: 13,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                        ),
                        GameButton(
                          label: locked
                              ? 'AL${item.minAl}+'
                              : atCap
                              ? 'MAX'
                              : 'BUY ${item.cost}e',
                          expanded: false,
                          onPressed: canBuy
                              ? () => director.buyPrestigeShopItem(item.id)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  static String _prestigeHaveLine(GameState state, String id) {
    final md = state.metaDepth;
    return switch (id) {
      'stash_slot' => 'Have ${md.stashBonusSlots} extra bag slots (max 20)',
      'combine_luck' =>
        'Luck ${md.combinatorLuck}/5 · MERGE −${md.combinatorLuck * 3}g',
      'torch_keep' =>
        'Now +${state.torchOfflineGoldPercent}% hub AFK gold (max 80%)',
      'gh_cdr' =>
        'CD ${state.godHandCooldownSeconds.toStringAsFixed(2)}s · '
            'Lv${md.godHandCdLevel}/8 · same as ESSENCE KEEP',
      'roster_cap' => 'Roster +${md.petRosterCapBonus} (max +10)',
      'loadout_slot' =>
        'Loadouts ${GameLogic.maxLoadoutsFor(state)} '
            '(base 3 · shop +${md.loadoutBonusSlots}/2)',
      'flask_discount' =>
        'Market −${md.marketDiscountLevel * 5}% gold (max 25%)',
      'filter_span' =>
        'Auto-sell/scrap max iLvl ${GameLogic.maxAutoSellIlvlCap(state)} '
            '(+${md.filterSpanLevel * 8} from shop)',
      'offline_ledger' =>
        'Welcome Back rows ${3 + md.offlineHighlightBonus} (max 6)',
      'legacy_spark' => 'Legacy ATK +${md.legacyPoints} (max 20)',
      'daily_essence' =>
        'Vault claim +${GameLogic.dailyVaultClaimEssence(state)}e '
            '· Daily Run ${25 + md.dailyEssenceBonusLevel * GameLogic.dawnTitheEssencePerLevel}e',
      'gauntlet_gold' =>
        '+${md.gauntletGoldBonusLevel * 4}% Gauntlet gold (max 20%)',
      _ => '',
    };
  }
}
