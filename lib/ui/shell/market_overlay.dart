
import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/gear/gear_scorer.dart';
import '../../core/market_listings_service.dart';
import '../../models/hero.dart';
import '../../models/loot.dart';
import '../../models/market_listing.dart';
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';
import 'shell_common.dart';

class MarketOverlay extends StatefulWidget {
  const MarketOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  State<MarketOverlay> createState() => _MarketOverlayState();
}

class _MarketOverlayState extends State<MarketOverlay> {
  EquipmentSlot? _slotFilter;
  int? _heroFilterIndex;

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
    final refreshLabel = MarketListingsService.formatRefreshRemaining(state);
    final refreshCost = GameLogic.marketListingsPaidRefreshCost(state);
    final msReady = MarketListingsService.refreshRemainingMs(state) <= 0;
    final listings = _filteredListings(state);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Buy gear · sell & clean in GEAR → BAG',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 13, color: GameTheme.mossLit),
        ),
        const SizedBox(height: 6),
        Text(
          'Gold ${formatCount(state.gold)} · Essence ${formatCount(state.essence)}',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        MenuChrome.sectionLabelScoped('SUPPLIES', scope: MenuScope.run),
        const SizedBox(height: 4),
        Text(
          'Empty flask slots first, extras go to BAG.\n'
          'Full bag: BAG → CLEAN BAG / MERGE, or SETTINGS auto-sell.',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: state.gold >= flaskCost
              ? 'Buy flask · ${flaskCost}g'
              : 'Buy flask · Need ${flaskCost}g',
          onPressed: state.gold >= flaskCost ? director.buyMarketFlask : null,
        ),
        const SizedBox(height: 4),
        KenneyButton(
          label: state.gold >= flaskCost * 3
              ? 'Buy 3 flasks · ${flaskCost * 3}g'
              : 'Buy 3 flasks · Need ${flaskCost * 3}g',
          onPressed: state.gold >= flaskCost * 3
              ? () => director.buyMarketFlasks()
              : null,
        ),
        const SizedBox(height: 4),
        KenneyButton(
          label: state.gold >= GameLogic.marketBandageCost(state)
              ? 'Buy bandage · ${GameLogic.marketBandageCost(state)}g'
              : 'Buy bandage · Need ${GameLogic.marketBandageCost(state)}g',
          onPressed: state.gold >= GameLogic.marketBandageCost(state)
              ? director.buyMarketBandage
              : null,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            KenneySprite(asset: KenneyAssets.potionRed, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Flask: whole party (~30% HP). Bandage: lowest hero (~40% HP).\n'
                '${_marketHealCount(state)}',
                style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Bag cleanup: use BAG → CLEAN BAG / MERGE, or SETTINGS auto-sell '
          'and auto-disassemble. Tap-sell stash is hidden.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: GameTheme.border),
        const SizedBox(height: 8),
        MenuChrome.sectionLabelScoped('GEAR LISTINGS', scope: MenuScope.run),
        const SizedBox(height: 4),
        Text(
          msReady
              ? 'Traveling listings · free refresh ready'
              : 'Traveling listings · free refresh in $refreshLabel',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: msReady
              ? 'LISTINGS FRESH'
              : (state.gold >= refreshCost
                    ? 'REFRESH NOW · ${formatCount(refreshCost)}g'
                    : 'REFRESH · Need ${formatCount(refreshCost)}g'),
          style: KenneyButtonStyle.grey,
          onPressed: msReady
              ? null
              : (state.gold >= refreshCost
                    ? director.refreshMarketListings
                    : null),
        ),
        const SizedBox(height: 6),
        _slotFilterRow(),
        const SizedBox(height: 4),
        _heroFilterRow(state),
        const SizedBox(height: 6),
        if (listings.isEmpty)
          Text(
            'No listings match this filter.',
            textAlign: TextAlign.center,
            style: GameTheme.body(
              size: 13,
              color: GameTheme.parchmentDim,
            ),
          )
        else ...[
          for (final listing in listings)
            _listingCard(state, director, listing),
          const SizedBox(height: 8),
          Text(
            'Buy gear when drops miss your slot. Listings refresh '
            'over time. Fill empty slots here — dungeon loot still '
            'scales higher later.',
            textAlign: TextAlign.center,
            style: GameTheme.body(
              size: 11,
              color: GameTheme.parchmentDim,
            ),
          ),
        ],
      ],
    );
  }

  List<MarketListing> _filteredListings(GameState state) {
    return [
      for (final listing in state.marketListings)
        if (_matchesFilters(state, listing)) listing,
    ];
  }

  bool _matchesFilters(GameState state, MarketListing listing) {
    if (_slotFilter != null) {
      if (_slotFilter == EquipmentSlot.ring) {
        if (listing.slot != EquipmentSlot.ring &&
            listing.slot != EquipmentSlot.ring2) {
          return false;
        }
      } else if (_slotFilter == EquipmentSlot.trinket) {
        if (listing.slot != EquipmentSlot.trinket &&
            listing.slot != EquipmentSlot.trinket2) {
          return false;
        }
      } else if (listing.slot != _slotFilter) {
        return false;
      }
    }
    if (_heroFilterIndex != null) {
      return _heroCanWearListing(state.heroes[_heroFilterIndex!], listing);
    }
    return true;
  }

  bool _heroCanWearListing(PartyHero hero, MarketListing listing) {
    return GearScorer.compareForHeroSlot(
      hero,
      listing.item,
      listing.slot,
      pairingStash: const [],
    ).powerDelta > -9999;
  }

  Widget _slotFilterRow() {
    const filters = <(String, EquipmentSlot?)>[
      ('ALL', null),
      ('HEAD', EquipmentSlot.head),
      ('CHEST', EquipmentSlot.chest),
      ('BOOTS', EquipmentSlot.boots),
      ('WEAPON', EquipmentSlot.weapon),
      ('OFF-HAND', EquipmentSlot.offHand),
      ('RING', EquipmentSlot.ring),
      ('TRINKET', EquipmentSlot.trinket),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (label, slot) in filters)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(label, style: GameTheme.body(size: 11)),
                selected: _slotFilter == slot,
                onSelected: (_) => setState(() => _slotFilter = slot),
                selectedColor: GameTheme.torchHot.withValues(alpha: 0.35),
                backgroundColor: GameTheme.panelInset,
                side: BorderSide(color: GameTheme.border.withValues(alpha: 0.8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _heroFilterRow(GameState state) {
    if (state.heroes.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Text(
          'Hero',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              isExpanded: true,
              value: _heroFilterIndex,
              hint: Text(
                'Any',
                style: GameTheme.body(size: 13, color: GameTheme.parchment),
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Any', style: GameTheme.body(size: 13)),
                ),
                for (var i = 0; i < state.heroes.length; i++)
                  DropdownMenuItem<int?>(
                    value: i,
                    child: Text(
                      state.heroes[i].name,
                      style: GameTheme.body(size: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _heroFilterIndex = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _listingCard(
    GameState state,
    GameDirector director,
    MarketListing listing,
  ) {
    final item = listing.item;
    final upgradeHero = _upgradeHeroName(state, listing);
    final armorLine = item.armorType != null
        ? ' · ${item.armorType!.name}'
        : '';
    final canBuy = state.gold >= listing.priceGold;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: MenuChrome.listCard(
        borderColor: rarityBorderColor(item.rarity).withValues(alpha: 0.85),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KenneySprite(
            asset: KenneyAssets.equipmentIconFor(item),
            size: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GameTheme.body(size: 14, color: GameTheme.parchment),
                ),
                const SizedBox(height: 2),
                Text(
                  '${listing.slot.name.toUpperCase()} · '
                  'iLvl ${item.effectiveItemLevel}$armorLine',
                  style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
                ),
                if (upgradeHero != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: GameTheme.mossLit.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                      border: Border.all(
                        color: GameTheme.mossLit.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Text(
                      canBuy
                          ? 'UPGRADE · $upgradeHero'
                          : 'UPGRADE · $upgradeHero (need gold)',
                      style: GameTheme.body(size: 11, color: GameTheme.mossLit),
                    ),
                  ),
                ] else if (MarketListingsService.isGapFillListing(state, listing)) ...[
                  const SizedBox(height: 2),
                  Text(
                    _gapFillLine(state, listing),
                    style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${formatCount(listing.priceGold)}g',
                style: GameTheme.body(size: 13, color: GameTheme.torchHot),
              ),
              const SizedBox(height: 4),
              KenneyButton(
                label: 'BUY',
                style: KenneyButtonStyle.brown,
                expanded: false,
                onPressed: canBuy
                    ? () => director.buyMarketListing(listing.id)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
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

  String _gapFillLine(GameState state, MarketListing listing) {
    final wornILvl =
        MarketListingsService.wornItemLevelForListing(state, listing);
    final heroName = listing.targetHeroIndex >= 0 &&
            listing.targetHeroIndex < state.heroes.length
        ? state.heroes[listing.targetHeroIndex].name
        : 'hero';
    if (wornILvl != null) {
      return 'GAP FILL → $heroName · worn iLvl $wornILvl';
    }
    return 'GAP FILL → $heroName · empty slot';
  }

  static String _marketHealCount(GameState state) {
    var flasks = 0;
    var bandages = 0;
    var emptySlots = 0;
    for (final h in state.heroes) {
      final c = h.itemIn(EquipmentSlot.consumable);
      if (c == null) {
        emptySlots++;
      } else if (c.iconId == 'flask') {
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
    return 'Have $flasks flask${flasks == 1 ? '' : 's'} · '
        '$bandages bandage${bandages == 1 ? '' : 's'} · '
        '$emptySlots empty slot${emptySlots == 1 ? '' : 's'}';
  }
}
