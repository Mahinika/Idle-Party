import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../game_theme.dart';
import '../meta/offline_welcome.dart';

/// Dungeon Welcome Back banner + auto-open. Scene does not import the dialog.
class DungeonOfflineChrome extends StatefulWidget {
  const DungeonOfflineChrome({super.key, required this.director});

  final GameDirector director;

  @override
  State<DungeonOfflineChrome> createState() => _DungeonOfflineChromeState();
}

class _DungeonOfflineChromeState extends State<DungeonOfflineChrome> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (_dialogShown ||
        !mounted ||
        widget.director.offlineSummary == null) {
      return;
    }
    _dialogShown = true;
    await showOfflineProgressDialog(context, widget.director);
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.director.offlineSummary;
    if (summary == null) return const SizedBox.shrink();
    return Align(
      alignment: const Alignment(0, -0.55),
      child: GestureDetector(
        onTap: () => showOfflineProgressDialog(context, widget.director),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: GameTheme.panel.withValues(alpha: 0.93),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: GameTheme.mossLit),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary.headline,
                textAlign: TextAlign.center,
                style: GameTheme.pixel(
                  size: GameTheme.hudPixel,
                  color: GameTheme.mossLit,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap for details',
                style: GameTheme.body(
                  size: 12,
                  color: GameTheme.parchmentDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
