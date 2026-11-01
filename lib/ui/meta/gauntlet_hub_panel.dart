import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/gauntlet_anomaly.dart';
import '../../core/gauntlet_pact.dart';
import '../../core/gauntlet_trophies.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';

/// KEY tab: Infinity Gauntlet enter (party max-level Spire climb).
class GauntletHubPanel extends StatelessWidget {
  const GauntletHubPanel({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.endgameUnlocked(state)) {
      return Text(
        'GAUNTLET unlocks when every active hero is Lv${GameLogic.maxHeroLevel}. '
        'Boss every 5 floors.',
        textAlign: TextAlign.center,
        style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
      );
    }
    final best = state.metaDepth.gauntletBestFloor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'GAUNTLET · CLIMB',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          best <= 0
              ? 'Pick a climb. Boss every 5 floors.'
              : 'Best clear F$best. Pick a climb. Boss every 5 floors.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        if (_nextBossPayLine(best) case final pay?) ...[
          const SizedBox(height: 4),
          Text(
            pay,
            style: GameTheme.body(size: 12, color: GameTheme.torchHot),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'MIGHT hits harder. WARD takes less. GREED pays double essence and the party is softer.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        _SpireTrophyGrid(state: state),
        const SizedBox(height: 8),
        GameButton(
          label: 'CHOOSE A CLIMB',
          style: GameButtonStyle.brown,
          onPressed: GameLogic.canEnterGauntlet(state)
              ? () => confirmGauntletRun(context, director)
              : null,
        ),
      ],
    );
  }
}

class _SpireTrophyGrid extends StatelessWidget {
  const _SpireTrophyGrid({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final earned = state.metaDepth.spireTrophies.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'SPIRE TROPHIES · $earned/12',
          style: GameTheme.body(size: 12, color: GameTheme.parchment),
        ),
        const SizedBox(height: 2),
        Text(
          'First clear of each cell pays ${GauntletTrophies.firstEssence} essence. '
          'MIGHT earns RUSH instead of SWARM. A full row grants a title. All 12 grant 1 STAR.',
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        for (final pact in GauntletPact.values) ...[
          Row(
            children: [
              SizedBox(
                width: 58,
                child: Text(
                  GauntletPacts.title(pact),
                  style: GameTheme.pixel(
                    size: 9,
                    color: GameTheme.parchmentDim,
                  ),
                ),
              ),
              for (final squeeze in GauntletTrophies.squeezesFor(pact))
                Expanded(
                  child: _TrophyCell(
                    pact: pact,
                    squeeze: squeeze,
                    earned: GauntletTrophies.owned(state, pact, squeeze),
                  ),
                ),
            ],
          ),
          if (GauntletTrophies.oneShortLine(state, pact) case final short
              when short.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              short,
              style: GameTheme.body(size: 11, color: GameTheme.torchHot),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

String? _nextBossPayLine(int best) {
  final nextBoss = (best ~/ 5 + 1) * 5;
  if (nextBoss != 5 && nextBoss != 10 && nextBoss != 15) return null;
  final pay = GameLogic.gauntletEssenceForFloor(nextBoss, boss: true);
  return 'Floor $nextBoss boss pays +$pay essence.';
}

class _TrophyCell extends StatelessWidget {
  const _TrophyCell({
    required this.pact,
    required this.squeeze,
    required this.earned,
  });

  final GauntletPact pact;
  final GauntletAnomaly squeeze;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final label = GauntletAnomalies.chip(squeeze);
    return Semantics(
      label: earned
          ? '${GauntletPacts.title(pact)} $label, earned'
          : '${GauntletPacts.title(pact)} $label, not yet',
      child: Container(
        margin: const EdgeInsets.only(left: 3),
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: earned
              ? GameTheme.torch.withValues(alpha: 0.28)
              : GameTheme.stoneDeep.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: earned ? GameTheme.torchHot : GameTheme.borderLit,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GameTheme.pixel(
            size: 8,
            color: earned ? GameTheme.torchHot : GameTheme.parchmentDim,
          ),
        ),
      ),
    );
  }
}
