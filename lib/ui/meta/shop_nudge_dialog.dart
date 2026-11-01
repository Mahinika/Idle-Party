import 'package:flutter/material.dart';

import '../../core/menu_router.dart';
import '../../core/shop_catalog.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// Offers the existing ad-free and Forever Rest rows. Does not add a SKU.
Future<void> showShopNudgeDialog(
  BuildContext context,
  MenuRouter router,
  List<String> offerIds,
) {
  final items = <ShopCatalogItem>[
    for (final id in offerIds)
      if (ShopCatalog.byId[id] != null) ShopCatalog.byId[id]!,
  ];
  if (items.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    barrierColor: MenuChrome.scrim,
    builder: (ctx) => MenuChrome.dialog(
      title: 'SKIP THE ADS',
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.42,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items) ...[
                Text(item.name, style: GameTheme.body(size: 15)),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: GameTheme.body(
                    size: 13,
                    color: GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
      actions: [
        MenuChrome.dialogCancel(
          label: 'NOT NOW',
          onPressed: () => Navigator.pop(ctx),
        ),
        GameButton(
          label: 'OPEN SHOP',
          expanded: false,
          onPressed: () {
            Navigator.pop(ctx);
            router.open(MenuRoute.shop);
          },
        ),
      ],
    ),
  );
}
