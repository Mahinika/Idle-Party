import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../apex_forge_panel.dart';

/// MORE → CRAFT — lasting Apex station.
class CraftOverlay extends StatelessWidget {
  const CraftOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ApexHubPanel(director: director),
        const SizedBox(height: 12),
      ],
    );
  }
}
