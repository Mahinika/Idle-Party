import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gold_income.dart';
import '../../core/menu_alerts.dart';
import '../../core/game_state.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';
import 'income_overlay.dart';
import 'power_upgrade_row.dart';
import 'shell_common.dart';
import 'shell_layout.dart';

class SanctuaryOverlay extends StatefulWidget {
  const SanctuaryOverlay({
    super.key,
    required this.director,
    this.inlineUnderFight = false,
    this.expandedTrackList = false,
  });
  final GameDirector director;
  final bool inlineUnderFight;

  /// Bounded height (SPLIT panel or FORGE/CAMP sheet): scroll all tracks.
  final bool expandedTrackList;

  @override
  State<SanctuaryOverlay> createState() => _SanctuaryOverlayState();
}

class _SanctuaryOverlayState extends State<SanctuaryOverlay> {
  /// Shared buy size for every CAMP row (#53): 1 / 3 / 5 / max.
  int _buyLevels = 1;

  GameDirector get director => widget.director;

  int _prestigeOf(GameState state, String track) => switch (track) {
    'gold' => state.metaDepth.sanctuaryGoldPrestige,
    'power' => state.metaDepth.sanctuaryPowerPrestige,
    'vitality' => state.metaDepth.sanctuaryVitalityPrestige,
    'defense' => state.metaDepth.sanctuaryDefensePrestige,
    'xp' => state.metaDepth.sanctuaryXpPrestige,
    _ => 0,
  };

  int _levelOf(GameState state, String track) => switch (track) {
    'gold' => state.sanctuaryGoldLevel,
    'power' => state.sanctuaryPowerLevel,
    'vitality' => state.sanctuaryVitalityLevel,
    'defense' => state.sanctuaryDefenseLevel,
    'xp' => state.metaDepth.sanctuaryXpLevel,
    _ => 0,
  };

  Color _trackAccent(String track) => switch (track) {
    'gold' => GameTheme.torch,
    'power' => GameTheme.hudHpDamage,
    'vitality' => GameTheme.mossLit,
    'defense' => GameTheme.rarityRare,
    'xp' => GameTheme.rarityRare,
    _ => GameTheme.parchmentDim,
  };

  static const _tracks = <String>[
    'gold',
    'power',
    'vitality',
    'defense',
    'xp',
  ];

  bool get _compactPrice =>
      widget.inlineUnderFight || widget.expandedTrackList;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final campOpen = MenuTabs.showCamp(state);
    if (widget.inlineUnderFight || widget.expandedTrackList) {
      return _scrollableTrackBody(state, campOpen);
    }
    final maxBulk = campOpen
        ? _tracks
            .map((t) => GameLogic.sanctuaryBulkAffordableLevels(state, t))
            .fold<int>(1, (a, b) => a > b ? a : b)
        : 1;
    final buyCap = maxBulk.clamp(1, 99);
    final effectiveBuy = _buyLevels.clamp(1, buyCap);

