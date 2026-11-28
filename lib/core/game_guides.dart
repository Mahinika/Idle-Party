import 'ad_boost.dart';
import 'ashen_crown.dart';
import 'game_logic.dart';
import 'game_state.dart';
/// In-game guide copy for MENU → INFO.
abstract final class GameGuides {
  /// Early topics before the first boss (plain chrome).
  static const Set<String> firstHourTopicIds = {
    'basics',
    'away',
    'combat',
    'party',
    'bag_equip',
    'world_path',
  };

  /// KEY / Gauntlet / Rift / Ashen — MENU → INFO hides these until party max.
  static const Set<String> endgameTopicIds = {
    'gauntlet',
    'rift',
    'greater_rift',
    'ashen_crown',
    'hardmode',
  };

  /// AL20 VS ENDGAME: only when the split actually matters.
  static bool showEndgameBridgeGuides(GameState state) {
    if (GameLogic.endgameUnlocked(state)) return true;
    if (GameLogic.isMaxAscension(state)) return true;
    final heroes = state.heroes;
    if (heroes.isEmpty) return false;
    var minLv = heroes.first.level;
    for (final h in heroes) {
      if (h.level < minLv) minLv = h.level;
    }
    return minLv >= GameLogic.maxHeroLevel - 20;
  }

  static List<GuideTopic> topicsFor(GameState state) {
    if (GameLogic.plainPlayerChrome(state)) {
      return [
        for (final t in topics)
          if (firstHourTopicIds.contains(t.id))
            switch (t.id) {
              'basics' => _firstHourBasics,
              'combat' => _firstHourCombat,
              'party' => _firstHourParty,
              'bag_equip' => _firstHourBagEquip,
              'world_path' => _firstHourWorldPath,
              _ => t,
            },
      ];
    }
    if (GameLogic.endgameUnlocked(state)) return topics;
    final bridge = showEndgameBridgeGuides(state);
    return [
      for (final t in topics)
        if (_visibleMidgame(t.id, state: state, bridge: bridge))
          _midgameCopy(t, state),
    ];
  }

  static bool _visibleMidgame(
    String id, {
    required GameState state,
    required bool bridge,
  }) {
    if (endgameTopicIds.contains(id)) return false;
    if (id == 'gates') return bridge;
    if (id == 'constellation') return GameLogic.isMaxAscension(state);
    if (id == 'daily' && !GameLogic.showDailyRunOnHub(state)) return false;
    return true;
  }

  static GuideTopic _midgameCopy(GuideTopic t, GameState state) =>
      switch (t.id) {
        'basics' => _midgameBasics,
        'world_path' => _midgameWorldPath,
        'dailies' =>
          GameLogic.showDailyRunOnHub(state) ? _midgameDailies : _dayTwoDailies,
        'classes' => _midgameClasses,
        'ascend' => _midgameAscend,
        'weekly' =>
          GameLogic.showDailyRunOnHub(state) ? _midgameWeekly : _dayTwoWeekly,
        'jobs' => _midgameJobs,
        'daily' => _midgameDaily,
        'apex' => _midgameApex,
        'constellation' => _midgameConstellation,
        _ => t,
      };

  /// Day-one BASICS: how to play, not the meta syllabus.
  static const GuideTopic _firstHourBasics = GuideTopic(
    id: 'basics',
    title: 'BASICS',
    body:
        'You have a small party of heroes. They fight on their own.\n\n'
        '• Tap ENTER DUNGEON to start the first cave (Sandy Caverns).\n'
        '• Watch them clear rooms. Long-press the fight, or tap the fist, when you want to help.\n'
        '• The hunt line on the hub always names the next job — start there.\n'
        '• A number on GEAR means better items wait in BAG.\n'
        '• Starter roles: Tank, Healer, DPS. You do not need another RPG.',
  );

  static const GuideTopic _firstHourWorldPath = GuideTopic(
    id: 'world_path',
    title: 'WORLD PATH',
    body:
        'The hub map is the World Path. Start at Sandy Caverns on the dune coast.\n\n'
        '• Tap a cave, then ENTER DUNGEON.\n'
        '• Caves sit in different lands on one map — no scrolling the board.\n'
        '• New caves open as the party grows (mean level) or when you clear '
        'the one before. Gold does not unlock caves.\n'
        '• Locked caves sit dim. The caption under the map shows party level '
        'progress (have / need).\n'
        '• Boss floor is shown under your party name (Boss on F n).',
  );

  static const GuideTopic _firstHourCombat = GuideTopic(
    id: 'combat',
    title: 'COMBAT',
    body:
        'Each floor is a few rooms. The party walks and fights on its own.\n\n'
        '• Clear a room to open the next.\n'
        '• When enemies are down, loot banks and they walk to the stairs.\n'
        '• Long-press the fight, or tap the fist, when you want to smash and steer.\n'
        '• HP strip is bottom-left — tap a hero for their abilities.\n'
        '• Target chip is top-right (name + HP).',
  );

  static const GuideTopic _firstHourParty = GuideTopic(
    id: 'party',
    title: 'PARTY',
    body:
        'Your party is three roles: Tank (soaks hits), Healer (keeps people up), '
        'and DPS (kills enemies).\n\n'
        '• Easy start: one of each. You do not need another RPG.\n'
        '• Tap a hero in the HUD for abilities. Chips show when a skill is ready.\n'
        '• The strip shows level so growth is visible mid-fight.\n'
        '• Flask heals the party when you have a potion.',
  );

