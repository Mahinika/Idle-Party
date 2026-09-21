import 'package:flutter/material.dart';

import '../models/hero.dart';
import 'game_theme.dart';
import 'hero_doll_sprite.dart';
import 'menu_chrome.dart';

/// LOOK race grid (Cataclysm 12). Sex follows the kit family (healer female).
class HeroLookRow extends StatelessWidget {
  const HeroLookRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.title,
    this.compact = false,
    this.columns = 0,
    this.dollFor,
  });

  final HeroRace value;
  final ValueChanged<HeroRace> onChanged;
  final String? hint;

  /// Defaults to `LOOK`. New Game passes `RACE` inside the LOOK tab.
  final String? title;
  final bool compact;

  /// When > 0, lay out a fixed column grid (New Party RACE panel).
  /// Otherwise use a centered [Wrap].
  final int columns;

  /// When set, each race cell shows that hero so skin and hair read on a phone.
  final PartyHero Function(HeroRace race)? dollFor;

  @override
  Widget build(BuildContext context) {
    final races = HeroRace.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title ?? 'LOOK',
          textAlign: TextAlign.center,
          style: GameTheme.body(
            size: compact ? 11 : 12,
            color: GameTheme.parchmentDim,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        if (columns > 0)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gap = compact ? 6.0 : 8.0;
                final colW =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                final rows = (races.length / columns).ceil();
                final rowH =
                    ((constraints.maxHeight - gap * (rows - 1)) / rows)
                        .clamp(40.0, 52.0);
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final race in races)
                      SizedBox(
                        width: colW,
                        height: rowH,
                        child: _RaceCell(
                          label: race.shortLabel,
                          selected: value == race,
                          onTap: () => onChanged(race),
                          doll: dollFor?.call(race),
                        ),
                      ),
                  ],
                );
              },
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final race in races)
                MenuChrome.chip(
                  label: race.shortLabel,
                  selected: value == race,
                  tone: value == race
                      ? GameTheme.torchHot
                      : GameTheme.parchmentDim,
                  onTap: () => onChanged(race),
                ),
            ],
          ),
        if (hint != null && hint!.isNotEmpty) ...[
          SizedBox(height: compact ? 4 : 6),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: GameTheme.body(
              size: compact ? 11 : 12,
              color: GameTheme.parchmentDim,
            ),
          ),
        ],
      ],
    );
  }
}

class _RaceCell extends StatelessWidget {
  const _RaceCell({
    required this.label,
    required this.selected,
    required this.onTap,
    this.doll,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final PartyHero? doll;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
        child: DecoratedBox(
          decoration: MenuChrome.cardBox(selected: selected, inset: true),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (doll != null)
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: HeroDollSprite(hero: doll!, size: 32),
                    ),
                  ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixel,
                      color: selected
                          ? GameTheme.torchHot
                          : GameTheme.parchmentDim,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// New Game: LOOK is per selected hero slot.
String newGameLookHint(HeroRace race) {
  return 'LOOK for the selected hero · ${race.label}.';
}
