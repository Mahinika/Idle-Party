import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_state.dart';
import '../../../core/gold_income.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../../core/nav_copy.dart';
import '../../game_theme.dart';
import '../../web_click_bridge.dart';
import '../forge_overlay.dart';
import '../market_overlay.dart';
import '../sanctuary_overlay.dart';

/// FORGE, CAMP, and MARKET under the fight. The fight keeps running.
class UpgradePanel extends StatefulWidget {
  const UpgradePanel({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

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
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final open = MenuTabs.showGold(state);
    return Material(
      color: GameTheme.panel,
      child: Column(
        children: [
          Expanded(child: _body(state, open)),
          _footer(state),
        ],
      ),
    );
  }

  Widget _body(GameState state, bool open) {
    if (!open) return _locked(state);
    switch (_mode) {
      case _Panel.market:
        return SingleChildScrollView(
          child: MarketOverlay(director: widget.director),
        );
      case _Panel.camp:
        return SingleChildScrollView(
          child: SanctuaryOverlay(director: widget.director),
        );
      case _Panel.forge:
        return ForgeOverlay(director: widget.director);
    }
  }

  Widget _locked(GameState state) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final hero in state.heroes)
          Text(
            '${hero.name}  Lv${hero.level}',
            style: GameTheme.body(size: 13, color: GameTheme.parchment),
          ),
        const SizedBox(height: 8),
        Text(
          'FORGE opens after the first boss (F2).',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
      ],
    );
  }

  Widget _footer(GameState state) {
    final perMin = GoldIncome.perMinuteLabel(GoldIncome.hubGoldPerMinute(state));
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              NavCopy.playerText(perMin, state.homeLayout),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
            ),
          ),
          _tabButton('FORGE', _mode == _Panel.forge, () {
            setState(() => _mode = _Panel.forge);
          }),
          _tabButton('CAMP', _mode == _Panel.camp, () {
            setState(() => _mode = _Panel.camp);
          }),
          _tabButton('MARKET', _mode == _Panel.market, () {
            setState(() => _mode = _Panel.market);
          }),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool selected, VoidCallback onTap) {
    return WebClickScope(
      label: label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: GameTheme.minTouch,
              minHeight: GameTheme.minTouch,
            ),
            child: Center(
              child: Text(
                label,
                style: GameTheme.menuTitle(
                  size: 11,
                  color: selected ? GameTheme.torchHot : GameTheme.parchment,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Panel { forge, camp, market }