    return Padding(
      padding: ShellLayout.listPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CampRatesSection(director: director),
          ShellLayout.gap(8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MenuChrome.chip(
                label: 'Ascend ${state.ascensionLevel}',
                tone: GameTheme.torchHot,
              ),
              MenuChrome.chip(label: 'Camp tracks', selected: campOpen),
              Text(
                '${formatCount(state.essence)}e · survive Ascend',
                style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
              ),
            ],
          ),
          if (campOpen && buyCap > 1) ...[
            ShellLayout.gap(8),
            _bulkChooser(buyCap, effectiveBuy),
          ],
          ShellLayout.gap(8),
          if (campOpen)
            for (final track in _tracks)
              _campTrackCard(
                state,
                track,
                effectiveBuy,
                recommended: track == GameLogic.recommendedSanctuaryTrack(state),
              )
          else
            ShellLayout.hint(
              'Gold Find, War Altar, Life Well, Aegis, and Lore Font appear here once Essence unlocks.',
              maxLines: 3,
            ),
          ShellLayout.gap(12),
        ],
      ),
    );
  }

  Widget _scrollableTrackBody(GameState state, bool campOpen) {
    if (!campOpen) {
      return Padding(
        padding: ShellLayout.listPadding,
        child: ShellLayout.hint(
          'CAMP tracks unlock on ESSENCE after the first hour.',
          maxLines: 2,
        ),
      );
    }
    final maxBulk = _tracks
        .map((t) => GameLogic.sanctuaryBulkAffordableLevels(state, t))
        .fold<int>(1, (a, b) => a > b ? a : b);
    final buyCap = maxBulk.clamp(1, 99);
    final effectiveBuy = _buyLevels.clamp(1, buyCap);
    final pick = GameLogic.recommendedSanctuaryTrack(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (buyCap > 1)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ShellLayout.sheetHorizontal,
            ),
            child: _bulkChooserThin(buyCap, effectiveBuy),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              ShellLayout.sheetHorizontal,
              4,
              ShellLayout.sheetHorizontal,
              8,
            ),
            children: [
              for (final track in _tracks)
                _campTrackCard(
                  state,
                  track,
                  effectiveBuy,
                  recommended: track == pick,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bulkChooser(int buyCap, int effectiveBuy) {
    final options = <int>[1];
    if (buyCap >= 3) options.add(3);
    if (buyCap >= 5) options.add(5);
    if (buyCap > 5 && !options.contains(buyCap)) options.add(buyCap);
    final labels = [
      for (final n in options) n == buyCap && n > 5 ? 'Max ×$n' : '×$n',
    ];
    var selected = options.indexOf(effectiveBuy);
    if (selected < 0) selected = 0;
    return MenuChrome.segmented(
      dense: true,
      labels: labels,
      selectedIndex: selected,
      onSelect: (i) => setState(() => _buyLevels = options[i]),
    );
  }

  Widget _bulkChooserThin(int buyCap, int effectiveBuy) {
    final options = <int>[1];
    if (buyCap >= 3) options.add(3);
    if (buyCap >= 5) options.add(5);
    if (buyCap > 5 && !options.contains(buyCap)) options.add(buyCap);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final n in options)
          MenuChrome.chip(
            label: n == buyCap && n > 5 ? 'Max ×$n' : '×$n',
            selected: effectiveBuy == n,
            onTap: () => setState(() => _buyLevels = n),
          ),
      ],
    );
  }

  Widget _campTrackCard(
    GameState state,
    String track,
    int buyLevels, {
    bool recommended = false,
  }) {
    final level = _levelOf(state, track);
    final prestige = _prestigeOf(state, track);
    final cost = GameLogic.sanctuaryCost(level);
    final currentBonus = GameLogic.sanctuaryBonusLabel(
      track,
      level,
      prestige: prestige,
    );
    final maxForTrack = GameLogic.sanctuaryBulkAffordableLevels(state, track);
    // clamp(1, 0) throws when this track costs more than the wallet.
    final buyN = maxForTrack < 1 ? 1 : buyLevels.clamp(1, maxForTrack);
    final canAffordOne = state.essence >= cost;

    String? detail;
    if (track == 'gold') {
      final hubDelta = GoldIncome.nextGoldFindDeltaPerMinute(state);
      final campPct = GameLogic.sanctuaryTrackBonusAt(
        'gold',
        state.sanctuaryGoldLevel + 1,
      );
      final nowPct = GameLogic.sanctuaryTrackBonusAt(
        'gold',
        state.sanctuaryGoldLevel,
      );
      final combatDelta = campPct - nowPct;
      detail = 'Next +${hubDelta}g/min hub · +$combatDelta% find';
    } else if (track == 'power') {
      detail = 'Speeds hub AFK essence';
    }

    if (_compactPrice) {
      detail = null;
    }

    late final Widget trailing;
    if (_compactPrice) {
      if (buyN > 1 && maxForTrack >= buyN) {
        final bulkCost = GameLogic.sanctuaryBulkCost(state, track, buyN);
        final label = track == 'gold'
            ? () {
                final hubNow = GoldIncome.hubGoldPerMinute(state);
                final hubAfter = GoldIncome.hubGoldPerMinuteAtGoldLevel(
                  state,
                  level + buyN,
                );
                return '+${hubAfter - hubNow}g · ${bulkCost}e';
              }()
            : '$buyN · ${bulkCost}e';
        trailing = PowerUpgradePriceChip(
          label: label,
          primary: recommended,
          onPressed: () {
            director.upgradeSanctuaryBulk(track, maxLevels: buyN);
            setState(() {});
          },
        );
      } else {
        trailing = PowerUpgradePriceChip(
          label: '${cost}e',
          primary: recommended && canAffordOne,
          onPressed: canAffordOne
              ? () {
                  director.upgradeSanctuary(track);
                  setState(() {});
                }
              : null,
        );
      }
    } else if (buyN > 1) {
      final bulkCost = GameLogic.sanctuaryBulkCost(state, track, buyN);
      final target = level + buyN;
      final label = track == 'gold'
          ? () {
              final hubNow = GoldIncome.hubGoldPerMinute(state);
              final hubAfter =
                  GoldIncome.hubGoldPerMinuteAtGoldLevel(state, target);
              return '+${hubAfter - hubNow}g/min · ${bulkCost}e';
            }()
          : 'Buy $buyN · ${bulkCost}e';
      trailing = PowerUpgradePriceChip(
        label: label,
        primary: true,
        onPressed: () {
          director.upgradeSanctuaryBulk(track, maxLevels: buyN);
          setState(() {});
        },
      );
    } else {
      trailing = PowerUpgradePriceChip(
        label: '${cost}e',
        primary: canAffordOne && recommended,
        onPressed: canAffordOne
            ? () {
                director.upgradeSanctuary(track);
                setState(() {});
              }
            : null,
      );
    }

    final subtitle = _compactPrice
        ? 'Lv$level · $currentBonus'
        : 'Lv$level · $currentBonus'
            '${prestige > 0 ? ' · P$prestige' : ''}';

    return PowerUpgradeRow(
      accent: _trackAccent(track),
      title: GameLogic.sanctuaryNames[track] ?? track,
      tag: recommended ? 'BEST' : null,
      subtitle: subtitle,
      detail: detail,
      selected: recommended,
      dense: true,
      trailing: trailing,
    );
  }
}
