import 'package:flutter/material.dart';

import 'game_theme.dart';

/// Shared feedback toast — keep above meta overlays / hub scrims so players
/// always see director messages (equip, ascend, save, unlock, etc.).
class FeedbackToast extends StatelessWidget {
  const FeedbackToast({
    super.key,
    required this.message,
    this.maxLines = 3,
    this.alignment = const Alignment(0, -0.42),
  });

  final String message;
  final int maxLines;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Semantics(
          liveRegion: true,
          label: message,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xF214110C),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: GameTheme.borderLit),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 15),
            ),
          ),
        ),
      ),
    );
  }
}