  static const GuideTopic _firstHourBagEquip = GuideTopic(
    id: 'bag_equip',
    title: 'BAG & GEAR',
    body:
        'Loot drops on the floor, then goes to BAG.\n\n'
        '• A number on GEAR means better items wait — open BAG and tap EQUIP BEST.\n'
        '• BAG: view stash. EQUIP BEST wears the better pieces, only when you tap it. '
        'SELL JUNK sells what FILTERS match, for gold.\n'
        '• FILTERS (when the bag is filling): auto-sell weak drops for gold.\n'
        '• Compare AP / Armor / STA. Worn pieces you replace go back to the bag.',
  );

  /// After first boss, before first Ascend — one daily job, not three dailies.
  static const GuideTopic _dayTwoDailies = GuideTopic(
    id: 'dailies',
    title: 'TODAY\'S CLEAR',
    body:
        'Come back each day and clear one cave.\n\n'
        '• Tap ENTER DUNGEON and beat a floor.\n'
        '• The hunt names that cave and where the prize is spent: CAMP, TRAIN, RELICS, or SCROLLS.\n'
        '• Then CLAIM VAULT for essence + 1 Cinder.\n'
        '• That claim also pays Check-in. Days 1–6 are a large prize. '
        'Day 7 is a jackpot. A missed day does not reset the row.\n'
        '• After the claim, the hunt names tomorrow\'s cave. '
        'The party keeps fighting while the app is closed.',
  );

  static const GuideTopic _dayTwoWeekly = GuideTopic(
    id: 'weekly',
    title: 'DAILY VAULT',
    body:
        'One dungeon clear fills today\'s Daily Vault, then CLAIM VAULT '
        'for essence + 1 Cinder, plus Check-in '
        '(days 1–6 a large prize, day 7 a jackpot; a missed day does not reset the row).\n\n'
        '• The hub hunt names this job until you claim.\n'
        '• First Daily Vault claim of each calendar month also pays a season bonus.\n'
        '• Daily Vault resets at midnight.\n'
        '• The hub hunt and offline Up next share the same job.',
  );

  /// After first boss, before party max level — no KEY / ENDGAME syllabus.
  static const GuideTopic _midgameBasics = GuideTopic(
    id: 'basics',
    title: 'BASICS',
    body:
        'You have a small party of heroes. They fight on their own.\n\n'
        '• Tap ENTER DUNGEON to start (or continue) a cave.\n'
        '• Watch them clear rooms. Long-press the fight, or tap the fist, when you want to help.\n'
        '• The hunt line on the hub always names the next job — start there.\n'
        '• Bottom tabs (same bar in hub and dungeon): GEAR, GOLD (tracks + '
        'market), SHOP (ad-free, Long Away, Supporter), ESSENCE (tracks / '
        'lasting buys / Embers relics / pets), MORE. QUESTS and Craft live as rows '
        'inside MENU when they unlock.\n'
        '• In a dungeon the sixth slot is LEAVE (back to hub).\n'
        '• Gold buys supplies and run power. Essence buys lasting CAMP power; '
        'relics use Embers and Cinders.\n'
        '• Four currencies: gold (run power, resets on Ascend), essence '
        '(lasting power), Embers (relics; from bosses and Ascend), Cinders '
        '(Daily Vault and Ad Tickets; bag space, eggs, relic trades).\n'
        '• A number on a button means something waits inside — GEAR 3 means '
        '3 better items for the party. No number means nothing to do there.\n'
        '• Menus stay small at the start; more tabs appear as you unlock them.\n'
        '• You do not need to have played another RPG. Names like PROT / DISC / FIRE '
        'are just the three starter roles: Tank, Healer, DPS.',
  );

  static const GuideTopic _midgameWorldPath = GuideTopic(
    id: 'world_path',
    title: 'WORLD PATH',
    body:
        'The hub World Path is one continent map: dunes (Sandy / Goblin), crownlands '
        '(King’s Fort), the Underworld, frost (Crystal Spire / Rimeglass), tide isles (Tidehold), blight '
        '(City of Dead / Blightfen), ash (Hell’s Gate / Ashen Vault), Hollow Grove, '
        'Stormwake, Brassvault, and Mothveil in the east.\n\n'
        '• Tap a zone portrait to select it — the whole map fits on the hub.\n'
        '• The selected zone is HERE; the next unlocked uncleared zone is NEXT. Other rings stay unlabeled so the path stays readable.\n'
        '• Unlock the next zone by clearing the previous boss, or when your '
        'party mean level reaches that zone’s gate (even steps from Lv1 on '
        'Sandy Caverns through Lv100 on Mothveil).\n'
        '• Zones unlock by party mean level or prior clear — gold does not unlock them. '
        'Later party-max hunts need every active hero at Lv${GameLogic.maxHeroLevel} '
        '(mean alone is not enough).\n'
        '• Locked zones dim on the map; the caption under the map shows '
        'party level progress (have / need).\n'
        "• Goblin's Hideout: stolen-stash chests pay better gold but wake ambush guards.\n"
        '• Boss floor is shown under your party name (Boss on F n).',
  );

