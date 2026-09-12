import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/gear/gear_cleanup.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';

/// Auto-sell (gold) and auto-scrap (essence) rules.
/// Same widget in BAG → FILTERS and MORE → SETTINGS → BAG.
class BagCleanupFilters extends StatelessWidget {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact) ...[
          Text(
            'CLEAN BAG uses these rules. BiS / upgrades are never cleaned.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 10),
        ] else ...[
          MenuChrome.sectionLabelScoped(
            'BAG CLEANUP',
            scope: MenuScope.account,
          ),
          const SizedBox(height: 4),
          Text(
            'Near-full bag auto-rules (also BAG → FILTERS). '
            'Auto-sell = gold · auto-scrap = essence. '
            'BiS / upgrades are never cleaned.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 10),
        ],
        MenuChrome.sectionLabelScoped(
          'AUTO-SELL · gold',
          scope: MenuScope.account,
        ),
        const SizedBox(height: 4),
        Text(
          'Junk sold for coins when bag is near full or you CLEAN BAG. '
          '${state.autoSellMaxPower <= 0 ? 'Off = never auto-sells.' : 'Sells iLvl 1–${state.autoSellMaxPower} at or below the rarity cap.'}',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Text(
          'Max iLvl to sell',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
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
            'Sells ~${GearCleanup.autoSellPreviewCount(state)} stash items',
            style: GameTheme.body(size: 12, color: GameTheme.mossLit),
          ),
        ],
        const SizedBox(height: 12),
        MenuChrome.sectionLabelScoped(
          'AUTO-SCRAP · essence',
          scope: MenuScope.account,
        ),
        const SizedBox(height: 4),
        Text(
          'Leftovers broken for essence after sell pass — not the same as sell. '
          '${state.autoDisassembleMaxIlvl <= 0 ? 'Off = never auto-scraps.' : 'Scraps iLvl 1–${state.autoDisassembleMaxIlvl} at or below the rarity cap.'}',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Text(
          'Max iLvl to scrap',
          style: GameTheme.body(size: 13, color: GameTheme.mossLit),
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
        const SizedBox(height: 8),
        Text(
          compact
              ? 'CLEAN BAG: sell gold first, then scrap leftovers that match. '
                  'GOLD → MARKET buys flasks — it does not tap-sell stash.'
              : 'Pickup & CLEAN BAG: sell gold first (≤iLvl + rarity), then scrap '
                  'leftovers that match scrap filters. GOLD → MARKET buys flasks '
                  'and listings — it does not tap-sell stash.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
      ],
    );
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
            value <= 0 ? offLabel : 'i$value',
            textAlign: TextAlign.right,
            style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
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
            'Max rarity',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          const Spacer(),
          MenuChrome.stepperButton(
            label: 'Max rarity decrease',
            sign: '-',
            onPressed: enabled && value > 0 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 88,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 12, color: GameTheme.torchHot),
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
