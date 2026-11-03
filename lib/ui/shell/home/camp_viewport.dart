import 'package:flutter/material.dart';

import '../../../core/chase_dispatcher.dart';
import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/home_layout.dart';
import '../../../core/hub_chase.dart';
import '../../../core/menu_router.dart';
import '../../../core/nav_copy.dart';
import '../../chase_bind.dart';
import '../../confirm_dialogs.dart';
import '../../game_theme.dart';
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
    final title = NavCopy.playerText(chase.title, HomeLayout.home);
    final label = plan.label ?? 'ENTER';
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
            const SizedBox(height: 8),
            for (final hero in state.heroes)
              Text(
                '${hero.name}  Lv${hero.level}',
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 14, color: GameTheme.parchment),
              ),
            const Spacer(),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
