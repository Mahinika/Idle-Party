import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ad_boost.dart';
import '../../core/app_analytics.dart';
import '../../core/game_director.dart';
import '../../core/menu_alerts.dart';
import '../../core/remote_tune.dart';
import '../../core/shop_billing.dart';
import '../../core/shop_catalog.dart';
import '../../core/shop_hub_offer.dart';
import '../../core/shop_store.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../redeem_coupon_dialog.dart';

/// Bottom-tab SHOP: real-money catalog via Play Billing.
class ShopDock extends StatefulWidget {
  const ShopDock({super.key, required this.director});

  final GameDirector director;

  /// SHOP blurb. ESSENCE is named only when that tab exists.
  static String convenienceLine({required bool showEssence}) {
    final essenceBit = showEssence ? ' Essence is under ESSENCE.' : '';
    return 'Free tickets are SCROLLS on the hub. '
        'Ad-free, Long Away, and Supporter are here. '
        'Bag space and pet errands use gold or Cinders in GEAR'
        '${showEssence ? ' and ESSENCE' : ''} — not real money. '
        'Gold is under GOLD.$essenceBit';
  }

  @override
  State<ShopDock> createState() => _ShopDockState();
}

class _ShopDockState extends State<ShopDock> {
  final Set<String> _productViewsLogged = {};

  @override
  void initState() {
    super.initState();
    unawaited(AppAnalytics.storeView());
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    await ShopStore.refreshProducts();
    if (mounted) setState(() {});
  }

