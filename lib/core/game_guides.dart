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
          '• Open POWER (Forge, Camp, Market, Shop) or META (Key, Jobs, Guides…) '
          'from the bottom nav — same labels in hub and dungeon.',
    ),
    GuideTopic(
      id: 'world_path',
      title: 'WORLD PATH',
      body:
          'The hub World Path is a painted map from Sandy Caverns through Rimeglass Rift '
          '(Tidehold, Ashen Vault, Hollow Grove, Stormwake, and the rest along the road).\n\n'
          '• Scroll the map and tap a zone portrait on a glowing ring to select it.\n'
          '• Unlock the next zone by clearing the previous boss, or by earning enough lifetime gold.\n'
          '• Locked zones dim on the map; the caption under the map shows lifetime gold progress (have / need).\n'
          '• Lifetime gold (not wallet gold) counts for gold unlocks.\n'
          '• Boss floor is shown under Hero\'s Keep (Boss F n).',
    ),
    GuideTopic(
      id: 'combat',
      title: 'COMBAT',
      body:
          'Each floor is one combat wave on a multi-chamber map.\n\n'
          '• Clear a chamber to open gates into the next.\n'
          '• Pick up ground loot (or wait for auto-timeout), then walk to the stairs.\n'
          '• Elite and treasure floors often hide a room chest — grab it like other floor loot.\n'
          '• Boss floors use a special arena.\n'
          '• Party HP strip is bottom-left — tap a hero to open their kit, tap again to fold.\n'
          '• Target chip is top-right (name + HP).\n'
          '• Tap METER (top-left) for DPS / healer HPS / tank damage taken.'
    ),
    GuideTopic(
      id: 'god_hand',
      title: 'GOD HAND',
      body:
          'You are the distant will. Tap the dungeon floor to steer and burst.\n\n'
          '• First job: smash a pack and pull the party toward your tap.\n'
          '• Cooldown ring is top-right of the dungeon view.\n'
          '• Forge → KEEP (soft knobs): more damage, shorter CD, BAL / FOCUS / WIDE styles.\n'
          '• Styles trade damage vs radius — not a second talent tree.\n'
          '• Upgrades use essence and survive Ascend.',
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
          '• PARTY → ROSTER to set active heroes from your roster (4 slots, '
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
          '• Stats: Primary (Armor, Str/Agi/Int, Sta, Spirit, Spell Power) and '
          'Secondary (Crit, Haste, Mp5) — new drops keep ≤2 secondaries (no Move).\n'
          '• Item level is the power size; green UPGRADE means Auto Equip would swap '
          '(same score for both — no affinity/armor ghost points).\n'
          '• GEAR: paper-doll per hero — UNEQUIP worn pieces, AUTO EQUIP from bag.\n'
          '• Tap an empty GEAR slot to open BAG filtered to that slot.\n'
          '• SELL only scraps items in BAG (unequip first).\n'
          '• Auto-Equip follows budget stats (skips crumbs; will not swap to clearly '
          'lower iLvl without a real power jump; 1H+off-hand can beat a lonely 2H).\n'
          '• Armor sets (2pc/4pc) give combat bonuses — not fake BiS score.\n'
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
          '• In BAG: select an item → ADD TO MERGE.\n'
          '• Long-press any item for the full tip card.\n'
          '• Add a second item of the same slot; MERGE opens when ready.\n'
          '• Check RESULT preview and gold cost, then MERGE.\n'
          '• AUTO MERGE: repeatedly merges junk pairs of the same slot '
          '(skips BiS / clear upgrades) while you can afford the cost.\n'
          '• Both inputs are consumed. Soulbind is separate (3 fragments).',
    ),
    GuideTopic(
      id: 'forge',
      title: 'FORGE',
      body:
          'POWER → FORGE.\n\n'
          'Tabs:\n'
          '• GOLD — spend gold this run. Train = +1 level to every hero '
          '(levels keep on Ascend). ATK/DEF/STA/MOVE/HASTE/CRIT wipe on Ascend. '
          'BEST marks the cheapest relative upgrade.\n'
          '• KEEP — essence that survives Ascend: relics, soulbound refine, '
          'God Hand damage/cooldown/style.\n'
          '• MATS / APEX — boss materials and Apex craft.\n\n'
          '• Ascend from the Hub when ready (not from Forge).',
    ),
    GuideTopic(
      id: 'classes',
      title: 'CLASS UNLOCKS',
      body:
          'Ascend grows your roster — TODAY and Ascend teasers name the next kits '
          'with a short fantasy line plus a Watch… combat hook.\n\n'
          '• AL1: Combat Rogue, Arms\n'
          '• AL2: Beast Mastery, Holy Priest, Arcane · 5th party slot (essence)\n'
          '• AL3: Prot Paladin, Assassination, Resto Shaman, Frost Mage, Resto Druid\n'
          '• AL4: Survival, Elemental, Enhancement, Balance, Feral\n'
          '• AL5: Blood DK, Frost DK, Guardian\n'
          '• AL6: Affliction, Demonology\n'
          '• AL10: Infinity Gauntlet\n\n'
          'Some kits also unlock from zone clears or the Prestige Shop — see each '
          'spec’s unlock hint in PARTY.',
    ),
    GuideTopic(
      id: 'sanctuary',
      title: 'SANCTUARY',
      body:
          'POWER → CAMP. Spend essence on permanent tracks.\n\n'
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
          'FORGE → MATS / APEX.\n\n'
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
          'POWER → MARKET.\n\n'
          '• Buy flasks and consumables with gold.\n'
          '• Sell stash junk when the bag is full.\n'
          '• Keep at least one flask for tough floors and bosses.',
    ),
    GuideTopic(
      id: 'pets',
      title: 'BEAST PEN',
      body:
          'META → BEAST.\n\n'
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
          'POWER → SHOP (AL-gated).\n\n'
          '• Spend essence on permanent stash slots, pet roster, GH CD, and more.\n'
          '• Purchases survive Ascend.\n'
          '• Unlock higher offerings as Ascension Level rises.',
    ),
    GuideTopic(
      id: 'jobs',
      title: 'CONTRACTS',
      body:
          'META → JOBS.\n\n'
          '• Goals rotate: kills, elites, floors, bosses, gold.\n'
          '• Hard / Brutal variants pay more and take longer.\n'
          '• Targets scale with Ascension, zones cleared, and hardmode.\n'
          '• Claiming rolls a new contract (usually a different type).\n'
          '• Claim 3 in a row for a +5e chain bonus.\n'
          '• Hub META badge may show ! when claims are ready.\n'
          '• The top CLAIM chip claims all ready contracts at once '
          '(visible in combat too; long-press opens the list).',
    ),
    GuideTopic(
      id: 'weekly',
      title: 'DAILY VAULT',
      body:
          'Keystone affixes still rotate each ISO week, but the vault is daily.\n\n'
          '• Early on: TODAY tells you to grow the party in the starter zone. '
          'Daily and vault-start wait until you have beaten a boss (or Ascended).\n'
          '• Fill today’s vault with 1 dungeon clear, then claim essence.\n'
          '• Later: time a KEY +2 (or higher) for a bigger claim — META → KEYSTONE.\n'
          '• Hub TODAY and offline Up next share one chase (claim → READY → '
          'ALMOST → grind) — same title whether you are in the hub or returning from AFK.\n'
          '• Welcome-back shows one wow line, a few highlights, then Up next.\n'
          '• TODAY flashes READY / ALMOST when a claim or Ascend is close.\n'
          '• First vault claim of each calendar month also pays a season bonus.\n'
          '• Progress resets at UTC midnight.\n'
          '• Will ranks and Gauntlet F25/50/100 grant one-time essence when unlocked.',
    ),
    GuideTopic(
      id: 'loadouts',
      title: 'LOADOUTS',
      body:
          'PARTY → LOADOUTS (named gear presets).\n\n'
          '• Save up to 3 named presets (by hero id).\n'
          '• Apply a loadout to swap equipped gear quickly.\n'
          '• Handy when switching Farm vs Push or Keystone setups.\n'
          '• Party lineup is separate — use PARTY → ROSTER.\n'
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
      title: 'KEYSTONE RUNS',
      body:
          'Mythic+-style keys from the hub KEYSTONE panel — set before you enter.\n\n'
          '• Key level is AL-gated (cap rises with Ascension, up to +20).\n'
          '• Affixes lock on enter (weekly + Fortified/Tyrannical at +4, more at higher keys).\n'
          '• Idle-friendly timer: AFK time counts; beat the boss under par to TIMED upgrade.\n'
          '• Overtime = depleted (clear still counts, no key upgrade).\n'
          '• Daily vault: 1 clear or timed KEY+2 — claim once per day.\n'
          '• Optional Boss Rush / No Flask add extra affixes + essence.\n'
          '• Higher keys: denser packs, more gold, better legendary odds.',
    ),
    GuideTopic(
      id: 'ascend',
      title: 'ASCEND',
      body:
          'Prestige when Ascend unlocks in the hub.\n\n'
          '• Each Ascend grants a lasting Blessing: +2 ATK · +1 DEF · +4 STA · '
          '+3% gold (stacks forever). See Forge → KEEP.\n'
          '• Confirm / toast show the next unlock (Combat Rogue, 5th slot, Gauntlet…).\n'
          '• Also raises Ascension Level (AL: +ATK/STA/+10% gold per level) and pays essence.\n'
          '• Keeps: essence, relics, sanctuary, pets, soulbound, God Hand, '
          'highest dungeon cleared, lifetime gold, unlocked specs, '
          'roster levels/XP, Apex, and 5th party slot.\n'
          '• Resets: wallet gold, floors, run gear, loadouts, forge gold upgrades.\n'
          '• AL makes later runs tougher but richer in meta power.',
    ),
    GuideTopic(
      id: 'daily',
      title: 'DAILY RUN',
      body:
          'A daily echo dungeon appears on the hub when available.\n\n'
          '• TODAY offers Daily after you have beaten a boss or Ascended once.\n'
          '• Clear the required floor(s) for a flat essence reward.\n'
          '• May let you visit a locked zone for the day.\n'
          '• Claim once per day — good free essence.',
    ),
    GuideTopic(
      id: 'codex',
      title: 'CODEX & ACHIEVEMENTS',
      body:
          'META → CODEX (codex + trophies).\n\n'
          '• Codex records monsters and items you have seen.\n'
          '• Achievements track milestones and grant rewards.\n'
          '• Discovery happens automatically as you play.',
    ),
    GuideTopic(
      id: 'ui',
      title: 'UI TIPS',
      body:
          '• Party strip (bottom-left) fades after idle — tap a hero for kit, tap again to fold.\n'
          '• Target chip sits top-right (name + HP).\n'
          '• Tap METER (top-left) for DPS / healer HPS / tank damage taken.\n'
          '• Settings: text scale, reduced VFX, colorblind floaters, '
          'bag auto-sell / auto-disassemble.\n'
          '• META → GUIDE brings you back here anytime.\n'
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
