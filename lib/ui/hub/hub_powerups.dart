import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ad_boost.dart';
import '../../core/ad_rewarded.dart';
import '../../core/game_director.dart';
import '../../core/game_state.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';

/// Compact floating POWERUPS control — ticket count / active buff timer.
class HubPowerupsFab extends StatelessWidget {
  const HubPowerupsFab({
    super.key,
    required this.state,
    required this.onOpen,
    this.compact = false,
  });

  final GameState state;
  final VoidCallback onOpen;

  /// Header icon — star only, no chip under action buttons.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final md = state.metaDepth;
    final status = AdBoost.fabStatus(md);
    final lit = AdBoost.anyBuffActive(md) || md.adTickets > 0;
    final labelColor =
        lit ? GameTheme.torchHot : GameTheme.parchmentDim;
    if (compact) {
      return GameIconButton(
        label: 'POWERUPS. $status',
        asset: UiIcon.star,
        size: 18,
        color: labelColor,
        onPressed: onOpen,
      );
    }
    return WebClickScope(
      label: 'POWERUPS',
      onPressed: onOpen,
      child: Semantics(
        button: true,
        label: 'POWERUPS. $status',
        onTap: onOpen,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            child: Ink(
              decoration: MenuChrome.hubPanel(selected: lit),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: GameTheme.minTouch,
                  minHeight: GameTheme.minTouch,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GameIcon.asset(
                        UiIcon.star,
                        size: 18,
                        color: labelColor,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GameTheme.body(size: 10, color: labelColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Legacy name kept for older call sites — same as [HubPowerupsFab].
typedef HubPowerupsCard = HubPowerupsFab;

/// Bottom sheet: earn tickets (WATCH) + spend on buffs.
Future<void> openPowerupsSheet(
  BuildContext context,
  GameDirector director,
) async {
  WebClickBridge.pushLayer();
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: director,
          builder: (ctx, _) {
            final md = director.state.metaDepth;
            final realAds = AdRewarded.realAdsAvailable;
            final adFree = md.adFree;
            final canDaily = AdBoost.canClaimAdFreeDaily(md);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: MenuChrome.sheet,
                  borderRadius: MenuChrome.sheetRadius,
                  border: Border.all(
                    color: GameTheme.borderLit.withValues(alpha: 0.45),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MenuChrome.sheetHandle(),
                        Text('POWERUPS', style: GameTheme.menuTitle(size: 18)),
                        const SizedBox(height: 8),
                        Text(
                          'Watch a short ad for 1 Ad Ticket. Spend tickets on '
                          'timed boosts. Optional — fights never pause for an ad.',
                          style: GameTheme.body(
                            size: 15,
                            color: GameTheme.parchment,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MenuChrome.statRow(
                          label: 'Ad Tickets',
                          value: '${md.adTickets}',
                        ),
                        if (AdBoost.atkActive(md))
                          MenuChrome.statRow(
                            label: 'Sharp Edge',
                            value: AdBoost.formatRemaining(md.adAtkUntilMs),
                          ),
                        if (AdBoost.goldActive(md))
                          MenuChrome.statRow(
                            label: 'Gold Rush',
                            value: AdBoost.formatRemaining(md.adGoldUntilMs),
                          ),
                        if (AdBoost.awayBonusReady(md))
                          MenuChrome.statRow(
                            label: 'Away Bonus',
                            value: 'Ready',
                          ),
                        const SizedBox(height: 12),
                        Text(
                          'EARN',
                          style: GameTheme.body(
                            size: 12,
                            color: GameTheme.parchmentDim,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (adFree) ...[
                          if (canDaily)
                            GameButton(
                              label: 'CLAIM DAILY TICKET',
                              style: GameButtonStyle.brown,
                              primary: true,
                              onPressed: () =>
                                  director.claimAdFreeDailyTicket(),
                            )
                          else
                            Text(
                              'Daily ticket already claimed (UTC day).',
                              style: GameTheme.body(
                                size: 13,
                                color: GameTheme.parchmentDim,
                              ),
                            ),
                        ] else if (realAds)
                          GameButton(
                            label: 'WATCH AD · +1 TICKET',
                            style: GameButtonStyle.brown,
                            primary: true,
                            onPressed: () {
                              unawaited(director.watchPowerupAd());
                            },
                          )
                        else ...[
                          Text(
                            'Ads play on the Android app. This playtest can '
                            'preview a ticket.',
                            style: GameTheme.body(
                              size: 13,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GameButton(
                            label: 'PREVIEW +1 TICKET',
                            style: GameButtonStyle.brown,
                            primary: true,
                            onPressed: () => director.grantPowerupHour(),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          'SPEND',
                          style: GameTheme.body(
                            size: 12,
                            color: GameTheme.parchmentDim,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (md.adTickets <= 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'WATCH an ad to earn a ticket.',
                              style: GameTheme.body(
                                size: 13,
                                color: GameTheme.parchmentDim,
                              ),
                            ),
                          ),
                        for (final offer in AdBuffCatalog.offered) ...[
                          _BuffRow(
                            offer: offer,
                            tickets: md.adTickets,
                            onUse: () => director.spendPowerupBuff(offer.id),
                          ),
                          const SizedBox(height: 6),
                        ],
                        const SizedBox(height: 4),
                        GameButton(
                          label: 'CLOSE',
                          style: GameButtonStyle.grey,
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    WebClickBridge.popLayer();
  }
}

class _BuffRow extends StatelessWidget {
  const _BuffRow({
    required this.offer,
    required this.tickets,
    required this.onUse,
  });

  final AdBuffOffer offer;
  final int tickets;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final can = tickets >= offer.ticketCost;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: GameTheme.panel.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
        border: Border.all(
          color: GameTheme.borderLit.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.label,
                  style: GameTheme.body(size: 14, color: GameTheme.parchment),
                ),
                Text(
                  offer.blurb,
                  style: GameTheme.body(
                    size: 12,
                    color: GameTheme.parchmentDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GameButton(
            label: can
                ? 'USE · ${offer.ticketCost}'
                : 'NEED ${offer.ticketCost}',
            style: GameButtonStyle.brown,
            primary: can,
            onPressed: can ? onUse : null,
          ),
        ],
      ),
    );
  }
}
