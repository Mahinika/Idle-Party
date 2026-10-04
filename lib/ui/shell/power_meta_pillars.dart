import 'package:flutter/material.dart';
import '../../core/game_director.dart';
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

/// MORE list: INFO / Settings / Credits plus QUESTS / Craft as tabs (like GEAR).
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
    this.initialInfoPane = 0,
  });

  final GameDirector director;
  final MoreSection section;
  final ValueChanged<MoreSection> onSectionChanged;
  final VoidCallback onOpenWhatsNew;
  final VoidCallback onClose;

  /// 0 guide, 1 codex, 2 trophies. The hub CODEX button asks for 1.
  final int initialInfoPane;

  @override
  State<MoreList> createState() => _MoreListState();
}

class _MoreListState extends State<MoreList> with TickerProviderStateMixin {
  late final FlexTabs _tabs;
  int _infoPane = 0;

  @override
  void initState() {
    super.initState();
    _infoPane = widget.initialInfoPane;
    final sections = MenuRouter.visibleMoreSections(widget.director.state);
    var chrome = widget.section;
    if (!sections.contains(chrome)) chrome = MoreSection.info;
    final initial = sections.indexOf(chrome).clamp(0, sections.length - 1);
    _tabs = FlexTabs(
      vsync: this,
      length: sections.length,
      initialIndex: initial,
      onChanged: (i) {
        final next = MenuRouter.visibleMoreSections(widget.director.state);
        if (i >= 0 && i < next.length) {
          widget.onSectionChanged(next[i]);
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
    final sections = MenuRouter.visibleMoreSections(s);
    var section = widget.section;
    if (!sections.contains(section)) {
      section = MoreSection.info;
    }
    final alert = MenuAlerts.moreAlert(s);
    _tabs.syncToId(sections, section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuChrome.tabRail(
          controller: _tabs.controller,
          onTap: (i) {
            if (i >= 0 && i < sections.length) {
              widget.onSectionChanged(sections[i]);
            }
            setState(() {});
          },
          tabs: [
            for (var i = 0; i < sections.length; i++)
              MenuChrome.bridgedTab(
                sections[i].rowLabel,
                onSelect: () {
                  _tabs.controller.animateTo(i);
                  widget.onSectionChanged(sections[i]);
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
    final showCodex = MenuTabs.showCodex(s);
    final panes = showCodex
        ? const ['GUIDE', 'CODEX', 'TROPHIES']
        : const ['GUIDE'];
    final pane = _infoPane.clamp(0, panes.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (MenuTabs.showWhatsNew(s)) ...[
          GameButton(
            label: 'PATCH NOTES',
            style: GameButtonStyle.grey,
            dense: true,
            onPressed: widget.onOpenWhatsNew,
          ),
          const SizedBox(height: 8),
        ],
        if (showCodex) ...[
          MenuChrome.segmented(
            labels: panes,
            selectedIndex: pane,
            onSelect: (i) => setState(() => _infoPane = i),
          ),
          const SizedBox(height: 8),
        ],
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
