import 'package:flutter/material.dart';

import '../core/ui_feedback.dart';
import 'game_theme.dart';

/// Single ephemeral notice painter (tips, celebrate, danger).
/// Callers should hide this while full-screen meta overlays are open so it
/// does not cover Contracts / Forge chrome.
class FeedbackToast extends StatelessWidget {
  const FeedbackToast({
    super.key,
    required this.message,
    this.kind = NoticeKind.tip,
    this.maxLines = 3,
    this.alignment = const Alignment(0, -0.42),
  });

  final String message;
  final NoticeKind kind;
  final int maxLines;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final (Color fillTop, Color fillBot, Color border, Color text) =
        switch (kind) {
          NoticeKind.celebrate => (
            GameTheme.toastCelebrateTop,
            GameTheme.toastCelebrateBottom,
            GameTheme.clear,
            GameTheme.clear,
          ),
          NoticeKind.danger => (
            GameTheme.blood.withValues(alpha: 0.92),
            GameTheme.toastDangerBottom,
            GameTheme.torchHot,
            GameTheme.torchHot,
          ),
          NoticeKind.tip => (
            GameTheme.stoneRaised.withValues(alpha: 0.96),
            GameTheme.stoneDeep.withValues(alpha: 0.96),
            GameTheme.borderLit.withValues(alpha: 0.55),
            GameTheme.parchment,
          ),
        };

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
                colors: [fillTop, fillBot],
              ),
              borderRadius: BorderRadius.circular(
                kind == NoticeKind.celebrate
                    ? 4
                    : GameTheme.radiusMd,
              ),
              border: Border.all(color: border),
              boxShadow: kind == NoticeKind.tip
                  ? [
                      BoxShadow(
                        color: GameTheme.torch.withValues(alpha: 0.12),
                        blurRadius: 16,
                      ),
                      const BoxShadow(
                        color: GameTheme.shadowMid,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            // ExcludeSemantics: otherwise TalkBack / UI dump hears the toast twice.
            child: ExcludeSemantics(
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: kind == NoticeKind.celebrate
                    ? GameTheme.pixel(
                        size: GameTheme.hudPixelComfort,
                        color: text,
                      )
                    : GameTheme.body(size: 16, color: text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
