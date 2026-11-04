import 'package:flutter/material.dart';

import '../../../core/chase_dispatcher.dart';
import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/hub_chase.dart';
import '../../../core/menu_router.dart';
import '../../../models/dungeon_def.dart';
import '../../chase_bind.dart';
import '../../confirm_dialogs.dart';
import '../../game_theme.dart';
import '../../hero_doll_sprite.dart';
import '../../kenney_button.dart';
import '../../web_click_bridge.dart';

/// Out of the cave. The party rests here after a wipe or an Ascend.
class CampViewport extends StatelessWidget {
  const CampViewport({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final chase = HubChase.forState(state);
    final plan = ChaseDispatcher.plan(chase, state: state);
    final label = plan.label ?? 'ENTER';
    final cave = DungeonCatalog.byId(state.dungeonId).name;
    final heroes = state.heroes;
    return ColoredBox(
      color: GameTheme.stoneDeep,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'CAMP',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
            ),
            const SizedBox(height: 4),
            Text(
              state.partyName,
              textAlign: TextAlign.center,
              style: GameTheme.menuTitle(size: 18),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < heroes.length; i++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HeroDollSprite(
                            hero: heroes[i],
                            partyIndex: i,
                            size: heroes.length > 4 ? 48 : 64,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            heroes[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GameTheme.body(
                              size: 12,
                              color: GameTheme.parchment,
                            ),
                          ),
                          Text(
                            'Lv${heroes[i].level}',
                            style: GameTheme.body(
                              size: 11,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Text(
              cave,
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
            ),
            const SizedBox(height: 8),
            WebClickScope(
              label: 'ENTER',
              onPressed: () => runChasePlan(
                context: context,
                director: director,
                router: router,
                plan: plan,
                onEnterDungeon: (id) {
                  router.close();
                  director.enterDungeon(dungeonId: id);
                },
              ),
              child: GameButton(
                label: label,
                onPressed: () => runChasePlan(
                  context: context,
                  director: director,
                  router: router,
                  plan: plan,
                  onEnterDungeon: (id) {
                    router.close();
                    director.enterDungeon(dungeonId: id);
                  },
                ),
              ),
            ),
            if (GameLogic.canAscend(state)) ...[
              const SizedBox(height: 8),
              GameButton(
                label: 'ASCEND',
                style: GameButtonStyle.brown,
                onPressed: () => confirmAscend(context, director),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
