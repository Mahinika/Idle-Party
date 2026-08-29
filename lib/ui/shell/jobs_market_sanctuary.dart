import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gold_income.dart';
import '../../core/menu_alerts.dart';
import '../../core/game_state.dart';
import '../../core/gear/gear_scorer.dart';
import '../../core/market_listings_service.dart';
import '../../models/hero.dart';
import '../../models/loot.dart';
import '../../models/market_listing.dart';
import '../../models/mission.dart';
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_bar.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';
import 'income_overlay.dart';
import 'shell_common.dart';

class JobsOverlay extends StatelessWidget {
  const JobsOverlay({super.key, required this.director});
  final GameDirector director;

  static String _slotBadge(int index) => switch (index) {
    0 => 'DAILY · easy',
    1 => 'BOUNTY · climb',
    _ => 'SIDE · variety',
  };

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final claimable = state.missions.where((m) => m.canClaim).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'QUESTS — clear goals while you dungeon. Claim for gold + essence.\n'
          'Chain ${state.metaDepth.jobChainCount}/3 · the 3rd claim in a row pays +5e extra.',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        if (claimable > 0) ...[
          const SizedBox(height: 8),
          KenneyButton(
            label: claimable == 1
                ? 'CLAIM QUESTS'
                : 'CLAIM QUESTS ($claimable)',
            onPressed: () => director.claimAllReadyMissions(),
            style: KenneyButtonStyle.brown,
            primary: true,
          ),
        ],
        const SizedBox(height: 8),
        for (var i = 0; i < state.missions.length; i++)
          _questCard(state.missions[i], i, hideClaim: claimable > 0),
      ],
    );
  }

  Widget _questCard(Mission mission, int index, {bool hideClaim = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: MenuChrome.listCard(
        borderColor: switch (mission.tier) {
          2 => GameTheme.bloodLit,
          1 => GameTheme.torchHot,
          _ => GameTheme.border.withValues(alpha: 0.9),
        },
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: GameTheme.panelInset,
                        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                        border: Border.all(
                          color: GameTheme.border.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Text(
                        _slotBadge(index),
                        style: GameTheme.pixel(
                          size: 9,
                          color: GameTheme.torchHot,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        mission.title,
                        style: GameTheme.body(
                          size: 16,
                          color: switch (mission.tier) {
                            2 => GameTheme.bloodLit,
                            1 => GameTheme.torchHot,
                            _ => GameTheme.parchment,
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Progress ${mission.progress}/${mission.target}',
                  style: GameTheme.body(size: 14),
                ),
                Text(
                  '+${mission.goldReward}g +${mission.essenceReward}e',
                  style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                  child: LinearProgressIndicator(
                    value: mission.target <= 0
                        ? 0
                        : (mission.progress / mission.target).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: GameTheme.panelInset,
                    color: mission.canClaim || mission.claimed
                        ? GameTheme.mossLit
                        : GameTheme.torchHot,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!hideClaim && (mission.canClaim || mission.claimed))
            KenneyButton(
              label: mission.claimed
                  ? 'CLAIMED'
                  : (director.state.metaDepth.jobChainCount == 2
                      ? 'CLAIM · chain +5e'
                      : 'CLAIM'),
              onPressed: mission.canClaim
                  ? () => director.claimMission(mission.id)
                  : null,
              style: KenneyButtonStyle.grey,
              expanded: false,
            ),
        ],
      ),
    );
  }
}

class SanctuaryOverlay extends StatelessWidget {
  const SanctuaryOverlay({super.key, required this.director});
  final GameDirector director;

  int _prestigeOf(GameState state, String track) => switch (track) {
    'gold' => state.metaDepth.sanctuaryGoldPrestige,
    'power' => state.metaDepth.sanctuaryPowerPrestige,
    'vitality' => state.metaDepth.sanctuaryVitalityPrestige,
    'xp' => state.metaDepth.sanctuaryXpPrestige,
    _ => 0,
  };

  int _levelOf(GameState state, String track) => switch (track) {
    'gold' => state.sanctuaryGoldLevel,
    'power' => state.sanctuaryPowerLevel,
    'vitality' => state.sanctuaryVitalityLevel,
    'xp' => state.metaDepth.sanctuaryXpLevel,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final relicLine = GameLogic.relicKeepSummary(state);
    final campOpen = MenuTabs.showCamp(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampRatesSection(director: director),
        const SizedBox(height: 10),
        Text(
          'Permanent tracks — survive Ascend. Upgrade forever.\n'
          'From Lv12 you can reset this track (not Ascend): cheap levels again, '
          'a small forever bonus, and essence back.',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        if (state.metaDepth.ascendBlessings > 0) ...[
          const SizedBox(height: 6),
          Text(
            'Ascend Blessing ×${state.metaDepth.ascendBlessings} · '
            'see Gold → KEEP',
            style: GameTheme.body(size: 13, color: GameTheme.mossLit),
          ),
        ],
        if (relicLine != null) ...[
          const SizedBox(height: 6),
          Text(
            relicLine,
            style: GameTheme.body(size: 13, color: GameTheme.mossLit),
          ),
        ],
        const SizedBox(height: 10),
        if (campOpen)
          for (final track in <String>['gold', 'power', 'vitality', 'xp'])
            _campTrackCard(context, state, track)
        else
          Text(
            'War Altar, Life Well, and Lore Font appear here once Forever unlocks.',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
      ],
    );
  }

  Widget _campTrackCard(BuildContext context, GameState state, String track) {
    final level = _levelOf(state, track);
    final prestige = _prestigeOf(state, track);
    final nextLevel = level + 1;
    final cost = GameLogic.sanctuaryCost(level);
    final keepShort = GameLogic.sanctuaryPrestigeKeepShort(track);
    final nextBonus = GameLogic.sanctuaryBonusLabel(
      track,
      nextLevel,
      prestige: prestige,
    );
    final currentBonus = GameLogic.sanctuaryBonusLabel(
      track,
      level,
      prestige: prestige,
    );
    final cycleStep = level <= 0 ? 0 : ((level - 1) % 12 + 1);
    final canPrestige = level >= 12;
    final prestigeGain = GameLogic.sanctuaryPrestigeEssenceGain(level);
    final afterPrestige = GameLogic.sanctuaryBonusLabel(
      track,
      0,
      prestige: prestige + 1,
    );
    final canAfford = state.essence >= cost;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: MenuChrome.listCard(
        selected: canPrestige || (track == 'gold' && canAfford),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuChrome.sectionLabelScoped(
            GameLogic.sanctuaryNames[track] ?? track,
            scope: MenuScope.account,
          ),
          Text(
            'Lv$level  ·  $currentBonus'
            '${prestige > 0 ? '  ·  Prestige $prestige' : ''}',
            style: GameTheme.body(size: 13, color: GameTheme.parchment),
          ),
          Text(
            track == 'gold'
                ? () {
                    final hubNext = GoldIncome.hubGoldPerMinuteAtGoldLevel(
                      state,
                      nextLevel,
                    );
                    final hubDelta = GoldIncome.nextGoldFindDeltaPerMinute(
                      state,
                    );
                    final run = director.runGoldPerMinute;
                    final oldP = GoldIncome.goldFindPercent(state);
                    final newP = GoldIncome.goldFindPercent(
                      state.copyWith(sanctuaryGoldLevel: nextLevel),
                    );
                    final runDelta = GoldIncome.goldFindDeltaOnRate(
                      run,
                      oldP,
                      newP,
                    );
                    final runBit = run > 0
                        ? ' · Run +${runDelta}g/min'
                        : '';
                    return 'Next: $nextBonus · Hub ${GoldIncome.perMinuteLabel(hubNext)} '
                        '(+${hubDelta}g/min)$runBit';
                  }()
                : 'Next: $nextBonus',
            style: GameTheme.body(size: 12, color: GameTheme.mossLit),
          ),
          Text(
            canPrestige
                ? 'Track reset (not Ascend): keeps $keepShort forever, '
                      'refunds ${prestigeGain}e, resets to $afterPrestige. '
                      'Levels start cheap again.'
                : 'Each track reset keeps $keepShort forever · ready at Lv12 '
                      '(cycle $cycleStep/12) — separate from Ascend',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          Text(
            'Prestige cycle $cycleStep/12 (not hero XP)',
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
          KenneyProgressBar(
            value: (cycleStep / 12.0).clamp(0.0, 1.0),
            height: 12,
            color: track == 'vitality'
                ? KenneyBarColor.red
                : track == 'power'
                ? KenneyBarColor.yellow
                : KenneyBarColor.green,
          ),
          const SizedBox(height: 6),
          KenneyButton(
            label: 'Upgrade · ${cost}e',
            onPressed: canAfford
                ? () => director.upgradeSanctuary(track)
                : null,
          ),
          Builder(
            builder: (_) {
              final bulk = GameLogic.sanctuaryBulkAffordableLevels(state, track);
              if (bulk <= 1) return const SizedBox.shrink();
              final target = level + bulk;
              if (track == 'gold') {
                final hubNow = GoldIncome.hubGoldPerMinute(state);
                final hubAfter = GoldIncome.hubGoldPerMinuteAtGoldLevel(
                  state,
                  target,
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: KenneyButton(
                    label:
                        'Buy $bulk · Lv$target · +${hubAfter - hubNow} g/min',
                    style: KenneyButtonStyle.brown,
                    onPressed: () => director.upgradeSanctuaryBulk(track),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: KenneyButton(
                  label: 'Buy $bulk · Lv$target',
                  style: KenneyButtonStyle.brown,
                  onPressed: () => director.upgradeSanctuaryBulk(track),
                ),
              );
            },
          ),
          if (canPrestige) ...[
            const SizedBox(height: 4),
            KenneyButton(
              label: 'Reset track · keep $keepShort · +${prestigeGain}e',
              style: KenneyButtonStyle.grey,
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  barrierColor: MenuChrome.scrim,
                  builder: (ctx) => MenuChrome.dialog(
                    title: 'Reset this track?',
                    content: Text(
                      'Resets this Forever track to Lv1. Keeps $keepShort forever '
                      'and refunds ${prestigeGain}e.\n\n'
                      'This is not Ascend — only this track. '
                      'Ascend (hub claim) resets the run bag and raises AL.',
                      style: GameTheme.body(
                        size: 15,
                        color: GameTheme.parchment,
                      ),
                    ),
                    actions: [
                      KenneyButton(
                        label: 'CANCEL',
                        style: KenneyButtonStyle.grey,
                        expanded: false,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                      KenneyButton(
                        label: 'RESET',
                        style: KenneyButtonStyle.red,
                        expanded: false,
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  director.prestigeSanctuaryTrack(track);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

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
