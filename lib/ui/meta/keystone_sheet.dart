import 'package:flutter/material.dart';

import '../../core/game_director.dart';
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
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.director;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: GameTheme.torchHot,
          unselectedLabelColor: GameTheme.parchmentDim,
          indicatorColor: GameTheme.torchHot,
          labelStyle: GameTheme.pixel(size: GameTheme.hudPixel),
          tabs: [
            MenuChrome.bridgedTabScoped(
              'KEY',
              scope: 'run',
              onSelect: () => _tabs.animateTo(0),
            ),
            MenuChrome.bridgedTabScoped(
              'SPIRE',
              scope: 'run',
              onSelect: () => _tabs.animateTo(1),
            ),
            MenuChrome.bridgedTabScoped(
              'RIFT',
              scope: 'run',
              onSelect: () => _tabs.animateTo(2),
            ),
            MenuChrome.bridgedTabScoped(
              'GR',
              scope: 'run',
              onSelect: () => _tabs.animateTo(3),
            ),
            MenuChrome.bridgedTabScoped(
              'BOARDS',
              scope: 'account',
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
                    ChallengeToggles(director: d),
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
