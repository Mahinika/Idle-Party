import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_bar.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';
import 'shell_common.dart';

class JobsOverlay extends StatelessWidget {
  const JobsOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final ready = state.missions.where((m) => m.isComplete).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Contracts — clear goals while you dungeon. Claim for gold + essence.',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        if (ready > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$ready ready to claim',
              style: GameTheme.body(size: 13, color: GameTheme.mossLit),
            ),
          ),
        const SizedBox(height: 8),
        for (final mission in state.missions)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: MenuChrome.listCard(
              borderColor: switch (mission.tier) {
                2 => GameTheme.bloodLit,
                1 => GameTheme.torchHot,
                _ => GameTheme.border.withValues(alpha: 0.9),
              },
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: GameTheme.body(
                          size: 16,
                          color: switch (mission.tier) {
                            2 => GameTheme.bloodLit,
                            1 => GameTheme.torchHot,
                            _ => GameTheme.parchment,
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${mission.progress}/${mission.target}  '
                        '+${mission.goldReward}g +${mission.essenceReward}e',
                        style: GameTheme.body(size: 14),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                        child: LinearProgressIndicator(
                          value: mission.target <= 0
                              ? 0
                              : (mission.progress / mission.target).clamp(
                                  0.0,
                                  1.0,
                                ),
                          minHeight: 8,
                          backgroundColor: GameTheme.panelInset,
                          color: mission.isComplete
                              ? GameTheme.mossLit
                              : GameTheme.torchHot,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                KenneyButton(
                  label: mission.isComplete ? 'CLAIM' : 'IN PROGRESS',
                  onPressed: mission.isComplete
                      ? () => director.claimMission(mission.id)
                      : null,
                  style: KenneyButtonStyle.grey,
                  expanded: false,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class SanctuaryOverlay extends StatelessWidget {
  const SanctuaryOverlay({super.key, required this.director});
  final GameDirector director;

  int _prestigeOf(GameState state, String track) => switch (track) {
    'gold' => state.metaDepth.sanctuaryGoldPrestige,
    'power' => state.metaDepth.sanctuaryPowerPrestige,
    'vitality' => state.metaDepth.sanctuaryVitalityPrestige,
    'xp' => state.metaDepth.sanctuaryXpPrestige,
    _ => 0,
  };

  int _levelOf(GameState state, String track) => switch (track) {
    'gold' => state.sanctuaryGoldLevel,
    'power' => state.sanctuaryPowerLevel,
    'vitality' => state.sanctuaryVitalityLevel,
    'xp' => state.metaDepth.sanctuaryXpLevel,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Permanent essence tracks — survive Ascend. '
          'Upgrade forever; from Lv12 you can Prestige (reset level, keep a bonus).',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        if (state.metaDepth.ascendBlessings > 0) ...[
          const SizedBox(height: 6),
          Text(
            'Ascend Blessing ×${state.metaDepth.ascendBlessings} · '
            '+${state.ascendBlessingAttackBonus} ATK · '
            '+${state.ascendBlessingDefenseBonus} DEF · '
            '+${state.ascendBlessingVitalityBonus} STA · '
            '+${state.ascendBlessingGoldPercent}% gold',
            style: GameTheme.body(size: 13, color: GameTheme.mossLit),
          ),
        ],
        const SizedBox(height: 10),
        for (final track in <String>['gold', 'power', 'vitality', 'xp']) ...[
          Builder(
            builder: (context) {
              final level = _levelOf(state, track);
              final prestige = _prestigeOf(state, track);
              final nextLevel = level + 1;
              final cost = GameLogic.sanctuaryCost(level);
              final nextBonus = GameLogic.sanctuaryBonusLabel(
                track,
                nextLevel,
                prestige: prestige,
              );
              final currentBonus = GameLogic.sanctuaryBonusLabel(
                track,
                level,
                prestige: prestige,
              );
              final cycle = level <= 0 ? 0.0 : ((level - 1) % 12 + 1) / 12.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MenuChrome.sectionLabel(
                    GameLogic.sanctuaryNames[track] ?? track,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lv$level  ·  $currentBonus'
                    '${prestige > 0 ? '  ·  Prestige $prestige' : ''}',
                    style: GameTheme.body(
                      size: 13,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                  Text(
                    'Next: $nextBonus',
                    style: GameTheme.body(size: 12, color: GameTheme.mossLit),
                  ),
                  const SizedBox(height: 6),
                  KenneyProgressBar(
                    value: cycle.clamp(0.0, 1.0),
                    height: 12,
                    color: track == 'vitality'
                        ? KenneyBarColor.red
                        : track == 'power'
                        ? KenneyBarColor.yellow
                        : KenneyBarColor.green,
                  ),
                  const SizedBox(height: 6),
                  KenneyButton(
                    label: 'Upgrade · ${cost}e',
                    onPressed: state.essence >= cost
                        ? () => director.upgradeSanctuary(track)
                        : null,
                  ),
                  if (level >= 12) ...[
                    const SizedBox(height: 4),
                    KenneyButton(
                      label: 'Prestige reset · +${25 + level}e',
                      style: KenneyButtonStyle.brown,
                      onPressed: () => director.prestigeSanctuaryTrack(track),
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class MarketOverlay extends StatelessWidget {
  const MarketOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final flaskCost = GameLogic.marketFlaskCost(state);
    final stash = state.gearStash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Gold ${formatCount(state.gold)} · Essence ${formatCount(state.essence)}',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        Text(
          'Buy heals with gold. Tap a stash item here to sell it for gold.\n'
          'In the bag: SELL JUNK = gold · SCRAP = essence (Settings filters).',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 12),
        MenuChrome.sectionLabel('CONSUMABLES'),
        const SizedBox(height: 6),
        KenneyButton(
          label: state.gold >= flaskCost
              ? 'Buy flask · ${flaskCost}g'
              : 'Buy flask · Need ${flaskCost}g',
          onPressed: state.gold >= flaskCost ? director.buyMarketFlask : null,
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: state.gold >= flaskCost * 3
              ? 'Buy 3 flasks · ${flaskCost * 3}g'
              : 'Buy 3 flasks · Need ${flaskCost * 3}g',
          onPressed: state.gold >= flaskCost * 3
              ? () => director.buyMarketFlasks()
              : null,
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: state.gold >= GameLogic.marketBandageCost(state)
              ? 'Buy bandage · ${GameLogic.marketBandageCost(state)}g'
              : 'Buy bandage · Need ${GameLogic.marketBandageCost(state)}g',
          onPressed: state.gold >= GameLogic.marketBandageCost(state)
              ? director.buyMarketBandage
              : null,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            KenneySprite(asset: KenneyAssets.potionRed, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Flask: whole party (~30% HP). Bandage: lowest hero (~40% HP).',
                style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        MenuChrome.sectionLabel('SELL STASH (TAP = GOLD)'),
        const SizedBox(height: 6),
        if (stash.isEmpty)
          Text(
            'Bag empty. Clear rooms for gear, then sell extras here for gold.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.builder(
              itemCount: stash.length,
              itemBuilder: (context, i) {
                final item = stash[i];
                final gold = GameLogic.equipmentGoldValue(item);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                      onTap: () => director.sellGearForGold(item.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: MenuChrome.listCard(inset: true),
                        child: Row(
                          children: [
                            KenneySprite(
                              asset: KenneyAssets.equipmentIconFor(item),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.name,
                                style: GameTheme.body(size: 14),
                              ),
                            ),
                            Text(
                              '+${gold}g',
                              style: GameTheme.body(
                                size: 14,
                                color: GameTheme.torchHot,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
