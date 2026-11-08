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
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';
import 'fight_seam_rails.dart';

/// Legacy out-of-cave rest scene. Live home layout uses [TownViewport].
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: DecoratedBox(
                decoration: MenuChrome.panel(opaque: true),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        cave,
                        textAlign: TextAlign.center,
                        style: GameTheme.title(),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (var i = 0; i < heroes.length; i++)
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: (heroes.length > 4 ? 44 : 56) + 12,
                                      height: (heroes.length > 4 ? 44 : 56) + 12,
                                      alignment: Alignment.center,
                                      decoration: MenuChrome.dollWellDecoration(),
                                      child: HeroDollSprite(
                                        hero: heroes[i],
                                        partyIndex: i,
                                        size: heroes.length > 4 ? 44 : 56,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      heroes[i].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: GameTheme.hint(color: GameTheme.parchment),
                                    ),
                                    Text(
                                      'Lv${heroes[i].level}',
                                      style: GameTheme.hint(color: GameTheme.parchmentDim),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          ),
                        ),
                      ),
                      WebClickScope(
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
                      if (GameLogic.canAscend(state) &&
                          plan.op != ChaseOp.confirmAscend &&
                          plan.op != ChaseOp.enter &&
                          plan.op != ChaseOp.enterKey) ...[
                        const SizedBox(height: 6),
                        GameButton(
                          label: 'ASCEND',
                          style: GameButtonStyle.brown,
                          dense: true,
                          onPressed: () => confirmAscend(context, director),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          FightSeamRails(director: director, router: router),
        ],
      ),
    );
  }
}