  void _buy(ShopCatalogItem item) {
    unawaited(
      widget.director.buyShopItem(item.id).then((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.director,
      builder: (context, _) {
        final state = widget.director.state;
        final storeOk = ShopBilling.billingReady && ShopStore.storeAvailable;
        final catalogOk = ShopStore.productsReady;
        final storeLine = storeOk
            ? (catalogOk
                  ? 'Prices come from Google Play.'
                  : 'Waiting for Play catalog…')
            : 'Waiting for Play billing…';
        final playListed = ShopStore.productsReady
            ? {
                for (final item in ShopCatalog.offered)
                  if (ShopStore.storeLists(item.id)) item.id,
              }
            : null;
        final items = RemoteTune.pin(ShopCatalog.shelf(playListed: playListed));
        for (final item in items) {
          if (_productViewsLogged.add(item.id)) {
            unawaited(AppAnalytics.storeProductView(item.id));
          }
        }
        final featured = ShopHubOffer.featuredItem(state);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _page(
                hint: ShopDock.convenienceLine(
                  showEssence: MenuTabs.showCamp(state),
                ),
                storeLine: storeLine,
                items: items,
                featured: featured,
                showAccountActions: true,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Play's localized price. Never the catalog's hardcoded label.
  String _priceLabel(ShopCatalogItem item) {
    final live = ShopStore.storePriceLabel(item.id)?.trim();
    if (live == null || live.isEmpty) return 'Unavailable';
    return live;
  }

  bool _priceReady(ShopCatalogItem item) {
    final live = ShopStore.storePriceLabel(item.id)?.trim();
    return live != null && live.isNotEmpty;
  }

  Widget _page({
    required String hint,
    required String storeLine,
    required List<ShopCatalogItem> items,
    ShopCatalogItem? featured,
    bool showAccountActions = false,
  }) {
    final state = widget.director.state;
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      children: [
        Text(
          hint,
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        if (featured != null) ...[
          const SizedBox(height: 6),
          Text(
            ShopHubOffer.countdownLine(state),
            style: GameTheme.body(size: 12, color: GameTheme.torchHot),
          ),
          const SizedBox(height: 6),
          _ShopRow(
            item: featured,
            owned: ShopBilling.isOwned(state, featured),
            priceLabel: _priceLabel(featured),
            available: _priceReady(featured) ||
                ShopCatalog.playChargeableIds.contains(featured.id),
            compact: false,
            titleOverride: ShopHubOffer.featuredTitle(featured),
            onBuy: () => _buy(featured),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        Text(
          storeLine,
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ShopRow(
            item: items[i],
            owned: ShopBilling.isOwned(state, items[i]),
            priceLabel: _priceLabel(items[i]),
            available: _priceReady(items[i]),
            compact:
                items[i].kind == ShopOfferKind.permScroll &&
                items[i].permMask != AdBoost.permAll,
            onBuy: () => _buy(items[i]),
          ),
        ],
        if (showAccountActions) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GameButton(
                  label: 'RESTORE',
                  style: GameButtonStyle.grey,
                  dense: true,
                  onPressed: widget.director.restoreShopPurchases,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  label: 'REDEEM CODE',
                  style: GameButtonStyle.grey,
                  dense: true,
                  onPressed: () =>
                      showRedeemCouponDialog(context, widget.director),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.item,
    required this.owned,
    required this.priceLabel,
    required this.available,
    required this.onBuy,
    this.compact = false,
    this.titleOverride,
  });

  final ShopCatalogItem item;
  final bool owned;
  final String priceLabel;
  final bool available;
  final VoidCallback? onBuy;
  final bool compact;
  final String? titleOverride;

  static String? assetFor(ShopCatalogItem item) {
    if (item.permMask == AdBoost.permAll) return UiIcon.star;
    if (item.kind == ShopOfferKind.adFree) return UiIcon.heart;
    if (item.kind == ShopOfferKind.longAway) return UiIcon.campfire;
    if (item.kind == ShopOfferKind.supporterQol) return UiIcon.trophy;
    if (item.kind == ShopOfferKind.boostHours) return UiIcon.flask;
    if (item.kind == ShopOfferKind.cinders) return UiIcon.gold;
    if (item.kind == ShopOfferKind.seasonPass) return UiIcon.star;
    return switch (item.permMask) {
      AdBoost.permAtk => UiIcon.sword,
      AdBoost.permGold => UiIcon.gold,
      AdBoost.permXp => UiIcon.tome,
      AdBoost.permMove => UiIcon.boots,
      AdBoost.permLoot => UiIcon.chest,
      AdBoost.permSpeed => UiIcon.wand,
      AdBoost.permRest => UiIcon.campfire,
      _ => null,
    };
  }

  static String shortTitle(ShopCatalogItem item) {
    const prefix = 'Forever Scroll of ';
    if (item.name.startsWith(prefix)) {
      return 'Forever ${item.name.substring(prefix.length)}';
    }
    return item.name;
  }

  static String tag(ShopCatalogItem item) {
    return switch (item.kind) {
      ShopOfferKind.boostHours =>
        '+${item.boostHours}h${item.oneTime ? ' · once' : ''}',
      ShopOfferKind.adFree => 'permanent',
      ShopOfferKind.longAway => '16h cave · 24h chest · once',
      ShopOfferKind.supporterQol =>
        '+${item.bagSlots} bag · +${item.boostHours}h · once',
      ShopOfferKind.cinders => '${item.cinderGrant} Cinders',
      ShopOfferKind.seasonPass => 'month pass · once',
      ShopOfferKind.permScroll =>
        item.permMask == AdBoost.permAll
            ? 'permanent · all seven · cheaper than each'
            : '${_permEffect(item.permMask)} · permanent',
    };
  }

  static String _permEffect(int mask) => switch (mask) {
    AdBoost.permAtk => '+${AdBoost.attackPercent}% AP',
    AdBoost.permGold => '×${AdBoost.goldMul} gold',
    AdBoost.permXp => '+${AdBoost.xpPercent}% XP',
    AdBoost.permMove => '+${AdBoost.movePercent}% walk',
    AdBoost.permLoot => '+${AdBoost.lootFindPercent}% find',
    AdBoost.permSpeed => '+${AdBoost.speedPercent}% haste',
    AdBoost.permRest => 'Welcome Back ×${AdBoost.awayGoldMul}',
    _ => 'always on',
  };

  @override
  Widget build(BuildContext context) {
    final mark = assetFor(item);
    final featured = RemoteTune.highlights(item);
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: MenuChrome.listCard(selected: owned || featured),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (mark != null) ...[
                GameIcon.asset(
                  mark,
                  size: 22,
                  color: owned ? GameTheme.torchHot : null,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleOverride ?? shortTitle(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.body(
                        size: 15,
                        color: GameTheme.torchHot,
                      ),
                    ),
                    Text(
                      priceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.body(
                        size: 13,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            tag(item),
            style: GameTheme.body(size: 11, color: GameTheme.mossLit),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              item.description,
              style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GameButton(
              label: owned
                  ? 'OWNED'
                  : available
                  ? 'BUY'
                  : 'UNAVAILABLE',
              tip: owned
                  ? 'Already on this save'
                  : available
                  ? null
                  : 'Google Play has not listed this pack',
              style: GameButtonStyle.grey,
              expanded: false,
              dense: true,
              onPressed: owned || !available ? null : onBuy,
            ),
          ),
        ],
      ),
    );
  }
}
