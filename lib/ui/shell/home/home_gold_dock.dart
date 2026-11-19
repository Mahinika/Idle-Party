import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';
import '../shell_layout.dart';
import 'home_nav_bar.dart';
import 'upgrade_panel.dart';

/// Thin FORGE / CAMP / MARKET row when the fight uses FULL height.
/// Opens a sheet so upgrades do not steal the cave viewport.
class HomeGoldDock extends StatelessWidget {
  const HomeGoldDock({super.key, required this.director, required this.router});

  final GameDirector director;
  final MenuRouter router;

  /// FORGE / CAMP / MARKET: true when that sheet has an affordable buy.
  static List<bool> dots(GameState state) => !MenuTabs.showGold(state)
      ? const [false, false, false]
      : [
          MenuAlerts.forgeAlert(state).count > 0,
          MenuAlerts.essenceAlert(state).count > 0,
          MenuAlerts.marketAlert(state).count > 0,
        ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GameTheme.panel,
      child: Padding(
        // The raised FIGHT circle rises over this row. Keep the
        // segments above it.
        padding: ShellLayout.seamPadding.copyWith(
          top: 2,
          bottom: 2 + HomeNavBar.fightOverhang(context),
        ),
        child: MenuChrome.segmented(
          dense: true,
          labels: const ['FORGE', 'CAMP', 'MARKET'],
          icons: UiIcon.goldDockSegment,
          // Which rows have something to buy, like Brick (audit F022).
          dots: dots(director.state),
          locked: !MenuTabs.showGold(director.state),
          selectedIndex: -1,
          onSelect: (i) => _openSheet(context, HomeGoldPanel.values[i]),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, HomeGoldPanel mode) {
    showHomeGoldSheet(
      context,
      director: director,
      router: router,
      initialPanel: mode,
    );
  }
}

/// FORGE / CAMP / MARKET sheet. Fight or camp stays behind it.
void showHomeGoldSheet(
  BuildContext context, {
  required GameDirector director,
  required MenuRouter router,
  required HomeGoldPanel initialPanel,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => HomeGoldSheet(
      director: director,
      router: router,
      initialPanel: initialPanel,
    ),
  );
}

/// Scrollable FORGE / CAMP / MARKET while the fight keeps running behind.
class HomeGoldSheet extends StatefulWidget {
  const HomeGoldSheet({
    super.key,
    required this.director,
    required this.router,
    required this.initialPanel,
  });

  final GameDirector director;
  final MenuRouter router;
  final HomeGoldPanel initialPanel;

  @override
  State<HomeGoldSheet> createState() => _HomeGoldSheetState();
}

class _HomeGoldSheetState extends State<HomeGoldSheet> {
  late HomeGoldPanel _panel = widget.initialPanel;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.58;
    return Padding(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Material(
        color: GameTheme.sheet,
        borderRadius: MenuChrome.sheetRadius,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height.clamp(280.0, 520.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: MenuChrome.sheetHandle(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: MenuChrome.segmented(
                        dense: true,
                        labels: const ['FORGE', 'CAMP', 'MARKET'],
                        icons: UiIcon.goldDockSegment,
                        // Locked: padlocks, and no lit plum tab (F039).
                        locked: !MenuTabs.showGold(widget.director.state),
                        selectedIndex: MenuTabs.showGold(widget.director.state)
                            ? _panel.index
                            : -1,
                        onSelect: (i) =>
                            setState(() => _panel = HomeGoldPanel.values[i]),
                      ),
                    ),
                    WebClickScope(
                      label: 'Close',
                      onPressed: () => Navigator.pop(context),
                      child: Semantics(
                        button: true,
                        label: 'Close',
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: GameTheme.minTouch,
                              minHeight: GameTheme.minTouch,
                            ),
                            child: Center(
                              child: GameIcon.glyph(
                                UiGlyph.close,
                                size: 18,
                                color: GameTheme.parchmentDim,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: UpgradePanel(
                  director: widget.director,
                  router: widget.router,
                  sheetPanel: _panel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
