import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ad_boost.dart';
import '../../core/game_director.dart';
import '../../core/menu_alerts.dart';
import '../../core/shop_billing.dart';
import '../../core/shop_catalog.dart';
import '../../core/shop_store.dart';
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
    return 'Same Scroll of Battle as SCROLLS tickets '
        '(×${AdBoost.goldMul} gold · +${AdBoost.attackPercent}% ATK). '
        'Watch ads for Ad Tickets on the hub · gold under GOLD$essenceBit.';
  }

  @override
  State<ShopDock> createState() => _ShopDockState();
}

class _ShopDockState extends State<ShopDock> {
  @override
  void initState() {
    super.initState();
    // Newly activated Console SKUs can take hours; refresh every open.
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    await ShopStore.refreshProducts();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.director,
      builder: (context, _) {
        final state = widget.director.state;
        final storeOk = ShopBilling.billingReady && ShopStore.storeAvailable;
        final catalogOk = ShopStore.productsReady;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                children: [
                  Text(
                    'Real money · cheap convenience',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(size: 15, color: GameTheme.torchHot),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${ShopDock.convenienceLine(showEssence: MenuTabs.showCamp(state))}\n'
                    '${!storeOk ? 'Buys need a Play Store install of Idle Party (not sideload).' : catalogOk ? 'Prices come from Google Play.' : 'Waiting for Play catalog (can take a few hours after SKUs go live)…'}',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < ShopCatalog.offered.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _ShopRow(
                      item: ShopCatalog.offered[i],
                      owned: ShopBilling.isOwned(state, ShopCatalog.offered[i]),
                      priceLabel:
                          ShopStore.storePriceLabel(ShopCatalog.offered[i].id) ??
                          ShopCatalog.offered[i].priceLabel,
                      onBuy: () => widget.director
                          .buyShopItem(ShopCatalog.offered[i].id)
                          .then((_) {
                        if (mounted) setState(() {});
                      }),
                    ),
                  ],
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
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.item,
    required this.owned,
    required this.priceLabel,
    required this.onBuy,
  });

  final ShopCatalogItem item;
  final bool owned;
  final String priceLabel;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final tag = switch (item.kind) {
      ShopOfferKind.boostHours =>
        '+${item.boostHours}h${item.oneTime ? ' · once' : ''}',
      ShopOfferKind.adFree => item.boostHours > 0
          ? 'permanent · +${item.boostHours}h once'
          : 'permanent',
      ShopOfferKind.supporterQol =>
        '+${item.bagSlots} bag'
        '${item.boostHours > 0 ? ' · +${item.boostHours}h' : ''} · once',
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: MenuChrome.listCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
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
            tag,
            style: GameTheme.body(size: 11, color: GameTheme.mossLit),
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
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
