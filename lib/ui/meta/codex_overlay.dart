
import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../game_theme.dart';
import '../../assets/kenney_assets.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';

/// Discovered enemies / items grid — purely cosmetic Codex.
class CodexOverlay extends StatefulWidget {
  const CodexOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  State<CodexOverlay> createState() => _CodexOverlayState();
}

class _CodexOverlayState extends State<CodexOverlay> {
  bool _showEnemies = true;

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final entries = _showEnemies ? state.codexEnemies : state.codexItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: GameButton(
                label: 'MONSTERS (${state.codexEnemies.length})',
                style: _showEnemies
                    ? GameButtonStyle.brown
                    : GameButtonStyle.grey,
                onPressed: () => setState(() => _showEnemies = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GameButton(
                label: 'ITEMS (${state.codexItems.length})',
                style: !_showEnemies
                    ? GameButtonStyle.brown
                    : GameButtonStyle.grey,
                onPressed: () => setState(() => _showEnemies = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Codex ${GameLogic.codexCompletionPercent(state)}%  |  '
          '${state.codexEnemies.length + state.codexItems.length} discovered '
          '(goal ${GameLogic.expectedCodexEntries} entries)',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: GameTheme.minTouch,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: GameLogic.codexRewardTiers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final entry = GameLogic.codexRewardTiers.entries.elementAt(i);
              final claimed = state.metaDepth.codexClaims.contains(entry.key);
              final pct = GameLogic.codexCompletionPercent(state);
              final ready = pct >= entry.value.pct && !claimed;
              final label = claimed
                  ? '${entry.value.pct}%'
                  : ready
                  ? '${entry.value.pct}% +${entry.value.reward}e'
                  : '${entry.value.pct}%';
              return GameButton(
                label: label,
                expanded: false,
                style: ready
                    ? GameButtonStyle.brown
                    : GameButtonStyle.grey,
                onPressed: ready
                    ? () => widget.director.claimCodexReward(entry.key)
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    _showEnemies
                        ? 'No monsters discovered yet. Fight your way through a dungeon.'
                        : 'No items discovered yet. Clear floors for gear drops.',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 15,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final name = entries[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: MenuChrome.listCard(inset: true),
                        child: Row(
                          children: [
                            KenneySprite(
                              asset: _showEnemies
                                  ? KenneyAssets.enemySpriteForCodexName(name)
                                  : KenneyAssets.codexItemIconFor(name),
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                style: GameTheme.body(size: 15),
                              ),
                            ),
                          ],
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

/// Save/apply up to 3 named gear presets.
