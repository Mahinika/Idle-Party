import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../menu_chrome.dart';
import '../forge_overlay.dart';
import '../market_overlay.dart';
import '../sanctuary_overlay.dart';
import '../shell_layout.dart';

enum HomeGoldPanel { forge, camp, market }

/// FORGE, CAMP, and MARKET under the fight. The fight keeps running.
class UpgradePanel extends StatefulWidget {
  const UpgradePanel({
    super.key,
    required this.director,
    required this.router,
    this.sheetPanel,
    this.focusPanel,
    this.focusGeneration = 0,
  });

  final GameDirector director;
  final MenuRouter router;

  /// When set, only the body for this tab (sheet owns the segmented header).
  final HomeGoldPanel? sheetPanel;

  /// SPLIT fight: a GOLD / MARKET intent moves the segmented control here.
  final HomeGoldPanel? focusPanel;
  final int focusGeneration;

  @override
  State<UpgradePanel> createState() => _UpgradePanelState();
}

class _UpgradePanelState extends State<UpgradePanel> {
  _Panel _mode = _Panel.forge;

  @override
  void initState() {
    super.initState();
    widget.router.addListener(_onRoute);
  }

  @override
  void dispose() {
    widget.router.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() {
    if (widget.router.route != MenuRoute.gold) return;
    if (_mode != _Panel.forge) setState(() => _mode = _Panel.forge);
  }

  @override
  void didUpdateWidget(covariant UpgradePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focus = widget.focusPanel;
    if (focus != null &&
        widget.focusGeneration != oldWidget.focusGeneration) {
      _mode = _Panel.values[focus.index];
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final open = MenuTabs.showGold(state);
    final embedded = widget.sheetPanel != null;
    final active = embedded
        ? _Panel.values[widget.sheetPanel!.index]
        : _mode;
    return Material(
      color: embedded ? Colors.transparent : GameTheme.panel,
      child: Column(
        children: [
          if (!embedded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: MenuChrome.segmented(
                dense: true,
                labels: const ['FORGE', 'CAMP', 'MARKET'],
                icons: UiIcon.goldDockSegment,
                selectedIndex: _mode.index,
                onSelect: (i) => setState(() => _mode = _Panel.values[i]),
              ),
            ),
          Expanded(child: _body(state, open, active, embedded)),
        ],
      ),
    );
  }

  Widget _body(GameState state, bool open, _Panel mode, bool embedded) {
    if (!open) return _locked(state);
    final inline =
        widget.sheetPanel == null && !state.homePanelFull;
    switch (mode) {
      case _Panel.market:
        return MarketOverlay(
          director: widget.director,
          inlineUnderFight: inline,
          expandedTrackList: embedded,
        );
      case _Panel.camp:
        return SanctuaryOverlay(
          director: widget.director,
          inlineUnderFight: inline,
          expandedTrackList: embedded,
        );
      case _Panel.forge:
        return ForgeOverlay(
          director: widget.director,
          inlineUnderFight: inline,
          expandedTrackList: embedded,
        );
    }
  }

  Widget _locked(GameState state) {
    return ListView(
      padding: ShellLayout.listPadding,
      children: [
        for (final hero in state.heroes)
          Text(
            '${hero.name}  Lv${hero.level}',
            style: GameTheme.body(size: 13, color: GameTheme.parchment),
          ),
        ShellLayout.gap(8),
        ShellLayout.hint(
          'FORGE opens after the first boss (F2).',
          maxLines: 2,
        ),
      ],
    );
  }
}

enum _Panel { forge, camp, market }
