import 'package:flutter/material.dart';

import '../game_button.dart';
import '../game_theme.dart';

/// Full-screen pause while a save copy is unfinished.
///
/// Sits on the play shell, over both the home layout and the classic bar,
/// because that is the screen a boot with an unfinished copy opens. The
/// player finds it covering the fight, with RETRY, until both copies are
/// durable. Purchases and combat stay off behind it.
class SaveRecoveryGate extends StatelessWidget {
  const SaveRecoveryGate({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final line = message.trim().isEmpty
        ? 'Saving is paused. An unfinished copy is still on this device. '
              'Retry keeps both copies.'
        : message.trim();
    return ColoredBox(
      color: GameTheme.scrim,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SAVE RECOVERY',
                textAlign: TextAlign.center,
                style: GameTheme.menuTitle(size: 22),
              ),
              const SizedBox(height: 16),
              Text(
                line,
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 16, color: GameTheme.parchment),
              ),
              const SizedBox(height: 12),
              Text(
                'Play and purchases stay off so nothing from this sitting is lost.',
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
              ),
              const SizedBox(height: 24),
              GameButton(
                label: 'RETRY',
                primary: true,
                onPressed: () => onRetry(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
