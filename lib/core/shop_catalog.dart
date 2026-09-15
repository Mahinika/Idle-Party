/// Real-money SHOP catalog (UI + Play Billing product ids).
///
/// Keep in sync with [docs/SHOP_MONETIZATION.md]. Grant path: [ShopBilling].
library;

import 'ad_boost.dart';

enum ShopOfferKind {
  /// Timed Full Boost (same ×2 gold / +ATK as POWERUPS ticket spend).
  boostHours,

  /// Permanent: skip rewarded POWERUPS ads (may include welcome tickets / boost).
  adFree,

  /// Small QoL + thank-you (+ optional boost); no extra combat power.
  supporterQol,

  /// Forever SCROLLS — same % as tickets, not a stronger combat class.
  permScroll,
}

class ShopCatalogItem {
  const ShopCatalogItem({
    required this.id,
    required this.name,
    required this.description,
    required this.priceLabel,
    required this.kind,
    this.boostHours = 0,
    this.oneTime = false,
    this.bagSlots = 0,
    this.permMask = 0,
  });

  /// Play Console product id — must match Console exactly.
  final String id;
  final String name;
  final String description;

  /// Fallback price label when the store has not returned localized price yet.
  final String priceLabel;
  final ShopOfferKind kind;

  /// Hours of Full Boost granted (both ATK + gold timers).
  final int boostHours;

  /// One-time purchase (non-consumable in Play Billing).
  final bool oneTime;

  /// Extra bag slots when [kind] is [ShopOfferKind.supporterQol].
  final int bagSlots;

  /// Bits on [MetaDepthState.shopPermScrolls] granted by this SKU.
  final int permMask;

  /// Repeatable boost packs — `buyConsumable`. Everything else is non-consumable.
  bool get isConsumable => kind == ShopOfferKind.boostHours && !oneTime;
}

/// Cheap convenience ladder — no whale packs, no gacha.
/// Prices tuned so larger packs are better $/hour than smaller ones.
abstract final class ShopCatalog {
  static const List<ShopCatalogItem> offered = [
    ShopCatalogItem(
      id: 'perm_scroll_atk',
      name: 'Forever Scroll of Damage',
      description:
          'Always on: +${AdBoost.attackPercent}% ATK. Same as the SCROLLS ticket, forever.',
      priceLabel: '\$0.99',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permAtk,
    ),
    ShopCatalogItem(
      id: 'perm_scroll_gold',
      name: 'Forever Scroll of Gold',
      description:
          'Always on: ×${AdBoost.goldMul} gold. Same as the SCROLLS ticket, forever.',
      priceLabel: '\$0.99',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permGold,
    ),
    ShopCatalogItem(
      id: 'perm_scroll_xp',
      name: 'Forever Scroll of XP',
      description:
          'Always on: +${AdBoost.xpPercent}% party XP. Same as the SCROLLS ticket, forever.',
      priceLabel: '\$0.99',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permXp,
    ),
    ShopCatalogItem(
      id: 'perm_scroll_move',
      name: 'Forever Scroll of Speed',
      description:
          'Always on: +${AdBoost.movePercent}% walk. Same as the SCROLLS ticket, forever.',
      priceLabel: '\$0.99',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permMove,
    ),
    ShopCatalogItem(
      id: 'perm_scroll_loot',
      name: 'Forever Scroll of Loot',
      description:
          'Always on: +${AdBoost.lootFindPercent}% item find. Same as the SCROLLS ticket, forever.',
      priceLabel: '\$0.99',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permLoot,
    ),
    ShopCatalogItem(
      id: 'perm_scroll_haste',
      name: 'Forever Scroll of Haste',
      description:
          'Always on: +${AdBoost.speedPercent}% dungeon speed. Same as the SCROLLS ticket, forever.',
      priceLabel: '\$0.99',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permSpeed,
    ),
    ShopCatalogItem(
      id: 'perm_scroll_rest',
      name: 'Forever Scroll of Rest',
      description:
          'Always on: Welcome Back gold ×${AdBoost.awayGoldMul}. Same as the SCROLLS ticket, forever.',
      priceLabel: '\$0.99',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permRest,
    ),
    ShopCatalogItem(
      id: 'perm_scrolls_all',
      name: 'Forever Scrolls bundle',
      description:
          'All seven forever scrolls (Damage, Gold, XP, Speed, Loot, Haste, Rest). '
          'Same ticket power, cheaper than buying each.',
      priceLabel: '\$4.99',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permAll,
    ),
    ShopCatalogItem(
      id: 'starter_boost_6h',
      name: 'Starter boost',
      description:
          '+6 hours Scroll of Battle (×${AdBoost.goldMul} gold · +${AdBoost.attackPercent}% ATK). '
          'Same as SCROLLS tickets — once per save.',
      priceLabel: '\$0.99',
      kind: ShopOfferKind.boostHours,
      boostHours: 6,
      oneTime: true,
    ),
    ShopCatalogItem(
      id: 'boost_12h',
      name: '12-hour boost',
      description:
          '+12 hours Scroll of Battle (×${AdBoost.goldMul} gold · +${AdBoost.attackPercent}% ATK). '
          'Stacks up to 24 hours, same as tickets.',
      priceLabel: '\$1.99',
      kind: ShopOfferKind.boostHours,
      boostHours: 12,
    ),
    ShopCatalogItem(
      id: 'ad_free',
      name: 'Ad-free welcome',
      description:
          'Permanent — hide SCROLLS ads, +2 Ad Tickets once, and a free '
          'ticket claim once per UTC day. More boost time still for sale here.',
      priceLabel: '\$2.99',
      kind: ShopOfferKind.adFree,
      boostHours: 0,
      oneTime: true,
    ),
    ShopCatalogItem(
      id: 'day_boost_24h',
      name: 'Day pack',
      description:
          '+24 hours Scroll of Battle (fills the stack from empty). '
          'Best boost value per hour — same ×${AdBoost.goldMul} gold · +${AdBoost.attackPercent}% ATK as tickets.',
      priceLabel: '\$2.99',
      kind: ShopOfferKind.boostHours,
      boostHours: 24,
    ),
    ShopCatalogItem(
      id: 'supporter_qol',
      name: 'Supporter pack',
      description:
          '+4 bag slots, +12 hours Scroll of Battle, and a thank-you. '
          'No extra combat power beyond the same boost tickets give.',
      priceLabel: '\$4.99',
      kind: ShopOfferKind.supporterQol,
      bagSlots: 4,
      boostHours: 12,
      oneTime: true,
    ),
  ];

  static final Map<String, ShopCatalogItem> byId = {
    for (final item in offered) item.id: item,
  };

  static Set<String> get productIds => byId.keys.toSet();

  static List<ShopCatalogItem> get foreverBundle => offered
      .where((e) => e.kind == ShopOfferKind.permScroll && e.permMask == AdBoost.permAll)
      .toList();

  static List<ShopCatalogItem> get foreverSingles => offered
      .where((e) => e.kind == ShopOfferKind.permScroll && e.permMask != AdBoost.permAll)
      .toList();

  static List<ShopCatalogItem> get timePacks =>
      offered.where((e) => e.kind == ShopOfferKind.boostHours).toList();

  static List<ShopCatalogItem> get extraPacks => offered
      .where(
        (e) =>
            e.kind == ShopOfferKind.adFree ||
            e.kind == ShopOfferKind.supporterQol,
      )
      .toList();
}
