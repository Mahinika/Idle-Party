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
import 'home/nav_clearance.dart';
import 'power_upgrade_row.dart';
import 'shell_common.dart';
import 'shell_layout.dart';

/// GOLD → MARKET — few controls: flask, upgrades/all, tap listing to buy.
class MarketOverlay extends StatefulWidget {
  const MarketOverlay({
    super.key,
    required this.director,
    this.inlineUnderFight = false,
    this.expandedTrackList = false,
  });
  final GameDirector director;
  final bool inlineUnderFight;
  final bool expandedTrackList;

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

  bool get _boundedList => widget.inlineUnderFight || widget.expandedTrackList;

  @override
  Widget build(BuildContext context) {
    final director = widget.director;
    final state = director.state;
    if (_boundedList) {
      return _boundedMarketBody(context, state, director);
    }
    return SingleChildScrollView(
      child: _fullBody(context, state, director, compactControls: true),
    );
  }

  Widget _boundedMarketBody(
    BuildContext context,
    GameState state,
    GameDirector director,
  ) {
    final listings = _sortedFilteredListings(state);
    // Controls scroll with the listings: at 1.45 the wrapped chip rows can
    // not push the fixed panel past its bottom.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              ShellLayout.sheetHorizontal,
              0,
              ShellLayout.sheetHorizontal,
              8 + NavClearance.of(context),
            ),
            children: [
              _marketTopControls(state, director, compact: true),
              ShellLayout.gap(4),
              _filterChips(state, director),
              ShellLayout.gap(4),
              ...listings.isEmpty
                  ? [
                      ShellLayout.hint(
                        _upgradesOnly
                            ? 'No upgrades in stock.'
                            : 'No listings.',
                        maxLines: 2,
                      ),
                      if (_upgradesOnly) ...[
                        const SizedBox(height: 8),
                        GameButton(
                          label: 'ALL GEAR',
                          style: GameButtonStyle.grey,
                          dense: true,
                          expanded: false,
                          onPressed: () =>
                              setState(() => _upgradesOnly = false),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        GameButton(
                          label: 'REROLL',
                          style: GameButtonStyle.grey,
                          dense: true,
                          expanded: false,
                          onPressed:
                              state.gold >=
                                  GameLogic.marketListingsPaidRefreshCost(state)
                              ? director.refreshMarketListings
                              : null,
                        ),
                      ],
                    ]
                  : [
                      for (final listing in listings)
                        _listingCard(state, director, listing),
                    ],
            ],
          ),
        ),
      ],
    );
  }

  /// UPGRADES / ALL GEAR plus the reroll chip. A [Wrap], never a sideways
  /// scroll: at 1.45 the reroll price takes its own line instead of being
  /// cut at the edge.
  Widget _filterChips(GameState state, GameDirector director) {
    final upgradeCount = state.marketListings
        .where((l) => _upgradeHeroName(state, l) != null)
        .length;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        MenuChrome.chip(
          label: upgradeCount > 0 ? 'UPGRADES · $upgradeCount' : 'UPGRADES',
          selected: _upgradesOnly,
          onTap: () => setState(() => _upgradesOnly = true),
        ),
        MenuChrome.chip(
          label: 'ALL GEAR',
          selected: !_upgradesOnly,
          onTap: () => setState(() => _upgradesOnly = false),
        ),
        _rerollChip(state, director),
      ],
    );
  }

  /// Paid reroll while listings are on cooldown, "Fresh stock" otherwise.
  Widget _rerollChip(GameState state, GameDirector director) {
    final refreshCost = GameLogic.marketListingsPaidRefreshCost(state);
    final freeReady = MarketListingsService.refreshRemainingMs(state) <= 0;
    if (freeReady) {
      return _marketFlaskChip(label: 'Fresh stock', tone: GameTheme.mossLit);
    }
    return _marketFlaskChip(
      label: 'Reroll ${formatGold(refreshCost)}',
      onTap: state.gold >= refreshCost ? director.refreshMarketListings : null,
    );
  }

  Widget _marketTopControls(
    GameState state,
    GameDirector director, {
    required bool compact,
  }) {
    final flaskCost = GameLogic.marketFlaskCost(state);
    final bandageCost = GameLogic.marketBandageCost(state);
    final refreshCost = GameLogic.marketListingsPaidRefreshCost(state);
    final freeReady = MarketListingsService.refreshRemainingMs(state) <= 0;
    final canFlask = state.gold >= flaskCost;
    final canBandage = state.gold >= bandageCost;
    final canReroll = state.gold >= refreshCost;

    if (compact) {
      final wrap = Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _marketFlaskChip(
            label: canFlask
                ? 'Flask ${formatGold(flaskCost)}'
                : 'Flask need ${formatGold(flaskCost)}',
            selected: canFlask,
            onTap: canFlask ? director.buyMarketFlask : null,
          ),
          _marketFlaskChip(
            label: 'Buy 3 flasks · ${formatGold(flaskCost * 3)}',
            onTap: state.gold >= flaskCost * 3
                ? () => director.buyMarketFlasks()
                : null,
          ),
          _marketFlaskChip(
            label: 'Bandage ${formatGold(bandageCost)}',
            onTap: canBandage ? director.buyMarketBandage : null,
          ),
        ],
      );
      return wrap;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (freeReady)
          ShellLayout.hint('Listings fresh', maxLines: 1)
        else ...[
          GameButton(
            label: 'REROLL · ${formatGold(refreshCost)}',
            style: GameButtonStyle.grey,
            dense: true,
            onPressed: canReroll ? director.refreshMarketListings : null,
          ),
          ShellLayout.gap(4),
          ShellLayout.hint(
            'Free refresh in ${MarketListingsService.formatRefreshRemaining(state)}',
            maxLines: 1,
          ),
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
              style: GameButtonStyle.grey,
              dense: true,
              onPressed: canBandage ? director.buyMarketBandage : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _fullBody(
    BuildContext context,
    GameState state,
    GameDirector director, {
    required bool compactControls,
  }) {
    final listings = _sortedFilteredListings(state);
    final upgradeCount = state.marketListings
        .where((l) => _upgradeHeroName(state, l) != null)
        .length;
    final refreshCost = GameLogic.marketListingsPaidRefreshCost(state);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShellLayout.sheetHorizontal,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _marketTopControls(state, director, compact: compactControls),
          if (!compactControls) ...[
            ShellLayout.gap(6),
            ShellLayout.hint(
              '${_marketHealCount(state)} · Flask: party heal · Bandage: one hero most hurt',
              maxLines: 2,
            ),
          ],
          ShellLayout.gap(8),
          if (compactControls)
            _filterChips(state, director)
          else
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
            'Fills an empty slot. UPGRADE is stronger than what is worn.',
            maxLines: 2,
          ),
          ShellLayout.gap(6),
          if (listings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text(
                    _upgradesOnly ? 'No upgrades in stock.' : 'No listings.',
                    textAlign: TextAlign.center,
                    style: GameTheme.readable(color: GameTheme.parchmentDim),
                  ),
                  if (_upgradesOnly) ...[
                    const SizedBox(height: 8),
                    GameButton(
                      label: 'ALL GEAR',
                      style: GameButtonStyle.grey,
                      dense: true,
                      expanded: false,
                      onPressed: () => setState(() => _upgradesOnly = false),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    GameButton(
                      label: 'REROLL',
                      style: GameButtonStyle.grey,
                      dense: true,
                      expanded: false,
                      onPressed: state.gold >= refreshCost
                          ? director.refreshMarketListings
                          : null,
                    ),
                  ],
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
    final canBuy = state.gold >= listing.priceGold;
    final showUpgradeBadge = isUpgrade && canBuy;
    final price = formatGold(listing.priceGold);
    final ilvl = item.effectiveItemLevel;
    final compare = isUpgrade ? _wornCompare(state, listing) : null;
    // "now › next": what is worn today, then the listing in green.
    final (String subtitle, String? next) = isUpgrade
        ? (compare != null
              ? ('$upgradeHero · ${compare.now}', compare.next)
              : ('$upgradeHero · upgrade', null))
        : isGapFill
        ? ('Fills empty slot · ${_slotLabel(listing.slot)}', 'i$ilvl')
        : ('${_slotLabel(listing.slot)} · iLvl $ilvl', null);
    final rim = rarityBorderColor(item.rarity);
    void buy() => director.buyMarketListing(listing.id);

    return Semantics(
      button: true,
      label: canBuy ? 'Buy ${item.name}, $price' : '${item.name}, need $price',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canBuy
            ? buy
            : () => director.showToast('Need $price', life: 1.6),
        child: PowerUpgradeRow(
          accent: rim.withValues(alpha: 0.85),
          selected: showUpgradeBadge || isGapFill,
          dense: true,
          leading: UpgradeIconTile(
            accent: rim,
            child: EquipmentIcon(item: item, size: 30),
          ),
          title: item.name,
          tag: showUpgradeBadge
              ? 'UPGRADE'
              : isGapFill
              ? 'EMPTY SLOT'
              : null,
          subtitle: subtitle,
          gainNext: next,
          detail: canBuy
              ? null
              : 'Need ${formatGold(listing.priceGold - state.gold)} more',
          trailing: ExcludeSemantics(
            child: PowerUpgradePriceChip(
              label: price,
              primary: showUpgradeBadge,
              onPressed: canBuy ? buy : null,
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

  /// Worn vs listing for the hero the listing upgrades: ("i5", "i9 · +37").
  ({String now, String next})? _wornCompare(
    GameState state,
    MarketListing listing,
  ) {
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
    final wornIlvl = hero.itemIn(listing.slot)?.effectiveItemLevel;
    final ilvl = listing.item.effectiveItemLevel;
    final gain = cmp.powerDelta > 0 ? ' · +${cmp.powerDelta}' : '';
    return (
      now: wornIlvl != null ? 'i$wornIlvl' : 'empty',
      next: 'i$ilvl$gain',
    );
  }

  Widget _marketFlaskChip({
    required String label,
    bool selected = false,
    VoidCallback? onTap,
    Color? tone,
  }) {
    // IntrinsicWidth: a disabled chip is a centred box that would fill the
    // whole Wrap line.
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
        child: MenuChrome.chip(
          label: label,
          selected: selected,
          onTap: onTap,
          tone: tone,
        ),
      ),
    );
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
