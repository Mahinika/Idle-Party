import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/menu_alerts.dart';
import '../../core/menu_router.dart';
import '../../core/meta_systems.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../meta/achievements_overlay.dart';
import '../meta/codex_overlay.dart';
import '../meta/prestige_shop.dart';
import '../guides_overlay.dart';
import 'beast_overlay.dart';
import 'craft_overlay.dart';
import 'forge_overlay.dart';
import 'market_overlay.dart';
import 'relics_overlay.dart';
import 'sanctuary_overlay.dart';
import 'settings_overlay.dart';
import 'shell_common.dart';

/// POWER sheet: sticky Gold | Shop | Relics | Craft | Essence.
class PowerPillar extends StatefulWidget {
  const PowerPillar({
    super.key,
    required this.director,
    required this.segment,
    required this.onSegmentChanged,
  });
  final GameDirector director;
  final PowerSegment segment;
  final ValueChanged<PowerSegment> onSegmentChanged;

  @override
  State<PowerPillar> createState() => _PowerPillarState();
}

class _PowerPillarState extends State<PowerPillar>
    with TickerProviderStateMixin {
  late final FlexTabs _tabs;
  List<PowerSegment> _visible = const [
    PowerSegment.forge,
    PowerSegment.market,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = FlexTabs(
      vsync: this,
      length: 2,
      onChanged: (i) {
        if (i >= 0 && i < _visible.length) {
          widget.onSegmentChanged(_visible[i]);
        }
        setState(() {});
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
    final d = widget.director;
    final s = d.state;
    final plain = GameLogic.plainPlayerChrome(s);
    _visible = MenuRouter.visiblePowerSegments(s);
    final pages = <({String label, Widget body})>[
      for (final seg in _visible)
        switch (seg) {
          PowerSegment.forge => (
            label: seg.tabLabel,
            body: ForgeOverlay(director: d),
          ),
          PowerSegment.market => (
            label: seg.tabLabel,
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MarketOverlay(director: d),
                  if (MenuTabs.showShop(s)) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Essence',
                      style: GameTheme.pixel(
                        size: GameTheme.hudPixel,
                        color: GameTheme.torchHot,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PrestigeShopOverlay(director: d),
                  ],
                ],
              ),
            ),
          ),
          PowerSegment.relics => (
            label: seg.tabLabel,
            body: RelicsOverlay(director: d),
          ),
          PowerSegment.craft => (
            label: seg.tabLabel,
            body: CraftOverlay(director: d),
          ),
          PowerSegment.camp => (
            label: seg.tabLabel,
            body: ListView(
              padding: EdgeInsets.zero,
              children: [
                SanctuaryOverlay(director: d),
                if (MenuTabs.showBeast(s)) ...[
                  const SizedBox(height: 16),
                  Text(
                    'BEAST',
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixel,
                      color: GameTheme.torchHot,
                    ),
                  ),
                  const SizedBox(height: 8),
                  BeastOverlay(director: d),
                ],
              ],
            ),
          ),
        },
    ];
    _tabs.syncToId(_visible, widget.segment);
    final alert = MenuAlerts.powerAlert(s);
    final activeIndex = _tabs.index.clamp(0, pages.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuChrome.tabRail(
          controller: _tabs.controller,
          onTap: (_) => setState(() {}),
          tabs: [
            for (var i = 0; i < pages.length; i++)
              MenuChrome.bridgedTab(
                pages[i].label,
                onSelect: () {
                  _tabs.controller.animateTo(i);
                  widget.onSegmentChanged(_visible[i]);
                  setState(() {});
                },
              ),
          ],
        ),
        if (plain && !MenuTabs.showCamp(s)) ...[
          const SizedBox(height: 4),
          Text(
            'Essence unlocks later.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
        ] else if (!MenuTabs.showCamp(s)) ...[
          const SizedBox(height: 4),
          Text(
            'Essence unlocks after Ascend or when you earn essence.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
        ],
        const SizedBox(height: 4),
        if (!alert.isQuiet)
          Text(
            alert.reason,
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.torchHot),
          ),
        const SizedBox(height: 6),
        Expanded(child: pages[activeIndex].body),
      ],
    );
  }
}