  static const GuideTopic _midgameDailies = GuideTopic(
    id: 'dailies',
    title: 'THREE DAILIES',
    body:
        'Three different systems — not the same button:\n\n'
        '• Daily Vault — day on the hub hunt. One PUSH floor fills it '
        '(FARM does not, including a FARM boss). Then CLAIM VAULT for essence + 1 Cinder.\n'
        '• Daily Run — one free seeded floor scaled from yesterday\'s PUSH '
        '(hub DAILY RUN) for +25e base; Dawn Tithe can add more. Separate from the vault.\n'
        '• Quests — MENU · QUESTS board (Daily / Bounty / Side / Week / Contract). '
        'CLAIM QUESTS on the hub hunt when rewards are ready.\n\n'
        'The hub hunt always picks one job. Vault reset and Daily Run reset at midnight. '
        'Daily Run unlocks after your first Ascend (or when every active hero hits max level). '
        'Before that, the hub hunt stays on Grow the party / one cave today.',
  );

  static const GuideTopic _midgameClasses = GuideTopic(
    id: 'classes',
    title: 'SPECIALIZATION UNLOCKS',
    body:
        'Ascend grows your roster — the hub hunt and Ascend teasers name the next specializations '
        'with a short fantasy line plus a Watch… combat hook.\n\n'
        '• AL1: Alleyblade, Greatblade, Dawnward\n'
        '• AL2: Packbond, Hymnward, Prismcast · 5th party slot '
        '(ESSENCE lasting buys · 80e)\n'
        '• AL3: Oathwall, Venomcut, Tidecall, Glacecast, Bloomward\n'
        '• AL4: Snarebow, Stormcall, Totemstrike, Moonweft, Clawdance\n'
        '• AL5: Graveward, Rimeblade, Barkwall\n'
        '• AL6: Hexrot, Pactimp\n\n'
        'Some specializations also unlock from zone clears or ESSENCE lasting buys — see each '
        'spec’s unlock hint in GEAR → ROSTER.',
  );

  static const GuideTopic _midgameAscend = GuideTopic(
    id: 'ascend',
    title: 'ASCEND',
    body:
        'Ascend = prestige: same heroes and zones, empty bag, gold, GOLD tracks, '
        'and floor progress, stronger lasting Blessing. Not the same as party '
        'max-level hunts.\n\n'
        'Claim Ascend in the hub when ready (AL1–AL20) — same party, empty bag, '
        'gold, GOLD tracks, and floor progress, stronger Ascend Blessing.\n\n'
        '• AL20 is the Ascension cap. More content unlocks when every active hero '
        'reaches level 100 — not from AL20 alone.\n'
        '• Each Ascend grants a lasting Ascend Blessing: +5 AP · +20 Armor · +60 STA · '
        '+8% gold (stacks forever). See ESSENCE lasting buys. Separate from Star Nodes.\n'
        '• Confirm / toast show the next unlock (Alleyblade, 5th slot…).\n'
        '• Also raises Ascension Level (AL: +AP/STA/Armor and +10% gold per level) and pays essence.\n'
        '• Keep: hero levels/XP, open zones, essence, Embers, Cinders, relics, CAMP, '
        'pets, God Hand, Apex, soulbound gear, shop buys, ad tickets, Star Nodes, '
        'settings, unlocked specs, 5th party slot, lifetime gold, constellation / meta season.\n'
        '• Reset: wallet gold, TRAIN under the fight, bag and worn drops, market, floor height '
        '(starter gear back on).\n'
        '• Boss victories toward the next Ascend clear. Ascend also pays Embers.\n'
        '• At AL20, ESSENCE lasting buys offer optional REBORN (same bag wipe, AL stays 20, '
        'no extra Ascend Blessing). The hub hunt never nags you to press it.',
  );

  static const GuideTopic _midgameWeekly = GuideTopic(
    id: 'weekly',
    title: 'DAILY VAULT',
    body:
        'Three different dailies:\n'
        '• Daily Vault — one PUSH clear (FARM does not count), then CLAIM VAULT '
        'for essence + 1 Cinder.\n'
        '• Daily Run — one free seeded floor scaled from yesterday\'s PUSH '
        'for +25e base; Dawn Tithe can add more (hub DAILY RUN).\n'
        '• Quests — Daily / Bounty / Side / Week / Contract board; '
        'CLAIM QUESTS when ready.\n\n'
        '• Early on: the hub hunt tells you to grow the party in the starter zone. '
        'Daily Run waits until your first Ascend (or when every active hero hits max level). '
        'Vault-start waits until you have beaten a boss (or Ascended).\n'
        '• Fill today’s Daily Vault with one PUSH clear (not a FARM loop), then claim '
        'essence + 1 Cinder.\n'
        '• CLAIM VAULT pays the timed-key essence table, plus Dawn Tithe, plus enough for one CAMP upgrade, '
        'plus 1 Cinder, plus Check-in (days 1–6 a large prize, day 7 a jackpot; a missed day does not reset the row). First claim of each calendar month also pays a season bonus.\n'
        '• The hub hunt and offline Up next share one chase (claim → READY → '
        'ALMOST → grind) — same title whether you are in the hub or returning from AFK.\n'
        '• Welcome-back says where you were: hub gold fills for 12 hours (24 with Long Away), then stops (essence after 10 min); '
        'mid-dungeon = party kept fighting with AFK assist. Then one wow line, '
        'a few highlights, then Up next.\n'
        '• The hub hunt flashes READY / ALMOST when a claim or Ascend is close.\n'
        '• midnight resets Daily Vault and Daily Run (not the ISO week goal).',
  );

