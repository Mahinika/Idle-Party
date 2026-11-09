import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/menu_alerts.dart';
import '../apex_forge_panel.dart';
import 'shell_layout.dart';

/// MORE → CRAFT — lasting Apex station.
class CraftOverlay extends StatelessWidget {
  const CraftOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    return ListView(
      padding: ShellLayout.scrollBodyPadding,
      children: [
        if (MenuTabs.showCraft(state))
          ShellLayout.hint(
            'Gear that stays. Trials live here.',
            maxLines: 2,
          ),
        if (MenuTabs.showCraft(state)) ShellLayout.gap(6),
        Semantics(
          container: true,
          label: 'Craft trial station',
          child: ApexHubPanel(director: director),
        ),
        ShellLayout.gap(12),
      ],
    );
  }
}
