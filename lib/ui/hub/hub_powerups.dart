import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ad_boost.dart';
import '../../core/ad_free_nudge.dart';
import '../../core/ad_rewarded.dart';
import '../../core/build_stamp.dart';
import '../../core/game_director.dart';
import '../../core/menu_router.dart';
import '../../core/scroll_well.dart';
import '../../core/shop_store.dart';
import '../../core/reinstall_pouch.dart';
import '../../core/wisp_gift.dart';
import 'friend_tip_block.dart';
import '../../core/game_state.dart';
import '../../core/menu_alerts.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../shell/home/home_shell.dart';
import '../shell/play_nav.dart';
import '../shell/shell_common.dart';
import '../shell/shell_layout.dart';
import '../shell/wallet_strip.dart';
import '../web_click_bridge.dart';

/// Which SCROLLS block to open on (POUCH vs default hub body).
enum PowerupsFocus { none, pouch }

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
    if (ScrollWell.canClaimFree(md, now: now)) {
      return 'Free ticket in SCROLLS';
    }
    if (!md.adFree && !ScrollWell.ladderComplete(md, now: now)) {
      return 'Daily Well · ${ScrollWell.progressLine(md, now: now)}';
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
                minHeight: 44,
              ),
              child: ShellLayout.hubCard(
                selected: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: GameIcon.glyph(
                              UiGlyph.scroll,
                              size: 22,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                          if (tickets > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: _TicketBadge(count: tickets),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SCROLLS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GameTheme.section(color: GameTheme.parchment),
                          ),
                          Text(
                            hint(state),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GameTheme.hint(color: GameTheme.parchmentDim),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'OPEN',
                      style: GameTheme.readable(color: GameTheme.torch),
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
        style: GameTheme.hint(color: GameTheme.stone),
      ),
    );
  }
}

/// Copy and keys for the SCROLLS sheet.
abstract final class ScrollsSheet {
  static const Key ticketPillKey = ValueKey('scrolls-ticket-pill');
  static final GlobalKey pouchSectionKey = GlobalKey(
    debugLabel: 'scrolls-pouch-section',
  );
  static const Key pouchTitleKey = ValueKey('scrolls-pouch-title');

  static String _tickets(int n) => n == 1 ? '1 ticket' : '$n tickets';

  /// "USE · 1 ticket" on a scroll row.
  static String useLabel(int cost) => 'USE · ${_tickets(cost)}';

  /// Under a scroll row the player cannot afford yet.
  static String needTickets(int short) => 'Need ${_tickets(short)}';
}

const Key powerupsSheetKey = ValueKey('powerups-sheet');

/// Bottom sheet: earn tickets (WATCH) + spend on buffs.
Future<void> openPowerupsSheet(
  BuildContext context,
  GameDirector director, {
  PowerupsFocus focus = PowerupsFocus.none,
}) async {
  WebClickBridge.pushLayer();
  unawaited(director.syncFriendReferral());
  final router = PlayNav.maybeOf(context)?.router;
  // From the home rails: open below the HUD, like QUESTS / the menu panels,
  // so gold, essence and the nav stay visible (audit F048).
  final hudBottom = HomeShell.topChromeBottom(context);
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: hudBottom == null ? MenuChrome.scrim : Colors.transparent,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) {
        final viewPad = MediaQuery.viewPaddingOf(ctx);
        final keyboard = MediaQuery.viewInsetsOf(ctx).bottom;
        // Same stack as GEAR / KEY: fill above the bottom bar, not the status
        // strip and not over the tabs.
        final bottomGap = GameTheme.bottomNavHeight + viewPad.bottom + keyboard;
        return Padding(
          key: powerupsSheetKey,
          padding: EdgeInsets.only(
            top: hudBottom ?? viewPad.top,
            bottom: bottomGap,
          ),
          child: _PowerupsSheet(
            director: director,
            router: router,
            focus: focus,
          ),
        );
      },
    );
  } finally {
    WebClickBridge.popLayer();
  }
}

class _PowerupsSheet extends StatefulWidget {
  const _PowerupsSheet({
    required this.director,
    required this.router,
    this.focus = PowerupsFocus.none,
  });

  final GameDirector director;
  final MenuRouter? router;
  final PowerupsFocus focus;

  @override
  State<_PowerupsSheet> createState() => _PowerupsSheetState();
}