  static const GuideTopic _midgameJobs = GuideTopic(
    id: 'jobs',
    title: 'QUESTS',
    body:
        'QUESTS.\n\n'
        '• Five slots: Daily (kill), Bounty (kill ladder), Side '
        '(bosses, elites, floors, or gold), Week (ISO-week goal), '
        'Contract (big goal).\n'
        '• Daily returns next day after you claim; Week returns next ISO week.\n'
        '• Bounty ladder climbs as you grow; top rung repeats.\n'
        '• Every 3rd quest claimed adds +5 essence.\n'
        '• MENU · QUESTS (or the badge on MENU) when claims are ready.\n'
        '• Hub CLAIM QUESTS claims ready rewards from the hub hunt line.\n'
        '• The dungeon top CLAIM chip claims all ready quests at once '
        '(visible in combat too; long-press opens the list).\n'
        '• QUESTS is a MENU board — not a PATH cave.',
  );

  static const GuideTopic _midgameDaily = GuideTopic(
    id: 'daily',
    title: 'DAILY RUN',
    body:
        'A free one-floor Daily Run on the hub — separate from Daily Vault and Quests.\n\n'
        '• Floor scales from yesterday\'s best PUSH clear (+1), so it stays a stretch.\n'
        '• Unlocks after your first Ascend (or when every hero hits max level) — before that, '
        'the hub hunt focuses on growing the party / one cave today.\n'
        '• After it unlocks, the hub hunt may chase Ascend, zones, Daily Vault, or '
        'Daily Run — one hunt at a time.\n'
        '• Clear the floor for +25e base; Dawn Tithe can add more. Then return to hub.\n'
        '• May let you visit a locked zone for the day.\n'
        '• Claim once per day — not the same as CLAIM VAULT.',
  );

  static const GuideTopic _midgameApex = GuideTopic(
    id: 'apex',
    title: 'CRAFT',
    body:
        'MENU → CRAFT.\n\n'
        '• Tap a party hero, then a slot — recipe and CRAFT / UPGRADE sit under that.\n'
        '• Tap a recipe mat to lock the farm target (meter sits on the recipe).\n'
        '• Zone Shards are a pool: any dungeon boss shard pays the recipe.\n'
        '• Materials and vault stay collapsed. Other classes is only for specializations not in the party.\n'
        '• Opening CRAFT saves the party goal so the meter runs. Every boss fills it '
        '(PUSH faster than FARM) and grants the target, from any cave.\n'
        '• Apex Slag drops from Crystal Spire bosses. The meter can still grant slag once it is the target.\n'
        '• Craft weapon R1 first, then armor; the button shows CRAFT R1 or the real upgrade rank.\n'
        '• Apex secondaries: DPS Crit + Haste; healers Mp5 + Crit + Haste.\n'
        '• Crafted gear and materials survive Ascend.',
  );

  static const GuideTopic _midgameConstellation = GuideTopic(
    id: 'constellation',
    title: 'STAR NODES',
    body:
        'At AL20, ESSENCE lasting buys open Star Nodes (spend points).\n\n'
        '• Not the same as Ascend Blessing stacks (+AP/Armor/STA/gold each Ascend).\n'
        '• Reaching AL20 grants 3 points. Earn more from Ashen Crown, Craft Trial, and REBORN.\n'
        '• Spend points on permanent nodes (crit, gold, block, …) — '
        'that is real combat power, shown on the node.\n'
        '• Points and lit nodes survive Ascend / REBORN.',
  );

