import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/relics.dart';
import '../game_theme.dart';
import '../../assets/kenney_assets.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';

/// ESSENCE → Relics. Discover and level with Embers. Cinders salvage.
class RelicsOverlay extends StatelessWidget {
  const RelicsOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final md = state.metaDepth;
    final nextId = GameLogic.nextRelicId(state);
    final next = nextId == null ? null : RelicCatalog.byId(nextId);
    final discoverCost = RelicCatalog.discoverCost(state.unlockedRelics.length);
    final trades = GameLogic.cinderExchangesUsed(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${md.embers} Embers · ${md.cinders} Cinders · survive Ascend',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 8),
        if (next != null)
          GameButton(
            label: 'DISCOVER ${next.name} · $discoverCost Embers',
            onPressed: md.embers >= discoverCost
                ? () => director.unlockRelic(next.id)
                : null,
          ),
        const SizedBox(height: 8),
        for (final id in state.unlockedRelics.reversed)
          _OwnedRelic(director: director, relicId: id),
        GameButton(
          label:
              '4 Cinders → 1 Ember · $trades/${GameLogic.cinderExchangeWeeklyCap} this week',
          style: GameButtonStyle.grey,
          onPressed:
              trades < GameLogic.cinderExchangeWeeklyCap &&
                  md.cinders >= GameLogic.cinderExchangeCost
              ? director.exchangeCinders
              : null,
        ),
        const SizedBox(height: 6),
        GameButton(
          label: '2 tickets → 1 Cinder',
          style: GameButtonStyle.grey,
          onPressed: md.adTickets >= GameLogic.ticketCostPerCinder
              ? director.buyCinderWithTickets
              : null,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _OwnedRelic extends StatelessWidget {
  const _OwnedRelic({required this.director, required this.relicId});
  final GameDirector director;
  final String relicId;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final def = RelicCatalog.byId(relicId);
    final name = def?.name ?? relicId;
    final tier = state.relicTierOf(relicId);
    final pay = GameLogic.relicOwnedPayout(state, relicId);
    final nextTier = tier + 1;
    final tierCost = GameLogic.relicTierUpgradeCost(nextTier);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: MenuChrome.listCard(selected: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KenneySprite(asset: KenneyAssets.relicIconFor(relicId), size: 36),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name · T$tier',
                      style: GameTheme.body(size: 16, color: GameTheme.parchment),
                    ),
                    Text(
                      pay,
                      style: GameTheme.body(size: 13, color: GameTheme.mossLit),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tier < RelicCatalog.maxTier) ...[
            const SizedBox(height: 6),
            GameButton(
              label: 'T$nextTier · ${def?.payoutAt(1) ?? ''} · $tierCost Embers',
              style: GameButtonStyle.grey,
              onPressed: state.metaDepth.embers >= tierCost
                  ? () => director.upgradeRelicTier(relicId)
                  : null,
            ),
          ],
          const SizedBox(height: 6),
          GameButton(
            label: 'SALVAGE · ${GameLogic.salvageCinderCost} Cinders',
            style: GameButtonStyle.red,
            onPressed: state.metaDepth.cinders >= GameLogic.salvageCinderCost
                ? () => director.salvageRelic(relicId)
                : null,
          ),
        ],
      ),
    );
  }
}