class _PowerupsSheetState extends State<_PowerupsSheet> {
  bool _nudgeLatched = false;
  bool _impressionQueued = false;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(_refreshStore());
    if (widget.focus == PowerupsFocus.pouch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPouch());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToPouch() {
    final ctx = ScrollsSheet.pouchSectionKey.currentContext;
    if (ctx == null || !_scroll.hasClients) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: 0.05,
    );
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
              padding: ShellLayout.sheetPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MenuChrome.sheetHandle(),
                  Text(
                    widget.focus == PowerupsFocus.pouch ? 'POUCH' : 'SCROLLS',
                    style: GameTheme.title(),
                  ),
                  ShellLayout.gap(6),
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
                  ShellLayout.gap(4),
                  ShellLayout.hint(
                    adFree
                        ? 'Ad-free: no ads. Claim five free tickets each day, then spend them here.'
                        : 'Watch for a ticket, then spend it here.',
                  ),
                  ShellLayout.gap(6),
                  ShellLayout.divider(),
                  ShellLayout.gap(8),
                  // A wallet pill like gold / essence, not a text field
                  // look-alike (audit F073).
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      label: 'Ad Tickets ${md.adTickets}',
                      excludeSemantics: true,
                      child: Container(
                        key: ScrollsSheet.ticketPillKey,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: MenuChrome.cardBox(inset: true),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GameIcon.glyph(
                              UiGlyph.scroll,
                              size: 18,
                              color: GameTheme.torchHot,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Ad Tickets',
                              style: GameTheme.readable(
                                color: GameTheme.parchmentDim,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${md.adTickets}',
                              style: GameTheme.button(
                                size: GameTheme.typeSection,
                                color: GameTheme.torchHot,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ShellLayout.gap(6),
                  ShellLayout.hint(
                    'Optional ads. Never mid-fight. '
                    'Timed ticket scrolls live here.',
                    maxLines: 3,
                  ),
                  ShellLayout.blockGapWidget(),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (ReinstallPouch.showOffer(state)) ...[
                            KeyedSubtree(
                              key: ScrollsSheet.pouchSectionKey,
                              child: DecoratedBox(
                                decoration: widget.focus == PowerupsFocus.pouch
                                    ? MenuChrome.listCard(selected: true)
                                    : const BoxDecoration(),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'POUCH',
                                        key: ScrollsSheet.pouchTitleKey,
                                        style: GameTheme.title(),
                                      ),
                                      ShellLayout.gap(4),
                                      ShellLayout.hint(
                                        'One-time starter gold after a fresh install.',
                                        maxLines: 2,
                                      ),
                                      ShellLayout.gap(6),
                                      ReinstallPouchFab(
                                        state: state,
                                        onWatch: () => unawaited(
                                          director.watchReinstallPouchAd(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          MenuChrome.sectionLabelScoped(
                            'THE WELL',
                            scope: MenuScope.today,
                          ),
                          _ScrollWellBlock(
                            state: state,
                            adFree: adFree,
                            canDaily: canDaily,
                            realAds: realAds,
                            onClaimDaily: director.claimAdFreeDailyTicket,
                            onClaimWellFree: director.claimScrollWellFree,
                            onWatch: () {
                              unawaited(director.watchPowerupAd());
                            },
                            onPreview: director.grantPowerupHour,
                            onPreviewExtra: director.grantExtraTicketPreview,
                          ),
                          if (WispGift.unlocked(md)) ...[
                            const SizedBox(height: 8),
                            MenuChrome.sectionLabelScoped(
                              'WISP',
                              scope: MenuScope.today,
                            ),
                            _WispDailyLine(state: state),
                          ],
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
                      style: GameTheme.section(color: GameTheme.torchHot),
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

class _ScrollWellBlock extends StatelessWidget {
  const _ScrollWellBlock({
    required this.state,
    required this.adFree,
    required this.canDaily,
    required this.realAds,
    required this.onClaimDaily,
    required this.onClaimWellFree,
    required this.onWatch,
    required this.onPreview,
    required this.onPreviewExtra,
  });

  final GameState state;
  final bool adFree;
  final bool canDaily;
  final bool realAds;
  final VoidCallback onClaimDaily;
  final VoidCallback onClaimWellFree;
  final VoidCallback onWatch;
  final VoidCallback onPreview;
  final VoidCallback onPreviewExtra;

  @override
  Widget build(BuildContext context) {
    if (adFree) {
      if (canDaily) {
        return GameButton(
          label: 'CLAIM ${AdBoost.adFreeDailyTickets} DAILY TICKETS',
          style: GameButtonStyle.brown,
          primary: true,
          onPressed: onClaimDaily,
        );
      }
      return Text(
        'Today\'s ${AdBoost.adFreeDailyTickets} free tickets are claimed. '
        'Next ones after the daily reset.',
        style: GameTheme.section(color: GameTheme.parchmentDim),
      );
    }

    final md = state.metaDepth;
    final progress = ScrollWell.progressLine(md);
    final ladderDone = ScrollWell.ladderComplete(md);
    final canFree = ScrollWell.canClaimFree(md);
    final canWellAd = ScrollWell.canAdvanceWithAd(md);
    final extraLeft = ScrollWell.extraAdsRemaining(md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(progress, style: GameTheme.section(color: GameTheme.torchHot)),
        const SizedBox(height: 4),
        Text(
          ladderDone
              ? 'Daily bonus done. ${ScrollWell.extraAdsLine(md)}.'
              : '1 free ticket, then 2 ad steps each day.',
          style: GameTheme.hint(color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        if (canFree)
          GameButton(
            label: 'FREE · +1 TICKET',
            style: GameButtonStyle.go,
            primary: true,
            onPressed: onClaimWellFree,
          ),
        if (canWellAd && realAds) ...[
          if (canFree) const SizedBox(height: 8),
          GameButton(
            label: 'WATCH AD · +1 TICKET',
            style: GameButtonStyle.brown,
            primary: !canFree,
            onPressed: onWatch,
          ),
        ],
        if (ladderDone && extraLeft > 0) ...[
          const SizedBox(height: 8),
          if (realAds)
            GameButton(
              label: 'WATCH AD · +1 TICKET',
              style: GameButtonStyle.grey,
              onPressed: onWatch,
            )
          else ...[
            Text(
              'Ads play on the Android app. This playtest can preview a ticket.',
              style: GameTheme.section(color: GameTheme.parchmentDim),
            ),
            const SizedBox(height: 8),
            GameButton(
              label: 'PREVIEW +1 TICKET',
              style: GameButtonStyle.grey,
              onPressed: onPreviewExtra,
            ),
          ],
        ] else if (ladderDone) ...[
          const SizedBox(height: 8),
          Text(
            '${ScrollWell.extraAdsLine(md)}. More after the daily reset.',
            style: GameTheme.section(color: GameTheme.parchmentDim),
          ),
        ] else if (!canFree && !canWellAd && !realAds) ...[
          const SizedBox(height: 8),
          Text(
            'Ads play on the Android app. This playtest can preview a ticket.',
            style: GameTheme.section(color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 8),
          GameButton(
            label: 'PREVIEW +1 TICKET',
            style: GameButtonStyle.brown,
            primary: true,
            onPressed: onPreview,
          ),
        ],
      ],
    );
  }
}

class _WispDailyLine extends StatelessWidget {
  const _WispDailyLine({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final md = state.metaDepth;
    final cap = WispGift.dailyCap;
    final used = WispGift.claimsToday(md);
    final left = (cap - used).clamp(0, cap);
    return Text(
      left <= 0
          ? 'WISP · 0 LEFT TODAY · In the cave, tap the lantern for gold.'
          : 'WISP · $left LEFT TODAY · In the cave, tap the lantern for gold.',
      style: GameTheme.section(color: GameTheme.parchmentDim),
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
                          style: GameTheme.readable(color: GameTheme.torchHot),
                        ),
                      ),
                      if (on) MenuChrome.chip(label: timer!, selected: true),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    offer.effect,
                    style: GameTheme.hint(color: GameTheme.mossLit),
                  ),
                  // Say why USE is off (audit F029).
                  if (!can)
                    Text(
                      ScrollsSheet.needTickets(offer.ticketCost - tickets),
                      style: GameTheme.hint(color: GameTheme.torchHot),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GameButton(
              label: ScrollsSheet.useLabel(offer.ticketCost),
              style: GameButtonStyle.grey,
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

/// Widget tests / goldens — SCROLLS sheet body without opening a route.
@visibleForTesting
Widget scrollsSheetForTest({
  required GameDirector director,
  MenuRouter? router,
  PowerupsFocus focus = PowerupsFocus.none,
}) =>
    _PowerupsSheet(director: director, router: router, focus: focus);

/// One WATCH gold pile after a fresh install with no prior save file.
class ReinstallPouchFab extends StatelessWidget {
  const ReinstallPouchFab({
    super.key,
    required this.state,
    required this.onWatch,
  });

  final GameState state;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    if (!ReinstallPouch.showOffer(state)) return const SizedBox.shrink();
    final gold = ReinstallPouch.goldAmount(state);
    return Padding(
      padding: const EdgeInsets.only(bottom: GameTheme.clusterGap),
      child: GameButton(
        label: 'WATCH AD · +${formatGold(gold)} STARTER',
        style: GameButtonStyle.grey,
        tip: 'One-time gold after a fresh install',
        onPressed: onWatch,
      ),
    );
  }
}
