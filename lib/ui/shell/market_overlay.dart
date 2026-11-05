import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/gear/gear_scorer.dart';
import '../../core/market_listings_service.dart';
import '../../core/market_service.dart';
import '../../models/hero.dart';
import '../../models/loot.dart';
import '../../models/market_listing.dart';
import '../equipment_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import 'shell_common.dart';
import 'shell_layout.dart';

/// GOLD → MARKET — few controls: flask, upgrades/all, tap listing to buy.
class MarketOverlay extends StatefulWidget {
  const MarketOverlay({
    super.key,
    required this.director,
    this.inlineUnderFight = false,
  });
  final GameDirector director;
  final bool inlineUnderFight;

  @override
  State<MarketOverlay> createState() => _MarketOverlayState();
}

class _MarketOverlayState extends State<MarketOverlay> {
  /// Start on upgrades — the usual reason to open MARKET.
  bool _upgradesOnly = true;
  bool _showAllListings = false;

  @override
  void initState() {
    super.initState();
    widget.director.ensureMarketListings();
  }

  @override
  Widget build(BuildContext context) {
    final director = widget.director;
    final state = director.state;
    if (widget.inlineUnderFight && !_showAllListings) {
      return _inlineUnderFightBody(context, state, director);
    }
    final body = _fullBody(context, state, director);
    if (widget.inlineUnderFight) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(child: body),
          ),
        ],
      );
    }
    return body;
  }

  Widget _inlineUnderFightBody(
    BuildContext context,
    GameState state,
    GameDirector director,
  ) {
    final flaskCost = GameLogic.marketFlaskCost(state);
    final listings = _sortedFilteredListings(state);
    final best = listings.isNotEmpty ? listings.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ShellLayout.sheetHorizontal),
          child: GameButton(
            label: state.gold >= flaskCost
                ? 'FLASK · ${formatGold(flaskCost)}'
                : 'FLASK · NEED ${formatGold(flaskCost)}',
            dense: true,
            style: state.gold >= flaskCost
                ? GameButtonStyle.brown
                : GameButtonStyle.grey,
            primary: state.gold >= flaskCost,
            onPressed:
                state.gold >= flaskCost ? director.buyMarketFlask : null,
          ),
        ),
        if (best != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ShellLayout.sheetHorizontal),
            child: _listingCard(state, director, best),
          ),
        ShellLayout.sheetLink(
          label: 'All listings',
          onTap: () => setState(() => _showAllListings = true),
        ),
      ],
    );
  }

  Widget _fullBody(
    BuildContext context,
    GameState state,
    GameDirector director,
  ) {
    final flaskCost = GameLogic.marketFlaskCost(state);
    final bandageCost = GameLogic.marketBandageCost(state);
    final refreshLabel = MarketListingsService.formatRefreshRemaining(state);
    final refreshCost = GameLogic.marketListingsPaidRefreshCost(state);
    final freeReady = MarketListingsService.refreshRemainingMs(state) <= 0;
    final listings = _sortedFilteredListings(state);
    final upgradeCount = state.marketListings
        .where((l) => _upgradeHeroName(state, l) != null)
        .length;

    final canFlask = state.gold >= flaskCost;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShellLayout.sheetHorizontal),
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.inlineUnderFight)
          ShellLayout.sheetLink(
            label: 'Show picks only',
            onTap: () => setState(() => _showAllListings = false),
          ),
        if (freeReady)
          ShellLayout.hint('Listings fresh', maxLines: 1)
        else ...[
          GameButton(
            label: 'REROLL · ${formatGold(refreshCost)}',
            style: GameButtonStyle.grey,
            dense: true,
            onPressed: state.gold >= refreshCost
                ? director.refreshMarketListings
                : null,
          ),
          ShellLayout.gap(4),
          ShellLayout.hint('Free refresh in $refreshLabel', maxLines: 1),
        ],

        ShellLayout.gap(10),
        GameButton(
          label: canFlask
              ? 'BUY FLASK · ${formatGold(flaskCost)}'
              : 'FLASK · NEED ${formatGold(flaskCost)}',
          tip: 'Heals the whole party when HP is low (auto in AFK).',
          dense: true,
          style: canFlask ? GameButtonStyle.brown : GameButtonStyle.grey,
          primary: canFlask,
          onPressed: canFlask ? director.buyMarketFlask : null,
        ),
        ShellLayout.gap(6),
        ShellLayout.hint(
          '${_marketHealCount(state)} · Flask: party heal · Bandage: one hero most hurt',
          maxLines: 2,
        ),
        ShellLayout.gap(6),
        ShellLayout.secondaryActionRow(
          children: [
            GameButton(
              label: 'BUY 3 · ${formatGold(flaskCost * 3)}',
              style: GameButtonStyle.grey,
              dense: true,
              onPressed: state.gold >= flaskCost * 3
                  ? () => director.buyMarketFlasks()
                  : null,
            ),
            GameButton(
              label: 'BANDAGE · ${formatGold(bandageCost)}',
              tip: 'Heals the one hero who needs it most.',
              style: GameButtonStyle.grey,
              dense: true,
              onPressed: state.gold >= bandageCost
                  ? director.buyMarketBandage
                  : null,
            ),
          ],
        ),

        ShellLayout.gap(12),
        Row(
          children: [
            MenuChrome.chip(
              label: upgradeCount > 0
                  ? 'UPGRADES · $upgradeCount'
                  : 'UPGRADES',
              selected: _upgradesOnly,
              onTap: () => setState(() => _upgradesOnly = true),
            ),
            const SizedBox(width: 6),
            MenuChrome.chip(
              label: 'ALL GEAR',
              selected: !_upgradesOnly,
              onTap: () => setState(() => _upgradesOnly = false),
            ),
          ],
        ),
        ShellLayout.gap(8),

        ShellLayout.hint(
          'GAP FILL = empty slot piece (not a budget upgrade). UPGRADE = stronger than worn.',
          maxLines: 2,
        ),
        ShellLayout.gap(6),

        if (listings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  _upgradesOnly
                      ? 'No upgrades in stock.'
                      : 'No listings yet.',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 14,
                    color: GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 8),
                GameButton(
                  label: _upgradesOnly ? 'ALL GEAR' : 'REROLL',
                  style: GameButtonStyle.grey,
                  dense: true,
                  expanded: false,
                  onPressed: _upgradesOnly
                      ? () => setState(() => _upgradesOnly = false)
                      : (state.gold >= refreshCost
                            ? director.refreshMarketListings
                            : null),
                  tip: _upgradesOnly
                      ? 'Show every listing, not only upgrades'
                      : 'Pay gold for a new stock',
                ),
              ],
            ),
          )
        else
          for (final listing in listings)
            _listingCard(state, director, listing),

        ShellLayout.gap(8),
        ShellLayout.hint(
          'Tap a listing to buy · this-run gear only',
          maxLines: 2,
        ),
      ],
    ),
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
    final isGapFill =
        !isUpgrade && MarketListingsService.isGapFillListing(state, listing);
    final wornCompare = _wornCompareLine(state, listing);
    final canBuy = state.gold >= listing.priceGold;
    final showUpgradeBadge = isUpgrade && canBuy;
    final subtitle = isUpgrade
        ? (wornCompare != null
              ? '$upgradeHero · $wornCompare'
              : '$upgradeHero · upgrade')
        : isGapFill
        ? 'GAP FILL · ${_slotLabel(listing.slot)} · iLvl ${item.effectiveItemLevel}'
        : '${_slotLabel(listing.slot)} · iLvl ${item.effectiveItemLevel}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        button: true,
        label: canBuy
            ? 'Buy ${item.name}, ${formatGold(listing.priceGold)}'
            : '${item.name}, need ${formatGold(listing.priceGold)}',
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canBuy
            ? () => director.buyMarketListing(listing.id)
            : () => director.showToast(
                'Need ${formatGold(listing.priceGold)}',
                life: 1.6,
              ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          decoration: MenuChrome.listCard(
            selected: showUpgradeBadge || isGapFill,
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
                    Row(
                      children: [
                        if (showUpgradeBadge) ...[
                          Text(
                            'UPGRADE',
                            style: GameTheme.pixel(
                              size: 6,
                              color: GameTheme.mossLit,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ] else if (isGapFill) ...[
                          Text(
                            'GAP FILL',
                            style: GameTheme.pixel(
                              size: 6,
                              color: GameTheme.torchHot,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
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
                        ),
                      ],
                    ),
                    Text(
                      subtitle,
                      style: GameTheme.body(
                        size: 11,
                        color: showUpgradeBadge
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
                    ? formatGold(listing.priceGold)
                    : 'Need ${formatGold(listing.priceGold)}',
                style: GameTheme.body(
                  size: 13,
                  color: canBuy && showUpgradeBadge
                      ? GameTheme.torchHot
                      : GameTheme.parchmentDim,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  static String _slotLabel(EquipmentSlot slot) {
    return switch (slot) {
      EquipmentSlot.offHand => 'OFF',
      EquipmentSlot.ring || EquipmentSlot.ring2 => 'RING',
      EquipmentSlot.trinket || EquipmentSlot.trinket2 => 'CHARM',
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
    void tally(EquipmentItem? c) {
      if (c == null || c.slot != EquipmentSlot.consumable) return;
      if (MarketService.isBandageConsumable(c)) {
        bandages++;
      } else {
        flasks++;
      }
    }

    for (final h in state.heroes) {
      tally(h.itemIn(EquipmentSlot.consumable));
    }
    for (final g in state.gearStash) {
      tally(g);
    }
    return 'Have ${_marketCount(flasks, 'flask', 'flasks')} · '
        '${_marketCount(bandages, 'bandage', 'bandages')}';
  }

  static String _marketCount(int n, String one, String many) =>
      '$n ${n == 1 ? one : many}';
}
