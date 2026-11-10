import 'package:flutter/material.dart';

import '../game_button.dart';
import '../game_theme.dart';

/// Full-screen pause while a save copy is unfinished.
///
/// Sits on the play shell, over both the home layout and the classic bar,
/// because that is the screen a boot with an unfinished copy opens. The
/// player finds it covering the fight until both copies are durable.
/// RETRY finishes a copy whose owner is known. An unmatched older copy
/// offers export and the other slots instead. An empty slot opens party
/// setup and does not start a fight until that game is saved. Purchases
/// and combat stay off.
class SaveRecoveryGate extends StatefulWidget {
  const SaveRecoveryGate({
    super.key,
    required this.message,
    required this.onRetry,
    this.onExport,
    this.safeSlots = const [],
    this.onOpenSlot,
  });

  final String message;
  final Future<bool> Function() onRetry;

  /// Copies the raw journal and slot bytes. Null when the journal has one
  /// owner and RETRY is enough.
  final Future<void> Function()? onExport;

  /// Slots that are not part of an unmatched journal.
  final List<int> safeSlots;

  final Future<void> Function(int slot)? onOpenSlot;

  @override
  State<SaveRecoveryGate> createState() => _SaveRecoveryGateState();
}

class _SaveRecoveryGateState extends State<SaveRecoveryGate> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.message.trim().isEmpty
        ? 'Saving is paused. An unfinished copy is still on this device. '
              'Retry keeps both copies.'
        : widget.message.trim();
    return ColoredBox(
      color: GameTheme.scrim,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text(
                'SAVE RECOVERY',
                textAlign: TextAlign.center,
                style: GameTheme.title(),
              ),
              const SizedBox(height: 16),
              Text(
                line,
                textAlign: TextAlign.center,
                style: GameTheme.readable(color: GameTheme.parchment),
              ),
              const SizedBox(height: 12),
              Text(
                'Play and purchases stay off so nothing from this sitting is lost.',
                textAlign: TextAlign.center,
                style: GameTheme.readable(color: GameTheme.parchmentDim),
              ),
              const SizedBox(height: 24),
              if (widget.onExport == null)
                GameButton(
                  label: _retrying ? 'RETRYING…' : 'RETRY',
                  primary: true,
                  onPressed: _retrying ? null : _retry,
                )
              else ...[
                Text(
                  'Retry cannot choose an owner for this copy.',
                  textAlign: TextAlign.center,
                  style: GameTheme.readable(color: GameTheme.parchmentDim),
                ),
                const SizedBox(height: 12),
                GameButton(
                  label: 'EXPORT RECORDS',
                  primary: true,
                  onPressed: () => widget.onExport!(),
                ),
              ],
              for (final slot in widget.safeSlots) ...[
                const SizedBox(height: 12),
                GameButton(
                  label: 'OPEN SLOT ${slot + 1}',
                  onPressed: widget.onOpenSlot == null
                      ? null
                      : () => widget.onOpenSlot!(slot),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
