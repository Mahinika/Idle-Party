import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/play_review_ask.dart';
import '../first_session_tips.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';

/// One-time hub card after first boss. No loot for rating.
class PlayReviewAskOverlay extends StatelessWidget {
  const PlayReviewAskOverlay({super.key, required this.director});

  final GameDirector director;

  static bool shouldOffer(GameDirector director) {
    if (!PlayReviewAsk.shouldOffer(director.state)) return false;
    // Same porch as Discord — never cover the first ENTER tip.
    if (!director.state.seenTips.contains('first_run') &&
        !FirstSessionTips.leftPorch(director.state)) {
      return false;
    }
    return true;
  }

  static Future<void> show(BuildContext context, GameDirector director) {
    WebClickBridge.pushLayer();
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final maxW = math.min(380.0, size.width - 32);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: DecoratedBox(
            decoration: MenuChrome.panel(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: maxW,
                child: PlayReviewAskOverlay(director: director),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (!director.state.metaDepth.reviewPrompted) {
        director.dismissPlayReviewAsk();
      }
    }).whenComplete(WebClickBridge.popLayer);
  }

  void _rate(BuildContext context) {
    unawaited(director.requestPlayReview(source: 'card'));
    Navigator.of(context).pop();
  }

  void _later(BuildContext context) {
    director.dismissPlayReviewAsk();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          PlayReviewAsk.title,
          textAlign: TextAlign.center,
          style: GameTheme.menuTitle(size: 20),
        ),
        const SizedBox(height: 10),
        Text(
          PlayReviewAsk.body,
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 14),
        GameButton(
          label: 'RATE ON PLAY',
          tip: 'Opens Google Play — no reward for rating',
          style: GameButtonStyle.brown,
          onPressed: () => _rate(context),
        ),
        const SizedBox(height: 8),
        GameButton(
          label: 'NOT NOW',
          style: GameButtonStyle.grey,
          onPressed: () => _later(context),
        ),
      ],
    );
  }
}