  static final topics = <GuideTopic>[
    GuideTopic(
      id: 'basics',
      title: 'BASICS',
      body:
          'You have a small party of heroes. They fight on their own.\n\n'
          '• Tap ENTER DUNGEON; long-press the fight or tap the fist to help.\n'
          '• Hub hunt names the next job. Tabs: GEAR, GOLD, SHOP, ESSENCE, MENU (QUESTS/CRAFT inside).\n'
          '• Gold (run power), essence (CAMP / lasting buys), Embers (relics), Cinders (vault / bag trades).\n'
          '• In dungeons: GEAR · GOLD · SHOP · ESSENCE · MENU · LEAVE. KEY joins at party max.\n'
          '• Badge numbers mean something waits inside. PROT / DISC / FIRE = Tank / Healer / DPS.',
    ),
    GuideTopic(
      id: 'away',
      title: 'AWAY',
      body:
          'The party keeps going when you close the app.\n\n'
          '• In a cave, they keep fighting while the app is closed.\n'
          '• On the hub, gold gathers while you are away.\n'
          '• Come back and you will see Welcome back.\n'
          '• After the first boss, the hub names tomorrow\'s cave and where to spend the prize: CAMP, TRAIN, or SCROLLS.',
    ),
    GuideTopic(
      id: 'dailies',
      title: 'THREE DAILIES',
      body:
          'Three different systems — not the same button:\n\n'
          '• Daily Vault — day on the hub hunt. One PUSH floor fills it '
          '(FARM does not). Or time KEY +2. Or a Gauntlet clear. Then CLAIM VAULT '
          'for essence + 1 Cinder.\n'
          "• Daily Run — one free seeded floor scaled from yesterday's PUSH "
          '(hub DAILY RUN) for +25e base; Dawn Tithe can add more. Separate from the vault.\n'
          '• Quests — MENU · QUESTS board (Daily / Bounty / Side / Week / Contract). '
          'CLAIM QUESTS on the hub hunt when rewards are ready.\n\n'
          'The hub hunt always picks one job. Vault reset and Daily Run reset at midnight. '
          'Daily Run unlocks after your first Ascend (or endgame). Before that, the hub hunt '
          'stays on Grow the party / one cave today.',
    ),
    GuideTopic(
      id: 'powerups',
      title: 'SCROLLS',
      body:
          'Tap SCROLLS under the party in a run, or in MENU in town (after first boss).\n\n'
          '• TIP A FRIEND: 10 Ad Tickets per friend (up to 30 friends).\n'
          '• Tickets buy timed scrolls: +${AdBoost.attackPercent}% ATK, ×${AdBoost.goldMul} gold, '
          '+${AdBoost.xpPercent}% XP (${AdBoost.splitHours}h each · 1 ticket).\n'
          '• Scroll of Battle: AP + gold for ${AdBoost.hoursPerAd}h (2 tickets) — best value.\n'
          '• Time stacks to 24h per scroll. Ads never pop up mid-fight.\n'
          '• Tickets and remaining time survive Ascend.',
    ),
    GuideTopic(
      id: 'world_path',
      title: 'WORLD PATH',
      body:
          'The hub World Path is one continent map — tap a zone, then ENTER DUNGEON.\n\n'
          '• Unlock by prior boss clear or party mean level (gold does not unlock zones).\n'
          '• Endgame hunts need every active hero at Lv${GameLogic.maxHeroLevel} (mean alone is not enough).\n'
          '• ENDGAME tab when every hero is ≥Lv80 opens Gauntlet, Ranked GR, Farm Rift, Ashen.\n'
          '• Caption under the map shows party level progress (have / need). Boss on F n under the party.\n'
          '• Goblin\'s Hideout chests pay more gold but can wake ambush guards.',
    ),
    GuideTopic(
      id: 'combat',
      title: 'COMBAT',
      body:
          'Each floor is a few rooms; the party fights and walks on their own.\n\n'
          '• Clear rooms — loot banks, then walk to STAIRS. Corner chip says CLEAR.\n'
          '• Long-press the fight or tap the fist for God Hand help.\n'
          '• Party HP strip bottom-left; target chip top-right (name + HP).\n'
          '• Boss tells (WAVE, SLAM, …) telegraph big hits — elites may hide a chest.\n'
          '• SETTINGS VFX: Full / Lite / Minimal — God Hand still shows on Minimal.',
    ),
    GuideTopic(
      id: 'god_hand',
      title: 'GOD HAND',
      body:
          'Long-press the fight, or tap the fist, to smash enemies and steer the party.\n\n'
          '• Cooldown ring top-right; ESSENCE → BLESSING upgrades damage and CD.\n'
          '• BAL / FOCUS / WIDE trade damage vs radius.\n'
          '• Mastery titles: Hand of Embers (Lv5), Swift Smash (CD 4), Hundred Blows (100 smashes).\n'
          '• Spellcraft (MENU → SETTINGS) adds a small party-wide ability damage bonus.\n'
          '• Essence upgrades survive Ascend.',
    ),
    GuideTopic(
      id: 'farm_push',
      title: 'FARM / PUSH',
      body:
          'Toggle at the top of the dungeon view (FARM / PUSH).\n\n'
          '• FARM (loop): after clearing, stay on the same floor for more loot/gold.\n'
          '• On a floor you already cleared, FARM can run 1×, 2×, or 4× packs with '
          'matching gold and XP (TRY once if a tier is still locked).\n'
          '• PUSH (climb): after clearing, advance to the next floor toward the boss. '
          'PUSH floor clear pays +1 essence, boss +2 — FARM pays 0 essence.\n'
          '• Use Floor −1 / +1 in the floor menu to travel when allowed.',
    ),
    GuideTopic(
      id: 'party',
      title: 'PARTY & ROSTER',
      body:
          'Your party is three jobs: Shield, Healer, and Damage.\n\n'
          '• GEAR → ROSTER swaps who fights (4 slots; 5th unlocks later).\n'
          '• Easy start: Shieldwall, Aegislight, Cinderweft — more specs unlock with Ascend.\n'
          '• Tap a hero for abilities; chips show cooldowns. Strip shows level + XP.\n'
          '• Rage / Mana / Energy / Runic fuel specialization skills.\n'
          '• Flask heals when you carry a potion. Roster levels keep on Ascend; gold resets.',
    ),
    GuideTopic(
      id: 'bag_equip',
      title: 'BAG & GEAR',
      body:
          'Loot drops on the floor, then goes to your stash (BAG).\n\n'
          '• GEAR badge → open BAG. EQUIP BEST wears upgrades; Dual-wield is '
          'Cutpurse / Twinrage / Totemstrike / Rimeblade.\n'
          '• FILTERS matches auto-sell and disassemble rules; SELL JUNK uses them (BiS kept).\n'
          '• Deep drops soft-cap shown iLvl past 100 (global — not only Crystal Spire); '
          'budget follows the shown iLvl.\n'
          '• EQUIP follows budget Score and will not swap to clearly lower iLvl without a jump.\n'
          '• Swapped pieces return to the bag. Apex upgrades live under MENU → CRAFT.',
    ),
    GuideTopic(
      id: 'combinator',
      title: 'MERGE',
      body:
          'Merge two same-slot gear pieces into one stronger item.\n\n'
          '• BAG → select an item → ADD TO MERGE; long-press for the full tip.\n'
          '• Add a second same-slot piece; check RESULT, then MERGE (both consumed).\n'
          '• AUTO MERGE repeats affordable junk pairs (skips BiS / clear upgrades).\n'
          '• Apex gear cannot MERGE — rank it under MENU → CRAFT.\n'
          '• Combinator Charm (ESSENCE → BLESSING) lowers MERGE gold (−3g per luck).',
    ),
    GuideTopic(
      id: 'income',
      title: 'HUB GOLD RATE',
      body:
          'ESSENCE → CAMP (hub gold while the app is closed).\n\n'
          'Your incremental dashboard: Hub gold/min, Run gold/min (from real '
          'loot in the last couple of minutes), gold % multipliers, and Gold Find '
          '— the keep generator on the Gold Find track below.\n\n'
          'Hub ticks while you sit at the keep (slower than a dungeon run, but '
          'time away still buys Gold). Buy one Gold Find level or bulk levels '
          'when you can afford them.',
    ),
    GuideTopic(
      id: 'forge',
      title: 'GOLD',
      body:
          'GOLD — TRAIN under the fight plus MARKET listings.\n\n'
          '• TRAIN: party AP / Armor / STA / MOVE / HASTE / CRIT / MASTERY '
          '(×1…100% of wallet gold, or SPEND ALL · EVEN). Resets on Ascend.\n'
          '• Hero levels come from combat XP (max ${GameLogic.maxHeroLevel}). '
          'BEST marks the cheapest relative upgrade.\n'
          '• MARKET: flasks, bandages, traveling gear listings.\n'
          '• Essence shelves (Blessing, God Hand, Star Nodes) live on ESSENCE → BLESSING.\n'
          '• Ascend from the Hub when ready — not from GOLD.',
    ),
    GuideTopic(
      id: 'power_shelves',
      title: 'POWER SHELVES',
      body:
          'AP / Armor / STA come from three shelves — do not stack them up wrong.\n\n'
          '• GOLD tracks (TRAIN under the fight) — run-only gold buys; wipes on Ascend.\n'
          '• Ascend Blessing — stacks each Ascend forever (ESSENCE → BLESSING).\n'
          '• ESSENCE CAMP + pets — lasting essence power.\n'
          '• RELICS — Embers and Cinders; not essence buys.\n'
          '• After Ascend, rebuild TRAIN first — Blessing and essence shelves stay.',
    ),
    GuideTopic(
      id: 'gates',
      title: 'AL20 VS ENDGAME',
      body:
          'Two gates — AL20 (Ascend cap) vs party Lv${GameLogic.maxHeroLevel} (endgame).\n\n'
          '• AL20: Ascend stacks Blessing, specs, Star Nodes; optional REBORN. Wipes gold + TRAIN + normal gear.\n'
          '• Endgame needs every active hero Lv${GameLogic.maxHeroLevel} — not AL20 alone. Bridge copy: '
          'Level every active hero to ${GameLogic.maxHeroLevel}.\n'
          '• Three dailies (not the same): Daily Vault (PUSH clear / KEY +2 / Gauntlet clear → essence + 1 Cinder), '
          'Daily Run (+25e base from yesterday PUSH), Quests Daily on MENU · QUESTS.\n'
          '• ENDGAME tab: KEY → Gauntlet → Ranked GR → Farm Rift → Ashen Crown.\n'
          '• Clocks: midnight (vault + Daily Run), ISO week (KEY affix), calendar month (vault bonus), Play month (boards).',
    ),
    GuideTopic(
      id: 'classes',
      title: 'SPECIALIZATION UNLOCKS',
      body:
          'New specializations unlock on Ascend — hub teasers name the next specs.\n\n'
          '• AL1–AL6 each add a batch (see GEAR → ROSTER for the full list).\n'
          '• AL2 also opens the 5th party slot (ESSENCE BLESSING · 80e).\n'
          '• Some specs also unlock from zone clears or permanent buys.\n'
          '• Endgame hunts need every active hero Lv${GameLogic.maxHeroLevel}, not AL20 alone.\n'
          '• Swap specs in GEAR → ROSTER when a slot unlocks.',
    ),
    GuideTopic(
      id: 'sanctuary',
      title: 'ESSENCE',
      body:
          'ESSENCE tab: CAMP, BLESSING, RELICS, PETS.\n\n'
          '• CAMP: lasting gold find and run rates (spend essence).\n'
          '• BLESSING: God Hand, Ascend Blessing, Star Nodes, permanent QoL — not bottom-tab SHOP.\n'
          '• RELICS: Embers level unique finds; Cinders from vault or tickets — not essence buys.\n'
          '• PETS: hatch, errands, combat chip damage — survives Ascend.\n'
          '• Relic procs include boss damage bonuses — not flat ATK/DEF/STA shelves.',
    ),
    GuideTopic(
      id: 'gauntlet',
      title: 'GAUNTLET',
      body:
          'Gauntlet unlocks at party Lv${GameLogic.maxHeroLevel} — endless Crystal Spire.\n\n'
          '• Pick MIGHT, WARD, or GREED; boss every 5 floors; best floor saves on wipe.\n'
          '• Between bosses: one squeeze (tight room, swarm, borrowed tell, or extra gates).\n'
          '• Spire Trophies track each squeeze per pact — kept on Ascend.\n'
          '• Gold and essence scale with floor; enter from ENDGAME or hub hunt.\n'
          '• Gauntlet clear can fill today\'s Daily Vault (see AL20 VS ENDGAME).',
    ),
    GuideTopic(
      id: 'rift',
      title: 'FARM RIFT',
      body:
          'Farm Rift (Stormwake) when every active hero is Lv${GameLogic.maxHeroLevel}.\n\n'
          '• Kills fill progress; defeat the Rift Guardian to clear — no fail timer.\n'
          '• Gold and gear drop mid-run; essence + gold on success.\n'
          '• Tiers climb past R20; Ranked GR is the timed ladder (no mid-run gear).\n'
          '• Pick tier on ENTER from ENDGAME, KEY, or hub hunt.\n'
          '• Leave early pays small consolation essence.',
    ),
    GuideTopic(
      id: 'greater_rift',
      title: 'RANKED GR',
      body:
          'Ranked GR when every active hero is Lv${GameLogic.maxHeroLevel} — '
          'timed Mothveil ladder (no mid-run gear).\n\n'
          '• Kills fill progress; at 100% defeat the Rift Guardian before the par timer.\n'
          '• Clear with ≥25% timer left to unlock +2 tiers; otherwise +1. Fails keep best tier.\n'
          '• GR20+ keeps ~90s clock; essence + gold pay on clear (Farm Rift is the loot path).\n'
          '• Hub RANKS + KEY · BOARDS show Play season boards when opted in.\n'
          '• ENTER on ENDGAME picks tier; leave mid-run pays consolation essence.',
    ),
    GuideTopic(
      id: 'apex',
      title: 'CRAFT',
      body:
          'MENU → CRAFT.\n\n'
          '• Pick hero + slot — CRAFT R1 or UPGRADE sits under the recipe.\n'
          '• Tap a mat to lock the farm target; boss clears fill the meter (PUSH > FARM).\n'
          '• Zone Shards pool across caves; Apex Slag starts at Crystal Spire bosses.\n'
          '• Craft weapon R1 first per class/role. Gear and mats survive Ascend.\n'
          '• CRAFT TRIAL (Lv${GameLogic.maxHeroLevel} party) counts Apex on the body once per ISO month.',
    ),
    GuideTopic(
      id: 'market',
      title: 'GOLD MARKET',
      body:
          'GOLD → MARKET.\n\n'
          '• Listings refresh every 6h or for gold. Hub hunt can chase affordable upgrades.\n'
          '• Wipe advice may point at GOLD when listings beat TRAIN under the fight for the same gap.\n'
          '• Buy flasks and bandages with gold — keep one for bosses.\n'
          '• Full bag: BAG → SELL JUNK, MERGE, or FILTERS.\n'
          '• Bottom-tab SHOP is real money (ad-free, Long Away, Supporter) — not this market.',
    ),
    GuideTopic(
      id: 'pets',
      title: 'PETS',
      body:
          'ESSENCE → PETS.\n\n'
          '• Hatch with essence or EGG · 10 Cinders; merge same species + rarity to rank up.\n'
          '• Errands: limited sends per day (Bigger Shipment raises cap).\n'
          '• Active pet chips damage in combat; bond adds AP over time.\n'
          '• Favorite while active boosts passives (gold / loot / XP).\n'
          '• Pets survive Ascend.',
    ),
    GuideTopic(
      id: 'prestige_shop',
      title: 'PERMANENT BUYS',
      body:
          'ESSENCE → BLESSING · Permanent buys (AL-gated).\n\n'
          '• Spend essence on stash slots, cheaper MERGE gold, pet roster, '
          'cheaper market flasks, higher auto-sell / auto-disassemble ceilings, more Welcome '
          'Back rows, Dawn Tithe (vault + Daily Run), and more.\n'
          '• God Hand cooldown upgrades live only under God Hand on BLESSING (one door).\n'
          '• Purchases survive Ascend.\n'
          '• Unlock higher offerings as Ascension Level rises.\n'
          '• Bottom-tab SHOP is the real-money store (ad-free, Long Away, and '
          'Supporter) — not these essence buys.',
    ),
    GuideTopic(
      id: 'jobs',
      title: 'QUESTS',
      body:
          'MENU → QUESTS.\n\n'
          '• Five slots: Daily, Bounty, Side, Week, Contract (endgame hunts when Lv${GameLogic.maxHeroLevel}).\n'
          '• Daily / Week reset after claim (day / ISO week). Every 3rd claim +5 essence.\n'
          '• REROLL Daily/Side twice per day (ad or Ad-free instant).\n'
          '• MENU badge or hub CLAIM QUESTS when rewards are ready.\n'
          '• Dungeon CLAIM chip gathers all ready quests (long-press opens the list).',
    ),
    GuideTopic(
      id: 'weekly',
      title: 'DAILY VAULT',
      body:
          'Daily Vault is the day chase — separate from Daily Run and Quests.\n\n'
          '• Fill with one PUSH clear (not FARM), timed KEY +2, or Gauntlet clear; CLAIM VAULT pays essence + 1 Cinder.\n'
          '• Check-in row: days 1–6 large prize, day 7 jackpot; missed day does not reset the row.\n'
          '• First vault claim each calendar month pays a season bonus.\n'
          '• Daily Run (+25e base) unlocks after first Ascend — not the vault button.\n'
          '• ISO week rotates KEY affixes; see AL20 VS ENDGAME for all four clocks.',
    ),
    GuideTopic(
      id: 'armor_sets',
      title: 'ARMOR SETS',
      body:
          'Rare+ armor from a zone can form a dungeon set (head / shoulder / chest / legs).\n\n'
          '• 2pc: +3 Sta (cloth +3 Spi).\n'
          '• 4pc: +6 Sta +2 Crit (cloth +6 Spi +4 SP), plus mild role fantasy '
          'and a 10% tagged set proc on autos.\n'
          '• Set names follow the zone (Tidehold, Ashen, Spire, …).',
    ),
    GuideTopic(
      id: 'constellation',
      title: 'STAR NODES',
      body:
          'At AL20, ESSENCE → BLESSING opens Star Nodes (spend points).\n\n'
          '• Not the same as Ascend Blessing stacks (+AP/Armor/STA/gold each Ascend).\n'
          '• Reaching AL20 grants 3 points. Earn more from Ashen Crown, Craft Trial, and REBORN.\n'
          '• Spend points on permanent nodes (crit, gold, block, KEY par, …).\n'
          '• Points and lit nodes survive Ascend / REBORN.',
    ),
    GuideTopic(
      id: 'ashen_crown',
      title: 'ASHEN CROWN',
      body:
          'Weekly ticket boss when every active hero is Lv${GameLogic.maxHeroLevel}.\n\n'
          '• ${AshenCrown.ticketsPerWeek} tickets per ISO week; first clear pays rewards + STAR point.\n'
          '• PRACTICE is free and never spends a ticket.\n'
          '• Wipe or leave before the boss kills the run refunds the ticket.\n'
          '• Boss telegraphs (CROWN, WAVE, …) then punishes slow clears.\n'
          '• Rotates shipped caves — enter from ENDGAME or hub hunt.',
    ),
    GuideTopic(
      id: 'hardmode',
      title: 'KEY RUNS',
      body:
          'KEY runs when every active hero is Lv${GameLogic.maxHeroLevel} — set level before you enter a zone.\n\n'
          '• KEY timer keeps running while AFK; beat the boss under par to upgrade the key.\n'
          '• Weekly affixes include Fortified makes trash tougher and Glass foes hit harder.\n'
          '• PATH art stays your zone; pack mix and boss tell visit another cave each week.\n'
          '• Optional Tiny / No Flask / Boss Rush add essence on clear.\n'
          '• Ashen Crown tickets and PRACTICE also live on the KEY / ENDGAME tab.',
    ),
    GuideTopic(
      id: 'ascend',
      title: 'ASCEND',
      body:
          'Hub Ascend when ready (AL1–AL20) — party keeps levels; run bag resets.\n\n'
          '• Each Ascend stacks Ascend Blessing (+AP/Armor/STA/gold forever) and pays essence + Embers.\n'
          '• Keeps: levels, zones, essence, Embers, Cinders, relics, CAMP, pets, Apex, shop buys.\n'
          '• Resets: wallet gold, TRAIN under the fight, bag, market, floor height.\n'
          '• AL20 is the cap; endgame hunts still need every active hero Lv${GameLogic.maxHeroLevel}.\n'
          '• Optional REBORN at AL20 is the same bag wipe without extra Blessing.',
    ),
    GuideTopic(
      id: 'daily',
      title: 'DAILY RUN',
      body:
          'A free one-floor Daily Run on the hub — separate from Daily Vault and Quests.\n\n'
          '• Unlocks after your first Ascend (or endgame). Floor scales from yesterday\'s PUSH.\n'
          '• Clear for +25e base; Dawn Tithe can add more.\n'
          '• Claim once per day — not CLAIM VAULT.\n'
          '• Hub hunt may point here when the run is ready.\n'
          '• May preview a locked zone for the day.',
    ),
    GuideTopic(
      id: 'codex',
      title: 'CODEX & ACHIEVEMENTS',
      body:
          'MENU → INFO (codex + trophies).\n\n'
          '• Codex records monsters and items you have seen.\n'
          '• Achievements track milestones and grant rewards.\n'
          '• Discovery happens automatically as you play.',
    ),
    GuideTopic(
      id: 'ui',
      title: 'UI TIPS',
      body:
          'Quick layout and settings reminders.\n\n'
          '• Party strip bottom-left; target chip top-right; METER shows party rates.\n'
          '• SETTINGS: text scale, zoom, audio, VFX (Full / Lite / Minimal), colorblind floaters.\n'
          '• Bag auto-sell / auto-disassemble live under SETTINGS → bag cleanup.\n'
          '• MENU → INFO reopens these guides.\n'
          '• Back / escape closes overlays.',
    ),
  ];
}

class GuideTopic {
  const GuideTopic({required this.id, required this.title, required this.body});

  final String id;
  final String title;
  final String body;
}
