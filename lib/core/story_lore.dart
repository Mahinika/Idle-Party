import '../models/dungeon_def.dart';
import 'ascend_roadmap.dart';
import 'game_logic.dart';

/// Short fiction lines for Idle Party — no dialogue trees, just flavor
/// on existing UI rails (intro, hub, toasts, ascend).
abstract final class StoryLore {
  static const String introTagline = 'Your party fights while you watch.';

  static const String introSubline =
      'Tap to help. Grow stronger. No other game required.';

  /// Cold-start beats before CONTINUE / NEW GAME. Short, skippable.
  static const introBeats = <({String title, String body})>[
    (
      title: 'IDLE PARTY',
      body: 'Your heroes fight on their own while you watch.',
    ),
    (
      title: 'THE CAVE',
      body: 'Send them into a dungeon. They clear rooms and pick up loot.',
    ),
    (
      title: 'YOUR JOB',
      body: 'Tap the map to help. Grow the party. Beat the first boss.',
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
      'goblin' => "Torches in the Hideout. They know you're coming.",
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
      'goblin' => 'The Lord is broken. The wound still hums.',
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
    final rewardLine = milestoneBonus > 0
        ? '+${rewardEssence}e (+${milestoneBonus}e milestone) · AL → $nextAl'
        : '+${rewardEssence}e · AL → $nextAl';
    final alPower =
        'AL power: +${GameLogic.alAttackPerLevel} ATK · '
        '+${GameLogic.alDefensePerLevel} DEF · '
        '+${GameLogic.alVitalityPerLevel} STA · +10% gold';
    final blessAtk = blessingsAfter * GameLogic.ascendBlessingAtk;
    final blessDef = blessingsAfter * GameLogic.ascendBlessingDef;
    final blessVit = blessingsAfter * GameLogic.ascendBlessingVit;
    final blessGold = blessingsAfter * GameLogic.ascendBlessingGoldPct;
    final blessLine =
        'Blessing: +${GameLogic.ascendBlessingAtk} ATK · +${GameLogic.ascendBlessingDef} DEF · '
        '+${GameLogic.ascendBlessingVit} STA · +${GameLogic.ascendBlessingGoldPct}% gold '
        '(total ×$blessingsAfter: +$blessAtk ATK · +$blessDef DEF · +$blessVit STA · +$blessGold% gold)';
    final thisUnlock = AscendRoadmap.unlockLineForAscendTo(nextAl);
    final unlockLine = unlockCombatRogue
        ? '\nUnlock: Combat Rogue (Shade) joins the roster.'
        : (thisUnlock != null ? '\n$thisUnlock' : '');
    final ahead = AscendRoadmap.nextGoalLine(nextAl);
    return 'You grow stronger — then start a fresh run.\n\n'
        '$rewardLine\n'
        '$alPower\n'
        '$blessLine$unlockLine\n'
        '$ahead\n\n'
        'Keep: hero levels/XP, essence, relics, pets, sanctuary, '
        'God Hand, Apex, meta unlocks.\n'
        'Reset: wallet gold, floors, run gear, loadouts, forge gold upgrades.\n'
        'God Hand Lv$godHandLevel kept';
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
    return 'Reborn · AL$al$bless$unlockBit$mile';
  }

  static const String shadeJoins = 'Shade the Rogue answers the call.';

  static const String loreTipTitle = 'THE ROAD';
  static const String loreTipBody =
      'More caves wait after this one. Beat bosses to open the road. '
      'Later you can Ascend — a fresh run that keeps hero levels.';
}
