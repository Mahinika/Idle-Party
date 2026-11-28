import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/play_games_bridge.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';

/// One-time hub card after the first Ascend: back up progress on Play Games.
class PlayGamesProtectOverlay extends StatelessWidget {
  const PlayGamesProtectOverlay({super.key, required this.director});

  static const String tipId = 'play_games_protect';

  final GameDirector director;

  static bool shouldOffer(GameDirector director) {
    if (director.state.seenTips.contains(tipId)) return false;
    if (director.state.inDungeon) return false;
    if (director.state.ascensionLevel < 1) return false;
    if (director.state.metaDepth.playGamesOptIn) return false;
    if (!PlayGamesBridge.isSupported) return false;
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
                child: PlayGamesProtectOverlay(director: director),
              ),
            ),
          ),
        );
      },
    ).whenComplete(WebClickBridge.popLayer);
  }

  void _signIn(BuildContext context) {
    director.dismissTip(tipId);
    Navigator.of(context).pop();
    unawaited(director.signInPlayGames());
  }

  void _later(BuildContext context) {
    director.dismissTip(tipId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Back up your save?',
          textAlign: TextAlign.center,
          style: GameTheme.title(),
        ),
        const SizedBox(height: 10),
        Text(
          'You just Ascended. Sign in with Play Games and this phone keeps a '
          'cloud copy. Same account can restore on a new phone.',
          textAlign: TextAlign.center,
          style: GameTheme.readable(color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 14),
        GameButton(
          label: 'SIGN IN · PLAY GAMES',
          style: GameButtonStyle.brown,
          primary: true,
          onPressed: () => _signIn(context),
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