/// MORE list: INFO / Settings / Credits — no gameplay.
class MoreList extends StatefulWidget {
  const MoreList({
    super.key,
    required this.director,
    required this.section,
    required this.onSectionChanged,
    required this.onOpenWhatsNew,
    required this.onClose,
    this.bagFiltersScrollNonce = 0,
  });

  final GameDirector director;
  final MoreSection section;
  final ValueChanged<MoreSection> onSectionChanged;
  final VoidCallback onOpenWhatsNew;
  final VoidCallback onClose;
  final int bagFiltersScrollNonce;

  @override
  State<MoreList> createState() => _MoreListState();
}

class _MoreListState extends State<MoreList> with TickerProviderStateMixin {
  static const _sections = <MoreSection>[
    MoreSection.info,
    MoreSection.settings,
    MoreSection.credits,
  ];

  late final FlexTabs _tabs;
  int _infoPane = 0;

  @override
  void initState() {
    super.initState();
    final initial = _sections.indexOf(widget.section).clamp(0, 2);
    _tabs = FlexTabs(
      vsync: this,
      length: _sections.length,
      initialIndex: initial,
      onChanged: (i) {
        if (i >= 0 && i < _sections.length) {
          widget.onSectionChanged(_sections[i]);
        }
        setState(() {});
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
    final s = widget.director.state;
    final alert = MenuAlerts.moreAlert(s);
    _tabs.syncToId(_sections, widget.section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuChrome.tabRail(
          controller: _tabs.controller,
          onTap: (_) => setState(() {}),
          tabs: [
            for (var i = 0; i < _sections.length; i++)
              MenuChrome.bridgedTab(
                switch (_sections[i]) {
                  MoreSection.info => alert.star ? 'INFO ★' : 'INFO',
                  MoreSection.settings => 'SETTINGS',
                  MoreSection.credits => 'CREDITS',
                },
                onSelect: () {
                  _tabs.controller.animateTo(i);
                  widget.onSectionChanged(_sections[i]);
                  setState(() {});
                },
              ),
          ],
        ),
        if (!alert.isQuiet && widget.section == MoreSection.info)
          MenuChrome.tabBanner(alert.reason),
        const SizedBox(height: 8),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final d = widget.director;
    return switch (widget.section) {
      MoreSection.info => _infoBody(d),
      MoreSection.settings => SingleChildScrollView(
        child: SettingsOverlay(
          director: d,
          onClose: widget.onClose,
          bagFiltersScrollNonce: widget.bagFiltersScrollNonce,
        ),
      ),
      MoreSection.credits => SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Idle Party\n\n'
          'World art: Kenney (CC0)\n'
          'Custom sprites: Idle Party\n\n'
          'Made for portrait phones.',
          style: GameTheme.body(size: 14, color: GameTheme.parchment),
        ),
      ),
    };
  }

  Widget _infoBody(GameDirector d) {
    final s = d.state;
    final showCodex = MenuTabs.showCodex(s);
    final panes = showCodex
        ? const ['GUIDE', 'CODEX', 'TROPHIES']
        : const ['GUIDE'];
    final pane = _infoPane.clamp(0, panes.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KenneyButton(
          label: MetaSystems.hasUnseenChangelog(s)
              ? "WHAT'S NEW ★"
              : "WHAT'S NEW",
          style: KenneyButtonStyle.grey,
          onPressed: widget.onOpenWhatsNew,
        ),
        if (showCodex) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < panes.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: KenneyButton(
                    label: panes[i],
                    style: pane == i
                        ? KenneyButtonStyle.brown
                        : KenneyButtonStyle.grey,
                    onPressed: () => setState(() => _infoPane = i),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: switch (pane) {
            1 => CodexOverlay(director: d),
            2 => AchievementsOverlay(director: d),
            _ => GuidesOverlay(state: s),
          },
        ),
      ],
    );
  }
}


