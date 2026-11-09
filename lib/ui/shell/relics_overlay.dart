import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/relics.dart';
import '../game_theme.dart';
import '../../assets/kenney_assets.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';
import 'shell_layout.dart';

String _pile(int n, String one, String many) => '$n ${n == 1 ? one : many}';

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
    final canDiscover = next != null && md.embers >= discoverCost;
    final nextRelic = next;
    final ownedCount = state.unlockedRelics.length;
    final ownedHeight = (ownedCount * 132.0).clamp(0.0, 280.0);
    return Padding(
      padding: ShellLayout.listPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellLayout.hint(
            '${_pile(md.embers, 'Ember', 'Embers')} · '
            '${_pile(md.cinders, 'Cinder', 'Cinders')} · survive Ascend',
            maxLines: 2,
          ),
          ShellLayout.gap(8),
          if (nextRelic != null)
            Semantics(
              button: canDiscover,
              label: 'Discover ${nextRelic.name}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canDiscover
                      ? () => director.unlockRelic(nextRelic.id)
                      : null,
                  borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: canDiscover
                          ? GameTheme.buttonBrownBottom
                          : GameTheme.buttonDisabledBottom,
                      borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                      border: Border.all(
                        color: canDiscover
                            ? GameTheme.torch.withValues(alpha: 0.65)
                            : GameTheme.buttonDisabledBorder,
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: GameTheme.minTouch,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'DISCOVER ${nextRelic.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GameTheme.button(
                                color: canDiscover
                                    ? GameTheme.torchHot
                                    : GameTheme.buttonDisabledText,
                              ),
                            ),
                            Text(
                              canDiscover
                                  ? _pile(discoverCost, 'Ember', 'Embers')
                                  : 'Need ${discoverCost - md.embers} more Embers',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GameTheme.hint(
                                color: canDiscover
                                    ? GameTheme.parchment
                                    : GameTheme.parchmentDim,
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
          if (state.unlockedRelics.isEmpty) ...[
            ShellLayout.gap(8),
            ShellLayout.hint(
              'No relics yet. Embers from bosses, Ascend, and salvage. '
              'Cinders from Daily Vault — discover your first relic here.',
              maxLines: 3,
            ),
          ],
          if (ownedCount > 0) ...[
            ShellLayout.gap(8),
            SizedBox(
              height: ownedHeight,
              child: ListView(
                children: [
                  for (final id in state.unlockedRelics.reversed)
                    _OwnedRelic(director: director, relicId: id),
                ],
              ),
            ),
          ],
          ShellLayout.gap(8),
          ShellLayout.secondaryActionRow(
            children: [
              GameButton(
                label:
                    '4 Cinders → 1 Ember · $trades/${GameLogic.cinderExchangeWeeklyCap} this week',
                style: GameButtonStyle.grey,
                dense: true,
                onPressed:
                    trades < GameLogic.cinderExchangeWeeklyCap &&
                        md.cinders >= GameLogic.cinderExchangeCost
                    ? director.exchangeCinders
                    : null,
              ),
              GameButton(
                label: '2 tickets → 1 Cinder',
                style: GameButtonStyle.grey,
                dense: true,
                onPressed: md.adTickets >= GameLogic.ticketCostPerCinder
                    ? director.buyCinderWithTickets
                    : null,
              ),
            ],
          ),
          ShellLayout.gap(12),
        ],
      ),
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
                      style: GameTheme.readable(color: GameTheme.parchment),
                    ),
                    Text(
                      pay,
                      style: GameTheme.section(color: GameTheme.mossLit),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tier < RelicCatalog.maxTier) ...[
            const SizedBox(height: 6),
            GameButton(
              label: state.metaDepth.embers >= tierCost
                  ? 'T$nextTier · ${def?.payoutAt(1) ?? ''} · $tierCost Embers'
                  : 'Need ${tierCost - state.metaDepth.embers} more Embers',
              tip: state.metaDepth.embers >= tierCost
                  ? null
                  : 'Need ${tierCost - state.metaDepth.embers} more Embers',
              style: GameButtonStyle.grey,
              onPressed: state.metaDepth.embers >= tierCost
                  ? () => director.upgradeRelicTier(relicId)
                  : null,
            ),
          ],
          const SizedBox(height: 6),
          GameButton(
            label: state.metaDepth.cinders >= GameLogic.salvageCinderCost
                ? 'SALVAGE · ${GameLogic.salvageCinderCost} Cinders'
                : 'Need ${GameLogic.salvageCinderCost - state.metaDepth.cinders} more Cinders',
            tip: state.metaDepth.cinders >= GameLogic.salvageCinderCost
                ? null
                : 'Need ${GameLogic.salvageCinderCost - state.metaDepth.cinders} more Cinders',
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
