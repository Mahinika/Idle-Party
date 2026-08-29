import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';

/// POWER → Relics — permanent party auras (was under Gold → KEEP).
class RelicsOverlay extends StatelessWidget {
  const RelicsOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text(
          '${state.essence} essence · survives Ascend',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        Text(
          'Buy once · upgrade tiers · permanent party auras.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        for (final relicId in GameLogic.relicOrder)
          _RelicCard(director: director, relicId: relicId),
        KenneyButton(
          label: 'RESPEC · no refund · ${GameLogic.respecRelicsCost(state)}e',
          style: KenneyButtonStyle.red,
          onPressed:
              (state.unlockedRelics.isNotEmpty ||
                      state.metaDepth.relicTiers.isNotEmpty) &&
                  state.essence >= GameLogic.respecRelicsCost(state)
              ? director.respecRelics
              : null,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _RelicCard extends StatelessWidget {
  const _RelicCard({required this.director, required this.relicId});
  final GameDirector director;
  final String relicId;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final owned = state.hasRelic(relicId);
    final name = GameLogic.relicNames[relicId] ?? relicId;
    final cost = GameLogic.relicCosts[relicId] ?? 0;
    final tier = owned
        ? (state.metaDepth.relicTierOf(relicId) < 1
              ? 1
              : state.metaDepth.relicTierOf(relicId))
        : 0;
    final desc = _desc(state, owned, tier);
    final nextPayout = GameLogic.relicPerTierPayout(relicId);
    final nextTier = tier + 1;
    final tierCost = GameLogic.relicTierUpgradeCost(nextTier);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: MenuChrome.listCard(selected: owned),
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
                      owned ? '$name · T$tier' : name,
                      style: GameTheme.body(
                        size: 16,
                        color: GameTheme.parchment,
                      ),
                    ),
                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        style: GameTheme.body(
                          size: 13,
                          color: owned
                              ? GameTheme.mossLit
                              : GameTheme.parchmentDim,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!owned) ...[
            const SizedBox(height: 6),
            KenneyButton(
              label: '$name  ${cost}e',
              onPressed: state.essence < cost
                  ? null
                  : () => director.unlockRelic(relicId),
            ),
          ] else if (tier < 3) ...[
            const SizedBox(height: 6),
            KenneyButton(
              label: nextPayout.isEmpty
                  ? 'UPGRADE TIER  T$nextTier  ${tierCost}e'
                  : 'T$nextTier · $nextPayout · ${tierCost}e',
              style: KenneyButtonStyle.grey,
              onPressed: state.essence >= tierCost
                  ? () => director.upgradeRelicTier(relicId)
                  : null,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'T3 · MAX',
                style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
              ),
            ),
        ],
      ),
    );
  }

  String _desc(GameState state, bool owned, int tier) => switch (relicId) {
    GameLogic.warBannerRelic => owned
        ? 'Permanent +${state.relicAttackBonus} team attack (T$tier).'
        : 'Permanent +4 team attack per tier.',
    GameLogic.ironWardRelic => owned
        ? 'Permanent +${state.relicDefenseBonus} team defense (T$tier).'
        : 'Permanent +${GameLogic.relicDefensePerTier} team defense per tier.',
    GameLogic.phoenixEmberRelic => owned
        ? 'Permanent +${state.relicVitalityBonus} max HP per hero (T$tier).'
        : 'Permanent +${GameLogic.relicVitalityPerTier} max HP per hero per tier.',
    GameLogic.godHandFocusRelic => owned
        ? '+${state.relicGodHandDamageBonus} God Hand damage (T$tier).'
        : '+3 God Hand damage per tier.',
    GameLogic.chamberLuckRelic => owned
        ? '+${state.relicLootFindPercent}% loot find (T$tier).'
        : '+5% loot find per tier.',
    GameLogic.ironWillRelic => owned
        ? '+${state.relicMitigateFlat} flat mitigate (T$tier).'
        : '+${GameLogic.relicMitigatePerTier} flat mitigate per tier.',
    _ => GameLogic.relicDescriptions[relicId] ?? '',
  };
}
