import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/local_reminders.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';

/// One-time hub card after first loot. Never install, never combat.
class NotifyOptInOverlay extends StatelessWidget {
  const NotifyOptInOverlay({super.key, required this.director});

  final GameDirector director;

  static bool shouldOffer(GameDirector director) =>
      LocalReminders.shouldOfferOptIn(director.state);

  static Future<void> show(BuildContext context, GameDirector director) {
    WebClickBridge.pushLayer();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final maxW = math.min(380.0, size.width - 32);
        return PopScope(
          canPop: false,
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
                  child: NotifyOptInOverlay(director: director),
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(WebClickBridge.popLayer);
  }

  Future<void> _yes(BuildContext context) async {
    await director.acceptNotifyOptIn();
    if (context.mounted) Navigator.of(context).maybePop();
  }

  void _no(BuildContext context) {
    director.declineNotifyOptIn();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocalReminders.optInTitle,
          textAlign: TextAlign.center,
          style: GameTheme.menuTitle(size: 20),
        ),
        const SizedBox(height: 10),
        Text(
          LocalReminders.optInBody,
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 14),
        GameButton(
          label: 'YES',
          tip: 'Allow quiet away reminders — at most a couple a day',
          style: GameButtonStyle.brown,
          onPressed: () => _yes(context),
        ),
        const SizedBox(height: 8),
        GameButton(
          label: 'NOT NOW',
          style: GameButtonStyle.grey,
          onPressed: () => _no(context),
        ),
      ],
    );
  }
}
