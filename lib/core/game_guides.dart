/// In-game guide copy for META → GUIDE.
abstract final class GameGuides {
  static const topics = <GuideTopic>[
    GuideTopic(
      id: 'basics',
      title: 'BASICS',
      body:
          'You have a small party of heroes. They fight on their own.\n\n'
          '• Tap ENTER DUNGEON to start the first cave (Sandy Caverns).\n'
          '• Watch them clear rooms. Tap the map (God Hand) when you want to help.\n'
          '• TODAY on the hub always names the next job — start there.\n'
          '• Gold buys supplies and run power. Essence buys lasting power.\n'
          '• Bottom buttons (same in hub and dungeon): PARTY (heroes and gear), '
          'POWER (upgrades), META (extras and Guides), HUB (home).\n'
          '• A number on a button means something waits inside — PARTY 3 means '
          '3 better items for the party. No number means nothing to do there.\n'
          '• Menus stay small at the start; more tabs appear as you unlock them.\n'
          '• You do not need to have played another RPG. Names like PROT / DISC / FIRE '
          'are just the three starter jobs: Shield, Healer, Damage.',
    ),
    GuideTopic(
      id: 'world_path',
      title: 'WORLD PATH',
      body:
          'The hub World Path is a painted map from Sandy Caverns through Mothveil Hollow '
          '(Tidehold, Ashen Vault, Hollow Grove, Stormwake, Rimeglass, Blightfen, Brassvault, and the rest along the road).\n\n'
          '• Scroll the map and tap a zone portrait on a glowing ring to select it.\n'
          '• Markers show HERE / OPEN / CLEAR / LOCKED under each portrait.\n'
          '• Unlock the next zone by clearing the previous boss, or by earning enough lifetime gold.\n'
          '• Locked zones dim on the map; the caption under the map shows lifetime gold progress (have / need).\n'
          '• Lifetime gold (not wallet gold) counts for gold unlocks.\n'
          "• Goblin's Hideout: stolen-stash chests pay better gold but wake ambush guards.\n"
          '• Boss floor is shown under Hero\'s Keep (Boss F n).',
    ),
    GuideTopic(
      id: 'combat',
      title: 'COMBAT',
      body:
          'Each floor is one combat wave on a multi-chamber map.\n\n'
          '• Clear a chamber to open gates into the next — OPEN pops on the door.\n'
          '• When the pack is dead, ground loot banks instantly and the party '
          'heads to the stairs — GO marks the exit.\n'
          '• Elite and treasure floors often hide a room chest — grabbed with '
          'the floor clear.\n'
          '• Boss floors use a special arena.\n'
          '• Settings VFX: Full = all effects; Lite = no floaters/bursts (discs & auras stay); '
          'Minimal = reduce motion.\n'
          '• Party HP strip is bottom-left — tap a hero to open their kit, tap again to fold. Level and XP sit under HP.\n'
          '• Gold in the top bar ticks up as pickups land.\n'
          '• Target chip is top-right (name + HP).\n'
          '• Tap METER (top-left) for DPS / healer HPS / tank damage taken.',
    ),
    GuideTopic(
      id: 'god_hand',
      title: 'GOD HAND',
      body:
          'Tap the dungeon floor to help: smash enemies and steer the party.\n\n'
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
          'Your party is three jobs: Shield (soaks hits), Healer (keeps people up), '
          'and Damage (kills enemies).\n\n'
          '• PARTY → ROSTER to swap who is fighting (4 slots, '
          '5th unlockable later).\n'
          '• New Game: pick 3 starters — Protection (Shield), Discipline (Healer), '
          'Fire (Damage) is the easy mix.\n'
          '• More hero types unlock as you grow — you do not need another game.\n'
          '• Tap a hero in the HUD for abilities; chips show cooldowns '
          '(STREAK, SWEEP / FLURRY, BEACON when those windows are up).\n'
          '• The strip shows level and a thin XP bar so growth is visible mid-fight.\n'
          '• Resources: Rage / Mana / Energy / Runic — kits spend these.\n'
          '• Roster levels persist on Ascend; run gear still resets.\n'
          '• Flask heals the party when you have a potion.',
    ),
    GuideTopic(
      id: 'bag_equip',
      title: 'BAG & GEAR',
      body:
          'Loot drops on the floor, then goes to your stash (BAG).\n\n'
          '• You never have to hunt for upgrades: when PARTY shows a number, '
          'open it and tap EQUIP — that number is how many items are better.\n'
          '• BAG: view, sell, scrap, or equip stash gear.\n'
          '• Stats: plate wants Strength, leather/mail damage wants Agility, '
          'casters want Intellect and Spell Power. Spirit is mana, not damage. '
          'Secondaries are Crit / Haste / Mp5 — new drops keep ≤2 (no Move). '
          'Healers roll Mp5 then Crit (Haste last — heals do not haste). '
          'Near 75% crit, Auto Equip stops chasing more Crit.\n'
          '• Armor type is a hard gate: Warrior / Paladin / DK wear plate; '
          'Hunter starts leather then mail at 40; Shaman mail; Rogue leather; '
          'Druid leather (cloth OK); Priest / Mage / Warlock cloth. '
          'Auto Equip never puts the wrong material on a hero.\n'
          '• Weapons are a hard gate too: Paladin no daggers, Priest no swords, '
          'Hunter no maces. Dual-wield is Rogue / Fury / Enhancement / Frost DK / '
          'Survival. Shields are Warrior / Paladin / Shaman. Paladin / DK / Shaman / '
          'Druid have no ranged slot (empty is fine). Drops skip slots nobody '
          'in the party can wear, so a tank still sees shields.\n'
          '• CHARM (trinket) drops always come with an on-item effect '
          '(lifesteal, crit, gold find, …).\n'
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
          '• Check RESULT preview (rarity, iLvl, SCORE jump) and gold cost, then MERGE.\n'
          '• AUTO MERGE: repeatedly merges junk pairs of the same slot '
          '(skips BiS / clear upgrades) while you can afford the cost.\n'
          '• Combinator Charm in POWER → SHOP lowers MERGE gold (−3g per luck).\n'
          '• Both inputs are consumed.',
    ),
    GuideTopic(
      id: 'income',
      title: 'INCOME',
      body:
          'POWER → INCOME.\n\n'
          'Your incremental dashboard: Hub gold/min, Run gold/min (from real '
          'loot in the last couple of minutes), gold % multipliers, and Gold Find '
          '— the keep generator that raises Hub rate.\n\n'
          'Buy one Gold Find level or up to five at once when you can afford them. '
          'Affordable upgrades glow here and on CAMP.',
    ),
    GuideTopic(
      id: 'forge',
      title: 'FORGE',
      body:
          'POWER → FORGE.\n\n'
          'Tabs:\n'
          '• GOLD — spend gold this run. ATK/DEF/STA/MOVE/HASTE/CRIT. '
          'Train = +1 level to every hero '
          '(levels keep on Ascend). ATK/DEF/STA/MOVE/HASTE/CRIT wipe on Ascend. '
          'ATK, HASTE, and MOVE speed up clears — see INCOME for rates. '
          'One gold buy is similar punch: ATK hits, DEF is armor, STA is HP, '
          'HASTE and CRIT are the same percent step. BEST marks the cheapest '
          'relative upgrade.\n'
          '• KEEP — essence that survives Ascend: Blessing readout, relics, '
          'God Hand smash/cooldown/style, and the 5th party '
          'slot (AL2 · 80e).\n'
          '• APEX — one Apex station: materials, craft goals, target meter, vault.\n\n'
          '• Ascend from the Hub when ready (not from Forge).',
    ),
    GuideTopic(
      id: 'classes',
      title: 'CLASS UNLOCKS',
      body:
          'Ascend grows your roster — TODAY and Ascend teasers name the next kits '
          'with a short fantasy line plus a Watch… combat hook.\n\n'
          '• AL1: Combat Rogue, Arms, Holy Paladin\n'
          '• AL2: Beast Mastery, Holy Priest, Arcane · 5th party slot '
          '(Forge KEEP · 80e)\n'
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
          '• See POWER → INCOME for Hub / Run rates and Gold Find upgrades.\n'
          '• Gold Find, War Altar, Life Well, and Lore Font (XP).\n'
          '• Hub gold/min ticks while you sit at the keep — Gold Find raises that rate (shown on the hub and on CAMP).\n'
          '• Tracks level infinitely — cost scales with level.\n'
          '• Optional prestige from Lv12: reset to Lv0 (upgrades cheap again). '
          'You keep a small forever bonus '
          '(+3% gold / +1 ATK / +12 HP / +2% XP) and get 25+level essence back. '
          'The big level bonus is gone until you buy levels again.\n'
          '• Owned KEEP relics (ATK / DEF / HP / loot) also list on CAMP.\n'
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
          'FORGE → APEX.\n\n'
          '• One screen: materials, party craft goals, target meter, craft, vault.\n'
          '• Tap a party goal card to chase that hero\'s next Apex piece.\n'
          '• Target meter: every boss clear builds toward a guaranteed mat (PUSH faster than FARM).\n'
          '• Tap a recipe mat to lock the target; Auto Equip All equips vault Apex on matching heroes.\n'
          '• Craft weapon R1 first, then armor; upgrade in place to R3.\n'
          '• Apex gear and materials survive Ascend.',
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
          '• Hatch and level pets with essence (random species and rarity).\n'
          '• Merge two same-species pets of the same rarity into a higher rarity.\n'
          '• Favorite a species: +1 ATK and a stronger passive while that pet is ACTIVE.\n'
          '• Bond for +1 ATK every 5 ranks (max 25). Frames are looks only.\n'
          '• Active pet follows in combat and chips damage (cyan hits, ally ring).\n'
          '• Beast Mastery / Demonology / Unholy also bring a class companion '
          '(Hunter Pet / Felguard / Ghoul). Enhancement wolves and Frost Water '
          'Elemental are timed summons.\n'
          '• Pets are meta — they survive Ascend.',
    ),
    GuideTopic(
      id: 'prestige_shop',
      title: 'ESSENCE SHOP',
      body:
          'POWER → SHOP (AL-gated).\n\n'
          '• Spend essence on stash slots, cheaper MERGE gold, pet roster, '
          'extra loadout slots, cheaper market flasks, higher auto-sell/scrap '
          'ceilings, more Welcome Back rows, God Hand CD (same as Forge → KEEP), '
          'Dawn Tithe (vault + Daily Run), and more.\n'
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
          'Daily, KEY, and vault-start wait until you have beaten a boss (or Ascended).\n'
          '• After that first hour, TODAY chases KEY +1 (higher iLvl loot) until '
          'your key hits the AL cap — then Daily / vault / Will can surface.\n'
          '• Fill today’s vault with 1 dungeon clear, then claim essence.\n'
          '• Later: time a KEY +2 (or higher) for a bigger claim — META → KEY.\n'
          '• Hub TODAY and offline Up next share one chase (claim → READY → '
          'ALMOST → grind) — same title whether you are in the hub or returning from AFK.\n'
          '• Welcome-back shows one wow line, a few highlights, then Up next.\n'
          '• TODAY flashes READY / ALMOST when a claim or Ascend is close.\n'
          '• First vault claim of each calendar month also pays a season bonus.\n'
          '• Each ISO week has a named local season beat (KEY +2 or Gauntlet floor) '
          '— TODAY / META may chase it; claim pays essence + title.\n'
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
          'Mythic+-style keys from the hub KEY panel (META → KEY) — set before you enter.\n\n'
          '• Key level is AL-gated (cap rises with Ascension, up to +20).\n'
          '• Affixes lock on enter (weekly + Fortified/Tyrannical at +4, more at higher keys).\n'
          '• Idle-friendly timer: AFK time counts; beat the boss under par to TIMED upgrade.\n'
          '• Overtime = depleted (clear still counts, no key upgrade).\n'
          '• Daily vault: 1 clear or timed KEY+2 — claim once per day.\n'
          '• Optional Boss Rush / No Flask add extra affixes + essence.\n'
          '• Higher keys drop higher iLvl gear (KEY +10 is a real jump) plus '
          'denser packs, more gold, and better legendary odds.\n'
          '• After the first boss/Ascend, hub TODAY points at the next KEY until '
          'you are at the AL cap.',
    ),
    GuideTopic(
      id: 'ascend',
      title: 'ASCEND',
      body:
          'Prestige when Ascend unlocks in the hub.\n\n'
          '• Each Ascend grants a lasting Blessing: +2 ATK · +8 DEF · +24 STA · '
          '+3% gold (stacks forever). See Forge → KEEP.\n'
          '• Confirm / toast show the next unlock (Combat Rogue, 5th slot, Gauntlet…).\n'
          '• Also raises Ascension Level (AL: +ATK/STA/+10% gold per level) and pays essence.\n'
          '• Keeps: essence, relics, sanctuary, pets, God Hand, '
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
          '• After the first hour, TODAY chases KEY — Daily is extra essence, '
          'not the default habit.\n'
          '• TODAY offers Daily when your KEY is at the AL cap (or KEY is not the grind).\n'
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
          '• Settings: text scale, Full / Lite / Minimal VFX (Minimal = reduce motion), '
          'colorblind floaters, '
          'bag auto-sell / auto-disassemble.\n'
          '• META → GUIDE brings you back here anytime.\n'
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
