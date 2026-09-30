import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ad_boost.dart';
import '../../core/ad_rewarded.dart';
import '../../core/game_director.dart';
import 'friend_tip_block.dart';
import '../../core/game_state.dart';
import '../../core/menu_alerts.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../shell/wallet_strip.dart';
import '../web_click_bridge.dart';

/// Floating SCROLLS overlay — rolled-scroll glyph on the hub map, not in the header.
class HubPowerupsFab extends StatefulWidget {
  const HubPowerupsFab({super.key, required this.state, required this.onOpen});

  final GameState state;
  final VoidCallback onOpen;

  @override
  State<HubPowerupsFab> createState() => _HubPowerupsFabState();
}

class _HubPowerupsFabState extends State<HubPowerupsFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _syncMotion();
  }

  @override
  void didUpdateWidget(HubPowerupsFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.vfxQuality != widget.state.vfxQuality) {
      _syncMotion();
    }
  }

  void _syncMotion() {
    if (!widget.state.vfxQuality.showGuideAndPulse) {
      _pop.stop();
      _pop.value = 0.55;
      return;
    }
    if (!_pop.isAnimating) {
      unawaited(_pop.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final md = widget.state.metaDepth;
    final status = AdBoost.fabStatus(md);
    final tickets = md.adTickets;
    return WebClickScope(
      label: 'SCROLLS',
      onPressed: widget.onOpen,
      child: Semantics(
        button: true,
        label: 'SCROLLS. $status',
        onTap: widget.onOpen,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onOpen,
            borderRadius: BorderRadius.circular(GameTheme.radiusMd),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: GameTheme.minTouch,
                minHeight: GameTheme.minTouch,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pop,
                      builder: (context, child) {
                        final t = Curves.easeInOut.transform(_pop.value);
                        final scale = 1.0 + 0.1 * t;
                        final glow = 0.28 + 0.42 * t;
                        return Transform.scale(
                          scale: scale,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                GameTheme.radiusSm,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: GameTheme.torch.withValues(
                                    alpha: glow,
                                  ),
                                  blurRadius: 10 + 10 * t,
                                  spreadRadius: 1 + 2 * t,
                                ),
                              ],
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: SizedBox(
                        width: GameTheme.primaryTouch,
                        height: GameTheme.primaryTouch,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            DecoratedBox(
                              decoration: MenuChrome.hubPanel(selected: true),
                              child: Center(
                                child: GameIcon.glyph(
                                  UiGlyph.scroll,
                                  size: 26,
                                  color: GameTheme.torchHot,
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
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.body(
                        size: 10,
                        color: GameTheme.torchHot,
                      ),
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
  unawaited(director.syncFriendReferral());
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: MenuChrome.scrim,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) {
        final viewPad = MediaQuery.viewPaddingOf(ctx);
        final keyboard = MediaQuery.viewInsetsOf(ctx).bottom;
        // Same stack as GEAR / KEY: fill above the bottom bar, not the status
        // strip and not over the tabs.
        final bottomGap = GameTheme.bottomNavHeight + viewPad.bottom + keyboard;
        return Padding(
          padding: EdgeInsets.only(top: viewPad.top, bottom: bottomGap),
          child: ListenableBuilder(
            listenable: director,
            builder: (ctx, _) {
              final state = director.state;
              final md = state.metaDepth;
              final realAds = AdRewarded.realAdsAvailable;
              final adFree = md.adFree;
              final canDaily = AdBoost.canClaimAdFreeDaily(md);
              return Material(
                color: GameTheme.panel,
                child: DecoratedBox(
                  decoration: MenuChrome.panel(
                    borderRadius: BorderRadius.zero,
                    opaque: true,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('SCROLLS', style: GameTheme.menuTitle(size: 18)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            WalletStrip(
                              gold: state.gold,
                              essence: state.essence,
                              showEssence: MenuTabs.showCamp(state),
                            ),
                            const Spacer(),
                            GameButton(
                              label: 'CLOSE',
                              style: GameButtonStyle.grey,
                              expanded: false,
                              dense: true,
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          adFree
                              ? 'Ad-free: claim a free daily ticket, then spend it here.'
                              : 'Watch for a ticket, then spend it here.',
                          style: GameTheme.body(
                            size: 12,
                            color: GameTheme.parchmentDim,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 1,
                          color: GameTheme.borderLit.withValues(alpha: 0.22),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                          'Optional ads. Never mid-fight. '
                          'Timed ticket scrolls live here. '
                          'Forever scrolls are bought in SHOP.',
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
                        const SizedBox(height: 8),
                        FriendTipBlock(director: director),
                        const SizedBox(height: 10),
                        MenuChrome.sectionLabelScoped(
                          'USE',
                          scope: MenuScope.today,
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final offer in AdBuffCatalog.offered) ...[
                                  _BuffRow(
                                    offer: offer,
                                    tickets: md.adTickets,
                                    timer: AdBoost.rowTimer(offer.id, md),
                                    onUse: () =>
                                        director.spendPowerupBuff(offer.id),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
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
                      if (on) MenuChrome.chip(label: timer!, selected: true),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    offer.effect,
                    style: GameTheme.body(size: 12, color: GameTheme.mossLit),
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
