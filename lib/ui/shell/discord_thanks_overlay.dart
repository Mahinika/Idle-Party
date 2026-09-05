import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/community_links.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/hub_chase.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// One-time hub welcome: thanks + Discord invite.
class DiscordThanksOverlay extends StatelessWidget {
  const DiscordThanksOverlay({super.key, required this.director});

  static const String tipId = 'discord_thanks';

  final GameDirector director;

  static bool shouldOffer(GameDirector director) {
    if (director.state.seenTips.contains(tipId)) return false;
    // Never cover the first TODAY tip — wait until that tip is dismissed.
    if (!director.state.seenTips.contains('first_run')) return false;
    // Endgame / READY chase owns the hub — Discord stays under MORE · SETTINGS.
    if (GameLogic.endgameUnlocked(director.state)) return false;
    final chase = HubChase.forState(director.state);
    if (chase.urgency == HubChaseUrgency.ready) return false;
    return true;
  }

  static Future<void> show(BuildContext context, GameDirector director) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final maxW = math.min(380.0, size.width - 32);
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) director.dismissTip(tipId);
          },
          child: Dialog(
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
                  child: DiscordThanksOverlay(director: director),
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      // Outside tap / back — still mark seen so it does not re-trap.
      if (!director.state.seenTips.contains(tipId)) {
        director.dismissTip(tipId);
      }
    });
  }

  void _dismiss(BuildContext context) {
    director.dismissTip(tipId);
    Navigator.of(context).maybePop();
  }

  Future<void> _joinDiscord(BuildContext context) async {
    final ok = await CommunityLinks.openDiscord();
    if (!context.mounted) return;
    if (!ok) {
      director.showToast('Could not open Discord link', life: 2.2);
    }
    _dismiss(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'THANK YOU',
          textAlign: TextAlign.center,
          style: GameTheme.menuTitle(size: 20),
        ),
        const SizedBox(height: 10),
        Text(
          'Thanks for playing Idle Party!',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 16, color: GameTheme.parchment),
        ),
        const SizedBox(height: 8),
        Text(
          'Join our Discord for updates, tips, and chat with other players.',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 14),
        GameButton(
          label: 'JOIN DISCORD',
          tip: 'Opens Discord so you can join the Idle Party server',
          style: GameButtonStyle.brown,
          onPressed: () => _joinDiscord(context),
        ),
        const SizedBox(height: 8),
        GameButton(
          label: 'MAYBE LATER',
          style: GameButtonStyle.grey,
          onPressed: () => _dismiss(context),
        ),
      ],
    );
  }
}
