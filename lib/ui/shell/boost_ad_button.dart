import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ad_offer.dart';
import '../../core/ad_rewarded.dart';
import '../../core/analytics_events.dart';
import '../../core/game_director.dart';
import '../coach_pulse.dart';
import '../game_button.dart';

/// Pulsing WATCH on the hub and between fights when no Powerup scroll is on.
/// Hidden on Welcome Back, on a wipe, and while a pack is awake.
class BoostAdButton extends StatefulWidget {
  const BoostAdButton({super.key, required this.director});

  final GameDirector director;

  @override
  State<BoostAdButton> createState() => _BoostAdButtonState();
}

class _BoostAdButtonState extends State<BoostAdButton> {
  bool _prepared = false;

  bool _fightLive(GameDirector director) {
    if (!director.state.inDungeon) return false;
    final world = director.spatial;
    if (world == null) return false;
    return world.enemies.any((e) => e.isAlive && !e.dormant);
  }

  bool _show(GameDirector director) {
    return AdOffer.showHudButton(
      director.state,
      welcomeUp: director.offlineSummary != null,
      wipeUp: director.awaitingWipeChoice,
      fightLive: _fightLive(director),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.director,
      builder: (context, _) {
        final director = widget.director;
        final show = _show(director);
        if (!show) {
          _prepared = false;
          return const SizedBox.shrink();
        }
        if (!_prepared) {
          _prepared = true;
          unawaited(
            AdRewarded.prepareOffer(
              placement: AnalyticsEvents.placementPowerups,
            ),
          );
        }
        return CoachPulse(
          active: !director.state.reducedVfx,
          child: GameButton(
            label: AdOffer.hudLabel,
            expanded: false,
            dense: true,
            tip: 'Watch an ad for 1 Ad Ticket',
            onPressed: () {
              unawaited(director.watchPowerupAd());
            },
          ),
        );
      },
    );
  }
}
