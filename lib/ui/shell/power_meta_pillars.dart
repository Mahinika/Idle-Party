import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/menu_alerts.dart';
import '../../core/menu_router.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../meta/achievements_overlay.dart';
import '../meta/codex_overlay.dart';
import '../guides_overlay.dart';
import 'craft_overlay.dart';
import 'jobs_overlay.dart';
import 'settings_overlay.dart';
import 'shell_common.dart';

/// MORE list: INFO / Settings / Credits plus meta rows (QUESTS / Craft).
class MoreList extends StatefulWidget {
  /// MORE → CREDITS. Studio name, owned art — not a third-party pack credit.
  static const creditsBody = 'Idle Party\n\n'
      'Cognifox Studio\n\n'
      'Sprites and world art: Idle Party\n\n'
      'Made for portrait phones.';


  const MoreList({
    super.key,
    required this.director,
    required this.section,
    required this.onSectionChanged,
    required this.onOpenWhatsNew,
    required this.onClose,
    this.bagFiltersScrollNonce = 0,
    this.initialInfoPane = 0,
  });

  final GameDirector director;
  final MoreSection section;
  final ValueChanged<MoreSection> onSectionChanged;
  final VoidCallback onOpenWhatsNew;
  final VoidCallback onClose;
  final int bagFiltersScrollNonce;

  /// 0 guide, 1 codex, 2 trophies. The hub CODEX button asks for 1.
  final int initialInfoPane;

  @override
  State<MoreList> createState() => _MoreListState();
}

class _MoreListState extends State<MoreList> with TickerProviderStateMixin {
  static const _chromeSectionsEarly = <MoreSection>[
    MoreSection.settings,
    MoreSection.info,
    MoreSection.credits,
  ];

  static const _chromeSections = <MoreSection>[
    MoreSection.info,
    MoreSection.settings,
    MoreSection.credits,
  ];

  late final FlexTabs _tabs;
  int _infoPane = 0;

  @override
  void initState() {
    super.initState();
    _infoPane = widget.initialInfoPane;
    final s = widget.director.state;
    final chrome = widget.section.isMetaOverlay
        ? MoreSection.info
        : widget.section;
    final sections = GameLogic.plainPlayerChrome(s)
        ? _chromeSectionsEarly
        : _chromeSections;
    final initial = sections.indexOf(chrome).clamp(0, sections.length - 1);
    _tabs = FlexTabs(
      vsync: this,
      length: sections.length,
      initialIndex: initial,
      onChanged: (i) {
        if (i >= 0 && i < sections.length) {
          widget.onSectionChanged(sections[i]);
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
    final chromeSections = GameLogic.plainPlayerChrome(s)
        ? _chromeSectionsEarly
        : _chromeSections;
    var section = widget.section;
    if (section == MoreSection.quests && !MenuTabs.showQuests(s)) {
      section = MoreSection.info;
    }
    if (section == MoreSection.craft && !MenuTabs.showCraft(s)) {
      section = MoreSection.info;
    }
    final alert = MenuAlerts.moreAlert(s);
    final onMeta = section.isMetaOverlay;
    if (!onMeta) {
      _tabs.syncToId(chromeSections, section);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onMeta)
          Row(
            children: [
              Expanded(
                child: GameButton(
                  label: 'BACK',
                  style: GameButtonStyle.grey,
                  onPressed: () => widget.onSectionChanged(MoreSection.info),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                section.rowLabel,
                style: GameTheme.pixel(
                  size: GameTheme.hudPixel,
                  color: GameTheme.torchHot,
                ),
              ),
            ],
          )
        else
          MenuChrome.tabRail(
            controller: _tabs.controller,
            onTap: (_) => setState(() {}),
            tabs: [
              for (var i = 0; i < chromeSections.length; i++)
                MenuChrome.bridgedTab(
                  switch (chromeSections[i]) {
                    MoreSection.info => 'INFO',
                    MoreSection.settings => 'SETTINGS',
                    MoreSection.credits => 'CREDITS',
                    _ => chromeSections[i].rowLabel,
                  },
                  onSelect: () {
                    _tabs.controller.animateTo(i);
                    widget.onSectionChanged(chromeSections[i]);
                    setState(() {});
                  },
                ),
            ],
          ),
        if (!alert.isQuiet && section == MoreSection.info)
          MenuChrome.tabBanner(alert.reason),
        const SizedBox(height: 8),
        Expanded(child: _body(context, section)),
      ],
    );
  }

  Widget _body(BuildContext context, MoreSection section) {
    final d = widget.director;
    return switch (section) {
      MoreSection.info => _infoBody(d),
      MoreSection.settings => SettingsOverlay(
        director: d,
        onClose: widget.onClose,
        bagFiltersScrollNonce: widget.bagFiltersScrollNonce,
      ),
      MoreSection.credits => SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Text(
          MoreList.creditsBody,
          style: GameTheme.body(size: 14, color: GameTheme.parchment),
        ),
      ),
      MoreSection.craft => CraftOverlay(director: d),
      MoreSection.quests => SingleChildScrollView(
        child: JobsOverlay(director: d),
      ),
    };
  }

  Widget _infoBody(GameDirector d) {
    final s = d.state;
    final metaRows = MenuRouter.visibleMoreMetaRows(s);
    final showCodex = MenuTabs.showCodex(s);
    final panes = showCodex
        ? const ['GUIDE', 'CODEX', 'TROPHIES']
        : const ['GUIDE'];
    final pane = _infoPane.clamp(0, panes.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (metaRows.isNotEmpty) ...[
          for (final row in metaRows) ...[
            GameButton(
              label: row.rowLabel,
              tip: switch (row) {
                MoreSection.quests => 'Daily, bounty, side, and week jobs',
                MoreSection.craft => 'Apex and the Craft Trial',
                _ => null,
              },
              style: GameButtonStyle.grey,
              onPressed: () => widget.onSectionChanged(row),
            ),
            const SizedBox(height: 6),
          ],
        ],
        if (MenuTabs.showWhatsNew(s)) ...[
          GameButton(
            label: "WHAT'S NEW",
            style: GameButtonStyle.grey,
            dense: true,
            onPressed: widget.onOpenWhatsNew,
          ),
          const SizedBox(height: 6),
        ],
        if (showCodex) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < panes.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: GameButton(
                    label: panes[i],
                    style: pane == i
                        ? GameButtonStyle.brown
                        : GameButtonStyle.grey,
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
