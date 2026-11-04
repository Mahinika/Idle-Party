import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/menu_router.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';
import '../shell_layout.dart';
import 'upgrade_panel.dart';

/// Thin FORGE / CAMP / MARKET row when the fight uses FULL height.
/// Opens a sheet so upgrades do not steal the cave viewport.
class HomeGoldDock extends StatelessWidget {
  const HomeGoldDock({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GameTheme.panel,
      child: SizedBox(
        height: 32,
        child: Padding(
          padding: ShellLayout.seamPadding.copyWith(top: 2, bottom: 2),
          child: MenuChrome.segmented(
            dense: true,
            labels: const ['FORGE', 'CAMP', 'MARKET'],
            selectedIndex: -1,
            onSelect: (i) => _openSheet(context, HomeGoldPanel.values[i]),
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, HomeGoldPanel mode) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HomeGoldSheet(
        director: director,
        router: router,
        initialPanel: mode,
      ),
    );
  }
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
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: MenuChrome.segmented(
                        dense: true,
                        labels: const ['FORGE', 'CAMP', 'MARKET'],
                        selectedIndex: _panel.index,
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
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: GameIcon.glyph(
                              UiGlyph.close,
                              size: 18,
                              color: GameTheme.parchmentDim,
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
