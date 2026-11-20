import 'package:flutter/material.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/fight_seam.dart';
import 'package:idle_party/ui/shell/home/home_gold_dock.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

import '../shell_golden_harness.dart';

/// Five heroes (tank / healer / 3×DPS) on the home fight seam layout.
Future<GameState> roleIconsArtifactFightState() async {
  return withShellGoldenWeek(() async {
    var state = GameLogic.createInitialState(
      now: shellGoldenNow,
      partySpecs: const [
        HeroSpecId.protection,
        HeroSpecId.discipline,
        HeroSpecId.fire,
      ],
    );
    final dps2 = PartyHero.starting(
      name: 'Fang',
      specId: HeroSpecId.combat,
      level: 20,
    );
    final dps3 = PartyHero.starting(
      name: 'Storm',
      specId: HeroSpecId.fury,
      level: 18,
    );
    state = state.copyWith(
      ascensionLevel: 3,
      homeLayout: HomeLayout.home,
      homePanelFull: true,
      vfxQuality: VfxQuality.minimal,
      seenChangelogVersion: MetaSystems.currentVersion,
      metaDepth: state.metaDepth.copyWith(
        partySlot5Unlocked: true,
        reviewPrompted: true,
      ),
      heroRoster: [...state.heroRoster, dps2, dps3],
    );
    final roster = state.heroRoster;
    final tank = roster
        .firstWhere((h) => h.specId == HeroSpecId.protection)
        .copyWith(name: 'Aegis');
    final healer = roster
        .firstWhere((h) => h.specId == HeroSpecId.discipline)
        .copyWith(name: 'Vale');
    final dps1 = roster
        .firstWhere((h) => h.specId == HeroSpecId.fire)
        .copyWith(name: 'Blaze');
    state = state.withActiveParty([tank, healer, dps1, dps2, dps3]);
    final entered = GameLogic.enterDungeon(state);
    return entered.copyWith(
      lastUpdated: DateTime.now().add(const Duration(minutes: 10)),
    );
  });
}

/// Dark fight chrome: FARM/PUSH row, party strip, TRAIN/CAMP/MARKET.
class RoleIconsFightStripHarness extends StatelessWidget {
  const RoleIconsFightStripHarness({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: GameTheme.ink,
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: GameTheme.stoneDeep,
              child: SizedBox(
                height: 132,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: FightFieldControls(
                        director: director,
                        router: router,
                        onLeave: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
            FightSeam(
              director: director,
              router: router,
              onLeave: () {},
              hideRails: true,
            ),
            HomeGoldDock(director: director, router: router),
          ],
        ),
      ),
    );
  }
}

/// Applies [scale] inside [MaterialApp] — do not nest [shellGoldenScaffold]
/// on top (it resets textScaler to 1.0).
Widget roleIconsScaledScaffold({
  required double scale,
  required Widget body,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: const Size(360, 780),
        textScaler: TextScaler.linear(scale),
      ),
      child: child!,
    ),
    home: Scaffold(
      backgroundColor: GameTheme.ink,
      body: body,
    ),
  );
}

Future<GameDirector> roleIconsArtifactDirector() async {
  final state = await roleIconsArtifactFightState();
  final director = GameDirector.preview(initialState: state);
  director.debugAttachSpatial(SpatialCombat.build(state));
  return director;
}