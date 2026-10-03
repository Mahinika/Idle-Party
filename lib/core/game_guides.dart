import 'ad_boost.dart';
import 'ashen_crown.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'keystone.dart';

/// In-game guide copy for MORE → INFO.
abstract final class GameGuides {
  /// Early topics before the first boss (plain chrome).
  static const Set<String> firstHourTopicIds = {
    'basics',
    'combat',
    'party',
    'bag_equip',
    'world_path',
  };

  /// KEY / Gauntlet / Rift / Ashen — MORE → INFO hides these until party max.
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
        'dailies' => GameLogic.showDailyRunOnHub(state)
            ? _midgameDailies
            : _dayTwoDailies,
        'classes' => _midgameClasses,
        'ascend' => _midgameAscend,
        'weekly' => GameLogic.showDailyRunOnHub(state)
            ? _midgameWeekly
            : _dayTwoWeekly,
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
        '• Starter jobs: Shield, Healer, Damage. You do not need another RPG.',
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
        '• HP strip is bottom-left — tap a hero for their kit.\n'
        '• Target chip is top-right (name + HP).',
  );

  static const GuideTopic _firstHourParty = GuideTopic(
    id: 'party',
    title: 'PARTY',
    body:
        'Your party is three jobs: Shield (soaks hits), Healer (keeps people up), '
        'and Damage (kills enemies).\n\n'
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
        '• A number on GEAR means better items wait — open BAG and tap EQUIP.\n'
        '• BAG: view stash. EQUIP wears upgrades. CLEAN BAG sells filter matches '
        '(including upgrades) for gold — keeps Apex and soulbound.\n'
        '• FILTERS (when the bag is filling): auto-sell weak drops for gold.\n'
        '• Compare ATK / DEF / STA. Worn pieces you replace go back to the bag.',
  );

  /// After first boss, before first Ascend — one daily job, not three dailies.
  static const GuideTopic _dayTwoDailies = GuideTopic(
    id: 'dailies',
    title: 'TODAY\'S CLEAR',
    body:
        'Come back each day and clear one cave.\n\n'
        '• Tap ENTER DUNGEON and beat a floor.\n'
        '• The hub hunt says Clear one cave today until the vault fills.\n'
        '• Then CLAIM VAULT for essence + 1 Cinder.\n'
        '• Daily Vault progress resets at UTC midnight. That is the daily job.',
  );

  static const GuideTopic _dayTwoWeekly = GuideTopic(
    id: 'weekly',
    title: 'DAILY VAULT',
    body:
        'One dungeon clear fills today\'s Daily Vault, then CLAIM VAULT '
        'for essence + 1 Cinder.\n\n'
        '• The hub hunt names this job until you claim.\n'
        '• First Daily Vault claim of each calendar month also pays a season bonus.\n'
        '• Daily Vault resets at UTC midnight.\n'
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
        'market), SHOP (SCROLLS / Cinder packs / ad-free), ESSENCE (tracks / '
        'lasting buys / Embers relics / pets), MORE. QUESTS and Craft live as rows '
        'inside MORE when they unlock.\n'
        '• In a dungeon the sixth slot is LEAVE (back to hub).\n'
        '• Gold buys supplies and run power. Essence buys lasting CAMP power; '
        'relics use Embers and Cinders.\n'
        '• A number on a button means something waits inside — GEAR 3 means '
        '3 better items for the party. No number means nothing to do there.\n'
        '• Menus stay small at the start; more tabs appear as you unlock them.\n'
        '• You do not need to have played another RPG. Names like PROT / DISC / FIRE '
        'are just the three starter jobs: Shield, Healer, Damage.',
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
        '• Daily Vault — UTC day on the hub hunt. One PUSH floor fills it '
        '(FARM does not, including a FARM boss). Then CLAIM VAULT for essence + 1 Cinder.\n'
        '• Daily Run — one free seeded floor scaled from yesterday\'s PUSH '
        '(hub DAILY RUN) for +25e base; Dawn Tithe can add more. Separate from the vault.\n'
        '• Quests — MORE · QUESTS board (Daily / Bounty / Side / Week / Contract). '
        'CLAIM QUESTS on the hub hunt when rewards are ready.\n\n'
        'The hub hunt always picks one job. Vault reset and Daily Run reset at UTC midnight. '
        'Daily Run unlocks after your first Ascend (or when every active hero hits max level). '
        'Before that, the hub hunt stays on Grow the party / one cave today.',
  );

  static const GuideTopic _midgameClasses = GuideTopic(
    id: 'classes',
    title: 'CLASS UNLOCKS',
    body:
        'Ascend grows your roster — the hub hunt and Ascend teasers name the next kits '
        'with a short fantasy line plus a Watch… combat hook.\n\n'
        '• AL1: Combat Rogue, Arms, Holy Paladin\n'
        '• AL2: Beast Mastery, Holy Priest, Arcane · 5th party slot '
        '(ESSENCE lasting buys · 80e)\n'
        '• AL3: Prot Paladin, Assassination, Resto Shaman, Frost Mage, Resto Druid\n'
        '• AL4: Survival, Elemental, Enhancement, Balance, Feral\n'
        '• AL5: Blood DK, Frost DK, Guardian\n'
        '• AL6: Affliction, Demonology\n\n'
        'Some kits also unlock from zone clears or ESSENCE lasting buys — see each '
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
        '• Each Ascend grants a lasting Ascend Blessing: +5 ATK · +20 DEF · +60 STA · '
        '+8% gold (stacks forever). See ESSENCE lasting buys. Separate from Star Nodes.\n'
        '• Confirm / toast show the next unlock (Combat Rogue, 5th slot…).\n'
        '• Also raises Ascension Level (AL: +ATK/STA/DEF and +10% gold per level) and pays essence.\n'
        '• Keep: hero levels/XP, open zones, essence, Embers, Cinders, relics, CAMP, '
        'pets, God Hand, Apex, soulbound gear, shop buys, ad tickets, Star Nodes, '
        'settings, unlocked specs, 5th party slot, lifetime gold, constellation / meta season.\n'
        '• Reset: wallet gold, GOLD → FORGE, bag and worn drops, market, floor height '
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
        'plus 1 Cinder. First claim of each calendar month also pays a season bonus.\n'
        '• The hub hunt and offline Up next share one chase (claim → READY → '
        'ALMOST → grind) — same title whether you are in the hub or returning from AFK.\n'
        '• Welcome-back says where you were: hub = sanctuary gold, plus essence after a while; '
        'mid-dungeon = party kept fighting with AFK assist. Then one wow line, '
        'a few highlights, then Up next.\n'
        '• The hub hunt flashes READY / ALMOST when a claim or Ascend is close.\n'
        '• UTC midnight resets Daily Vault and Daily Run (not the ISO week goal).',
  );

  static const GuideTopic _midgameJobs = GuideTopic(
    id: 'jobs',
    title: 'QUESTS',
    body:
        'QUESTS.\n\n'
        '• Five slots: Daily (UTC kill), Bounty (kill ladder), Side '
        '(bosses, elites, floors, or gold), Week (ISO-week goal), '
        'Contract (big goal).\n'
        '• Daily returns next UTC day after you claim; Week returns next ISO week.\n'
        '• Bounty ladder climbs as you grow; top rung repeats.\n'
        '• Claim 3 in a row for a +5e chain bonus.\n'
        '• MORE · QUESTS (or the badge on MORE) when claims are ready.\n'
        '• Hub CLAIM QUESTS claims ready rewards from the hub hunt line.\n'
        '• The dungeon top CLAIM chip claims all ready quests at once '
        '(visible in combat too; long-press opens the list).\n'
        '• QUESTS is a MORE board — not a PATH cave.',
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
        '• Claim once per UTC day — not the same as CLAIM VAULT.',
  );

  static const GuideTopic _midgameApex = GuideTopic(
    id: 'apex',
    title: 'CRAFT',
    body:
        'MORE → CRAFT.\n\n'
        '• Tap a party hero, then a slot — recipe and CRAFT / UPGRADE sit under that.\n'
        '• Tap a recipe mat to lock the farm target (meter sits on the recipe).\n'
        '• Zone Shards are a pool: any dungeon boss shard pays the recipe.\n'
        '• Materials and vault stay collapsed. OTHER CLASS is only for kits not in the party.\n'
        '• Target meter: every boss clear builds toward a guaranteed mat '
        '(PUSH faster than FARM). Farm any zone — the meter grants what you need.\n'
        '• Craft weapon R1 first, then armor; the button shows CRAFT R1 or the real upgrade rank.\n'
        '• Apex secondaries: DPS Crit + Haste; healers Mp5 + Crit + Haste.\n'
        '• Crafted gear and materials survive Ascend.',
  );

  static const GuideTopic _midgameConstellation = GuideTopic(
    id: 'constellation',
    title: 'STAR NODES',
    body:
        'At AL20, ESSENCE lasting buys open Star Nodes (spend points).\n\n'
        '• Not the same as Ascend Blessing stacks (+ATK/DEF/STA/gold each Ascend).\n'
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
          '• Tap ENTER DUNGEON to start the first cave (Sandy Caverns).\n'
          '• Watch them clear rooms. Long-press the fight, or tap the fist, when you want to help.\n'
          '• The hunt line on the hub always names the next job — start there.\n'
          '• Bottom tabs (same bar in hub and dungeon): GEAR, GOLD (run power + '
          'market), SHOP (SCROLLS / Cinder packs / ad-free), ESSENCE (CAMP / '
          'BLESSING / Embers relics / pets), MORE. QUESTS and Craft live as rows '
          'inside MORE. When the party is max level, KEY joins the hub bar as a '
          'sixth tab after MORE — SHOP stays. In a dungeon the sixth slot is '
          'LEAVE instead of KEY.\n'
          '• Gold buys supplies and run power. Essence buys lasting CAMP power; '
          'relics use Embers and Cinders.\n'
          '• In a dungeon the bar is GEAR · GOLD · SHOP · ESSENCE · MORE · LEAVE '
          '(back to hub). Set KEY from the hub before you enter.\n'
          '• A number on a button means something waits inside — GEAR 3 means '
          '3 better items for the party. No number means nothing to do there.\n'
          '• Menus stay small at the start; more tabs appear as you unlock them.\n'
          '• You do not need to have played another RPG. Names like PROT / DISC / FIRE '
          'are just the three starter jobs: Shield, Healer, Damage.',
    ),
    GuideTopic(
      id: 'dailies',
      title: 'THREE DAILIES',
      body:
          'Three different systems — not the same button:\n\n'
          '• Daily Vault — UTC day on the hub hunt. One PUSH floor fills it '
          '(FARM does not). Or time KEY +2. Or a Gauntlet clear. Then CLAIM VAULT '
          'for essence + 1 Cinder.\n'
          "• Daily Run — one free seeded floor scaled from yesterday's PUSH "
          '(hub DAILY RUN) for +25e base; Dawn Tithe can add more. Separate from the vault.\n'
          '• Quests — MORE · QUESTS board (Daily / Bounty / Side / Week / Contract). '
          'CLAIM QUESTS on the hub hunt when rewards are ready.\n\n'
          'The hub hunt always picks one job. Vault reset and Daily Run reset at UTC midnight. '
          'Daily Run unlocks after your first Ascend (or endgame). Before that, the hub hunt '
          'stays on Grow the party / one cave today.',
    ),
    GuideTopic(
      id: 'powerups',
      title: 'SCROLLS',
      body:
          'Tap SCROLLS on the hub map. Optional. Watch a short ad '
          'for 1 Ad Ticket, then spend tickets on timed scrolls.\n\n'
          '• TIP A FRIEND: 10 Ad Tickets per friend who installs with your code (or enters it on SCROLLS), up to 30 friends.\n\n'
          '• Scroll of Damage: +${AdBoost.attackPercent}% attack for ${AdBoost.splitHours} hours (1 ticket).\n'
          '• Scroll of Gold: ×${AdBoost.goldMul} gold (kills, chests, hub AFK) for ${AdBoost.splitHours} hours (1 ticket).\n'
          '• Scroll of XP: +${AdBoost.xpPercent}% party XP for ${AdBoost.splitHours} hours (1 ticket).\n'
          '• Scroll of Speed: +${AdBoost.movePercent}% walk speed for ${AdBoost.splitHours} hours (1 ticket).\n'
          '• Scroll of Loot: +${AdBoost.lootFindPercent}% item find for ${AdBoost.splitHours} hours (1 ticket).\n'
          '• Scroll of Haste: +${AdBoost.speedPercent}% dungeon speed for ${AdBoost.splitHours} hours (1 ticket).\n'
          '• Scroll of Battle: ATK + gold for ${AdBoost.hoursPerAd} hours (2 tickets) — best gold/ATK value.\n'
          '• Scroll of Rest: next Welcome Back gold ×${AdBoost.awayGoldMul} (1 ticket).\n'
          '• Time stacks up to 24 hours per scroll. Magnitudes do not stack higher.\n'
          '• Ads never pop up in a fight. You choose when to watch.\n'
          '• Tickets and remaining time survive Ascend.',
    ),
    GuideTopic(
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
          'Endgame hunts need every active hero at Lv${GameLogic.maxHeroLevel} '
          '(mean alone is not enough).\n'
          '• Locked zones dim on the map; the caption under the map shows '
          'party level progress (have / need).\n'
          '• PATH is always on the hub. The ENDGAME tab appears from Ascend 20 or when every hero is ≥Lv80, still locked until every active hero is Lv${GameLogic.maxHeroLevel}. '
          'ENDGAME is its own map (Gauntlet, Ranked GR, Farm Rift, Ashen Crown) — '
          'not under Mothveil, not a 16th dungeon. Tap a hunt, then ENTER. '
          'Farm Rift and Ranked GR pick the number on ENTER. '
          'KEY still holds the KEY dial.\n'
          "• Goblin's Hideout: stolen-stash chests pay better gold but wake ambush guards.\n"
          '• Boss floor is shown under your party name (Boss on F n).',
    ),
    GuideTopic(
      id: 'combat',
      title: 'COMBAT',
      body:
          'Each floor is one combat wave on a multi-chamber map.\n\n'
          '• Clear a chamber to open gates into the next — OPEN pops on the door.\n'
          '• When the pack is dead, ground loot banks instantly and the party '
          'heads to the stairs — the corner chip says CLEAR. HOLD skips the walk '
          'and finishes the floor now.\n'
          '• Elite and treasure floors often hide a room chest — grabbed with '
          'the floor clear.\n'
          '• Boss floors telegraph their own tell '
          '(WAVE, SLAM, SPIT) — Brass shouts CRUSH.\n'
          '• Sandy and Grove open swarm-heavy; Tide holds the mid room; Brass stacks elites last.\n'
          '• Settings VFX: Full = all effects; Lite = ground discs, auras, crits, '
          'heals, BLOCK, and flask stay (routine hit numbers and cast bursts off); '
          'Minimal = reduce motion, but a God Hand smash still flashes.\n'
          '• Party HP strip is bottom-left — tap a hero to open their kit. '
          'Between fights, tap the same hero again to fold. Mid-fight the kit stays open. '
          'Level and XP sit under HP.\n'
          '• Gold in the top bar ticks up as pickups land.\n'
          '• Target chip is top-right (name + HP).\n'
          '• Tap METER (top-left) for party rates: DPS, healer HPS, tank damage taken (bars match unit; tanks/healers also show their damage).',
    ),
    GuideTopic(
      id: 'god_hand',
      title: 'GOD HAND',
      body:
          'Long-press the fight, or tap the fist, to help: smash enemies and steer the party.\n\n'
          '• First job: smash a pack and pull the party toward your press.\n'
          '• Cooldown ring is top-right of the dungeon view.\n'
          '• ESSENCE → BLESSING (soft knobs): more damage, shorter CD, BAL / FOCUS / WIDE styles.\n'
          '• Styles trade damage vs radius — not a second talent tree.\n'
          '• Mastery under BLESSING: claim +12e and a title at Hand 5 (Hand of Embers), '
          'CD 4 (Swift Smash), and 100 smashes (Hundred Blows).\n'
          '• Upgrades use essence and survive Ascend.',
    ),
    GuideTopic(
      id: 'farm_push',
      title: 'FARM / PUSH',
      body:
          'Toggle at the top of the dungeon view (FARM / PUSH).\n\n'
          '• FARM (loop): after clearing, stay on the same floor for more loot/gold.\n'
          '• PUSH (climb): after clearing, advance to the next floor toward the boss. '
          'PUSH floor clear pays +1 essence, boss +2 — FARM pays 0 essence.\n'
          '• Use Floor −1 / +1 in the floor menu to travel when allowed.',
    ),
    GuideTopic(
      id: 'party',
      title: 'PARTY & ROSTER',
      body:
          'Your party is three jobs: Shield (soaks hits), Healer (keeps people up), '
          'and Damage (kills enemies).\n\n'
          '• GEAR → ROSTER to swap who is fighting (4 slots, '
          '5th unlockable later).\n'
          '• New Game: pick 3 starters — Protection (Shield), Discipline (Healer), '
          'Fire (Damage) is the easy mix.\n'
          '• More hero types unlock as you grow — you do not need another game.\n'
          '• Tap a hero in the HUD for abilities; chips show cooldowns '
          '(STREAK, SWEEP / FLURRY, BEACON when those windows are up).\n'
          '• The strip shows level and a thin XP bar so growth is visible mid-fight.\n'
          '• Resources: Rage / Mana / Energy / Runic — kits spend these.\n'
          '• Roster levels and open zones keep on Ascend; bag, gold, and Gold buys reset.\n'
          '• Flask heals the party when you have a potion.',
    ),
    GuideTopic(
      id: 'bag_equip',
      title: 'BAG & GEAR',
      body:
          'Loot drops on the floor, then goes to your stash (BAG).\n\n'
          '• Upgrades stay in BAG until you equip them — GEAR badge shows how '
          'many are better; open BAG and tap EQUIP (or equip one by one).\n'
          '• BAG: view and equip stash gear. CLEAN BAG sells gold then scraps essence using FILTERS.\n'
          '• Stats: plate wants Strength, leather/mail damage wants Agility, '
          'casters want Intellect and Spell Power. Spirit is mana, not damage. '
          'Secondaries are Crit / Mastery / Haste / Mp5 — new drops keep ≤2 (no Move). '
          'Healers roll Mp5 then Crit or Haste. Haste shortens heal cooldowns. '
          'Weapon crits hit harder than spell crits. '
          'Near 75% crit, EQUIP stops chasing more Crit.\n'
          '• Armor type is a hard gate: Warrior / Paladin / DK wear plate; '
          'Hunter starts leather then mail at 40; Shaman mail; Rogue leather; '
          'Druid leather (cloth OK); Priest / Mage / Warlock cloth. '
          'EQUIP never puts the wrong material on a hero.\n'
          '• Weapons are a hard gate too: Paladin no daggers, Priest no swords, '
          'Hunter no maces. Dual-wield is Rogue / Fury / Enhancement / Frost DK. '
          'Shields are Warrior / Paladin / Shaman. Paladin / DK / Shaman / '
          'Druid have no ranged slot (empty is fine). Drops skip slots nobody '
          'in the party can wear, so a tank still sees shields.\n'
          '• CHARM (trinket) drops always come with an on-item effect '
          '(lifesteal, crit, gold find, …).\n'
          '• Deep drops soft-cap shown iLvl past 100 (global — not only Crystal Spire) so '
          'numbers stay readable — budget follows the shown iLvl.\n'
          '• GEAR: paper-doll per hero — UNEQUIP worn pieces, EQUIP from bag.\n'
          '• Tap an empty GEAR slot to open BAG filtered to that slot.\n'
          '• EQUIP follows budget stats. Green UPGRADE / EQUIP N is '
          'exactly what EQUIP wears (not a maybe-better crumb). '
          'Will not swap to clearly lower iLvl without a real power jump; '
          '1H+off-hand can beat a lonely 2H.\n'
          '• Armor sets (2pc/4pc) give combat bonuses — not fake BiS score. '
          '2pc +3 Sta (cloth +3 Spi); 4pc +6 Sta +2 Crit (cloth +6 Spi +4 SP) '
          'plus a 10% set proc on autos.\n'
          '• BAG → FILTERS: auto-sell weak drops for gold, '
          'auto-disassemble for essence (iLvl + rarity filters).\n'
          '• CLEAN BAG (BAG button): sells/scraps FILTERS matches — including '
          'BiS and upgrades — keeps Apex and soulbound only.\n'
          '• Near-full bag: light auto-clean while looting (still protects upgrades).\n'
          '• EQUIP, UPGRADE, and BEST follow Score. ATK / DEF / STA sit beside it. Swapped pieces return to the bag.',
    ),
    GuideTopic(
      id: 'combinator',
      title: 'MERGE',
      body:
          'Merge two same-slot gear pieces into one stronger item.\n\n'
          '• In BAG: select an item → ADD TO MERGE.\n'
          '• Long-press any item for the full tip card.\n'
          '• Add a second item of the same slot; MERGE opens when ready.\n'
          '• Check RESULT preview (rarity, iLvl, SCORE jump) and gold cost, then MERGE.\n'
          '• AUTO MERGE: repeatedly merges junk pairs of the same slot '
          '(skips BiS / clear upgrades) while you can afford the cost.\n'
          '• Apex gear cannot MERGE — rank it up under MORE → CRAFT.\n'
          '• Combinator Charm in ESSENCE → BLESSING (permanent buys) lowers MERGE gold (−3g per luck).\n'
          '• Both inputs are consumed.',
    ),
    GuideTopic(
      id: 'income',
      title: 'HUB GOLD RATE',
      body:
          'ESSENCE → CAMP (hub gold overnight).\n\n'
          'Your incremental dashboard: Hub gold/min, Run gold/min (from real '
          'loot in the last couple of minutes), gold % multipliers, and Gold Find '
          '— the keep generator on the Gold Find track below.\n\n'
          'Hub ticks while you sit at the keep (slower than a dungeon run, but '
          'overnight still buys Gold). Buy one Gold Find level or bulk levels '
          'when you can afford them.',
    ),
    GuideTopic(
      id: 'forge',
      title: 'GOLD',
      body:
          'GOLD tab — spend wallet gold on run power and the market.\n\n'
          '• FORGE: party ATK/DEF/STA/MOVE/HASTE/CRIT/MASTERY. '
          'Pick ×1 / 5% / 25% / 50% / 100% of wallet gold per tap, or '
          'SPEND ALL · EVEN to split gold round-robin across every track. '
          'Hero levels come from combat XP (max ${GameLogic.maxHeroLevel}). '
          'Harder kills (higher enemy level than the hero) pay more XP; heroes far behind the party catch up faster.\n'
          'Gold FORGE buys reset when you Ascend. '
          'ATK, HASTE, and MOVE speed up clears — see Essence for rates. '
          'One gold buy is similar punch: ATK hits, DEF is armor, STA is HP, '
          'HASTE and CRIT are the same percent step. BEST marks the cheapest '
          'relative upgrade.\n'
          '• MARKET: flasks, bandages, traveling gear listings.\n'
          '• Essence keeps (Ascend Blessing, God Hand, Star Nodes, 5th slot) live on ESSENCE → BLESSING.\n'
          '• Ascend from the Hub when ready (not from Gold).',
    ),
    GuideTopic(
      id: 'power_shelves',
      title: 'POWER SHELVES',
      body:
          'ATK / DEF / STA come from three shelves — do not stack them up wrong.\n\n'
          '• GOLD tracks (GOLD → FORGE) — run-only power bought with wallet gold. Wipes on Ascend. '
          'Wipe advice points here (or GOLD → MARKET listings) when the sim proves a gap.\n'
          '• Ascend Blessing — stacks each Ascend (+ATK/DEF/STA/gold forever). '
          'Readout on ESSENCE → BLESSING. Not Star Nodes.\n'
          '• ESSENCE CAMP + pets — forever power bought with essence (CAMP / PETS).\n'
          '• RELICS — Embers discover and level unique finds (bosses, Ascend, salvage). '
          'Cinders come from the Daily Vault, Ad Tickets, or a SHOP pouch — salvage or '
          'trade a few Embers. Not essence buys.\n\n'
          'Gear, Apex, AL flats, and Star Nodes add sheet power on top. '
          'After Ascend, rebuild GOLD → FORGE first — Blessing and essence shelves stay.',
    ),
    GuideTopic(
      id: 'gates',
      title: 'AL20 VS ENDGAME',
      body:
          'Two different gates — do not mix them up.\n\n'
          '• AL20 (Ascension cap): raise AL with Ascend, stack Ascend Blessing, '
          'unlock kits, spend Star Nodes, optional REBORN. Wipes your run bag '
          '(gold, GOLD → FORGE, normal gear).\n'
          '• Party Lv${GameLogic.maxHeroLevel} (endgame): every active hero at max level '
          'unlocks KEY, Gauntlet, Ranked GR, Farm Rifts, '
          'and Ashen Crown. AL20 alone is not enough.\n'
          '• At AL20 with heroes below ${GameLogic.maxHeroLevel}, the hub hunt may say '
          '"Level every active hero to ${GameLogic.maxHeroLevel}" — that is the bridge into endgame.\n\n'
          'Three different "dailies" (not the same button):\n'
          '• Daily Vault — UTC day; one PUSH clear (not FARM), timed KEY +2, '
          'or a Gauntlet clear, then CLAIM VAULT for essence + 1 Cinder. While the hub hunts KEY or a ladder, the line under '
          'it still shows Vault 0/1 until you fill it.\n'
          '• Daily Run — one free seeded floor scaled from yesterday\'s PUSH '
          'for +25e base; Dawn Tithe can add more.\n'
          '• Quests Daily — MORE · QUESTS kill board; CLAIM QUESTS when ready.\n\n'
          'Four season clocks (all optional — the hub hunt picks one job):\n'
          '• UTC midnight — vault + Daily Run reset.\n'
          '• ISO week — KEY affix rotation + local week goal.\n'
          '• Calendar month — first vault claim season bonus.\n'
          '• Play Games month — ranked KEY / Gauntlet / GR boards (opt-in).\n\n'
          'Endgame ladder on the hub hunt (every active hero Lv${GameLogic.maxHeroLevel}): '
          'KEY habit → Gauntlet → Ranked GR → Farm Rift → Ashen Crown.\n'
          'Those hunts live on the hub ENDGAME tab (its own map, not under the 15 zones).\n\n'
          'Class unlock ladder (WotLK-shaped AL kits) lives in CLASS UNLOCKS — '
          'Shield / Healer / Damage starters are plain English; AL1+ names match '
          'classic specs.',
    ),
    GuideTopic(
      id: 'classes',
      title: 'CLASS UNLOCKS',
      body:
          'Ascend grows your roster — the hub hunt and Ascend teasers name the next kits '
          'with a short fantasy line plus a Watch… combat hook.\n\n'
          '• AL1: Combat Rogue, Arms, Holy Paladin\n'
          '• AL2: Beast Mastery, Holy Priest, Arcane · 5th party slot '
          '(ESSENCE BLESSING · 80e)\n'
          '• AL3: Prot Paladin, Assassination, Resto Shaman, Frost Mage, Resto Druid\n'
          '• AL4: Survival, Elemental, Enhancement, Balance, Feral\n'
          '• AL5: Blood DK, Frost DK, Guardian\n'
          '• AL6: Affliction, Demonology\n\n'
          'Endgame (not Ascend):\n'
          '• Every hero Lv${GameLogic.maxHeroLevel}: KEY, Gauntlet, Farm Rifts, '
          'Ranked GR, and Ashen Crown unlock when every active hero is max level '
          '— AL20 alone is not enough.\n\n'
          'Some kits also unlock from zone clears or ESSENCE → BLESSING permanent buys — see each '
          'spec’s unlock hint in GEAR → ROSTER.',
    ),
    GuideTopic(
      id: 'sanctuary',
      title: 'ESSENCE',
      body:
          'ESSENCE tab. Four places: CAMP, BLESSING, RELICS, PETS.\n\n'
          '• CAMP: Gold Find, War Altar, Life Well, Aegis, Lore Font — spend essence '
          'on lasting rates/power.\n'
          '• BLESSING: God Hand damage/CD/style, Ascend Blessing readout, Star Nodes, lasting QoL buys '
          '(AL-gated), constellation at AL20, optional REBORN. '
          'Not the bottom-tab SHOP (SCROLLS / Cinder packs / ad-free).\n'
          '• RELICS: Embers discover and level unique finds (bosses, Ascend, salvage). '
          'Cinders from Daily Vault (+1 on claim), two Ad Tickets, or a SHOP pouch — '
          'salvage a relic or trade a few Embers each week. One effect each '
          '(boss damage, low-HP DR, stairs heal, God Hand CD, loot, mitigate, gold, '
          'offline gold, flask, mana, …), up to T6 — not ATK/DEF/STA auras, not essence buys.\n'
          '• PETS: hatch and level pets when unlocked — active pets deal chip damage '
          '(not cosmetics-only).\n'
          '• Everything here survives Ascend (including Embers and Cinders).\n'
          '• Invest early — CAMP compounds over many runs.',
    ),
    GuideTopic(
      id: 'gauntlet',
      title: 'GAUNTLET',
      body:
          'Unlocks when every active hero reaches level ${GameLogic.maxHeroLevel} (endgame).\n\n'
          '• Endless Crystal Spire climb — not a 16th PATH cave; each floor gets harder.\n'
          '• Boss every 5 floors — the picture stays Crystal Warden; the tell word cycles (SHARD, WAVE, '
          'CRUSH, …) from other caves and scale past F100 (faster).\n'
          '• Between bosses (F3, F8, F13, …) the floor can squeeze, swarm, echo a '
          'boss tell, or add extra gates. Treasure floors every 6th floor (F6, F12, …) '
          'skip the anomaly. Same fight — not a new hunt.\n'
          '• Gold and essence scale with floor; boss every 5 floors.\n'
          '• Wipe or leave returns to hub; best floor is saved.\n'
          '• Enter from the hub ENDGAME tab, KEY, or the hub hunt line.\n'
          '• Does not count toward Ascend boss requirements.',
    ),
    GuideTopic(
      id: 'rift',
      title: 'FARM RIFT',
      body:
          'Loot farm rift when every active hero is Lv${GameLogic.maxHeroLevel} — not Ranked GR.\n\n'
          '• Kills fill a progress bar; at 100% a Rift Guardian spawns — defeat it to clear.\n'
          '• No fail timer (elapsed is display-only). Leave/wipe before the Guardian dies = small consolation.\n'
          '• Gold and gear drop during the run; success also pays essence + gold.\n'
          '• Tiers keep going past R20 — packs get harder; progress target holds after R20. Clears unlock +1.\n'
          '• Not ranked on Play Games — gear drops mid-run (Ranked GR does not). '
          'The hub hunt chases Farm Rift after GR milestones quiet.\n'
          '• Set R on ENTER (arrows) — KEY · FARM RIFT, hub ENDGAME, or the hub hunt.',
    ),
    GuideTopic(
      id: 'greater_rift',
      title: 'RANKED GR',
      body:
          'Ranked GR when every active hero is Lv${GameLogic.maxHeroLevel} — '
          'Mothveil Greater-style, harder than Farm Rift.\n\n'
          '• Kills fill progress; at 100% a Rift Guardian spawns — defeat it before the par timer.\n'
          '• Mid-run: gold OK, no gear drops — big essence + gold on clear. '
          'Farm Rift is the loot path; Ranked GR is the ranked ladder.\n'
          '• GR20 sits on a ~90s clock — later ranks keep that cap and the kill quota. '
          'Each rank after that multiplies pack toughness (GOLD forge is your damage, not theirs).\n'
          '• Clear with ≥25% of the par timer left to unlock +2 tiers; otherwise +1. '
          'Fails keep your best tier.\n'
          '• Season ranks: hub RANKS button (KEY, Gauntlet, Ranked GR, party power). '
          'Same list on KEY · BOARDS. Play install + sign-in. '
          'The list stays in the game. Local PB also stays on hub ENDGAME.\n'
          '• Fail the par clock: the run is depleted — keep your best tier, '
          'consolation essence (at least 1, about a third of the tier), retry from hub ENDGAME. '
          'Leave mid-run pays the same consolation.\n'
          '• The hub hunt chases Ranked GR before Farm Rift. ENTER opens arrows to pick any GR.',
    ),
    GuideTopic(
      id: 'apex',
      title: 'CRAFT',
      body:
          'MORE → CRAFT.\n\n'
          '• Tap a party hero, then a slot — recipe and CRAFT / UPGRADE sit under that.\n'
          '• Tap a recipe mat to lock the farm target (meter sits on the recipe).\n'
          '• Zone Shards are a pool: any dungeon boss shard pays the recipe '
          '(KEY / Rift / late zones count).\n'
          '• Materials and vault stay collapsed. OTHER CLASS is only for kits not in the party.\n'
          '• Target meter: every boss clear builds toward a guaranteed mat '
          '(PUSH faster than FARM). Farm any zone — the meter grants what you need.\n'
          '• Craft weapon R1 first, then armor; the button shows CRAFT R1 or the real upgrade rank.\n'
          '• Apex secondaries: DPS Crit + Haste; healers Mp5 + Crit + Haste '
          '(three lines). Primaries use the same loot split as dungeon drops.\n'
          '• Crafted gear and materials survive Ascend.\n'
          '• At every active hero Lv${GameLogic.maxHeroLevel}, START CRAFT TRIAL (once per ISO month) '
          'uses Apex-crafted gear only — bag stays untouched. Not a hub ENDGAME hunt.',
    ),
    GuideTopic(
      id: 'market',
      title: 'GOLD MARKET',
      body:
          'GOLD → MARKET.\n\n'
          '• GEAR: opens on Upgrades. Tap a row to buy. Switch to All gear if you want '
          'the full stock. Free refresh every 6 hours, or pay gold to reroll.\n'
          '• The hub hunt can chase Market when an affordable listing beats your gear.\n'
          '• Wipe advice may point at GOLD when listings beat GOLD → FORGE for the same gap.\n'
          '• Buy flasks and bandages with gold.\n'
          '• Clear a full bag with BAG → CLEAN BAG, MERGE, or BAG → FILTERS.\n'
          '• Keep at least one flask for tough floors and bosses.\n'
          '• Bottom-tab SHOP is the real-money store (forever SCROLLS / Cinder packs / '
          'ad-free on Play installs) — not this market.',
    ),
    GuideTopic(
      id: 'pets',
      title: 'PETS',
      body:
          'ESSENCE → PETS.\n\n'
          '• Hatch and level pets with essence (random species and rarity).\n'
          '• Merge two same-species pets of the same rarity into a higher rarity.\n'
          '• Favorite while ACTIVE: +1 ATK; find passives (gold/loot/XP) get about '
          '+5% (at least +1 on small bonuses). Mitigate/heal bump too.\n'
          '• Bond for +1 ATK every 5 ranks (max 25). Frames are looks only.\n'
          '• Active pet follows in combat and chips damage (cyan hits, ally ring).\n'
          '• Beast Mastery / Demonology / Unholy also bring a class companion '
          '(Hunter Pet / Felguard / Ghoul). Enhancement wolves and Frost Water '
          'Elemental are timed summons.\n'
          '• Pets are meta — they survive Ascend.',
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
          '• Bottom-tab SHOP is real-money store (forever SCROLLS / Cinder packs / '
          'ad-free) — not these essence buys.',
    ),
    GuideTopic(
      id: 'jobs',
      title: 'QUESTS',
      body:
          'QUESTS.\n\n'
          '• Five slots: Daily (UTC kill), Bounty (kill ladder), Side '
          '(bosses, elites, floors, or gold), Week (ISO-week goal), '
          'Contract (big goal — KEY / Gauntlet / Rift / Ranked GR / Ashen '
          'when every active hero is Lv${GameLogic.maxHeroLevel}).\n'
          '• Daily returns next UTC day after you claim; Week returns next ISO week.\n'
          '• Bounty ladder climbs 100 → 500 → 1000 → 5k → 10k → 25k at endgame '
          '(smaller rungs earlier); top rung repeats.\n'
          '• Claim 3 in a row for a +5e chain bonus.\n'
          '• MORE · QUESTS (or the badge on MORE) when claims are ready.\n'
          '• Hub CLAIM QUESTS claims ready rewards from the hub hunt line.\n'
          '• The dungeon top CLAIM chip claims all ready quests at once '
          '(visible in combat too; long-press opens the list).\n'
          '• QUESTS is a MORE board — not a hub ENDGAME hunt.',
    ),
    GuideTopic(
      id: 'weekly',
      title: 'DAILY VAULT',
      body:
          'Three different dailies:\n'
          '• Daily Vault — one PUSH clear (FARM does not count), timed KEY +2, '
          'or a Gauntlet clear, then CLAIM VAULT for essence + 1 Cinder.\n'
          '• Daily Run — one free seeded floor scaled from yesterday\'s PUSH '
          'for +25e base; Dawn Tithe can add more (hub DAILY RUN).\n'
          '• Quests — Daily / Bounty / Side / Week / Contract board; '
          'CLAIM QUESTS when ready.\n\n'
          'Keystone affixes still rotate each ISO week (numbers + which cave’s '
          'jobs/tell KEY borrows). The vault is daily.\n\n'
          '• Early on: the hub hunt tells you to grow the party in the starter zone. '
          'Daily Run waits until your first Ascend (or endgame). Vault-start waits until you have beaten a boss (or Ascended).\n'
          '• Fill today’s Daily Vault with one PUSH clear (not a FARM loop), a timed KEY +2, '
          'or a Gauntlet clear, then claim essence + 1 Cinder.\n'
          '• CLAIM VAULT pays the timed-key essence table, plus Dawn Tithe, plus enough for one CAMP upgrade, '
          'plus 1 Cinder. First claim of each calendar month also pays a season bonus.\n'
          '• When every active hero is Lv${GameLogic.maxHeroLevel}: KEY unlocks — time a KEY +2 (or higher) for a bigger '
          'vault claim. The hub hunt may chase KEY / Gauntlet / Ranked GR / Farm Rift.\n'
          '• The hub hunt and offline Up next share one chase (claim → READY → '
          'ALMOST → grind) — same title whether you are in the hub or returning from AFK.\n'
          '• Welcome-back says where you were: hub = sanctuary gold, plus essence after a while; '
          'mid-dungeon = party kept fighting with AFK assist. Then one wow line, '
          'a few highlights, then Up next.\n'
          '• The hub hunt flashes READY / ALMOST when a claim or Ascend is close.\n'
          '• Each ISO week has a named local season beat (timed KEY, Gauntlet, Ranked GR, or Ashen Crown) '
          '— the hub hunt may chase it after every active hero is Lv${GameLogic.maxHeroLevel}; claim pays essence + title.\n'
          '• See AL20 VS ENDGAME for all four season clocks (UTC day / ISO week / '
          'calendar month / Play month).\n'
          '• UTC midnight resets Daily Vault and Daily Run. ISO week rotates KEY '
          'affixes and the local week goal. Calendar month pays the first-vault '
          'season bonus. Play month is ranked boards.\n'
          '• Will ranks and Gauntlet F25/50/100/150/200 grant one-time essence when unlocked.',
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
          '• Not the same as Ascend Blessing stacks (+ATK/DEF/STA/gold each Ascend).\n'
          '• Reaching AL20 grants 3 points. Earn more from Ashen Crown, Craft Trial, and REBORN.\n'
          '• Spend points on permanent nodes (crit, gold, block, KEY par, …).\n'
          '• Points and lit nodes survive Ascend / REBORN.',
    ),
    GuideTopic(
      id: 'ashen_crown',
      title: 'ASHEN CROWN',
      body:
          'Weekly ticket boss (every active hero Lv${GameLogic.maxHeroLevel}). Hub hunt, ENDGAME tab, or KEY.\n\n'
          '• ${AshenCrown.ticketsPerWeek} tickets each ISO week. The first ticket clear '
          'pays +${AshenCrown.essenceReward}e, title ${AshenCrown.titleReward}, '
          'and +1 STAR point.\n'
          '• After that clear, further tickets do not pay — use PRACTICE (free, no ticket) '
          'to rehearse the fight.\n'
          '• Confirm before a ticket run. Wipe or leave before the boss pays '
          'back the ticket — only a clear spends it. PRACTICE never spends a ticket.\n'
          '• Boss kit: the weekly telegraph (CROWN, WAVE, and others), then '
          'smash after telegraph (SLAM / SLOW) — same in PRACTICE.\n'
          '• Each ISO week the Crown visits a different shipped cave — not a 16th dungeon. '
          'Leave or wipe returns you to the hub.',
    ),
    GuideTopic(
      id: 'hardmode',
      title: 'KEY RUNS',
      body:
          'Mythic+-style keys from the hub KEY tab '
          '(every hero at Lv${GameLogic.maxHeroLevel}) — unlocks when '
          'every active hero is level ${GameLogic.maxHeroLevel}.\n\n'
          '• Endgame only: set key before you enter a normal zone dungeon.\n'
          '• Key level has no stop at +20 — time under par to push the next KEY.\n'
          '• Affixes lock on enter (weekly numbers + this week’s cave jobs / '
          'boss tell). Fortified/Tyrannical at +4, more at higher keys.\n'
          '• This week’s KEY fight is not a Farm Rift: PATH cave art stays, '
          'but pack mix and the boss tell visit another shipped cave.\n'
          '• KEY timer keeps running while AFK — beat the boss under par to TIMED upgrade.\n'
          '• Overtime = depleted (clear still counts, no key upgrade).\n'
          '• Daily vault: 1 PUSH/Gauntlet clear or timed KEY +2 — claim once per day.\n'
          '• Optional Boss Rush / No Flask / Tiny each add +2 essence on a clear. '
          'Boss Rush = tougher elite packs (not extra bosses). Tiny = 3 heroes (+2e), '
          'not a harder threat.\n'
          '• Affixes show in the fight: SWARM / FORTIFIED / TYRANNICAL banners; '
          'Glass foes hit harder and execute low-HP heroes; Fortified makes trash tougher.\n'
          '• Higher keys drop higher iLvl gear (KEY +10 is +20 iLvl) and pay '
          'gold in line with the harder packs — not a gold tax.\n'
          '• At every active hero Lv${GameLogic.maxHeroLevel}, the hub hunt may chase KEY until +${Keystone.campaignCap}; higher keys stay on the KEY tab.\n'
          '• Ashen Crown tickets and PRACTICE live under KEY and on the hub ENDGAME tab.',
    ),
    GuideTopic(
      id: 'ascend',
      title: 'ASCEND',
      body:
          'Claim Ascend in the hub when ready (AL1–AL20) — same party, empty bag, '
          'gold, GOLD tracks, and floor progress, stronger Ascend Blessing.\n\n'
          '• AL20 is the Ascension cap. Endgame (endless KEY / Farm Rift / Ranked GR, Gauntlet, '
          'Ashen Crown, boards) unlocks when every active hero reaches level '
          '${GameLogic.maxHeroLevel} — not from AL20 alone. Daily Vault is separate '
          '(available earlier; not endgame-gated).\n'
          '• Each Ascend grants a lasting Ascend Blessing: +5 ATK · +20 DEF · +60 STA · '
          '+8% gold (stacks forever). See ESSENCE → BLESSING. Separate from Star Nodes.\n'
          '• Confirm / toast show the next Ascend unlock (Combat Rogue, 5th slot…).\n'
          '• Also raises Ascension Level (AL: +ATK/STA/DEF and +10% gold per level) and pays essence.\n'
          '• Keep: hero levels/XP, open zones, essence, Embers, Cinders, relics, CAMP, '
          'pets, God Hand, Apex, soulbound gear, shop buys, ad tickets, Star Nodes, '
          'settings, unlocked specs, 5th party slot, lifetime gold, constellation / meta season.\n'
          '• Reset: wallet gold, GOLD → FORGE, bag and worn drops, market, floor height '
          '(starter gear back on).\n'
          '• Boss victories toward the next Ascend clear. Ascend also pays Embers.\n'
          '• At AL20, ESSENCE → BLESSING offers optional REBORN (same bag wipe, AL stays 20, '
          'no extra Ascend Blessing). The hub hunt never nags you to press it.',
    ),
    GuideTopic(
      id: 'daily',
      title: 'DAILY RUN',
      body:
          'A free one-floor Daily Run on the hub — separate from Daily Vault and Quests.\n\n'
          '• Floor scales from yesterday\'s best PUSH clear (+1), so it stays a stretch.\n'
          '• Unlocks after your first Ascend (or when endgame unlocks) — before that, '
          'the hub hunt focuses on growing the party / one cave today.\n'
          '• After it unlocks, the hub hunt may chase Ascend, zones, Daily Vault, Daily Run, or '
          '(when every active hero is Lv${GameLogic.maxHeroLevel}) KEY / Gauntlet / Rifts — one hunt at a time.\n'
          '• When KEY is below dial cap, KEY often wins the hub hunt; Daily Run is still free '
          'essence from the hub or Urgent row.\n'
          '• Clear the floor for +25e base; Dawn Tithe can add more. Then return to hub.\n'
          '• May let you visit a locked zone for the day.\n'
          '• Claim once per UTC day — not the same as CLAIM VAULT.',
    ),
    GuideTopic(
      id: 'codex',
      title: 'CODEX & ACHIEVEMENTS',
      body:
          'MORE → INFO (codex + trophies).\n\n'
          '• Codex records monsters and items you have seen.\n'
          '• Achievements track milestones and grant rewards.\n'
          '• Discovery happens automatically as you play.',
    ),
    GuideTopic(
      id: 'ui',
      title: 'UI TIPS',
      body:
          '• Party strip (bottom-left) fades after idle — tap a hero for kit. '
          'Between fights, tap again to fold; mid-fight the kit stays open.\n'
          '• Target chip sits top-right (name + HP).\n'
          '• Tap METER (top-left) for party rates: DPS, healer HPS, tank damage taken '
          '(bars match unit; tanks/healers also show their damage).\n'
          '• Settings: text scale (S/M/L/XL), dungeon zoom Close/Normal/Wide, '
          'mute + SFX/Ambience/Music volume + haptics, keep screen on in dungeon, Full / Lite / Minimal VFX '
          '(Minimal = reduce motion), colorblind floaters, '
          'bag auto-sell / auto-disassemble.\n'
          '• MORE → INFO brings you back here anytime.\n'
          '• Escape / back closes overlays.',
    ),
  ];
}

class GuideTopic {
  const GuideTopic({required this.id, required this.title, required this.body});

  final String id;
  final String title;
  final String body;
}
