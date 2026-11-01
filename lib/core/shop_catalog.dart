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

  /// Repeatable Cinder pack. Same relics a player can earn.
  cinders,

  /// Paid month-pass premium track (bonus on season claim).
  seasonPass,

  /// One-time longer away: 16h cave catch-up and a 24h hub gold chest.
  longAway,
}

class ShopCatalogItem {
  const ShopCatalogItem({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    this.boostHours = 0,
    this.oneTime = false,
    this.bagSlots = 0,
    this.permMask = 0,
    this.cinderGrant = 0,
  });

  /// Play Console product id — must match Console exactly.
  final String id;
  final String name;
  final String description;
  final ShopOfferKind kind;

  /// Hours of Full Boost granted (both ATK + gold timers).
  final int boostHours;

  /// One-time purchase (non-consumable in Play Billing).
  final bool oneTime;

  /// Extra bag slots when [kind] is [ShopOfferKind.supporterQol].
  final int bagSlots;

  /// Bits on [MetaDepthState.shopPermScrolls] granted by this SKU.
  final int permMask;

  /// Cinders granted when [kind] is [ShopOfferKind.cinders].
  final int cinderGrant;

  /// Repeatable boost packs — `buyConsumable`. Everything else is non-consumable.
  bool get isConsumable =>
      (kind == ShopOfferKind.boostHours && !oneTime) ||
      kind == ShopOfferKind.cinders;
}

/// Today's offers are a cheap convenience ladder. Larger packs are a
/// better $/hour than smaller ones. A stronger paid offer is allowed
/// when the owner names it (see docs/SHOP_MONETIZATION.md).
abstract final class ShopCatalog {
  /// Play Console has these activated, and this build offers them for sale.
  /// Hour packs stay in [offered] for restore only. Forever scrolls and the
  /// cinder pouch stay in [offered] for a code or a restore, and join
  /// [shelf] only after Play returns that product.
  static const Set<String> playChargeableIds = {
    'ad_free',
    'long_away',
    'supporter_qol',
  };

