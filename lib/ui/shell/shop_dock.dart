import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ad_boost.dart';
import '../../core/game_director.dart';
import '../../core/menu_alerts.dart';
import '../../core/shop_billing.dart';
import '../../core/shop_catalog.dart';
import '../../core/shop_store.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// Bottom-tab SHOP: real-money catalog via Play Billing.
class ShopDock extends StatefulWidget {
  const ShopDock({super.key, required this.director});

  final GameDirector director;

  /// SHOP blurb. ESSENCE is named only when that tab exists.
  static String convenienceLine({required bool showEssence}) {
    final essenceBit = showEssence ? ' · essence under ESSENCE' : '';
    return 'Same SCROLLS power as tickets '
        '(never a stronger combat class). Forever scrolls skip the watch; '
        'gold under GOLD$essenceBit.';
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
    _tabs = TabController(length: 3, vsync: this);
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
        final storeLine = !storeOk
            ? 'Buys need a Play Store install of Idle Party (not sideload).'
            : catalogOk
            ? 'Prices come from Google Play.'
            : 'Waiting for Play catalog…';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MenuChrome.tabRail(
              controller: _tabs,
              scrollable: false,
              onTap: (_) => setState(() {}),
              tabs: [
                MenuChrome.bridgedTab('SCROLLS', onSelect: () => _tabs.animateTo(0)),
                MenuChrome.bridgedTab('TIME', onSelect: () => _tabs.animateTo(1)),
                MenuChrome.bridgedTab('EXTRA', onSelect: () => _tabs.animateTo(2)),
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
                        'Hours of Scroll of Battle — same ×${AdBoost.goldMul} gold '
                        'and +${AdBoost.attackPercent}% ATK as tickets. Stacks to 24h.',
                    storeLine: storeLine,
                    items: ShopCatalog.timePacks,
                    compact: false,
                  ),
                  _page(
                    hint: 'Ad-free and a small thank-you pack. No extra combat class.',
                    storeLine: storeLine,
                    items: ShopCatalog.extraPacks,
                    compact: false,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: GameButton(
                label: 'RESTORE PURCHASES',
                style: GameButtonStyle.grey,
                onPressed: widget.director.restoreShopPurchases,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _page({
    required String hint,
    required String storeLine,
    required List<ShopCatalogItem> items,
    required bool compact,
  }) {
    final state = widget.director.state;
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
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ShopRow(
            item: items[i],
            owned: ShopBilling.isOwned(state, items[i]),
            priceLabel:
                ShopStore.storePriceLabel(items[i].id) ?? items[i].priceLabel,
            compact: compact && items[i].permMask != AdBoost.permAll,
            onBuy: () => _buy(items[i]),
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
    this.compact = false,
  });

  final ShopCatalogItem item;
  final bool owned;
  final String priceLabel;
  final VoidCallback onBuy;
  final bool compact;

  static String? assetFor(ShopCatalogItem item) {
    if (item.permMask == AdBoost.permAll) return UiIcon.star;
    if (item.kind == ShopOfferKind.adFree) return UiIcon.heart;
    if (item.kind == ShopOfferKind.supporterQol) return UiIcon.trophy;
    if (item.kind == ShopOfferKind.boostHours) return UiIcon.flask;
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
      return item.name.substring(prefix.length);
    }
    return item.name;
  }

  static String tag(ShopCatalogItem item) {
    return switch (item.kind) {
      ShopOfferKind.boostHours =>
        '+${item.boostHours}h${item.oneTime ? ' · once' : ''}',
      ShopOfferKind.adFree => 'permanent',
      ShopOfferKind.supporterQol =>
        '+${item.bagSlots} bag · +${item.boostHours}h · once',
      ShopOfferKind.permScroll => item.permMask == AdBoost.permAll
          ? 'all seven · cheaper than buying each'
          : _permEffect(item.permMask),
    };
  }

  static String _permEffect(int mask) => switch (mask) {
        AdBoost.permAtk => '+${AdBoost.attackPercent}% ATK always',
        AdBoost.permGold => '×${AdBoost.goldMul} gold always',
        AdBoost.permXp => '+${AdBoost.xpPercent}% XP always',
        AdBoost.permMove => '+${AdBoost.movePercent}% walk always',
        AdBoost.permLoot => '+${AdBoost.lootFindPercent}% find always',
        AdBoost.permSpeed => '+${AdBoost.speedPercent}% haste always',
        AdBoost.permRest => 'Welcome Back ×${AdBoost.awayGoldMul} always',
        _ => 'permanent',
      };

  @override
  Widget build(BuildContext context) {
    final mark = assetFor(item);
    final featured = item.permMask == AdBoost.permAll;
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
              label: owned ? 'OWNED' : 'BUY',
              expanded: false,
              dense: true,
              onPressed: owned ? null : onBuy,
            ),
          ),
        ],
      ),
    );
  }
}
