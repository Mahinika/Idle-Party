import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/gear/gear_scorer.dart';
import '../../core/market_listings_service.dart';
import '../../models/hero.dart';
import '../../models/loot.dart';
import '../../models/market_listing.dart';
import '../equipment_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import 'shell_common.dart';

/// GOLD → MARKET — few controls: flask, upgrades/all, tap listing to buy.
class MarketOverlay extends StatefulWidget {
  const MarketOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  State<MarketOverlay> createState() => _MarketOverlayState();
}

class _MarketOverlayState extends State<MarketOverlay> {
  /// Start on upgrades — the usual reason to open MARKET.
  bool _upgradesOnly = true;

  @override
  void initState() {
    super.initState();
    widget.director.ensureMarketListings();
  }

  @override
  Widget build(BuildContext context) {
    final director = widget.director;
    final state = director.state;
    final flaskCost = GameLogic.marketFlaskCost(state);
    final bandageCost = GameLogic.marketBandageCost(state);
    final refreshLabel = MarketListingsService.formatRefreshRemaining(state);
    final refreshCost = GameLogic.marketListingsPaidRefreshCost(state);
    final freeReady = MarketListingsService.refreshRemainingMs(state) <= 0;
    final listings = _sortedFilteredListings(state);
    final upgradeCount = state.marketListings
        .where((l) => _upgradeHeroName(state, l) != null)
        .length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${formatCount(state.gold)}g',
              style: GameTheme.body(size: 15, color: GameTheme.torchHot),
            ),
            const Spacer(),
            if (freeReady)
              Text(
                'Listings fresh',
                style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
              )
            else
              MenuChrome.textLink(
                label: 'Reroll · ${formatCount(refreshCost)}g',
                onPressed: state.gold >= refreshCost
                    ? director.refreshMarketListings
                    : null,
              ),
          ],
        ),
        if (!freeReady)
          Text(
            'Free refresh in $refreshLabel',
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),

        const SizedBox(height: 10),
        GameButton(
          label: state.gold >= flaskCost
              ? 'Buy flask · ${flaskCost}g'
              : 'Flask · need ${flaskCost}g',
          dense: true,
          onPressed:
              state.gold >= flaskCost ? director.buyMarketFlask : null,
        ),
        const SizedBox(height: 2),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          children: [
            Text(
              _marketHealCount(state),
              style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
            ),
            MenuChrome.textLink(
              label: '×3 · ${flaskCost * 3}g',
              onPressed: state.gold >= flaskCost * 3
                  ? () => director.buyMarketFlasks()
                  : null,
            ),
            MenuChrome.textLink(
              label: 'Bandage · ${bandageCost}g',
              onPressed: state.gold >= bandageCost
                  ? director.buyMarketBandage
                  : null,
            ),
          ],
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            MenuChrome.chip(
              label: upgradeCount > 0 ? 'Upgrades · $upgradeCount' : 'Upgrades',
              selected: _upgradesOnly,
              onTap: () => setState(() => _upgradesOnly = true),
            ),
            const SizedBox(width: 6),
            MenuChrome.chip(
              label: 'All gear',
              selected: !_upgradesOnly,
              onTap: () => setState(() => _upgradesOnly = false),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (listings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  _upgradesOnly
                      ? 'No upgrades in stock.'
                      : 'No listings right now.',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 14,
                    color: GameTheme.parchmentDim,
                  ),
                ),
                if (_upgradesOnly) ...[
                  const SizedBox(height: 6),
                  MenuChrome.textLink(
                    label: 'Show all gear',
                    onPressed: () => setState(() => _upgradesOnly = false),
                  ),
                ],
                if (!freeReady && state.gold >= refreshCost) ...[
                  const SizedBox(height: 4),
                  MenuChrome.textLink(
                    label: 'Reroll listings · ${formatCount(refreshCost)}g',
                    onPressed: director.refreshMarketListings,
                  ),
                ],
              ],
            ),
          )
        else
          for (final listing in listings)
            _listingCard(state, director, listing),

        const SizedBox(height: 8),
        Text(
          'Tap a listing to buy · this-run gear only',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
      ],
    );
  }

  List<MarketListing> _sortedFilteredListings(GameState state) {
    final list = [
      for (final listing in state.marketListings)
        if (!_upgradesOnly || _upgradeHeroName(state, listing) != null) listing,
    ];
    list.sort((a, b) {
      final aUp = _upgradeHeroName(state, a) != null;
      final bUp = _upgradeHeroName(state, b) != null;
      if (aUp != bUp) return aUp ? -1 : 1;
      final aAfford = state.gold >= a.priceGold;
      final bAfford = state.gold >= b.priceGold;
      if (aUp && aAfford != bAfford) return aAfford ? -1 : 1;
      return a.priceGold.compareTo(b.priceGold);
    });
    return list;
  }

  Widget _listingCard(
    GameState state,
    GameDirector director,
    MarketListing listing,
  ) {
    final item = listing.item;
    final upgradeHero = _upgradeHeroName(state, listing);
    final isUpgrade = upgradeHero != null;
    final wornCompare = _wornCompareLine(state, listing);
    final canBuy = state.gold >= listing.priceGold;
    final subtitle = isUpgrade
        ? (wornCompare != null
              ? '$upgradeHero · $wornCompare'
              : '$upgradeHero · upgrade')
        : '${_slotLabel(listing.slot)} · iLvl ${item.effectiveItemLevel}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canBuy
            ? () => director.buyMarketListing(listing.id)
            : () => director.showToast(
                'Need ${formatCount(listing.priceGold)}g',
                life: 1.6,
              ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          decoration: MenuChrome.listCard(
            selected: isUpgrade && canBuy,
            borderColor: rarityBorderColor(item.rarity).withValues(alpha: 0.85),
          ),
          child: Row(
            children: [
              EquipmentIcon(item: item, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GameTheme.body(
                        size: 13,
                        color: canBuy
                            ? GameTheme.parchment
                            : GameTheme.parchmentDim,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: GameTheme.body(
                        size: 11,
                        color: isUpgrade
                            ? GameTheme.mossLit
                            : GameTheme.parchmentDim,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                canBuy
                    ? '${formatCount(listing.priceGold)}g'
                    : 'Need ${formatCount(listing.priceGold)}g',
                style: GameTheme.body(
                  size: 13,
                  color: canBuy && isUpgrade
                      ? GameTheme.torchHot
                      : GameTheme.parchmentDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _slotLabel(EquipmentSlot slot) {
    return switch (slot) {
      EquipmentSlot.offHand => 'OFF',
      EquipmentSlot.ring || EquipmentSlot.ring2 => 'RING',
      EquipmentSlot.trinket || EquipmentSlot.trinket2 => 'TRINKET',
      _ => slot.name.toUpperCase(),
    };
  }

  String? _upgradeHeroName(GameState state, MarketListing listing) {
    if (listing.targetHeroIndex >= 0 &&
        listing.targetHeroIndex < state.heroes.length) {
      final hero = state.heroes[listing.targetHeroIndex];
      final cmp = GearScorer.compareForHeroSlot(
        hero,
        listing.item,
        listing.slot,
        pairingStash: state.gearStash,
      );
      if (cmp.isUpgrade) return hero.name;
    }
    for (final hero in state.heroes) {
      final cmp = GearScorer.compareForHeroSlot(
        hero,
        listing.item,
        listing.slot,
        pairingStash: state.gearStash,
      );
      if (cmp.isUpgrade) return hero.name;
    }
    return null;
  }

  String? _wornCompareLine(GameState state, MarketListing listing) {
    PartyHero? hero;
    if (listing.targetHeroIndex >= 0 &&
        listing.targetHeroIndex < state.heroes.length) {
      hero = state.heroes[listing.targetHeroIndex];
    } else {
      for (final h in state.heroes) {
        final cmp = GearScorer.compareForHeroSlot(
          h,
          listing.item,
          listing.slot,
          pairingStash: state.gearStash,
        );
        if (cmp.isUpgrade) {
          hero = h;
          break;
        }
      }
    }
    if (hero == null) return null;
    final cmp = GearScorer.compareForHeroSlot(
      hero,
      listing.item,
      listing.slot,
      pairingStash: state.gearStash,
    );
    if (!cmp.isUpgrade) return null;
    final worn = hero.itemIn(listing.slot);
    final wornIlvl = worn?.effectiveItemLevel;
    if (cmp.powerDelta > 0 && wornIlvl != null) {
      return '+${cmp.powerDelta} · i$wornIlvl→${listing.item.effectiveItemLevel}';
    }
    if (wornIlvl != null) {
      return 'i$wornIlvl→${listing.item.effectiveItemLevel}';
    }
    return 'empty→i${listing.item.effectiveItemLevel}';
  }

  static String _marketHealCount(GameState state) {
    var flasks = 0;
    var bandages = 0;
    for (final h in state.heroes) {
      final c = h.itemIn(EquipmentSlot.consumable);
      if (c == null) continue;
      if (c.iconId == 'flask') {
        flasks++;
      } else {
        bandages++;
      }
    }
    for (final g in state.gearStash) {
      if (g.slot != EquipmentSlot.consumable) continue;
      if (g.iconId == 'flask') {
        flasks++;
      } else {
        bandages++;
      }
    }
    return 'Have $flasks flask · $bandages bandage';
  }
}
