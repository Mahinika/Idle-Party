
import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../models/achievement_def.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// Local achievements list — unlocked ids come from `GameState.achievements`.
class AchievementsOverlay extends StatelessWidget {
  const AchievementsOverlay({super.key, required this.director});
  final GameDirector director;

  static String _categoryLabel(AchievementCategory c) => switch (c) {
    AchievementCategory.combat => 'COMBAT',
    AchievementCategory.meta => 'META',
    AchievementCategory.explorer => 'EXPLORER',
    AchievementCategory.collector => 'COLLECTOR',
  };

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final unlocked = state.achievements.toSet();
    final byCategory = <AchievementCategory, List<AchievementDef>>{};
    for (final def in AchievementCatalog.all) {
      byCategory.putIfAbsent(def.category, () => <AchievementDef>[]).add(def);
    }
    final categories = AchievementCategory.values
        .where((c) => byCategory.containsKey(c))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${state.willRankTitle}  ·  score ${state.collectionScore}',
          textAlign: TextAlign.center,
          style: GameTheme.menuTitle(size: 14, color: GameTheme.torchHot),
        ),
        if (state.metaDepth.titles.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Titles',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final title in state.metaDepth.titles)
                GameButton(
                  label: title,
                  expanded: false,
                  style: state.metaDepth.activeTitle == title
                      ? GameButtonStyle.brown
                      : GameButtonStyle.grey,
                  onPressed: () => director.setActiveTitle(title),
                ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Text(
          '${unlocked.length}/${AchievementCatalog.all.length} UNLOCKED',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: [
              for (final cat in categories) ...[
                MenuChrome.sectionLabelScoped(
                  _categoryLabel(cat),
                  scope: MenuScope.account,
                ),
                const SizedBox(height: 6),
                for (final def in byCategory[cat]!) ...[
                  Builder(
                    builder: (context) {
                      final done = unlocked.contains(def.id);
                      final hide = def.hidden && !done;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: MenuChrome.listCard(
                          borderColor: done
                              ? GameTheme.clear
                              : GameTheme.border,
                        ),
                        child: Row(
                          children: [
                            GameIcon.asset(
                              done ? UiIcon.trophy : UiIcon.skull,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hide ? 'Hidden' : def.title,
                                    style: GameTheme.body(
                                      size: 15,
                                      color: done
                                          ? GameTheme.torchHot
                                          : GameTheme.parchment,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    hide
                                        ? 'Hidden achievement'
                                        : def.description,
                                    style: GameTheme.body(
                                      size: 14,
                                      color: GameTheme.parchmentDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              hide
                                  ? '---'
                                  : done
                                  ? 'AWARDED'
                                  : '+${def.essenceReward}e',
                              style: GameTheme.body(
                                size: 11,
                                color: done
                                    ? GameTheme.clear
                                    : GameTheme.parchmentDim,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

