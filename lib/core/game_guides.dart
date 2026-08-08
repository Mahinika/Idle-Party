/// In-game guide copy for More → Guides.
abstract final class GameGuides {
  static const topics = <GuideTopic>[
    GuideTopic(
      id: 'basics',
      title: 'BASICS',
      body:
          'Idle Party is an idle RPG: your party fights in dungeons while you watch and steer.\n\n'
          '• Hub: pick a zone on the World Path, manage gear and meta upgrades.\n'
          '• Dungeon: combat runs automatically. Tap the map to use God Hand.\n'
          '• Gold buys unlocks and market goods. Essence powers permanent meta.\n'
          '• Open MORE for Forge, Sanctuary, Pets, Guides, and more.',
    ),
    GuideTopic(
      id: 'world_path',
      title: 'WORLD PATH',
      body:
          'The hub map lists every dungeon from Sand Caverns through Crystal Spire, '
          'Sunken Tidehold, and Ashen Vault.\n\n'
          '• Tap an unlocked zone to enter.\n'
          '• Unlock the next zone by clearing the previous boss, or by earning enough lifetime gold.\n'
          '• Locked zones show lifetime gold progress (have / need) on the hub.\n'
          '• Lifetime gold (not wallet gold) counts for gold unlocks.\n'
          '• Boss floor is shown on each node (Boss F n).',
    ),
    GuideTopic(
      id: 'combat',
      title: 'COMBAT',
      body:
          'Each floor is one combat wave on a multi-chamber map.\n\n'
          '• Clear a chamber to open gates into the next.\n'
          '• Pick up ground loot (or wait for auto-timeout), then walk to the stairs.\n'
          '• Boss floors use a special arena.\n'
          '• Party HP bars are bottom-left. Target info is bottom-right.\n'
          '• Party meter (top-left) shows DPS, heals/sec (H), and tank taken/sec (T).',
    ),
    GuideTopic(
      id: 'god_hand',
      title: 'GOD HAND',
      body:
          'You are the distant will. Tap the dungeon floor to strike.\n\n'
          '• Deals area damage and briefly steers the party toward the tap.\n'
          '• Cooldown ring is top-right of the dungeon view.\n'
          '• Upgrade God Hand damage with essence (meta).\n'
          '• Upgrade God Hand CD (Forge / Prestige) to shorten the cooldown.\n'
          '• Styles under Forge → META: BALANCED, FOCUS (+damage −radius), WIDE (+radius −damage).',
    ),
    GuideTopic(
      id: 'farm_push',
      title: 'FARM / PUSH',
      body:
          'Toggle at the top of the dungeon view.\n\n'
          '• FARM: after clearing, loop the same floor for more loot/gold.\n'
          '• PUSH: after clearing, advance to the next floor toward the boss.\n'
          '• Use Floor −1 / +1 in the ⋯ menu to travel when allowed.',
    ),
    GuideTopic(
      id: 'party',
      title: 'PARTY',
      body:
          'Unlock WotLK-style specs and build your own party.\n\n'
          '• MORE → PARTY to set active heroes from your roster (4 slots, '
          '5th unlockable with essence at AL 2+).\n'
          '• New Game: pick 3 from the starter specs (Protection, Disc, Fire).\n'
          '• Combat Rogue unlocks after first Ascend; more kits via clears.\n'
          '• More specs unlock via Ascend level and dungeon clears.\n'
          '• Tap a hero in the HUD for abilities; chips show cooldowns.\n'
          '• Resources: Rage / Mana / Energy / Runic — kits spend these.\n'
          '• Roster levels persist on Ascend; run gear still resets.\n'
          '• Flask heals the party when you have a potion.',
    ),
    GuideTopic(
      id: 'bag_equip',
      title: 'BAG & GEAR',
      body:
          'Loot drops on the floor, then goes to your stash (BAG).\n\n'
          '• BAG: view, sell, scrap, or equip stash gear.\n'
          '• GEAR: manage each hero’s slots (bottom nav or dock tab).\n'
          '• Auto-Equip picks clear class upgrades (skips low-iLvl affinity crumbs '
          'on empty slots; worn slots need a meaningful score delta).\n'
          '• Settings / Bag FILTERS: auto-sell weak drops for gold, '
          'auto-disassemble for essence (iLvl + rarity filters).\n'
          '• Near-full bag: merge → sell → scrap automatically.\n'
          '• Compare shows Score (BiS) — swapped pieces return to the bag.',
    ),
    GuideTopic(
      id: 'combinator',
      title: 'COMBINATOR',
      body:
          'Merge two same-slot gear pieces into one stronger item.\n\n'
          '• In BAG: select an item → ADD TO MERGE (or long-press).\n'
          '• Add a second item of the same slot; TOOLS opens when ready.\n'
          '• Check RESULT preview and gold cost, then MERGE.\n'
          '• AUTO MERGE: repeatedly merges junk pairs of the same slot '
          '(skips BiS / clear upgrades) while you can afford the cost.\n'
          '• Both inputs are consumed. Soulbind is separate (3 fragments).',
    ),
    GuideTopic(
      id: 'forge',
      title: 'FORGE',
      body:
          'MORE → FORGE.\n\n'
          '• Train party power with gold / run resources.\n'
          '• Buy relics that permanently boost combat or economy.\n'
          '• Upgrade relic tiers and respec if you change builds.\n'
          '• Refine soulbound gear; upgrade God Hand power and cooldown.\n'
          '• Ascend from the Hub when ready (not from Forge).',
    ),
    GuideTopic(
      id: 'sanctuary',
      title: 'SANCTUARY',
      body:
          'MORE → SANCTUARY. Spend essence on permanent tracks.\n\n'
          '• Gold Find, War Altar, Life Well, and Lore Font (XP).\n'
          '• Tracks level infinitely — cost scales with level.\n'
          '• Optional prestige from level 12+: reset for essence + lasting bonus.\n'
          '• Survives Ascend (meta progress).\n'
          '• Invest early — sanctuary compounds over many runs.',
    ),
    GuideTopic(
      id: 'gauntlet',
      title: 'INFINITY GAUNTLET',
      body:
          'Unlocks at Ascension Level 10 (Spireborn).\n\n'
          '• Endless Crystal Spire climb — each floor gets harder.\n'
          '• Gold and essence scale with floor; boss every 5 floors.\n'
          '• Wipe or leave returns to hub; best floor is saved.\n'
          '• Does not count toward Ascend boss requirements.',
    ),
    GuideTopic(
      id: 'apex',
      title: 'APEX FORGE',
      body:
          'FORGE → MATERIALS / APEX.\n\n'
          '• Craft the strongest class/role gear from boss-only materials.\n'
          '• Materials live in a separate bag (not gear stash) and survive Ascend.\n'
          '• Farm bosses on each dungeon — trash packs never drop mats.\n'
          '• Craft weapon R1 first, then armor; upgrade pieces in place to R3.\n'
          '• Apex gear stays equipped through Ascend.',
    ),
    GuideTopic(
      id: 'market',
      title: 'MARKET',
      body:
          'MORE → MARKET.\n\n'
          '• Buy flasks and consumables with gold.\n'
          '• Sell stash junk when the bag is full.\n'
          '• Keep at least one flask for tough floors and bosses.',
    ),
    GuideTopic(
      id: 'pets',
      title: 'BEAST PEN',
      body:
          'MORE → BEAST PEN.\n\n'
          '• Hatch and level pets with essence.\n'
          '• Merge two same-species pets into a higher rarity.\n'
          '• Favorite a species, bond for power, buy portrait frames.\n'
          '• Active pet follows in combat and chips damage.\n'
          '• Pets are meta — they survive Ascend.',
    ),
    GuideTopic(
      id: 'prestige_shop',
      title: 'ESSENCE SHOP',
      body:
          'MORE → ESSENCE SHOP (AL-gated).\n\n'
          '• Spend essence on permanent stash slots, pet roster, GH CD, and more.\n'
          '• Purchases survive Ascend.\n'
          '• Unlock higher offerings as Ascension Level rises.',
    ),
    GuideTopic(
      id: 'jobs',
      title: 'CONTRACTS',
      body:
          'MORE → CONTRACTS.\n\n'
          '• Goals rotate: kills, elites, floors, bosses, gold.\n'
          '• Hard / Brutal variants pay more and take longer.\n'
          '• Targets scale with Ascension, zones cleared, and hardmode.\n'
          '• Claiming rolls a new contract (usually a different type).\n'
          '• Claim 3 in a row for a +5e chain bonus.\n'
          '• The MORE menu may show CONTRACTS (n) when claims are ready.\n'
          '• The top CLAIM chip claims all ready contracts at once '
          '(visible in combat too; long-press opens the list).',
    ),
    GuideTopic(
      id: 'weekly',
      title: 'WEEKLY',
      body:
          'Each ISO week rolls a dungeon modifier (glass / swarm / elite / fortune / iron).\n\n'
          '• Clear 3 floors under that week’s modifier to fill progress (hub shows n/3).\n'
          '• Claim the weekly essence reward once progress hits 3/3.\n'
          '• Hub TODAY card points at your next chase (weekly, daily, Will, Gauntlet, zone).\n'
          '• First claim of each calendar month also pays a season bonus.\n'
          '• Progress resets when the week key rolls over.\n'
          '• Will ranks and Gauntlet F25/50/100 grant one-time essence when unlocked.',
    ),
    GuideTopic(
      id: 'loadouts',
      title: 'LOADOUTS',
      body:
          'MORE → LOADOUTS (named gear presets).\n\n'
          '• Save up to 3 named presets (by hero id).\n'
          '• Apply a loadout to swap equipped gear quickly.\n'
          '• Handy when switching Farm vs Push or Hardmode setups.\n'
          '• Party lineup is separate — use MORE → PARTY.\n'
          '• Not the same as dungeon armor sets (2pc/4pc bonuses + combat procs).',
    ),
    GuideTopic(
      id: 'armor_sets',
      title: 'ARMOR SETS',
      body:
          'Rare+ armor from a zone can form a dungeon set (head / shoulder / chest / legs).\n\n'
          '• 2pc: flat stamina (or spirit on cloth).\n'
          '• 4pc: more stats + role fantasy + a chance for a tagged set proc on autos.\n'
          '• Set names follow the zone (Tidehold, Ashen, Spire, …).\n'
          '• Loadouts are separate presets — see LOADOUTS.',
    ),
    GuideTopic(
      id: 'hardmode',
      title: 'HARDMODE & CHALLENGES',
      body:
          'Set before entering a dungeon (hub challenge panel).\n\n'
          '• Hardmode is AL-gated: max HM = min(10, 3 + AL÷2).\n'
          '• Hardmode +1…+10: huge enemy HP, damage, and pack size.\n'
          '• At HM+10: about 1000% (10×) HP, ATK, and enemy count.\n'
          '• Boss Rush / No Flask: harder clears, extra essence.\n'
          '• Hardmode also pays more gold — high risk, high reward.',
    ),
    GuideTopic(
      id: 'ascend',
      title: 'ASCEND',
      body:
          'Prestige when Ascend unlocks in the hub.\n\n'
          '• Resets run gear, stash, and floor progress.\n'
          '• Keeps: essence, relics, sanctuary, pets, soulbound, God Hand, '
          'highest dungeon cleared, lifetime gold, unlocked specs, '
          'roster levels/XP, and 5th party slot.\n'
          '• Grants essence and raises Ascension Level (AL).\n'
          '• AL makes later runs tougher but richer in meta power.',
    ),
    GuideTopic(
      id: 'daily',
      title: 'DAILY RUN',
      body:
          'A daily echo dungeon appears on the hub when available.\n\n'
          '• Clear the required floor(s) for a flat essence reward.\n'
          '• May let you visit a locked zone for the day.\n'
          '• Claim once per day — good free essence.',
    ),
    GuideTopic(
      id: 'codex',
      title: 'CODEX & ACHIEVEMENTS',
      body:
          'MORE → CODEX / ACHIEVEMENTS.\n\n'
          '• Codex records monsters and items you have seen.\n'
          '• Achievements track milestones and grant rewards.\n'
          '• Discovery happens automatically as you play.',
    ),
    GuideTopic(
      id: 'ui',
      title: 'UI TIPS',
      body:
          '• Party frame (bottom-left) shrinks on phones and fades after idle — tap to wake.\n'
          '• Party meter appears once heroes fight, heal, or take hits.\n'
          '• Settings: text scale, reduced VFX, colorblind floaters, '
          'bag auto-sell / auto-disassemble.\n'
          '• MORE → GUIDES brings you back here anytime.\n'
          '• Escape / back closes overlays.',
    ),
  ];
}

class GuideTopic {
  const GuideTopic({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;
}