  static const List<ShopCatalogItem> offered = [
    ShopCatalogItem(
      id: 'perm_scroll_atk',
      name: 'Forever Scroll of Damage',
      description:
          'Always on: +${AdBoost.attackPercent}% ATK. Same as the SCROLLS ticket, forever.',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permAtk,
    ),
    ShopCatalogItem(
      id: 'perm_scroll_gold',
      name: 'Forever Scroll of Gold',
      description:
          'Always on: ×${AdBoost.goldMul} gold. Same as the SCROLLS ticket, forever.',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permGold,
    ),
    ShopCatalogItem(
      id: 'perm_scroll_xp',
      name: 'Forever Scroll of XP',
      description:
          'Always on: +${AdBoost.xpPercent}% party XP. Same as the SCROLLS ticket, forever.',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permXp,
    ),
    ShopCatalogItem(
      id: 'perm_scroll_move',
      name: 'Forever Scroll of Speed',
      description:
          'Always on: +${AdBoost.movePercent}% walk. Same as the SCROLLS ticket, forever.',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permMove,
    ),
    ShopCatalogItem(
      id: 'perm_scroll_loot',
      name: 'Forever Scroll of Loot',
      description:
          'Always on: +${AdBoost.lootFindPercent}% item find. Same as the SCROLLS ticket, forever.',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permLoot,
    ),
    ShopCatalogItem(
      id: 'perm_scroll_haste',
      name: 'Forever Scroll of Haste',
      description:
          'Always on: +${AdBoost.speedPercent}% dungeon speed. Same as the SCROLLS ticket, forever.',
      kind: ShopOfferKind.permScroll,
      oneTime: true,
      permMask: AdBoost.permSpeed,
    ),
    ShopCatalogItem(
      id: 'perm_scroll_rest',
      name: 'Forever Scroll of Rest',
      description:
          'Always on: every Welcome Back uses gold ×${AdBoost.awayGoldMul}. Not a one-shot ticket.',
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
      kind: ShopOfferKind.boostHours,
      boostHours: 12,
    ),
    ShopCatalogItem(
      id: 'ad_free',
      name: 'Ad-free welcome',
      description:
          'Permanent — hide SCROLLS ads and remove WATCH AD earn. '
          '+2 Ad Tickets once, a free ticket claim once per UTC day, '
          'and WISP bonus gold without watching.',
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
      kind: ShopOfferKind.boostHours,
      boostHours: 24,
    ),
    ShopCatalogItem(
      id: 'long_away',
      name: 'Long Away',
      description:
          'Story caves catch up for 16 hours instead of 8 and fight twice as far. '
          'Hub gold fills for 24 hours instead of 12. Gauntlet and rifts stay short. Once.',
      kind: ShopOfferKind.longAway,
      oneTime: true,
    ),
    ShopCatalogItem(
      id: 'cinder_pouch',
      name: 'Cinder pouch',
      description:
          '8 Cinders. First buy on Play pays ×2 (16 total). Salvage or Ember trade in-game.',
      kind: ShopOfferKind.cinders,
      cinderGrant: 8,
    ),
    ShopCatalogItem(
      id: 'season_pass_premium',
      name: 'Season pass premium',
      description:
          'Extra essence and +5 Cinders on each month-pass claim. Free track unchanged.',
      kind: ShopOfferKind.seasonPass,
      oneTime: true,
    ),
    ShopCatalogItem(
      id: 'supporter_qol',
      name: 'Supporter pack',
      description:
          '+4 bag slots, +12 hours Scroll of Battle, and a thank-you. '
          'No extra combat power beyond the same boost tickets give.',
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
      .where(
        (e) =>
            e.kind == ShopOfferKind.permScroll && e.permMask == AdBoost.permAll,
      )
      .toList();

  static List<ShopCatalogItem> get foreverSingles => offered
      .where(
        (e) =>
            e.kind == ShopOfferKind.permScroll && e.permMask != AdBoost.permAll,
      )
      .toList();

  /// Timed hour packs — kept for restore / old Play SKUs, not listed in SHOP.
  static List<ShopCatalogItem> get timePacks =>
      offered.where((e) => e.kind == ShopOfferKind.boostHours).toList();

  /// Always on the SHOP shelf. Play can charge these.
  static List<ShopCatalogItem> get extraPacks =>
      offered.where((e) => playChargeableIds.contains(e.id)).toList();

  /// Rows the player can see.
  ///
  /// [playListed] is the set Play returned. Null means Play has not answered
  /// yet (sideload, or the catalog is still loading): the three chargeable
  /// packs stay up, and anything Play has not activated stays hidden.
  /// Hour packs are never shown.
  static List<ShopCatalogItem> shelf({Set<String>? playListed}) {
    final listed = playListed ?? const <String>{};
    return [
      for (final item in offered)
        if (_onShelf(item, listed)) item,
    ];
  }

  static bool _onShelf(ShopCatalogItem item, Set<String> listed) {
    if (item.kind == ShopOfferKind.boostHours) return false;
    if (playChargeableIds.contains(item.id)) return true;
    if (item.kind == ShopOfferKind.permScroll ||
        item.kind == ShopOfferKind.cinders ||
        item.kind == ShopOfferKind.seasonPass) {
      return listed.contains(item.id);
    }
    return false;
  }

  /// Hour packs never open a buy sheet. An unactivated scroll or pouch
  /// opens one only after Play has returned that product.
  static bool mayBuy(String id, {required bool playLists}) {
    if (playChargeableIds.contains(id)) return true;
    final item = byId[id];
    if (item == null || item.kind == ShopOfferKind.boostHours) return false;
    if (item.kind == ShopOfferKind.permScroll ||
        item.kind == ShopOfferKind.cinders ||
        item.kind == ShopOfferKind.seasonPass) {
      return playLists;
    }
    return false;
  }
}
