import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../feedback_toast.dart';
import '../game_theme.dart';

/// One-line equip / score ticker under the target nameplate — not on the scrum.
class CombatFightTicker extends StatelessWidget {
  const CombatFightTicker({
    super.key,
    required this.director,
    required this.routerOpen,
  });

  final GameDirector director;
  final bool routerOpen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: director,
      builder: (context, _) {
        final msg = director.toast;
        if (msg == null ||
            routerOpen ||
            director.awaitingWipeChoice ||
            !director.dungeonTilesReady) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(
            GameTheme.edgeGap,
            2,
            GameTheme.edgeGap,
            4,
          ),
          child: FeedbackToast(
            message: msg,
            kind: director.noticeKind,
            maxLines: 1,
            docked: true,
          ),
        );
      },
    );
  }
}