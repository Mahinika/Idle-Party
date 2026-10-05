import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ad_boost.dart';
import '../../core/game_director.dart';
import '../../core/menu_alerts.dart';
import '../../core/remote_tune.dart';
import '../../core/shop_billing.dart';
import '../../core/shop_catalog.dart';
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
        'Forever scrolls and Cinder packs are here. '
        'Gold is under GOLD.$essenceBit';
  }

  @override
  State<ShopDock> createState() => _ShopDockState();
}

class _ShopDockState extends State<ShopDock>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MenuChrome.tabRail(
              controller: _tabs,
              scrollable: false,
              onTap: (_) => setState(() {}),
              tabs: [
                MenuChrome.bridgedTab('SCROLLS', onSelect: () => _tabs.animateTo(0)),
                MenuChrome.bridgedTab('EXTRA', onSelect: () => _tabs.animateTo(1)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _page(
                    hint: ShopDock.convenienceLine(
                      showEssence: MenuTabs.showCamp(state),
                    ),
                    storeLine: storeLine,
                    items: [
                      ...ShopCatalog.foreverBundle,
                      ...ShopCatalog.foreverSingles,
                    ],
                    compact: true,
                  ),
                  _page(
                    hint:
                        'Ad-free, longer time away, and a small thank-you. No extra combat class.',
                    storeLine: storeLine,
                    items: ShopCatalog.extraPacks,
                    compact: false,
                    showAccountActions: true,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  bool _playLists(ShopCatalogItem item) =>
      !ShopStore.productsReady || ShopStore.storeLists(item.id);

  String _priceLabel(ShopCatalogItem item) {
    if (!_playLists(item)) return 'Not on Play';
    return ShopStore.storePriceLabel(item.id) ?? item.priceLabel;
  }

  Widget _page({
    required String hint,
    required String storeLine,
    required List<ShopCatalogItem> items,
    required bool compact,
    bool showAccountActions = false,
  }) {
    final state = widget.director.state;
    final shown = RemoteTune.pin(items);
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      children: [
        Text(
          hint,
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        Text(
          storeLine,
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ShopRow(
            item: shown[i],
            owned: ShopBilling.isOwned(state, shown[i]),
            priceLabel: _priceLabel(shown[i]),
            listed: _playLists(shown[i]),
            compact: compact && shown[i].permMask != AdBoost.permAll,
            onBuy: _playLists(shown[i]) ? () => _buy(shown[i]) : null,
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
                  onPressed: () => showRedeemCouponDialog(
                    context,
                    widget.director,
                  ),
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
    required this.onBuy,
    this.listed = true,
    this.compact = false,
  });

  final ShopCatalogItem item;
  final bool owned;
  final String priceLabel;
  final VoidCallback? onBuy;
  final bool listed;
  final bool compact;

  static String? assetFor(ShopCatalogItem item) {
    if (item.permMask == AdBoost.permAll) return UiIcon.star;
    if (item.kind == ShopOfferKind.adFree) return UiIcon.heart;
    if (item.kind == ShopOfferKind.longAway) return UiIcon.campfire;
    if (item.kind == ShopOfferKind.supporterQol) return UiIcon.trophy;
    if (item.kind == ShopOfferKind.boostHours) return UiIcon.flask;
    if (item.kind == ShopOfferKind.cinders) return UiIcon.gold;
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
      ShopOfferKind.permScroll => item.permMask == AdBoost.permAll
          ? 'permanent · all seven · cheaper than each'
          : '${_permEffect(item.permMask)} · permanent',
    };
  }

  static String _permEffect(int mask) => switch (mask) {
        AdBoost.permAtk => '+${AdBoost.attackPercent}% ATK',
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
                child: Text(
                  shortTitle(item),
                  style: GameTheme.body(size: 15, color: GameTheme.torchHot),
                ),
              ),
              Text(
                priceLabel,
                style: GameTheme.body(size: 14, color: GameTheme.parchment),
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
                  : listed
                  ? 'BUY'
                  : 'NOT ON PLAY',
              style: GameButtonStyle.grey,
              expanded: false,
              dense: true,
              onPressed: owned || !listed ? null : onBuy,
            ),
          ),
        ],
      ),
    );
  }
}
