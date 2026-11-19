import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../../assets/kenney_assets.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';
import '../shell/shell_common.dart';

/// Discovered enemies / items grid — purely cosmetic Codex.
class CodexOverlay extends StatefulWidget {
  const CodexOverlay({super.key, required this.director});
  final GameDirector director;

  static const emptyKey = ValueKey('codex-empty');

  /// Milestone row text: "Reward at 25%: +8 essence", "CLAIM 25% · +8",
  /// "25% · claimed".
  static String tierLabel({
    required int pct,
    required int reward,
    required bool claimed,
    required bool ready,
  }) {
    if (claimed) return '$pct% · claimed';
    if (ready) return 'CLAIM $pct% · +${formatCount(reward)}';
    return 'Reward at $pct%: +${formatCount(reward)} essence';
  }

  @override
  State<CodexOverlay> createState() => _CodexOverlayState();
}

class _CodexOverlayState extends State<CodexOverlay> {
  bool _showEnemies = true;

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final entries = _showEnemies ? state.codexEnemies : state.codexItems;
    // One scroll for the header and the list: the reward tiers alone
    // overflowed 360x640 at 1.45 inside MENU → CODEX (audit F099).
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // One toggle, counts on each side (polish7 P044).
              MenuChrome.segmented(
                labels: [
                  'MONSTERS (${state.codexEnemies.length})',
                  'ITEMS (${state.codexItems.length})',
                ],
                selectedIndex: _showEnemies ? 0 : 1,
                onSelect: (i) => setState(() => _showEnemies = i == 0),
              ),
              // Empty tab: say so right under the toggle, not far below.
              if (entries.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _showEnemies
                      ? 'No monsters discovered yet. Fight your way through a dungeon.'
                      : 'No items discovered yet. Clear floors for gear drops.',
                  key: CodexOverlay.emptyKey,
                  textAlign: TextAlign.center,
                  style: GameTheme.readable(color: GameTheme.parchmentDim),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Codex ${GameLogic.codexCompletionPercent(state)}% of '
                '${GameLogic.expectedCodexEntries} entries',
                textAlign: TextAlign.center,
                style: GameTheme.section(color: GameTheme.parchmentDim),
              ),
              const SizedBox(height: 4),
              Column(
                children: [
                  for (
                    var i = 0;
                    i < GameLogic.codexRewardTiers.length;
                    i++
                  ) ...[
                    if (i > 0) const SizedBox(height: 6),
                    Builder(
                      builder: (context) {
                        final entry = GameLogic.codexRewardTiers.entries
                            .elementAt(i);
                        final claimed = state.metaDepth.codexClaims.contains(
                          entry.key,
                        );
                        final pct = GameLogic.codexCompletionPercent(state);
                        final ready = pct >= entry.value.pct && !claimed;
                        // Say what each milestone pays, in words
                        // (polish7 P003/P044).
                        final label = CodexOverlay.tierLabel(
                          pct: entry.value.pct,
                          reward: entry.value.reward,
                          claimed: claimed,
                          ready: ready,
                        );
                        return GameButton(
                          label: label,
                          expanded: true,
                          icon: ready ? UiIcon.essence : null,
                          style: ready
                              ? GameButtonStyle.go
                              : GameButtonStyle.grey,
                          onPressed: ready
                              ? () =>
                                    widget.director.claimCodexReward(entry.key)
                              : null,
                        );
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        if (entries.isNotEmpty)
          SliverList.builder(
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
                      Expanded(child: Text(name, style: GameTheme.readable())),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Save/apply up to 3 named gear presets.
