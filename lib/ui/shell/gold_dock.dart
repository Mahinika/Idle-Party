import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/menu_router.dart';
import '../menu_chrome.dart';
import 'forge_overlay.dart';
import 'market_overlay.dart';
import 'shell_common.dart';

/// GOLD sheet: run forge tracks + gold market (flasks / listings).
class GoldDock extends StatefulWidget {
  const GoldDock({
    super.key,
    required this.director,
    required this.panel,
    required this.onPanelChanged,
  });

  final GameDirector director;
  final GoldPanel panel;
  final ValueChanged<GoldPanel> onPanelChanged;

  @override
  State<GoldDock> createState() => _GoldDockState();
}

class _GoldDockState extends State<GoldDock> with TickerProviderStateMixin {
  late final FlexTabs _tabs;
  List<GoldPanel> _visible = const [GoldPanel.tracks, GoldPanel.market];

  @override
  void initState() {
    super.initState();
    _visible = MenuRouter.visibleGoldPanels(widget.director.state);
    final initial =
        _visible.indexOf(widget.panel).clamp(0, _visible.length - 1);
    _tabs = FlexTabs(
      vsync: this,
      length: _visible.length,
      initialIndex: initial,
      onChanged: (i) {
        if (i >= 0 && i < _visible.length) widget.onPanelChanged(_visible[i]);
      },
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _visible = MenuRouter.visibleGoldPanels(widget.director.state);
    final safeTab =
        _visible.contains(widget.panel) ? widget.panel : _visible.first;
    if (safeTab != widget.panel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPanelChanged(safeTab);
      });
    }
    final pages = <({String label, Widget body})>[
      for (final tab in _visible)
        switch (tab) {
          GoldPanel.tracks => (
            label: 'TRACKS',
            body: ForgeOverlay(director: widget.director),
          ),
          GoldPanel.market => (
            label: 'MARKET',
            body: SingleChildScrollView(
              child: MarketOverlay(director: widget.director),
            ),
          ),
        },
    ];
    _tabs.syncToId(_visible, safeTab);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuChrome.tabRail(
          controller: _tabs.controller,
          tabs: [
            for (var i = 0; i < pages.length; i++)
              MenuChrome.bridgedTab(
                pages[i].label,
                onSelect: () {
                  _tabs.controller.animateTo(i);
                  widget.onPanelChanged(_visible[i]);
                  setState(() {});
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: IndexedStack(
            index: _visible.indexOf(safeTab).clamp(0, pages.length - 1),
            children: [for (final p in pages) p.body],
          ),
        ),
      ],
    );
  }
}
