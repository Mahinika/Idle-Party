import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/menu_alerts.dart';
import '../../core/menu_router.dart';
import '../../core/meta_systems.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../meta_overlays.dart';
import '../guides_overlay.dart';
import 'beast_overlay.dart';
import 'forge_overlay.dart';
import 'jobs_market_sanctuary.dart';
import 'settings_overlay.dart';
import 'shell_common.dart';

/// POWER sheet: sticky Forge | Market | Camp (Shop in Market, Beast in Camp).
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
    final keepStats = plain
        ? '${s.essence} essence · lasts between runs'
        : 'AL${s.ascensionLevel}${s.ascensionLevel >= GameLogic.maxAscensionLevel ? ' · MAX' : ''} · Bless ×${s.metaDepth.ascendBlessings} · '
            '${s.essence}e';
    final runStats = plain
        ? '${s.gold} gold · ATK +${s.attackBonus} · DEF +${s.defenseBonus} · '
            'STA +${s.vitalityBonus}'
        : 'forge ATK +${s.attackBonus} · DEF +${s.defenseBonus} · '
            'STA +${s.vitalityBonus}';
    _visible = MenuRouter.visiblePowerSegments(s);
    final pages = <({String label, String scope, Widget body})>[
      for (final seg in _visible)
        switch (seg) {
          PowerSegment.forge => (
            label: plain ? 'Gold upgrades' : 'FORGE',
            scope: plain ? 'GOLD' : 'RUN',
            body: ForgeOverlay(director: d),
          ),
          PowerSegment.market => (
            label: plain ? 'Buy supplies' : 'MARKET',
            scope: plain ? 'GOLD' : 'RUN',
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MarketOverlay(director: d),
                  if (MenuTabs.showShop(s)) ...[
                    const SizedBox(height: 16),
                    Text(
                      plain ? 'Permanent shop' : 'SHOP',
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
          PowerSegment.camp => (
            label: plain ? 'Permanent upgrades' : 'CAMP',
            scope: plain ? 'PERMANENT' : 'ACCOUNT',
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
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
          child: Column(
            children: [
              if (!plain || MenuTabs.showCamp(s))
                _PowerScopeLine(
                  scope: plain ? 'PERMANENT' : 'ACCOUNT',
                  text: keepStats,
                ),
              if (!plain || MenuTabs.showCamp(s)) const SizedBox(height: 2),
              _PowerScopeLine(scope: plain ? 'GOLD' : 'RUN', text: runStats),
            ],
          ),
        ),
        const SizedBox(height: 4),
        MenuChrome.tabRail(
          controller: _tabs.controller,
          onTap: (_) => setState(() {}),
          tabs: [
            for (var i = 0; i < pages.length; i++)
              MenuChrome.bridgedTabScoped(
                pages[i].label,
                scope: plain ? null : pages[i].scope,
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
            'More permanent upgrades unlock later.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
        ] else if (!MenuTabs.showCamp(s)) ...[
          const SizedBox(height: 4),
          Text(
            'Sanctuary tracks unlock after Ascend or when you earn essence.',
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

class _PowerScopeLine extends StatelessWidget {
  const _PowerScopeLine({required this.scope, required this.text});

  final String scope;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        MenuChrome.scopeChip(scope),
        Text(
          text,
          style: GameTheme.body(
            size: scope == 'ACCOUNT' || scope == 'PERMANENT' ? 12 : 11,
            color: scope == 'ACCOUNT' || scope == 'PERMANENT'
                ? GameTheme.torchHot
                : GameTheme.parchmentDim,
          ),
        ),
      ],
    );
  }
}

/// KEYSTONE sheet (hub tab + dungeon HUD Meta entry).
class KeystoneSheet extends StatelessWidget {
  const KeystoneSheet({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final d = director;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChallengeToggles(director: d),
          const SizedBox(height: 16),
          GauntletHubPanel(director: d),
          const SizedBox(height: 16),
          RiftHubPanel(director: d),
          const SizedBox(height: 16),
          GreaterRiftHubPanel(director: d),
          const SizedBox(height: 16),
          PlayGamesBoardsSection(director: d),
        ],
      ),
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
    final s = d.state;
    return switch (widget.section) {
      MoreSection.info => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KenneyButton(
            label: MetaSystems.hasUnseenChangelog(s)
                ? "WHAT'S NEW ★"
                : "WHAT'S NEW",
            style: KenneyButtonStyle.grey,
            onPressed: widget.onOpenWhatsNew,
          ),
          const SizedBox(height: 8),
          Expanded(child: GuidesOverlay(state: s)),
          if (MenuTabs.showCodex(s)) ...[
            const Divider(height: 8, color: GameTheme.border),
            Expanded(
              flex: 2,
              child: CodexOverlay(director: d),
            ),
            Expanded(
              flex: 1,
              child: AchievementsOverlay(director: d),
            ),
          ],
        ],
      ),
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
}


