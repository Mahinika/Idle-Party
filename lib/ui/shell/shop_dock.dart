import 'package:flutter/material.dart';

import '../../core/ad_boost.dart';
import '../../core/shop_catalog.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// Bottom-tab SHOP: real-money catalog (Buy soon — billing not wired).
class ShopDock extends StatelessWidget {
  const ShopDock({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        Text(
          'Real money · cheap convenience',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 15, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 6),
        Text(
          'Same POWERUPS as hub ads (×2 gold · +${AdBoost.attackPercent}% ATK). '
          'Gold buys live under GOLD · essence under ESSENCE.\n'
          'Purchases open soon — prices shown for feedback.',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < ShopCatalog.offered.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ShopRow(item: ShopCatalog.offered[i]),
        ],
      ],
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({required this.item});

  final ShopCatalogItem item;

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
                item.priceLabel,
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
              label: 'BUY SOON',
              expanded: false,
              dense: true,
              onPressed: null,
            ),
          ),
        ],
      ),
    );
  }
}
