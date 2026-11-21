import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/gear/gear_cleanup.dart';
import '../../core/menu_alerts.dart';
import '../../models/loot.dart';
import '../game_theme.dart';
import '../item_tooltip.dart';
import '../menu_chrome.dart';

/// Auto-sell (gold) and auto-scrap (essence) rules.
/// Same widget in BAG → FILTERS and MORE → SETTINGS → BAG.
class BagCleanupFilters extends StatelessWidget {
  /// Rarity limit label in the filter rows.
  static const rarityLabelKey = ValueKey('bag-cleanup-rarity');

  const BagCleanupFilters({
    super.key,
    required this.director,
    this.compact = false,
  });

  final GameDirector director;
  final bool compact;

  GameState get state => director.state;

  @override
  Widget build(BuildContext context) {
    final showScrap = MenuTabs.showCamp(state);
    final showMarket = MenuTabs.showGold(state);
    final keepLine =
        'SELL JUNK sells everything that matches, upgrades too. '
        'Apex and bound gear are never sold.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact) ...[
          Text(
            'SELL JUNK uses these rules. $keepLine',
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 10),
        ] else ...[
          MenuChrome.sectionLabelScoped(
            'BAG CLEANUP',
            scope: MenuScope.account,
          ),
          const SizedBox(height: 4),
          // One line up top, the rest folds so the controls stay high
          // (polish7 P038). Plain words, not iLvl / soulbound (P040).
          Text(
            'When the bag is nearly full these rules tidy it.',
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
          MenuChrome.fold(
            title: 'How cleanup works',
            children: [
              Text(
                showScrap
                    ? 'Selling gives gold, scrapping gives essence. $keepLine'
                    : 'Selling gives gold. $keepLine',
                style: GameTheme.hint(color: GameTheme.parchmentDim),
              ),
              const SizedBox(height: 4),
              Text(
                _footer(
                  compact: false,
                  showScrap: showScrap,
                  showMarket: showMarket,
                ),
                style: GameTheme.hint(color: GameTheme.parchmentDim),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        MenuChrome.sectionLabelScoped(
          'AUTO-SELL · gold',
          scope: MenuScope.account,
        ),
        const SizedBox(height: 4),
        Text(
          _sellRule(state),
          style: GameTheme.hint(color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Text(
          'Sell up to item level',
          style: GameTheme.section(color: GameTheme.torchHot),
        ),
        _IlvlFilterRow(
          value: state.autoSellMaxPower,
          max: GameLogic.maxAutoSellIlvlCap(state),
          onChanged: director.setAutoSellMaxPower,
          offLabel: 'Off',
        ),
        const SizedBox(height: 6),
        _RarityFilterRow(
          value: state.autoSellMaxRarity,
          onChanged: director.setAutoSellMaxRarity,
          enabled: state.autoSellMaxPower > 0,
        ),
        if (state.autoSellMaxPower > 0) ...[
          const SizedBox(height: 4),
          Text(
            'SELL JUNK would sell ${GearCleanup.cleanSellPreviewCount(state)} stash items',
            style: GameTheme.hint(color: GameTheme.mossLit),
          ),
        ],
        if (showScrap) ...[
          const SizedBox(height: 12),
          MenuChrome.sectionLabelScoped(
            'AUTO-SCRAP · essence',
            scope: MenuScope.account,
          ),
          const SizedBox(height: 4),
          Text(
            'Breaks what is left after selling into essence. '
            '${state.autoDisassembleMaxIlvl <= 0 ? 'Off = never scraps.' : 'Scraps item level 1–${state.autoDisassembleMaxIlvl}, up to the rarity below.'}',
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          Text(
            'Scrap up to item level',
            style: GameTheme.section(color: GameTheme.mossLit),
          ),
          _IlvlFilterRow(
            value: state.autoDisassembleMaxIlvl,
            max: GameLogic.maxAutoSellIlvlCap(state),
            onChanged: director.setAutoDisassembleMaxIlvl,
            offLabel: 'Off',
          ),
          const SizedBox(height: 6),
          _RarityFilterRow(
            value: state.autoDisassembleMaxRarity,
            onChanged: director.setAutoDisassembleMaxRarity,
            enabled: state.autoDisassembleMaxIlvl > 0,
          ),
        ],
        if (compact) ...[
          const SizedBox(height: 8),
          Text(
            _footer(
              compact: compact,
              showScrap: showScrap,
              showMarket: showMarket,
            ),
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
        ],
      ],
    );
  }

  static String _sellRule(GameState state) {
    if (state.autoSellMaxPower <= 0) {
      return 'Sells junk for gold when the bag is nearly full or you tap '
          'SELL JUNK. Off = never sells.';
    }
    final cap =
        'Sells item level 1–${state.autoSellMaxPower}, up to the rarity below.';
    final worn = GearCleanup.partyWornIlvl(state);
    if (worn == null) {
      return 'Sells junk for gold when the bag is nearly full or you tap SELL JUNK. $cap';
    }
    final vs = state.autoSellMaxPower >= worn
        ? ' Your worn gear is about item level $worn, so this can sell upgrades.'
        : ' Your worn gear is about item level $worn.';
    return 'Sells junk for gold when the bag is nearly full or you tap SELL JUNK. $cap$vs';
  }

  static String _footer({
    required bool compact,
    required bool showScrap,
    required bool showMarket,
  }) {
    final sell = compact
        ? 'SELL JUNK: sell gold first'
        : 'On pickup and SELL JUNK: sell for gold first';
    final scrap = showScrap
        ? (compact
              ? ', then scrap leftovers that match'
              : ', then scrap leftovers that match scrap filters')
        : '';
    final market = showMarket
        ? (compact
              ? '. MARKET buys flasks — it does not tap-sell stash.'
              : '. MARKET buys flasks and listings — it does not tap-sell stash.')
        : '.';
    return '$sell$scrap$market';
  }
}

class _IlvlFilterRow extends StatelessWidget {
  const _IlvlFilterRow({
    required this.value,
    required this.max,
    required this.onChanged,
    required this.offLabel,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  final String offLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MenuChrome.stepperButton(
          label: '$offLabel decrease',
          sign: '-',
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        Expanded(
          child: MenuChrome.slider(
            value: value.toDouble().clamp(0, max.toDouble()),
            min: 0,
            max: max.toDouble(),
            divisions: max.clamp(1, 200),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        MenuChrome.stepperButton(
          label: '$offLabel increase',
          sign: '+',
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
        SizedBox(
          width: 52,
          child: Text(
            value <= 0 ? offLabel : 'Lv $value',
            textAlign: TextAlign.right,
            style: GameTheme.readable(color: GameTheme.parchmentDim),
          ),
        ),
      ],
    );
  }
}

class _RarityFilterRow extends StatelessWidget {
  const _RarityFilterRow({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final label = GameLogic.rarityFilterLabel(value);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Row(
        children: [
          Text(
            'Up to rarity',
            style: GameTheme.section(color: GameTheme.parchmentDim),
          ),
          const Spacer(),
          MenuChrome.stepperButton(
            label: 'Max rarity decrease',
            sign: '-',
            onPressed: enabled && value > 0 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 96,
            // Section-size text in the rarity's own colour (polish7 P040).
            child: Text(
              label,
              key: BagCleanupFilters.rarityLabelKey,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.section(
                color: itemRarityColor(
                  LootRarity.values[value.clamp(0, LootRarity.values.length - 1)],
                ),
              ),
            ),
          ),
          MenuChrome.stepperButton(
            label: 'Max rarity increase',
            sign: '+',
            onPressed: enabled && value < 4 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
