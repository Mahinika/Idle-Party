import '../models/dungeon_def.dart';
import 'ascend_roadmap.dart';
import 'game_logic.dart';

/// Short fiction lines for Idle Party — no dialogue trees, just flavor
/// on existing UI rails (intro, hub, toasts, ascend).
abstract final class StoryLore {
  static const String introTagline = 'Your party fights while you watch.';

  static const String introSubline =
      'Tap to help. Grow stronger. No other game required.';

  static const String studioName = 'Cognifox Studio';

  /// First-launch cave beat after the Cognifox card. Returning saves skip this.
  static const introBeats = <({String title, String body})>[
    (
      title: 'IDLE PARTY',
      body: 'They fight without you. Send them in. Tap the fight to help.',
    ),
  ];

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
      'goblin' =>
          'Torches in the Hideout. Stolen stashes everywhere — they know you are coming.',
      'king' => "The Fort's banners hang wrong. Press on.",
      'underworld' => 'No sky here. Only watching.',
      'dead' => 'Footsteps echo where no one walks.',
      'hell' => "Hell's Gate breathes heat. Do not linger.",
      'crystal' => 'The Spire sings. Climb anyway.',
      'tide' => 'Salt water fills the hold. Hold your breath.',
      'ember' => 'Ash drifts in the vault. The crown still smolders.',
      'grove' => 'Roots tighten. Something old watches between the trunks.',
      'storm' =>
        'Wind screams through the hollow. Lightning answers every step.',
      'rime' =>
        'The wind dies. Rimeglass sings underfoot — cold enough to cut.',
      'fen' => 'The ice sweats. Bile water pools where the cold used to sing.',
      'brass' => 'The mire drains through brass grates. Something still ticks.',
      'veil' => 'Brass ticks fade. Moth-dust fills the hollow.',
      _ => 'Entering ${def.name}…',
    };
  }

  static String dungeonCleared(String dungeonId) {
    final def = DungeonCatalog.byId(dungeonId);
    return switch (dungeonId) {
      'sandy' => '${def.bossName} falls. The sand goes quiet.',
      'goblin' =>
          'The Lord is broken. The wound still hums — and the stashes are yours.',
      'king' => 'The crown cracks. Deeper still.',
      'underworld' => 'The Beholder closes. For now.',
      'dead' => 'The No-One fades. Names return briefly.',
      'hell' => 'Cthulhu sinks. The Gate stays ajar.',
      'crystal' => 'The Warden yields. Ascension waits in the hub.',
      'tide' => 'The Leviathan sinks. Pressure eases — briefly.',
      'ember' => 'The Sovereign cools. Embers still whisper.',
      'grove' => 'Wyrd Root stills. The grove exhales moss and quiet.',
      'storm' => 'The Tyrant breaks. Thunder rolls away into quiet.',
      'rime' =>
        'The Colossus cracks. Frost settles — the rift holds its breath.',
      'fen' => 'The Hydra sinks. The mire keeps bubbling.',
      'brass' => 'The Mainspring stills. Cogs keep ticking in the dark.',
      'veil' => 'The Pale Monarch folds. Silk still drifts.',
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
    int blessingsAfter = 1,
    bool unlockCombatRogue = false,
  }) {
    final gain =
        'You get AL$nextAl, +${rewardEssence}e, and a stronger Blessing'
        '${blessingsAfter > 1 ? ' (×$blessingsAfter)' : ''}.';
    final stay =
        'Party levels and open caves stay. Gold, bag, and GOLD tracks reset.';
    final kits = AscendRoadmap.kitUnlockSummary(nextAl, maxNames: 3);
    final String? neu;
    if (unlockCombatRogue) {
      neu = 'New: Combat Rogue joins the roster.';
    } else if (nextAl == 2 && kits != null) {
      neu = 'New kits: $kits. 5th party slot in ESSENCE.';
    } else if (kits != null) {
      neu = 'New kits: $kits.';
    } else {
      neu = null;
    }
    // milestoneBonus / godHandLevel still passed from the dialog; payoff is
    // already in [rewardEssence], God Hand is part of “party stays.”
    assert(milestoneBonus >= 0 && godHandLevel >= 0);
    return neu == null ? '$stay\n\n$gain' : '$stay\n\n$gain\n\n$neu';
  }

  static String ascendToast({
    required int al,
    required int milestoneBonus,
    int blessings = 0,
  }) {
    // Keep short — hub toast is 2–3 lines; detail lives in Ascend confirm.
    final bless = blessings > 0 ? ' · Blessing ×$blessings' : '';
    final unlock = AscendRoadmap.unlockAtAl(al);
    final unlockBit = unlock != null ? ' · $unlock' : '';
    final mile = milestoneBonus > 0 ? ' · +${milestoneBonus}e' : '';
    return 'Ascended · AL$al$bless$unlockBit$mile';
  }

  static String rebornConfirmBody({
    required int rewardEssence,
    required int godHandLevel,
    required int blessings,
  }) {
    assert(godHandLevel >= 0);
    return 'AL stays ${GameLogic.maxAscensionLevel}. Blessing stays ×$blessings.\n\n'
        'Party levels and open caves stay. Gold, bag, and GOLD tracks reset.\n\n'
        'You get +${rewardEssence}e and 1 STAR NODES point.\n\n'
        'Rebuild the bag by looting.';
  }

  static String rebornToast({required int essence}) {
    return 'Reborn · bag reset · +${essence}e';
  }

  static const String shadeJoins = 'Shade the Rogue answers the call.';

  static const String loreTipTitle = 'THE ROAD';
  static const String loreTipBody =
      'More caves wait after this one. Beat bosses to open the road. '
      'Later you can Ascend — same party, empty bag, stronger Blessing.';
}
