import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../models/meta_depth.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// AL-gated essence sinks that survive Ascend (embedded on KEEP when [compact]).
class PrestigeShopOverlay extends StatelessWidget {
  const PrestigeShopOverlay({
    super.key,
    required this.director,
    this.compact = false,
  });
  final GameDirector director;
  final bool compact;

  static String haveLine(GameState state, String id) {
    final md = state.metaDepth;
    return switch (id) {
      'stash_slot' => '${md.stashBonusSlots} extra bag slots',
      'combine_luck' => 'Luck ${md.combinatorLuck}/5',
      'torch_keep' => '+${state.torchOfflineGoldPercent}% hub AFK gold',
      'gh_cdr' =>
        'CD ${state.godHandCooldownSeconds.toStringAsFixed(1)}s · KEEP',
      'roster_cap' => 'Roster +${md.petRosterCapBonus}',
      'loadout_slot' => 'Loadouts ${GameLogic.maxLoadoutsFor(state)}',
      'flask_discount' => 'Market −${md.marketDiscountLevel * 5}%',
      'filter_span' => 'Auto-sell iLvl ${GameLogic.maxAutoSellIlvlCap(state)}',
      'offline_ledger' => 'Welcome Back ${3 + md.offlineHighlightBonus} rows',
      'legacy_spark' => 'Legacy ATK +${md.legacyPoints}',
      'daily_essence' => 'Vault +${GameLogic.dailyVaultClaimEssence(state)}e',
      'gauntlet_gold' => '+${md.gauntletGoldBonusLevel * 4}% Gauntlet gold',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final offered = PrestigeShopCatalog.offered;
    final buyable = <PrestigeShopItem>[];
    final locked = <PrestigeShopItem>[];
    final maxed = <PrestigeShopItem>[];
    for (final item in offered) {
      if (PrestigeShopCatalog.atCap(state.metaDepth, item.id)) {
        maxed.add(item);
      } else if (state.ascensionLevel < item.minAl) {
        locked.add(item);
      } else {
        buyable.add(item);
      }
    }
    // Compact KEEP: buyable first, then a few locked teasers — hide maxed.
    final shown = compact
        ? <PrestigeShopItem>[...buyable, ...locked.take(3)]
        : <PrestigeShopItem>[...buyable, ...locked, ...maxed];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          if (state.ascensionLevel < 3) ...[
            Text(
              'Buying unlocks at AL3+.',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 14, color: GameTheme.torchHot),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Permanent upgrades · ${state.essence}e · AL${state.ascensionLevel}\n'
            'Not the bottom-tab SHOP (real-money convenience).',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 10),
        ],
        if (shown.isEmpty)
          Text(
            compact ? 'All permanent buys maxed.' : 'Nothing listed.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) SizedBox(height: compact ? 4 : 8),
          _PrestigeRow(
            director: director,
            item: shown[i],
            compact: compact,
          ),
        ],
        if (compact && maxed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${maxed.length} maxed hidden',
              style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
            ),
          ),
      ],
    );
  }
}

class _PrestigeRow extends StatelessWidget {
  const _PrestigeRow({
    required this.director,
    required this.item,
    required this.compact,
  });

  final GameDirector director;
  final PrestigeShopItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final locked = state.ascensionLevel < item.minAl;
    final ownedCount = PrestigeShopCatalog.ownedCount(state.metaDepth, item.id);
    final atCap = PrestigeShopCatalog.atCap(state.metaDepth, item.id);
    final canBuy = !locked && !atCap && state.essence >= item.cost;
    final have = PrestigeShopOverlay.haveLine(state, item.id);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: MenuChrome.listCard(),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GameTheme.body(
                      size: 13,
                      color: locked
                          ? GameTheme.parchmentDim
                          : GameTheme.parchment,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    locked
                        ? 'AL${item.minAl}+'
                        : (have.isNotEmpty ? have : item.description),
                    style: GameTheme.body(
                      size: 11,
                      color: locked
                          ? GameTheme.parchmentDim
                          : GameTheme.mossLit,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            GameButton(
              label: locked
                  ? 'AL${item.minAl}+'
                  : atCap
                  ? 'MAX'
                  : '${item.cost}e',
              expanded: false,
              dense: true,
              onPressed: canBuy
                  ? () => director.buyPrestigeShopItem(item.id)
                  : null,
            ),
          ],
        ),
      );
    }

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
              color: locked ? GameTheme.parchmentDim : GameTheme.torchHot,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
          ),
          if (have.isNotEmpty)
            Text(
              have,
              style: GameTheme.body(size: 12, color: GameTheme.mossLit),
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
  }
}
