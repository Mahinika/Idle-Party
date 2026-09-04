import 'game_state.dart';

/// God Hand mastery milestones — independent of Ashen Crown.
abstract final class GodHandMastery {
  static const List<(String id, String label, int needLevel, int needCd)>
  milestones = <(String, String, int, int)>[
    ('gh_dmg_5', 'Hand of Embers', 5, 0),
    ('gh_cd_4', 'Swift Smash', 0, 4),
    ('gh_smash_100', 'Hundred Blows', 0, 0),
  ];

  static const int smashMilestone = 100;

  static bool ready(GameState state, String id) {
    if (state.metaDepth.claimedGodHandMastery.contains(id)) return false;
    return switch (id) {
      'gh_dmg_5' => state.godHandLevel >= 5,
      'gh_cd_4' => state.metaDepth.godHandCdLevel >= 4,
      'gh_smash_100' => state.metaDepth.godHandSmashCount >= smashMilestone,
      _ => false,
    };
  }

  /// Progress crumb for KEEP list (always visible).
  static String progressLabel(GameState state, String id) => switch (id) {
        'gh_dmg_5' => 'Hand ${state.godHandLevel}/5',
        'gh_cd_4' => 'CD ${state.metaDepth.godHandCdLevel}/4',
        'gh_smash_100' =>
          'Smash ${state.metaDepth.godHandSmashCount}/$smashMilestone',
        _ => '',
      };

  static GameState claim(GameState state, String id) {
    if (!ready(state, id)) return state;
    final titles = List<String>.from(state.metaDepth.titles);
    final label = milestones.firstWhere((m) => m.$1 == id).$2;
    if (!titles.contains(label)) titles.add(label);
    return state.copyWith(
      essence: state.essence + 12,
      metaDepth: state.metaDepth.copyWith(
        claimedGodHandMastery: [...state.metaDepth.claimedGodHandMastery, id],
        titles: titles,
      ),
    );
  }

  static GameState noteSmash(GameState state) => state.copyWith(
    metaDepth: state.metaDepth.copyWith(
      godHandSmashCount: state.metaDepth.godHandSmashCount + 1,
    ),
  );
}
