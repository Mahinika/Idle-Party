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
import 'income_overlay.dart';
import 'jobs_market_sanctuary.dart';
import 'settings_overlay.dart';
import 'shell_common.dart';

class PowerPillar extends StatefulWidget {
  const PowerPillar({
    super.key,
    required this.director,
    required this.tab,
    required this.onTabChanged,
  });
  final GameDirector director;
  final PowerTab tab;
  final ValueChanged<PowerTab> onTabChanged;

  @override
  State<PowerPillar> createState() => _PowerPillarState();
}

class _PowerPillarState extends State<PowerPillar>
    with TickerProviderStateMixin {
  late final FlexTabs _tabs;
  List<PowerTab> _visible = const [PowerTab.forge, PowerTab.market];

  @override
  void initState() {
    super.initState();
    _tabs = FlexTabs(
      vsync: this,
      length: 2,
      onChanged: (i) {
        if (i >= 0 && i < _visible.length) widget.onTabChanged(_visible[i]);
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
    final keepStats =
        'AL${s.ascensionLevel}${s.ascensionLevel >= GameLogic.maxAscensionLevel ? ' · MAX' : ''} · Bless ×${s.metaDepth.ascendBlessings} · '
        '${s.essence}e';
    final runStats =
        'forge ATK +${s.attackBonus} · DEF +${s.defenseBonus} · '
        'STA +${s.vitalityBonus}';
    // Progressive menu: CAMP and SHOP appear once essence / Ascend exist.
    _visible = MenuRouter.visiblePowerTabs(s);
    final pages = <({
      String label,
      String scope,
      String blurb,
      Widget body,
    })>[
      for (final tab in _visible)
        switch (tab) {
          PowerTab.income => (
            label: 'INCOME',
            scope: 'ACCOUNT',
            blurb: 'ACCOUNT · hub gold/min · Gold Find (not MARKET sell)',
            body: SingleChildScrollView(child: IncomeOverlay(director: d)),
          ),
          PowerTab.forge => (
            label: 'FORGE',
            scope: 'RUN',
            blurb: 'RUN · gold this run (wipes on Ascend) · KEEP forever',
            body: ForgeOverlay(director: d),
          ),
          PowerTab.camp => (
            label: 'CAMP',
            scope: 'ACCOUNT',
            blurb: 'ACCOUNT · essence tracks · Gold Find lives here too',
            body: SingleChildScrollView(child: SanctuaryOverlay(director: d)),
          ),
          PowerTab.market => (
            label: 'MARKET',
            scope: 'RUN',
            blurb: 'RUN · buy gear listings · sell lives in PARTY BAG',
            body: MarketOverlay(director: d),
          ),
          PowerTab.shop => (
            label: 'SHOP',
            scope: 'ACCOUNT',
            blurb: 'essence upgrades survive Ascend',
            body: PrestigeShopOverlay(director: d),
          ),
        },
    ];
    _tabs.syncToId(_visible, widget.tab);
    final alert = MenuAlerts.powerAlert(s);
    final active = pages[_tabs.index.clamp(0, pages.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
          child: Column(
            children: [
              _PowerScopeLine(scope: 'ACCOUNT', text: keepStats),
              const SizedBox(height: 2),
              _PowerScopeLine(scope: 'RUN', text: runStats),
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
                scope: pages[i].scope,
                onSelect: () {
                  _tabs.controller.animateTo(i);
                  widget.onTabChanged(_visible[i]);
                  setState(() {});
                },
              ),
          ],
        ),
        if (!MenuTabs.showCamp(s)) ...[
          const SizedBox(height: 4),
          Text(
            'CAMP unlocks after Ascend or when you earn essence — permanent '
            'Gold Find & tracks (also under INCOME).',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
        ],
        const SizedBox(height: 4),
        if (alert.isQuiet)
          _PowerScopeLine(scope: active.scope, text: active.blurb)
        else
          Text(
            alert.reason,
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.torchHot),
          ),
        const SizedBox(height: 6),
        Expanded(
          // Forge fills height and scrolls once (nested scroll hid MOVE/HASTE/CRIT).
          child: active.body,
        ),
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
            size: scope == 'ACCOUNT' ? 12 : 11,
            color: scope == 'ACCOUNT'
                ? GameTheme.torchHot
                : GameTheme.parchmentDim,
          ),
        ),
      ],
    );
  }
}

