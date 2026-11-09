import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../apex_forge_panel.dart';
import 'shell_layout.dart';

/// MORE → CRAFT — lasting Apex station.
class CraftOverlay extends StatelessWidget {
  const CraftOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: ShellLayout.scrollBodyPadding,
      children: [
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
