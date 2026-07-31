import '../models/dungeon_def.dart';

/// Short fiction lines for Idle Party — no dialogue trees, just flavor
/// on existing UI rails (intro, hub, toasts, ascend).
abstract final class StoryLore {
  static const String introTagline =
      'A party that fights while you watch.';

  static const String introSubline =
      'You are the distant will. Guide them into the deep.';

  /// Hub / catalog one-liners keyed by dungeon id.
  static String dungeonBlurb(String dungeonId) {
    final def = DungeonCatalog.byId(dungeonId);
    if (def.blurb.isNotEmpty) return def.blurb;
    return 'Another gate on the long descent.';
  }

  static String enterDungeon(String dungeonId) {
    final def = DungeonCatalog.byId(dungeonId);
    return switch (dungeonId) {
      'sandy' => 'The caverns open. Aegis takes the lead.',
      'goblin' => "Torches in the Hideout. They know you're coming.",
      'king' => "The Fort's banners hang wrong. Press on.",
      'underworld' => 'No sky here. Only watching.',
      'dead' => 'Footsteps echo where no one walks.',
      'hell' => "Hell's Gate breathes heat. Do not linger.",
      'crystal' => 'The Spire sings. Climb anyway.',
      _ => 'Entering ${def.name}…',
    };
  }

  static String dungeonCleared(String dungeonId) {
    final def = DungeonCatalog.byId(dungeonId);
    return switch (dungeonId) {
      'sandy' => '${def.bossName} falls. The sand goes quiet.',
      'goblin' => 'The Lord is broken. The wound still hums.',
      'king' => 'The crown cracks. Deeper still.',
      'underworld' => 'The Beholder closes. For now.',
      'dead' => 'The No-One fades. Names return briefly.',
      'hell' => 'Chtulu sinks. The Gate stays ajar.',
      'crystal' => 'The Warden yields. Ascension waits in the hub.',
      _ => '${def.name} cleared.',
    };
  }

  static String unlockedNextZone(String newDungeonId) {
    final def = DungeonCatalog.byId(newDungeonId);
    return 'A new gate: ${def.name}.';
  }

  static String dailyRun(String dungeonId) {
    final def = DungeonCatalog.byId(dungeonId);
    return "Daily echo — ${def.name}. Clear 1 floor · +25e";
  }

  static String ascendConfirmBody({
    required int rewardEssence,
    required int nextAl,
    int milestoneBonus = 0,
    int godHandLevel = 0,
    int soulboundFragments = 0,
  }) {
    final rewardLine = milestoneBonus > 0
        ? 'Reward: +${rewardEssence}e (+${milestoneBonus}e milestone) · AL → $nextAl'
        : 'Reward: +${rewardEssence}e · AL → $nextAl';
    return 'The will withdraws and returns stronger.\n'
        'Reset this run (gear, levels, stash, floor).\n'
        'Keep essence, relics, pets, sanctuary, soulbound, God Hand.\n\n'
        '$rewardLine\n'
        'God Hand Lv$godHandLevel kept · $soulboundFragments soulbound frag';
  }

  static String ascendToast({
    required int al,
    required int milestoneBonus,
  }) {
    final base = 'Reborn · AL$al';
    if (milestoneBonus > 0) {
      return '$base · +${milestoneBonus}e milestone';
    }
    return base;
  }

  static const String shadeJoins =
      'Shade the Rogue answers the call.';

  static const String loreTipTitle = 'THE DESCENT';
  static const String loreTipBody =
      'Seven gates. One wrongness below. Clear deeper zones, then Ascend.';
}