/// META pillar — keystone · quests · beast · collection · help · settings.
class MetaPillar extends StatefulWidget {
  const MetaPillar({
    super.key,
    required this.director,
    required this.tab,
    required this.onTabChanged,
    required this.onOpenWhatsNew,
    required this.onClose,
    this.bagFiltersScrollNonce = 0,
  });
  final GameDirector director;
  final MetaTab tab;
  final ValueChanged<MetaTab> onTabChanged;
  final VoidCallback onOpenWhatsNew;
  final VoidCallback onClose;
  final int bagFiltersScrollNonce;

  @override
  State<MetaPillar> createState() => _MetaPillarState();
}

class _MetaPillarState extends State<MetaPillar> with TickerProviderStateMixin {
  late final FlexTabs _tabs;
  List<MetaTab> _visible = const [
    MetaTab.jobs,
    MetaTab.guide,
    MetaTab.settings,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = FlexTabs(
      vsync: this,
      length: 3,
      onChanged: (i) {
        if (i >= 0 && i < _visible.length) widget.onTabChanged(_visible[i]);
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
    final alert = MenuAlerts.metaAlert(s);
    // Progressive menu: KEY / BEAST / CODEX appear once they mean something.
    _visible = MenuRouter.visibleMetaTabs(s);
    final pages = <({String label, Widget body})>[
      for (final tab in _visible)
        switch (tab) {
          MetaTab.key => (
            label: 'KEYSTONE',
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ChallengeToggles(director: d),
                  const SizedBox(height: 16),
                  RiftHubPanel(director: d),
                  const SizedBox(height: 16),
                  GreaterRiftHubPanel(director: d),
                  const SizedBox(height: 16),
                  PlayGamesBoardsSection(director: d),
                ],
              ),
            ),
          ),
          MetaTab.jobs => (
            label: 'QUESTS',
            body: SingleChildScrollView(child: JobsOverlay(director: d)),
          ),
          MetaTab.beast => (
            label: 'BEAST',
            body: SingleChildScrollView(child: BeastOverlay(director: d)),
          ),
          MetaTab.codex => (
            label: 'CODEX',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: CodexOverlay(director: d),
                ),
                const Divider(height: 8, color: GameTheme.border),
                Expanded(
                  flex: 2,
                  child: AchievementsOverlay(director: d),
                ),
              ],
            ),
          ),
          MetaTab.guide => (
            label: 'GUIDE',
            body: Column(
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
                const Expanded(child: GuidesOverlay()),
              ],
            ),
          ),
          MetaTab.settings => (
            label: 'SETTINGS',
            body: SingleChildScrollView(
              child: SettingsOverlay(
                director: d,
                onClose: widget.onClose,
                bagFiltersScrollNonce: widget.bagFiltersScrollNonce,
              ),
            ),
          ),
        },
    ];
    _tabs.syncToId(_visible, widget.tab);
    final activeTab = _visible[_tabs.index.clamp(0, _visible.length - 1)];
    final tabBanner = switch (activeTab) {
      MetaTab.jobs when !alert.isQuiet && !alert.star => alert.reason,
      MetaTab.guide when alert.star => alert.reason,
      _ => null,
    };
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
                  widget.onTabChanged(_visible[i]);
                  setState(() {});
                },
              ),
          ],
        ),
        if (tabBanner != null) MenuChrome.tabBanner(tabBanner),
        const SizedBox(height: 8),
        Expanded(child: pages[_tabs.index.clamp(0, pages.length - 1)].body),
      ],
    );
  }
}
