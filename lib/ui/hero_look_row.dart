import 'package:flutter/material.dart';

import '../models/hero.dart';
import 'game_theme.dart';
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
  });

  final HeroRace value;
  final ValueChanged<HeroRace> onChanged;
  final String? hint;

  /// Defaults to `LOOK`. New Game passes `LOOK · PROT` etc.
  final String? title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
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
        SizedBox(height: compact ? 4 : 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final race in HeroRace.values)
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

/// Shared New Game / GEAR hint — authored race bodies exist per family.
String nightElfLookHint({required bool authoredBody}) {
  if (authoredBody) {
    return 'Purple skin, long ears. Gear uses this kit\'s pose.';
  }
  return 'Uses the Human pose until this kit\'s Night Elf body is drawn.';
}

/// New Game: LOOK is per selected hero slot.
String newGameLookHint(HeroRace race) {
  final base = 'LOOK for the selected hero · ${race.label}.';
  return base;
}

/// Shared New Game / GEAR hint — authored Night Elf bodies exist per family.
String get newGameNightElfHint => newGameLookHint(HeroRace.nightElf);
