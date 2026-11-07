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
import '../../core/home_layout.dart';
import '../../core/nav_copy.dart';
import '../../core/shop_store.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../shell/shell_layout.dart';
import '../redeem_coupon_dialog.dart';

/// Bottom-tab SHOP: real-money catalog via Play Billing.
class ShopDock extends StatefulWidget {
  const ShopDock({
    super.key,
    required this.director,
    this.homeCompact = false,
  });

  /// Widget/golden tests only — bypasses Play catalog when set.
  @visibleForTesting
  static String goldenTestPriceLabel = '';

  final GameDirector director;

  /// Home sheet: one pick + expand (matches SPLIT forge).
  final bool homeCompact;

  /// SHOP blurb. ESSENCE is named only when that tab exists.
  static String convenienceLine({
    required bool showEssence,
    HomeLayout layout = HomeLayout.classic,
  }) {
    final essenceBit = showEssence ? ' Essence is under ESSENCE.' : '';
    final raw = 'Free tickets are SCROLLS on the hub. '
        'Ad-free, Long Away, and Supporter are here. '
        'Bag space and pet errands use gold or Cinders in GEAR'
        '${showEssence ? ' and ESSENCE' : ''} — not real money. '
        'Gold is under GOLD.$essenceBit';
    return NavCopy.playerText(raw, layout);
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
        final showFeatured = featured != null &&
            (_priceReady(featured) || ShopBilling.isOwned(state, featured));
        final hint = ShopDock.convenienceLine(
          showEssence: MenuTabs.showCamp(state),
          layout: state.homeLayout,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _page(
                hint: hint,
                storeLine: storeLine,
                items: items,
                featured: showFeatured ? featured : null,
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
    final test = ShopDock.goldenTestPriceLabel;
    if (test.isNotEmpty) return test;
    final live = ShopStore.storePriceLabel(item.id)?.trim();
    if (live == null || live.isEmpty) return 'Unavailable';
    return live;
  }

  bool _priceReady(ShopCatalogItem item) {
    if (ShopDock.goldenTestPriceLabel.isNotEmpty) return true;
    final live = ShopStore.storePriceLabel(item.id)?.trim();
    return live != null && live.isNotEmpty;
  }

  Widget _page({
    required String hint,
    required String storeLine,
    required List<ShopCatalogItem> items,
    ShopCatalogItem? featured,
    bool showAccountActions = false,
    bool showAllPacksToggle = false,
    VoidCallback? onToggleAllPacks,
  }) {
    final state = widget.director.state;
    return ListView(
      padding: ShellLayout.listPadding,
      children: [
        if (showAllPacksToggle && onToggleAllPacks != null)
          ShellLayout.sheetLink(
            label: 'Show picks only',
            onTap: onToggleAllPacks,
          ),
        ShellLayout.hint(hint, maxLines: 5),
        if (featured != null) ...[
          ShellLayout.gap(6),
          MenuChrome.sectionLabelScoped('FEATURED', scope: MenuScope.today),
          ShellLayout.gap(4),
          Text(
            ShopHubOffer.countdownLine(state),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.hint(color: GameTheme.torchHot),
          ),
          ShellLayout.gap(6),
          _ShopRow(
            item: featured,
            owned: ShopBilling.isOwned(state, featured),
            priceLabel: _priceLabel(featured),
            available: _priceReady(featured) ||
                ShopCatalog.playChargeableIds.contains(featured.id),
            compact: false,
            featuredPrimary: true,
            titleOverride: ShopHubOffer.featuredTitle(featured),
            layout: state.homeLayout,
            onBuy: () => _buy(featured),
          ),
          ShellLayout.blockGapWidget(),
        ],
        if (storeLine.isNotEmpty &&
            !(storeLine.startsWith('Waiting for') &&
                ShopDock.goldenTestPriceLabel.isNotEmpty)) ...[
          ShellLayout.gap(4),
          ShellLayout.hint(storeLine, maxLines: 1),
          const SizedBox(height: 10),
        ],
        ...() {
          final catalog = _catalogItems(items, featured);
          return [
            for (var i = 0; i < catalog.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _ShopRow(
                item: catalog[i],
                owned: ShopBilling.isOwned(state, catalog[i]),
                priceLabel: _priceLabel(catalog[i]),
                available: _priceReady(catalog[i]),
                compact:
                    catalog[i].kind == ShopOfferKind.permScroll &&
                    catalog[i].permMask != AdBoost.permAll,
                layout: state.homeLayout,
                onBuy: () => _buy(catalog[i]),
              ),
            ],
          ];
        }(),
        if (showAccountActions) ...[
          ShellLayout.blockGapWidget(),
          ShellLayout.secondaryActionRow(
            children: [
              GameButton(
                label: 'RESTORE',
                style: GameButtonStyle.grey,
                dense: true,
                onPressed: widget.director.restoreShopPurchases,
              ),
              GameButton(
                label: 'REDEEM CODE',
                style: GameButtonStyle.grey,
                dense: true,
                onPressed: () =>
                    showRedeemCouponDialog(context, widget.director),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<ShopCatalogItem> _catalogItems(
    List<ShopCatalogItem> items,
    ShopCatalogItem? featured,
  ) {
    if (featured == null) return items;
    return items.where((i) => i.id != featured.id).toList(growable: false);
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
    this.featuredPrimary = false,
    this.layout = HomeLayout.classic,
  });

  final ShopCatalogItem item;
  final bool owned;
  final String priceLabel;
  final bool available;
  final VoidCallback? onBuy;
  final bool compact;
  final String? titleOverride;
  final bool featuredPrimary;
  final HomeLayout layout;

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
    final highlighted = featuredPrimary || RemoteTune.highlights(item);
    final canBuy = !owned && available && onBuy != null;
    final buyLabel = owned
        ? 'OWNED'
        : available
        ? (featuredPrimary ? 'BUY NOW' : 'BUY')
        : 'UNAVAILABLE';
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: MenuChrome.listCard(selected: owned || highlighted),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mark != null) ...[
                GameIcon.asset(
                  mark,
                  size: ShellLayout.shellIconSize + 2,
                  color: owned ? GameTheme.torchHot : null,
                ),
                const SizedBox(width: GameTheme.clusterGap),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleOverride ?? shortTitle(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.readable(color: GameTheme.torchHot),
                    ),
                    Text(
                      priceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.section(color: GameTheme.parchmentDim),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            tag(item),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.hint(color: GameTheme.mossLit),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              NavCopy.playerText(item.description, layout),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.section(color: GameTheme.parchmentDim),
            ),
          ],
          const SizedBox(height: 8),
          if (featuredPrimary && canBuy)
            GameButton(
              label: buyLabel,
              style: GameButtonStyle.brown,
              primary: true,
              onPressed: onBuy,
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: GameButton(
                label: buyLabel,
                tip: owned
                    ? 'Already on this save'
                    : available
                    ? null
                    : 'Google Play has not listed this pack',
                style: GameButtonStyle.grey,
                expanded: false,
                dense: true,
                onPressed: canBuy ? onBuy : null,
              ),
            ),
        ],
      ),
    );
  }
}
