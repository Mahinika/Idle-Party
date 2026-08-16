import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/menu_alerts.dart';
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

class PowerPillar extends StatefulWidget {
  const PowerPillar({super.key, required this.director});
  final GameDirector director;

  @override
  State<PowerPillar> createState() => _PowerPillarState();
}

class _PowerPillarState extends State<PowerPillar>
    with TickerProviderStateMixin {
  late final FlexTabs _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = FlexTabs(
      vsync: this,
      length: 2,
      onChanged: (_) => setState(() {}),
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
    final keepLine =
        'Keep · AL${s.ascensionLevel} · Bless ×${s.metaDepth.ascendBlessings} · '
        '${s.essence}e';
    final runLine =
        'This run · forge ATK +${s.attackBonus} · DEF +${s.defenseBonus} · '
        'STA +${s.vitalityBonus}';
    // Progressive menu: CAMP and SHOP appear once essence / Ascend exist.
    final pages = <({String label, String blurb, Widget body})>[
      (
        label: 'FORGE',
        blurb: 'Forge: gold this run (wipes) · KEEP forever · Apex mats',
        body: ForgeOverlay(director: d),
      ),
      if (MenuTabs.showCamp(s))
        (
          label: 'CAMP',
          blurb: 'Camp: permanent essence tracks — survive Ascend',
          body: SingleChildScrollView(child: SanctuaryOverlay(director: d)),
        ),
      (
        label: 'MARKET',
        blurb: 'Market: flasks for the run · sell stash for gold',
        body: SingleChildScrollView(child: MarketOverlay(director: d)),
      ),
      if (MenuTabs.showShop(s))
        (
          label: 'SHOP',
          blurb: 'Shop: essence power that survives Ascend',
          body: PrestigeShopOverlay(director: d),
        ),
    ];
    _tabs.sync(pages.length);
    final alert = MenuAlerts.powerAlert(s);
    final blurb = pages[_tabs.index.clamp(0, pages.length - 1)].blurb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
          child: Column(
            children: [
              Text(
                keepLine,
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 12, color: GameTheme.torchHot),
              ),
              Text(
                runLine,
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        MenuChrome.tabRail(
          controller: _tabs.controller,
          onTap: (_) => setState(() {}),
          tabs: [
            for (final page in pages) Tab(text: page.label),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          alert.isQuiet ? blurb : alert.reason,
          textAlign: TextAlign.center,
          style: GameTheme.body(
            size: 12,
            color:
                alert.isQuiet ? GameTheme.parchmentDim : GameTheme.torchHot,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          // Forge fills height and scrolls once (nested scroll hid MOVE/HASTE/CRIT).
          child: pages[_tabs.index.clamp(0, pages.length - 1)].body,
        ),
      ],
    );
  }
}

/// META pillar — keystone · contracts · beast · collection · help · settings.
class MetaPillar extends StatefulWidget {
  const MetaPillar({super.key, 
    required this.director,
    required this.onOpenWhatsNew,
  });
  final GameDirector director;
  final VoidCallback onOpenWhatsNew;

  @override
  State<MetaPillar> createState() => _MetaPillarState();
}

class _MetaPillarState extends State<MetaPillar>
    with TickerProviderStateMixin {
  late final FlexTabs _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = FlexTabs(
      vsync: this,
      length: 3,
      onChanged: (_) => setState(() {}),
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
    final pages = <({String label, Widget body})>[
      if (MenuTabs.showKey(s))
        (
          label: 'KEY',
          body: SingleChildScrollView(child: ChallengeToggles(director: d)),
        ),
      (
        label: 'JOBS',
        body: SingleChildScrollView(child: JobsOverlay(director: d)),
      ),
      if (MenuTabs.showBeast(s))
        (
          label: 'BEAST',
          body: SingleChildScrollView(child: BeastOverlay(director: d)),
        ),
      if (MenuTabs.showCodex(s))
        (
          label: 'CODEX',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: CodexOverlay(director: d)),
              const Divider(height: 12, color: GameTheme.border),
              Expanded(child: AchievementsOverlay(director: d)),
            ],
          ),
        ),
      (
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
      (
        label: 'SET',
        body: SingleChildScrollView(
          child: SettingsOverlay(director: d, onClose: () {}),
        ),
      ),
    ];
    _tabs.sync(pages.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuChrome.tabRail(
          controller: _tabs.controller,
          onTap: (_) => setState(() {}),
          tabs: [
            for (final page in pages) Tab(text: page.label),
          ],
        ),
        if (!alert.isQuiet)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              alert.reason,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GameTheme.body(size: 12, color: GameTheme.torchHot),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: pages[_tabs.index.clamp(0, pages.length - 1)].body,
        ),
      ],
    );
  }
}
