import 'package:flutter/material.dart';

import '../../../core/ashen_crown.dart';
import '../../../core/chase_dispatcher.dart';
import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../../core/hub_endgame_act.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../../models/dungeon_def.dart';
import '../../confirm_dialogs.dart';
import '../../game_theme.dart';
import '../../hub/hub_ranks.dart';
import '../../hub/hub_world_map.dart';
import '../../kenney_button.dart';
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';
import '../shell_layout.dart';

/// Tap a cave or a hunt. ENTER in the footer starts it.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.director, required this.router});

  final GameDirector director;
  final MenuRouter router;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _endgame = false;
  String _zoneId = 'sandy';
  HubEndgameHunt? _hunt;

  GameDirector get director => widget.director;

  @override
  void initState() {
    super.initState();
    _zoneId = director.state.dungeonId;
    _endgame = widget.router.mapEndgame;
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final mean = GameLogic.partyMeanLevel(state);
    return Column(
      children: [
        Padding(
          padding: ShellLayout.seamPadding,
          child: MenuChrome.segmented(
            dense: true,
            labels: const ['PATH', 'ENDGAME'],
            selectedIndex: _endgame ? 1 : 0,
            onSelect: (i) => setState(() => _endgame = i == 1),
          ),
        ),
        Expanded(
          child: _endgame ? _hunts(state, mean) : _path(state, mean),
        ),
        _footer(state, mean),
      ],
    );
  }

  Widget _path(GameState state, int mean) {
    final dungeons = DungeonCatalog.all;
    return Column(
      children: [
        Expanded(
          child: ZonePathMap(
            dungeons: dungeons,
            selectedId: _zoneId,
            partyLevel: mean,
            highestCleared: state.highestDungeonCleared,
            onSelect: (id) => setState(() {
              _zoneId = id;
              _hunt = null;
            }),
          ),
        ),
        _reason(state, mean),
      ],
    );
  }

  Widget _reason(GameState state, int mean) {
    final def = DungeonCatalog.byId(_zoneId);
    final open = DungeonCatalog.isUnlocked(
      _zoneId,
      mean,
      state.highestDungeonCleared,
    );
    final line = open
        ? def.name
        : '${def.name} · Party Lv${DungeonCatalog.unlockHeroLevel(def)} or clear the previous cave';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        line,
        textAlign: TextAlign.center,
        style: GameTheme.hint(color: GameTheme.parchmentDim),
      ),
    );
  }

  Widget _hunts(GameState state, int mean) {
    final endgame = GameLogic.endgameUnlocked(state);
    return ListView(
      padding: ShellLayout.listPadding,
      children: [
        if (MenuTabs.showKey(state))
          _card('KEY', 'Harder cave. Same floors.', () {
            widget.router.open(MenuRoute.key);
          }),
        for (final node in HubEndgameAct.nodes)
          _card(
            node.shortLabel,
            endgame ? node.blurb : 'Active party all Lv100.',
            endgame
                ? () => setState(() => _hunt = node.hunt)
                : null,
            selected: _hunt == node.hunt,
            badge: node.hunt == HubEndgameHunt.ashen &&
                    AshenCrown.canEnter(state)
                ? '${state.metaDepth.worldBossTickets}'
                : null,
          ),
        _card('DAILY', 'Today\'s cave.', () {
          setState(() => _hunt = null);
          confirmDailyRun(context, director);
        }),
        _card('RANKS', 'Season boards.', () {
          openHubRanksSheet(context, director);
        }),
      ],
    );
  }

  Widget _card(
    String title,
    String body,
    VoidCallback? onTap, {
    bool selected = false,
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ShellLayout.card(
        selected: selected,
        child: WebClickScope(
        label: title,
        onPressed: onTap,
        child: Semantics(
          button: onTap != null,
          label: badge != null && badge.isNotEmpty
              ? '$title. $body. Tickets: $badge.'
              : '$title. $body',
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: const BoxDecoration(),
              child: Padding(
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: GameTheme.readable()),
                          Text(
                            body,
                            style: GameTheme.hint(color: GameTheme.parchmentDim),
                          ),
                        ],
                      ),
                    ),
                    if (badge != null && badge.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      MenuChrome.chip(
                        label: '$badge tickets',
                        selected: true,
                        tone: GameTheme.torchHot,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _footer(GameState state, int mean) {
    final endgame = GameLogic.endgameUnlocked(state);
    return Padding(
      padding: ShellLayout.listPadding,
      child: GameButton(
        label: 'ENTER',
        style: GameButtonStyle.brown,
        primary: true,
        onPressed: () => _enter(state, mean, endgame),
      ),
    );
  }

  void _enter(GameState state, int mean, bool endgame) {
    if (_endgame) {
      final hunt = _hunt;
      if (hunt == null || !endgame) {
        director.showToast(
          endgame ? 'Tap a hunt first' : 'Active party all Lv100',
          life: 2,
        );
        return;
      }
      switch (hunt) {
        case HubEndgameHunt.gauntlet:
          confirmGauntletRun(context, director);
        case HubEndgameHunt.farmRift:
          confirmRiftRun(context, director);
        case HubEndgameHunt.rankedGr:
          confirmGreaterRiftRun(context, director);
        case HubEndgameHunt.ashen:
          confirmAshenCrown(context, director, practice: false);
      }
      return;
    }
    final open = ChaseDispatcher.zoneUnlocked(state, _zoneId);
    if (!open) {
      final def = DungeonCatalog.byId(_zoneId);
      director.showToast(
        'Party Lv${DungeonCatalog.unlockHeroLevel(def)} or clear the previous cave',
        life: 2.4,
      );
      return;
    }
    widget.router.close();
    director.enterDungeon(dungeonId: _zoneId);
  }
}
