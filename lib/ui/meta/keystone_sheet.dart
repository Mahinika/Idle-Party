import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/hub_chase.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';
import 'challenge_toggles.dart';
import 'gauntlet_hub_panel.dart';
import 'greater_rift_hub_panel.dart';
import 'play_games_section.dart';
import 'rift_hub_panel.dart';

/// KEYSTONE sheet (hub tab + dungeon HUD Meta entry).
///
/// Phone-friendly sections: Keystone / Gauntlet / Rift / GR / Boards —
/// one hunt visible at a time instead of a long scroll stack.
class KeystoneSheet extends StatefulWidget {
  const KeystoneSheet({super.key, required this.director});
  final GameDirector director;

  @override
  State<KeystoneSheet> createState() => _KeystoneSheetState();
}

class _KeystoneSheetState extends State<KeystoneSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    final chase = HubChase.forState(widget.director.state);
    final initial = switch (chase.kind) {
      HubChaseKind.gauntletMilestone => 1,
      HubChaseKind.riftMilestone => 2,
      HubChaseKind.greaterRiftMilestone => 3,
      HubChaseKind.doneForToday => 4,
      HubChaseKind.ashenCrown => 0,
      HubChaseKind.keystone => 0,
      _ => 0,
    };
    _tabs = TabController(length: 5, vsync: this, initialIndex: initial);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.director;
    final chase = HubChase.forState(d.state);
    final huntHint = switch (chase.kind) {
      HubChaseKind.keystone =>
        'TODAY · KEY +${chase.keyLevel ?? d.state.hardmodeLevel}',
      HubChaseKind.gauntletMilestone => 'TODAY · Spire / Gauntlet',
      HubChaseKind.riftMilestone => 'TODAY · Farm Rift',
      HubChaseKind.greaterRiftMilestone => 'TODAY · Ranked GR',
      HubChaseKind.doneForToday => 'TODAY · soft rest · BOARDS',
      HubChaseKind.ashenCrown => 'TODAY · Ashen Crown (enter from hub)',
      _ => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (huntHint.isNotEmpty) ...[
          Text(
            huntHint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.body(size: 12, color: GameTheme.torchHot),
          ),
          const SizedBox(height: 4),
          Text(
            'Endgame ladder: KEY → Spire → Ranked GR → Farm Rift → Crown. '
            'Vault / Daily Run / Quests are separate dailies on the hub.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
        ],
        MenuChrome.tabRail(
          controller: _tabs,
          tabs: [
            MenuChrome.bridgedTab(
              'KEY',
              onSelect: () => _tabs.animateTo(0),
            ),
            MenuChrome.bridgedTab(
              'SPIRE',
              onSelect: () => _tabs.animateTo(1),
            ),
            MenuChrome.bridgedTab(
              'RIFT',
              onSelect: () => _tabs.animateTo(2),
            ),
            MenuChrome.bridgedTab(
              'GR',
              onSelect: () => _tabs.animateTo(3),
            ),
            MenuChrome.bridgedTab(
              'BOARDS',
              onSelect: () => _tabs.animateTo(4),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MenuChrome.sectionLabelScoped(
                      'KEYSTONE',
                      scope: MenuScope.run,
                    ),
                    ChallengeToggles(director: d, lockExpanded: true),
                  ],
                ),
              ),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MenuChrome.sectionLabelScoped(
                      'GAUNTLET',
                      scope: MenuScope.run,
                    ),
                    GauntletHubPanel(director: d),
                  ],
                ),
              ),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MenuChrome.sectionLabelScoped(
                      'RIFT · farm',
                      scope: MenuScope.run,
                    ),
                    RiftHubPanel(director: d),
                  ],
                ),
              ),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MenuChrome.sectionLabelScoped(
                      'GREATER RIFT · prestige',
                      scope: MenuScope.run,
                    ),
                    GreaterRiftHubPanel(director: d),
                  ],
                ),
              ),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MenuChrome.sectionLabelScoped(
                      'BOARDS',
                      scope: MenuScope.account,
                    ),
                    PlayGamesBoardsSection(director: d),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
