import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/menu_router.dart';
import '../menu_chrome.dart';
import '../meta/prestige_shop.dart';
import 'beast_overlay.dart';
import 'relics_overlay.dart';
import 'sanctuary_overlay.dart';
import 'shell_common.dart';

/// ESSENCE sheet: tracks/KEEP, prestige shop, relics, pets.
class EssenceDock extends StatefulWidget {
  const EssenceDock({
    super.key,
    required this.director,
    required this.panel,
    required this.onPanelChanged,
  });

  final GameDirector director;
  final EssencePanel panel;
  final ValueChanged<EssencePanel> onPanelChanged;

  @override
  State<EssenceDock> createState() => _EssenceDockState();
}

class _EssenceDockState extends State<EssenceDock>
    with TickerProviderStateMixin {
  late final FlexTabs _tabs;
  List<EssencePanel> _visible = const [EssencePanel.tracks];

  @override
  void initState() {
    super.initState();
    _visible = MenuRouter.visibleEssencePanels(widget.director.state);
    final initial =
        _visible.indexOf(widget.panel).clamp(0, _visible.length - 1);
    _tabs = FlexTabs(
      vsync: this,
      length: _visible.length,
      initialIndex: initial,
      onChanged: (i) {
        if (i >= 0 && i < _visible.length) {
          widget.onPanelChanged(_visible[i]);
        }
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
    _visible = MenuRouter.visibleEssencePanels(widget.director.state);
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
          EssencePanel.tracks => (
            label: 'TRACKS',
            body: SingleChildScrollView(
              child: SanctuaryOverlay(director: widget.director),
            ),
          ),
          EssencePanel.shop => (
            label: 'SHOP',
            body: SingleChildScrollView(
              child: PrestigeShopOverlay(director: widget.director),
            ),
          ),
          EssencePanel.relics => (
            label: 'RELICS',
            body: SingleChildScrollView(
              child: RelicsOverlay(director: widget.director),
            ),
          ),
          EssencePanel.pets => (
            label: 'PETS',
            body: SingleChildScrollView(
              child: BeastOverlay(director: widget.director),
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

