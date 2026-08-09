import 'package:flutter/material.dart';

import 'game_theme.dart';

/// Shared feedback toast for director messages (equip, claim, unlock, etc.).
/// Callers should hide this while full-screen meta overlays are open so it
/// does not cover Contracts / Forge chrome.
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
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  GameTheme.stoneRaised.withValues(alpha: 0.96),
                  GameTheme.stoneDeep.withValues(alpha: 0.96),
                ],
              ),
              borderRadius: BorderRadius.circular(GameTheme.radiusMd),
              border: Border.all(
                color: GameTheme.borderLit.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: GameTheme.torch.withValues(alpha: 0.12),
                  blurRadius: 16,
                ),
                const BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 16),
            ),
          ),
        ),
      ),
    );
  }
}
