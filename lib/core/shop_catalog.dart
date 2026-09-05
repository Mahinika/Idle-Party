/// Real-money SHOP catalog (UI + docs). Buttons say COMING LATER until Billing.
///
/// Keep in sync with [docs/SHOP_MONETIZATION.md]. Grant path: [ShopBilling].
library;

import 'ad_boost.dart';

enum ShopOfferKind {
  /// Timed POWERUPS (same ×2 gold / +ATK as hub ads).
  boostHours,

  /// Permanent: skip rewarded POWERUPS ads (may include welcome boost hours).
  adFree,

  /// Small QoL + thank-you (+ optional boost); no extra combat power.
  supporterQol,
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
  });

  final String id;
  final String name;
  final String description;

  /// Display price (USD Play tier), e.g. `$0.99`.
  final String priceLabel;
  final ShopOfferKind kind;

  /// Hours of POWERUPS granted (boost packs, or bonus on ad-free / supporter).
  final int boostHours;

  /// One-time purchase.
  final bool oneTime;

  /// Extra bag slots when [kind] is [ShopOfferKind.supporterQol].
  final int bagSlots;
}

/// Cheap convenience ladder — no whale packs, no gacha.
/// Prices tuned so larger packs are better $/hour than smaller ones.
abstract final class ShopCatalog {
  static const List<ShopCatalogItem> offered = [
    ShopCatalogItem(
      id: 'starter_boost_6h',
      name: 'Starter boost',
      description:
          '+6 hours POWERUPS (×2 gold · +${AdBoost.attackPercent}% ATK). '
          'Same boost as watching ads — once per save.',
      priceLabel: '\$0.99',
      kind: ShopOfferKind.boostHours,
      boostHours: 6,
      oneTime: true,
    ),
    ShopCatalogItem(
      id: 'boost_12h',
      name: '12-hour boost',
      description:
          '+12 hours POWERUPS (×2 gold · +${AdBoost.attackPercent}% ATK). '
          'Stacks up to 24 hours, same as ads.',
      priceLabel: '\$1.49',
      kind: ShopOfferKind.boostHours,
      boostHours: 12,
    ),
    ShopCatalogItem(
      id: 'ad_free',
      name: 'Ad-free welcome',
      description:
          'Permanent — hide hub POWERUPS ads, plus +6 hours boost once. '
          'More boost time still for sale here.',
      priceLabel: '\$1.99',
      kind: ShopOfferKind.adFree,
      boostHours: 6,
      oneTime: true,
    ),
    ShopCatalogItem(
      id: 'day_boost_24h',
      name: 'Day pack',
      description:
          '+24 hours POWERUPS (fills the stack from empty). '
          'Best boost value per hour — same ×2 gold · +${AdBoost.attackPercent}% ATK as ads.',
      priceLabel: '\$2.99',
      kind: ShopOfferKind.boostHours,
      boostHours: 24,
    ),
    ShopCatalogItem(
      id: 'supporter_qol',
      name: 'Supporter pack',
      description:
          '+4 bag slots, +12 hours POWERUPS, and a thank-you. '
          'No extra combat power beyond the same boost ads give.',
      priceLabel: '\$4.99',
      kind: ShopOfferKind.supporterQol,
      bagSlots: 4,
      boostHours: 12,
      oneTime: true,
    ),
  ];
}
