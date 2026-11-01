import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ad_boost.dart';
import '../../core/ad_free_nudge.dart';
import '../../core/ad_rewarded.dart';
import '../../core/build_stamp.dart';
import '../../core/game_director.dart';
import '../../core/menu_router.dart';
import '../../core/shop_store.dart';
import 'friend_tip_block.dart';
import '../../core/game_state.dart';
import '../../core/menu_alerts.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../shell/play_nav.dart';
import '../shell/wallet_strip.dart';
import '../web_click_bridge.dart';

/// One-tap SCROLLS row on the hub, under the cave button.
///
/// Hidden until the first boss (same gate as SHOP). The map corner stays
/// for RANKS so this row is the rewarded offer players can actually see.
class HubPowerupsFab extends StatelessWidget {
  const HubPowerupsFab({super.key, required this.state, required this.onOpen});

  final GameState state;
  final VoidCallback onOpen;

  /// Line under the title. Names the next rewarded step without opening SHOP.
  static String hint(GameState state, {DateTime? now}) {
    final md = state.metaDepth;
    if (md.adFree && AdBoost.canClaimAdFreeDaily(md, now: now)) {
      return 'Free ticket is ready';
    }
    if (md.adTickets > 0) return 'Spend a ticket on a scroll';
    if (AdBoost.anyBuffActive(md)) return 'A scroll is running';
    return 'Watch an ad for 1 ticket';
  }

  @override
  Widget build(BuildContext context) {
    final md = state.metaDepth;
    final status = AdBoost.fabStatus(md);
    final tickets = md.adTickets;
    final showStatus = status != 'SCROLLS';
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
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: GameTheme.minTouch,
                minHeight: GameTheme.minTouch,
              ),
              child: DecoratedBox(
                decoration: MenuChrome.hubPanel(selected: true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Center(
                              child: GameIcon.glyph(
                                UiGlyph.scroll,
                                size: 26,
                                color: GameTheme.torchHot,
                              ),
                            ),
                            if (tickets > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: _TicketBadge(count: tickets),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SCROLLS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GameTheme.body(
                                size: 16,
                                color: GameTheme.torchHot,
                              ),
                            ),
                            Text(
                              hint(state),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GameTheme.body(
                                size: 12,
                                color: GameTheme.parchmentDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showStatus) ...[
                        const SizedBox(width: 8),
                        Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GameTheme.body(
                            size: 13,
                            color: GameTheme.torchHot,
                          ),
                        ),
                      ],
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

/// Bottom sheet: earn tickets (WATCH) + spend on buffs.
Future<void> openPowerupsSheet(
  BuildContext context,
  GameDirector director,
) async {
  WebClickBridge.pushLayer();
  unawaited(director.syncFriendReferral());
  final router = PlayNav.maybeOf(context)?.router;
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
          child: _PowerupsSheet(director: director, router: router),
        );
      },
    );
  } finally {
    WebClickBridge.popLayer();
  }
}

class _PowerupsSheet extends StatefulWidget {
  const _PowerupsSheet({required this.director, required this.router});

  final GameDirector director;
  final MenuRouter? router;

  @override
  State<_PowerupsSheet> createState() => _PowerupsSheetState();
}

class _PowerupsSheetState extends State<_PowerupsSheet> {
  bool _nudgeLatched = false;
  bool _impressionQueued = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshStore());
  }

  Future<void> _refreshStore() async {
    await ShopStore.refreshProducts();
    if (mounted) setState(() {});
  }

  void _queueImpression(bool live) {
    if (!live || _impressionQueued) return;
    _impressionQueued = true;
    _nudgeLatched = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.director.markAdFreeNudgeShown();
    });
  }

  void _openShop() {
    widget.director.openAdFreeFromScrollsNudge();
    final router = widget.router;
    Navigator.of(context).pop();
    router?.open(MenuRoute.shop);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.director,
      builder: (context, _) {
        final director = widget.director;
        final state = director.state;
        final md = state.metaDepth;
        final realAds = AdRewarded.realAdsAvailable;
        final adFree = md.adFree;
        final canDaily = AdBoost.canClaimAdFreeDaily(md);
        final nudgeLive = AdFreeNudge.show(
          meta: md,
          playListsAdFree: AdFreeNudge.offerReady(
            playListsAdFree: ShopStore.storeLists(AdFreeNudge.productId),
            sideloadQaBuild: BuildStamp.gitSha.isNotEmpty,
          ),
        );
        _queueImpression(nudgeLive);
        final showNudge = nudgeLive || _nudgeLatched;
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
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adFree
                        ? 'Ad-free: no WATCH AD earn — claim one free daily ticket, then spend here.'
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
                    'Timed ticket scrolls live here.',
                    style: GameTheme.body(
                      size: 13,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                          if (showNudge) ...[
                            const SizedBox(height: 8),
                            _AdFreeNudgeTile(onTap: _openShop),
                          ],
                          const SizedBox(height: 8),
                          FriendTipBlock(director: director),
                          const SizedBox(height: 10),
                          MenuChrome.sectionLabelScoped(
                            'USE',
                            scope: MenuScope.today,
                          ),
                          for (final offer in AdBuffCatalog.offered) ...[
                            _BuffRow(
                              offer: offer,
                              tickets: md.adTickets,
                              timer: AdBoost.rowTimer(offer.id, md),
                              onUse: () => director.spendPowerupBuff(offer.id),
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
    );
  }
}

class _AdFreeNudgeTile extends StatelessWidget {
  const _AdFreeNudgeTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WebClickScope(
      label: AdFreeNudge.line,
      onPressed: onTap,
      child: Semantics(
        button: true,
        label: AdFreeNudge.line,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
              child: DecoratedBox(
                decoration: MenuChrome.listCard(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AdFreeNudge.line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.body(
                        size: 13,
                        color: GameTheme.torchHot,
                      ),
                    ),
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
