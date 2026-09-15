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

/// Floating SCROLLS overlay — rolled-scroll glyph on the hub map, not in the header.
class HubPowerupsFab extends StatelessWidget {
  const HubPowerupsFab({
    super.key,
    required this.state,
    required this.onOpen,
  });

  final GameState state;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final md = state.metaDepth;
    final status = AdBoost.fabStatus(md);
    final tickets = md.adTickets;
    final lit = AdBoost.anyBuffActive(md) || tickets > 0;
    final labelColor = lit ? GameTheme.torchHot : GameTheme.parchmentDim;
    return WebClickScope(
      label: 'SCROLLS',
      onPressed: onOpen,
      child: Semantics(
        button: true,
        label: 'SCROLLS. $status',
        onTap: onOpen,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(GameTheme.radiusMd),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: GameTheme.minTouch,
                minHeight: GameTheme.minTouch,
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: GameTheme.primaryTouch,
                      height: GameTheme.primaryTouch,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          DecoratedBox(
                            decoration: MenuChrome.hubPanel(selected: lit),
                            child: Center(
                              child: GameIcon.glyph(
                                UiGlyph.scroll,
                                size: 24,
                                color: labelColor,
                              ),
                            ),
                          ),
                          if (tickets > 0)
                            Positioned(
                              right: -3,
                              top: -3,
                              child: _TicketBadge(count: tickets),
                            ),
                        ],
                      ),
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
    );
  }
}

class _TicketBadge extends StatelessWidget {
  const _TicketBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: GameTheme.torch,
        borderRadius: BorderRadius.circular(GameTheme.radiusHud),
        border: Border.all(color: GameTheme.borderLit, width: 1),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textAlign: TextAlign.center,
        style: GameTheme.pixel(size: 8, color: GameTheme.stone),
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
        final maxH = MediaQuery.sizeOf(ctx).height * 0.88;
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
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxH,
                    maxWidth: MediaQuery.sizeOf(ctx).width,
                  ),
                  child: Material(
                    color: MenuChrome.sheet,
                    borderRadius: MenuChrome.sheetRadius,
                    clipBehavior: Clip.antiAlias,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: MenuChrome.sheetRadius,
                        border: Border.all(
                          color: GameTheme.borderLit.withValues(alpha: 0.45),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              MenuChrome.sheetHandle(),
                              Row(
                                children: [
                                  GameIcon.glyph(
                                    UiGlyph.scroll,
                                    size: 18,
                                    color: GameTheme.torch,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'SCROLLS',
                                      style: GameTheme.menuTitle(size: 18),
                                    ),
                                  ),
                                  MenuChrome.scopeChip('TODAY'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                decoration: MenuChrome.listCard(selected: true),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Ad Tickets',
                                        style: GameTheme.body(
                                          size: 14,
                                          color: GameTheme.parchmentDim,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${md.adTickets}',
                                      style: GameTheme.menuTitle(
                                        size: 22,
                                        color: GameTheme.torchHot,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Optional ads. Never mid-fight. Same scrolls as SHOP.',
                                style: GameTheme.body(
                                  size: 13,
                                  color: GameTheme.parchmentDim,
                                ),
                              ),
                              const SizedBox(height: 10),
                              MenuChrome.sectionLabelScoped(
                                'EARN',
                                scope: MenuScope.today,
                              ),
                              _EarnBlock(
                                adFree: adFree,
                                canDaily: canDaily,
                                realAds: realAds,
                                onClaimDaily: director.claimAdFreeDailyTicket,
                                onWatch: () {
                                  unawaited(director.watchPowerupAd());
                                },
                                onPreview: director.grantPowerupHour,
                              ),
                              const SizedBox(height: 10),
                              MenuChrome.sectionLabelScoped(
                                'USE',
                                scope: MenuScope.today,
                              ),
                              Expanded(
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: AdBuffCatalog.offered.length + 1,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, i) {
                                    if (i == AdBuffCatalog.offered.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: GameButton(
                                          label: 'CLOSE',
                                          style: GameButtonStyle.grey,
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(),
                                        ),
                                      );
                                    }
                                    final offer = AdBuffCatalog.offered[i];
                                    return _BuffRow(
                                      offer: offer,
                                      tickets: md.adTickets,
                                      timer: AdBoost.rowTimer(offer.id, md),
                                      onUse: () => director.spendPowerupBuff(
                                        offer.id,
                                      ),
                                    );
                                  },
                                ),
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
          },
        );
      },
    );
  } finally {
    WebClickBridge.popLayer();
  }
}

class _EarnBlock extends StatelessWidget {
  const _EarnBlock({
    required this.adFree,
    required this.canDaily,
    required this.realAds,
    required this.onClaimDaily,
    required this.onWatch,
    required this.onPreview,
  });

  final bool adFree;
  final bool canDaily;
  final bool realAds;
  final VoidCallback onClaimDaily;
  final VoidCallback onWatch;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    if (adFree) {
      if (canDaily) {
        return GameButton(
          label: 'CLAIM DAILY TICKET',
          style: GameButtonStyle.brown,
          primary: true,
          onPressed: onClaimDaily,
        );
      }
      return Text(
        'Daily ticket already claimed (UTC day).',
        style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
      );
    }
    if (realAds) {
      return GameButton(
        label: 'WATCH AD · +1 TICKET',
        style: GameButtonStyle.brown,
        primary: true,
        onPressed: onWatch,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ads play on the Android app. This playtest can preview a ticket.',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        GameButton(
          label: 'PREVIEW +1 TICKET',
          style: GameButtonStyle.brown,
          primary: true,
          onPressed: onPreview,
        ),
      ],
    );
  }
}

class _BuffRow extends StatelessWidget {
  const _BuffRow({
    required this.offer,
    required this.tickets,
    required this.timer,
    required this.onUse,
  });

  final AdBuffOffer offer;
  final int tickets;
  final String? timer;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final can = tickets >= offer.ticketCost;
    final on = timer != null;
    return Semantics(
      button: can,
      label: on
          ? '${offer.label}. ${offer.effect}. ${timer!} left. USE ${offer.ticketCost}'
          : '${offer.label}. ${offer.effect}. ${offer.ticketCost} tickets',
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: MenuChrome.listCard(selected: on),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          offer.label,
                          style: GameTheme.body(
                            size: 15,
                            color: GameTheme.torchHot,
                          ),
                        ),
                      ),
                      if (on)
                        MenuChrome.chip(
                          label: timer!,
                          selected: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    offer.effect,
                    style: GameTheme.body(
                      size: 12,
                      color: GameTheme.mossLit,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GameButton(
              label: 'USE · ${offer.ticketCost}',
              style: GameButtonStyle.brown,
              primary: false,
              expanded: false,
              dense: true,
              onPressed: can ? onUse : null,
            ),
          ],
        ),
      ),
    );
  }
}
