import '../models/apex_craft.dart';
import '../models/achievement_def.dart';
import '../models/dungeon_def.dart';
import '../models/enemy.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/pet.dart';
import 'game_state.dart';

/// One versioned What's New block (newest releases first in [MetaSystems.releases]).
class ChangelogRelease {
  const ChangelogRelease({required this.version, required this.bullets});
  final String version;
  final List<String> bullets;
}

/// Free, offline meta systems: daily run seeding, local achievements,
/// codex discovery tracking, and the in-app changelog. No servers, no
/// monetization — everything here is a pure function over [GameState].
abstract final class MetaSystems {
  /// Current build's changelog version. Keep in sync with pubspec version.
  static const String currentVersion = '1.12.19';

  /// Structured releases, newest first. Older highlights are condensed.
  static const List<ChangelogRelease> releases = <ChangelogRelease>[
    ChangelogRelease(
      version: '1.12.19',
      bullets: <String>[
        'Floor clear: when the last enemy dies, loot banks instantly and the party walks straight to the stairs — no more idle shuffle waiting for vacuum.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.18',
      bullets: <String>[
        'Apex is the forever gear. Heirloom soulbind (fragments / bind / refine) is retired — FORGE → APEX is the keep path.',
        'Older saves still keep a bound heirloom’s party bonus. New runs do not earn soulbind fragments.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.17',
      bullets: <String>[
        'FORGE → APEX: one station — party craft goals, target material meter, vault cards, and Auto Equip All.',
        'Boss clears now build a guaranteed mat toward your craft goal (PUSH fills the meter faster than FARM). Craft tries to equip on the matching hero automatically.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.16',
      bullets: <String>[
        'POWER → INCOME: Hub and Run gold/min, gold % multipliers, and Gold Find as your keep generator — one tab for the incremental loop.',
        'Gold Find: buy one level or up to five at once when you can afford them; affordable upgrades glow on INCOME and CAMP.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.15',
      bullets: <String>[
        'Dungeon gold/min is real loot from the last couple of minutes — Hub and Run sit on the floor HUD and POWER → FORGE GOLD.',
        'Gold Find and Blessing preview +g/min on both rates. ATK / HASTE / MOVE say faster clears (and last floor time) instead of fake gold.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.14',
      bullets: <String>[
        'The keep pays gold while you sit there — hub gold/min is on the header, and it ticks live (same rate as sanctuary AFK).',
        'POWER → CAMP shows that rate plus AL / CAMP / Blessing gold %. Gold Find preview is +g/min, and buying it bumps the keep rate immediately.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.13',
      bullets: <String>[
        'Crits thump in your hand, and LEVEL UP stays on screen instead of hiding behind damage numbers.',
        'Kills pop on the map. Gold, XP, and gear names stay bigger than damage ticks so pickups read on a phone.',
        'Clearing a chamber shouts OPEN on the door so the next pack is obvious.',
        'When the pack is down, stairs shout GO so the next floor is obvious.',
        'On a phone the party strip shows level and XP, and the dungeon HUD shows gold ticking up.',
        'Kit chips flash when a dump fires. Flasks shout FLASK, and loot streaks into the party.',
        'Tapping God Hand slams when it fires — waiting on cooldown stays quiet.',
        'Floor clear holds a beat in bigger type so gold and a level-up are readable on a phone. Boss kills shout BOSS DOWN.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.12',
      bullets: <String>[
        'Armor now cuts a percent of each hit — more DEF always helps, but nothing is immortal (packs included).',
        'Agility is the damage stat for rogues, hunters, cats, and Enhancement (Strength still rules plate).',
        'Caster gear: Intellect and Spell Power both feed damage the same way; Intellect still adds crit.',
        'Drops, starters, and Apex spend power on those same stats — no leftover Attack Power dump.',
        'Each class wears one armor: plate, mail, leather, or cloth — a Paladin will not put on leather just because the stats look bigger.',
        'Weapons are the same kind of hard gate: a Paladin will not take a dagger, a Priest will not take a sword, and Paladin / DK / Shaman / Druid leave the ranged slot empty.',
        'Balance Druid Moonkin Form thickens the hide, and Barkskin is ready before the floor gets nasty.',
        'Fury Warrior Rampage dumps mid-fight, Recklessness is an all-in damage window, and Death Wish hits harder — not a haste snack.',
        'Every kit now shows its signature dump and panic button on a typical floor — Templar''s Verdict, Trueshot, Ice Block, Shield Wall, and the rest no longer wait until 15.',
        'POWER → FORGE gold buys match each other again: DEF is a real armor chunk, STA is HP, and CRIT steps with HASTE. CAMP Life Well HP matches War Altar ATK. KEEP relics, Blessing, and Ascend flats use the same ATK / armor / HP split.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.11',
      bullets: <String>[
        'Lighter install and snappier hub: less art baggage, and the map only redraws what moved.',
        'One bottom bar in hub and dungeon — PARTY / POWER / META keep the same tab when you enter or leave a floor.',
        'Every zone has its own boss and trash look (plus pets stop borrowing enemy sprites).',
        'Long AFK returns without freezing the phone; bag cleanup and craft mat toasts stay honest.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.10',
      bullets: <String>[
        'First hour talks plain English: intro, New Game (Shield / Healer / Damage), and TODAY skip kit names until you beat a boss. No other RPG required.',
        'Guides BASICS / PARTY and first tips explain the loop: party fights on its own, tap ENTER DUNGEON, tap the map to help.',
        'Menus tell you when to look: PARTY / POWER / META show a number when gear, gold or claims are waiting, and PARTY has a one-tap EQUIP 3.',
        'Calmer menus early — MERGE, LOADOUTS, ROSTER, CAMP, SHOP, KEY, BEAST and CODEX tabs appear when they unlock instead of on day one.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.9',
      bullets: <String>[
        'Optional Play Games in MORE: seasonal Timed KEY + Gauntlet boards and cloud save (sign-in; clipboard backup still works).',
        'Protection / Discipline / Fire / Combat kits now share the same cast engine as every other spec (same feel, cleaner wiring).',
        'Tidehold / Ashen Vault / Hollow Grove read clearer apart from Crystal / Hell / Fen (wash, floors, props, trash sprites).',
        'Hub TODAY shows KEY · Vault · Week crumbs under the chase so you always see today’s meta on a phone.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.8',
      bullets: <String>[
        'Combat Rogue hits harder so the kit sits with other melee.',
        'Holy Priest Guardian Spirit is a real emergency save; Resto Lifebloom is a HoT again.',
        'Local season weeks named for late summer (Moth Dust / Brass Tempo) + KEYSTONE week-goal card.',
        'Tide / Ember / Grove layout kits lean harder into water alcoves, lava chokes, and root choke rooms.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.7',
      bullets: <String>[
        'Kit fantasy pass: Blood Bone Shield, Guardian Lacerate, Fury Enraged Regeneration, Unholy Gargoyle actually summons, Subtlety Preparation resets CDs.',
        'Pack tools: Elemental Flame Shock, Frost Mage Blizzard, Destruction Rain of Fire, Survival Multi-Shot — rain/fan AoEs aim at your focus pack.',
        'Healers unchanged — party heals already cover their fantasy.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.6',
      bullets: <String>[
        'Kit AoE gaps filled: Affliction Seed of Corruption, Assassination/Subtlety Fan of Knives, Shadow Mind Sear, Feral Swipe, Holy Paladin Consecration.',
        'Healers still clear packs via party heals (CoH / Holy Nova / Healing Rain / Wild Growth) — damage AoE was the missing feel on ST-heavy DPS.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.5',
      bullets: <String>[
        'VFX: Lite keeps ground discs (Consecration / Bladestorm) and auras — only Full shows floaters/bursts; Minimal still reduces motion.',
        'Signature kits (Execute, TV, Pyroblast, Chaos Bolt, Tranquility, …) get explicit cast tints / discs so fantasy reads clearer.',
        'Melee trails read thicker on Full; Lite/Minimal use a short bright slash nub.',
        'Settings + Guides name Full / Lite / Minimal honestly.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.4',
      bullets: <String>[
        'World Path map: endgame road (Rimeglass → Blightfen → Brassvault → Mothveil) painted as continuous terrain — not glued color bands.',
        'Hub path markers: clearer HERE / OPEN / CLEAR / LOCKED labels, bigger tap targets, lifetime gold as 1.2M / 750k.',
        'Zone caption shows boss + flavor when unlocked; locked still shows have/need lifetime gold.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.3',
      bullets: <String>[
        'World Path: Mothveil Hollow — new end zone after Brassvault (The Pale Monarch).',
        'Moth-silk identity: lilac dust wash, veil mites, Pale Monarch (not a Brassvault twin).',
        'World Path map extended with a painted moth-dust strip + 15th ring under the vault.',
        'Mothveil leans silk chokes; Brassvault keeps cog treasure alcoves.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.2',
      bullets: <String>[
        'Holy Paladin: Beacon marks an ally so your heals peel onto them. Holy Shock heals when someone is hurt, or smites when the party is topped. Divine Favor is a heal window — not haste.',
        'Marksmanship: Volley rains arrows on the pack (not a Scatter root). Aimed Shot still punches the focus.',
        'World Path still runs Sandy Caverns through Brassvault Deep (Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.1',
      bullets: <String>[
        'After the first hour, TODAY chases KEY +1 for better iLvl loot (not Daily). Higher keys raise item level honestly — KEY +10 is a real jump vs the same floor without a key.',
        'GEAR: plate tanks show more ARMOR than leather DPS. Agility is a small dodge crumb — it no longer turns Combat Rogue into the party’s armor king.',
        'Kits: Arms Sweeping Strikes is a cleave window on your swings (HUD shows SWEEP) — not a one-shot nova. Prot Paladin Holy Shield is a block window while you tank; Divine Protection stays the panic bubble.',
        'Arms, Beast Mastery, and Unholy sit closer to other DPS — Sweep, pet, and ghoul still look the same; they just hit a bit less.',
        'World Path still runs Sandy Caverns through Brassvault Deep (Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.0',
      bullets: <String>[
        'World Path: Brassvault Deep — new end zone after Blightfen (The Mainspring).',
        'Clockwork identity: brass wash, cog mites, golem mainspring (not a Blightfen twin).',
        'World Path map extended with a painted brass-vault strip + 14th ring under the mire.',
        'Brassvault leans treasure alcoves of cogs; Blightfen keeps choke water.',
        'Blightfen Mire still on the road after Rimeglass (Fen Hydra).',
        'World Path still runs Sandy Caverns through Brassvault (Tidehold, Ashen Vault, Grove, Stormwake, Rimeglass, Blightfen on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.11.5',
      bullets: <String>[
        'World Path: Rimeglass Rift — new end zone after Stormwake (Rime Colossus).',
        'Quiet ice identity: cyan wash, rime mites, frost golem boss (not Stormwake twin).',
        'World Path map extended with a painted Rimeglass ice strip + 12th ring under Stormwake.',
        'Floors use a Blueprint → placement plan: room beats, landmark props, and chest sockets (not just scatter clutter).',
        'Room chests drop gold/gear pickups on elite/treasure beats — same AFK vacuum as kill loot.',
        'Rimeglass leans quiet treasure alcoves; Stormwake leans choke corridors.',
        'TODAY first hour: grow the party in Sandy — Daily/vault wait until a boss. ALMOST zone/Will still beats Daily grind; offline Meet opens PARTY; KEY tips wait for mid progress.',
        'First tips: TODAY + ENTER, then FARM/PUSH and God Hand in the dungeon. Menu tips wait until you have cleared a floor.',
        'Cold start: a short skippable story intro (the keep, your will) plays before CONTINUE / NEW GAME.',
        'Offline welcome can lead with party levels when the roster grew while you were away.',
        'Kits: Fury Recklessness is an all-in damage window (not a panic wall); Bloodthirst returns rage. Frost DK Hungering Cold freezes the pack — Frost Strike shatters rooted foes. Fire HUD shows STREAK when Pyroblast is ready.',
        'Ascend AL1 teasers include Holy Paladin (AL1 or 25e shop) — same as the live unlock.',
        'World Path still runs Sandy Caverns through Rimeglass Rift (Tidehold, Ashen Vault, Grove, Stormwake on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.11.4',
      bullets: <String>[
        'Stormwake: unique Storm Tyrant boss + gale mite sprites (not ghost/bat twins).',
        'World Path markers retuned for the 11-zone map (Stormwake at the bottom chasm).',
        'Kit VFX: Survival traps/shots, Holy Priest CoH/Nova/Hymn, Disc Flash/PS/PI read clearer.',
        'POWER → FORGE: all run bonuses scroll on phone; forge HP is STA (Stamina), same as gear.',
        'Gear readability: Primary vs Secondary on tooltips; new drops lean (no Move spam, ≤2 secondaries).',
        'Gear power tuned: caster Int/SP ROI matches melee; full rare sets matter in combat without stomping.',
        'Gear budget: iLvl→stats power only — UPGRADE/Auto Equip ignore affinity/armor/set ghost score; BEST matches real upgrades; 1H+off-hand can beat a lonely 2H.',
        'TODAY chase: hub and offline Up next share one ChaseContract (claim → READY → ALMOST → grind).',
        'Offline welcome: one wow line, up to 3 highlights, then the same Up next chase as hub TODAY.',
        'Meet kits: TODAY/Ascend teasers include fantasy + a Watch… combat hook for each AL ladder unlock.',
        'Daily vault early: simple clear-and-claim copy; KEY jargon waits until mid progress (AL2+ / deeper zones).',
        'God Hand: steer-toy first (tap to pull + smash); Forge KEEP styles/CD stay soft power knobs.',
        'Auto Equip: will not replace worn gear with clearly lower iLvl for tiny affinity bumps.',
        'Gear systems: Apex hard-lock, merge keeps primary set only, unstick honors FILTERS.',
        'World Path still runs Sandy Caverns through Stormwake Hollow (Tidehold, Ashen Vault, Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.11.3',
      bullets: <String>[
        'World Path: Stormwake Hollow — new end zone after Hollow Grove (Storm Tyrant).',
        'Unique Tide / Ember / Grove combat backdrops; lighter washes so the art reads.',
        'POWER clearer: Keep (AL / Bless / essence) vs this-run forge on the POWER header.',
        'Kit VFX polish: Subtlety shadow, Discipline holy shields, Balance Hurricane/Starfall discs.',
        'World Path still runs Sandy Caverns through Stormwake Hollow (Tidehold, Ashen Vault, Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.11.2',
      bullets: <String>[
        'Meet new kits: Ascend/unlock queues a TODAY READY card + toast; open PARTY to field them. Specs tint distinctly (Shadow reads void).',
        'TODAY / Ascend name the next kit unlocks (AL1–6 ladder + Gauntlet) — party power chase is honest.',
        'Kit honesty: Feign drops aggro, Disengage kites, Circle of Healing splashes, Riptide/Renew HoT ticks, DK diseases on Boil/Howling.',
        'Tide / Ember / Grove read more distinct in combat (stronger washes + floor remaps); Jobs/Market copy clearer.',
        'POWER menu clearer: Forge tabs GOLD / KEEP / MATS / APEX; Train says +1 level; Keep vs run gold spelled out; Camp/Market/Shop blurbs.',
        'Gear: item stats now follow displayed item level (soft-cap honest); secondaries scale with iLvl; Apex uses the same curve.',
        'Gear: smarter Auto Equip per spec (Enh/Hunter/Shadow/Aff/Blood/Disc); tooltips show For SPEC: best stats; drops bias to your party kits.',
        'Kit honesty: Vendetta/Cold Blood amp melee, Unholy AMS on self, Enhancement Rage+DR, Frost Nova pack freeze, Arcane charge dump, Shadow/Affliction DoT maintain, Fire Hot Streak Pyro.',
        'Fixes: Ascend keeps high KEY prefs (up to AL cap 20); Daily wipe retry still claims; dungeon saves re-lock KEY combat.',
        'World Path: unique Tide / Ember / Grove portraits; lighter map asset; smoother path scroll.',
        'World Path still runs Sandy Caverns through Hollow Grove (Tidehold + Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.11.1',
      bullets: <String>[
        'World Path: painted campaign map with small zone portraits on the rings — tap to select; locked shows have/need lifetime gold under the map.',
        'Dungeon HUD: thinner party HP strip (tap to expand kit), compact target chip, collapsible DPS meter — more map, less chrome.',
        'Phone playtest target locked to Samsung A56 (360×780); guides updated for the new hub map and dungeon chrome.',
        'World Path still runs Sandy Caverns through Hollow Grove (Tidehold + Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.11.0',
      bullets: <String>[
        'Local seasons: weekly hub goals (timed KEY / Gauntlet) with essence + titles — same combat loop, new chase.',
        'TODAY stays on phone layouts; progress chases get ENTER / PATH / FORGE buttons; week affix sits above TODAY.',
        'Hub polish: MORE sheet titled MORE (not HUB); Daily only on TODAY when that is the chase; hub overlays clear on dungeon enter.',
        'Daily echo is one floor (claim → hub); wipe retries the floor. Forge shows this-run vs party totals. Shorter Ascend toast · Bound frags · quieter level-ups.',
        'Affliction kit fantasy: clearer DoT copy + purple shadow VFX on Corruption / UA / Haunt / Drain / Agony.',
        'World Path: Hollow Grove joins Sunken Tidehold and Ashen Vault as the deep endgame gates.',
      ],
    ),
    ChangelogRelease(
      version: '1.10.2',
      bullets: <String>[
        'Ascend Blessing: each Ascend permanently stacks +2 ATK · +1 DEF · +4 STA · +3% gold (Forge → KEEP).',
        'Keep playing: Ascend shows next unlocks (Rogue / 5th slot / Gauntlet), TODAY flashes READY/ALMOST, stronger AFK welcome-back.',
        'GEAR: WoW-style item tooltips with green/red compare vs equipped, hero arrows, fuller hero stats.',
        'World Path: Sunken Tidehold and Ashen Vault remain the endgame gates.',
      ],
    ),
    ChangelogRelease(
      version: '1.10.1',
      bullets: <String>[
        'Daily vault: claim once per day after 1 clear or a timed KEY +2 (scales with best timed key).',
        'Keystone affixes still rotate weekly; season bonus remains on first vault claim of the month.',
        'World Path: Sunken Tidehold and Ashen Vault remain the endgame gates.',
      ],
    ),
    ChangelogRelease(
      version: '1.10.0',
      bullets: <String>[
        'Keystone runs (Mythic+-style): pick KEY level, lock affixes on enter, idle-friendly timer.',
        'Beat the boss under par to TIMED upgrade; overtime = depleted. Fortified/Tyrannical from KEY +4.',
        'Daily vault: claim after 1 clear or a timed KEY +2 — reward scales with best timed key.',
        'World Path: Sunken Tidehold and Ashen Vault remain the endgame gates.',
      ],
    ),
    ChangelogRelease(
      version: '1.9.9',
      bullets: <String>[
        'Auto-equip: empty slots skip low-iLvl affinity junk; mid-fight equip is debounced (floor clear still full).',
        'Equip compare shows Score + UPGRADE; mail under plate is a soft penalty, not a hard dump.',
        'Bag UI: CLEAN BAG first, FILTERS shortcut; BAG n/cap on dungeon nav; fewer mid-fight tips.',
        'Custom icons: opaque black backgrounds cleared to transparency.',
        'World Path: Sunken Tidehold and Ashen Vault remain the endgame gates.',
      ],
    ),
    ChangelogRelease(
      version: '1.9.8',
      bullets: <String>[
        'Bag cleanup: auto-sell pays gold; new auto-disassemble pays essence (Settings: iLvl + rarity for each).',
        'Near-full bag: AUTO MERGE → sell → scrap. CLEAN BAG / SELL JUNK / SCRAP buttons in the bag.',
        'World Path: Sunken Tidehold and Ashen Vault remain the endgame gates.',
      ],
    ),
    ChangelogRelease(
      version: '1.9.7',
      bullets: <String>[
        'Hub clarity: Ascend boss progress under Enter (not Daily), WHAT\'S NEW in MORE, Challenges clickable for playtest.',
        'Shorter Contracts/Market/Beast sheets; clearer 0% progress bars; Market BUY shows need gold when broke.',
        'Bag slot tags (Neck/Ring/Shldr…), Forge axe icon in MORE; disabled buttons look greyer.',
        'World Path: Sunken Tidehold and Ashen Vault remain the endgame gates.',
      ],
    ),
    ChangelogRelease(
      version: '1.9.6',
      bullets: <String>[
        'Menu polish: MORE icons, Apex role/slot labels, Forge MOVE (not SPD), shorter tips.',
        'Contracts progress bars, clearer Beast empty state, Loadouts empty tip, Essence Shop BUY shows cost.',
        'World Path: Sunken Tidehold and Ashen Vault remain the endgame gates.',
      ],
    ),
    ChangelogRelease(
      version: '1.9.5',
      bullets: <String>[
        'Hub/UX polish: bag slots show slot + icon, CLAIM rewards without opening Contracts, Ascend label, God Hand fist icon.',
        'Party meter shows tank damage taken / healer HPS / DPS; AUTO EQUIP vs AUTO MERGE; clearer MORE → Return to hub.',
        'Confirm dialogs (leave/daily/gauntlet/new game) work with web playtest clicks.',
        'World Path: Sunken Tidehold and Ashen Vault remain the endgame gates.',
      ],
    ),
    ChangelogRelease(
      version: '1.9.4',
      bullets: <String>[
        'Hub TODAY card: always shows your next chase (weekly, daily, Will, Gauntlet, zone unlock).',
        'World Path: Sunken Tidehold and Ashen Vault remain the endgame gates.',
      ],
    ),
    ChangelogRelease(
      version: '1.9.3',
      bullets: <String>[
        'New zones: Sunken Tidehold and Ashen Vault (World Path gates 8–9).',
        'Meta: Will/Gauntlet milestone essence, God Hand BAL/FOCUS/WIDE, Iron Will & Chamber Luck relics.',
        'Weekly fortune/iron mods, monthly season bonus on first weekly claim, dungeon armor 4pc combat procs.',
        'Hub weekly progress, What’s New + mid-meta tips, guides for Tide/Ember & loadouts vs armor sets.',
        'A11y: toast dedupe, Minimal VFX = reduce motion, save backup hint in Settings.',
      ],
    ),
    ChangelogRelease(
      version: '1.9.2',
      bullets: <String>[
        'Economy: live kill gold, scaled treasure gold, softer AL loot skip, caster tax fix.',
        'DPS kit rebalance + live/AFK class-balance sims (flask, God Hand, gear bands).',
        'Loot Sprite pet: gold find + loot find passives that scale with level.',
        'Achievements and ascend milestones grant essence rewards.',
        'Challenge clears: +2e per active toggle; Daily Run clear awards +25e.',
        'Auto Equip / Sell Junk report what they did via toasts.',
      ],
    ),
    ChangelogRelease(
      version: '1.9.1',
      bullets: <String>[
        'Smarter Auto Equip: clear upgrades only, role-gated empty fills, live/AFK sync.',
      ],
    ),
    ChangelogRelease(
      version: '1.9.0',
      bullets: <String>[
        'Party: unlock WotLK-style specs and field 4–5 active heroes.',
        'All talent-tree kits (~30) with abilities via the shared effect runner.',
        'Gear Sets renamed (was Loadouts); 5th party slot for essence at AL 2+.',
        'Meta depth: prestige shop, sanctuary XP/prestige, relic tiers, weekly contracts.',
        'Expanded pet roster, codex milestones, ascend titles, zone trophies, Will ranks.',
        'Local achievements across zones, hardmode, gold, and pets.',
        'Light story layer: dungeon blurbs, enter/clear/ascend flavor.',
      ],
    ),
    ChangelogRelease(
      version: '1.8.x',
      bullets: <String>[
        'In-dungeon offline catch-up runs SpatialCombat (AFK assist + reduced VFX).',
        'Named gear loadouts, Boss Rush / No-Flask, Daily Run, Ascend milestones.',
        'Crystal Spire joins the world path; offline progress summary on hub return.',
        'Achievements, monster/item codex, export/import save, a11y text scale & colorblind.',
        'Keyboard shortcuts: Space (God Hand), Esc (close), B (bag), H (hub).',
      ],
    ),
  ];

  /// Flat bullets for backward compat — all releases, newest first.
  static List<String> get changelog => [for (final r in releases) ...r.bullets];

  /// True when the player has not acknowledged [currentVersion].
  static bool hasUnseenChangelog(GameState s) =>
      s.seenChangelogVersion != currentVersion;

  /// Releases newer than [GameState.seenChangelogVersion].
  /// Empty/unknown seen → current only; older major.minor → current + previous.
  static List<ChangelogRelease> unseenReleases(GameState s) {
    if (!hasUnseenChangelog(s) || releases.isEmpty) return const [];
    final current = releases.first;
    final seen = s.seenChangelogVersion;
    if (seen.isEmpty) return <ChangelogRelease>[current];
    if (_isOlderMajorMinor(seen, currentVersion)) {
      return releases.take(2).toList(growable: false);
    }
    return <ChangelogRelease>[current];
  }

  /// Compares `major.minor` (patch ignored). Non-semver [seen] counts as older.
  static bool _isOlderMajorMinor(String seen, String current) {
    final a = _versionMajorMinor(seen);
    final b = _versionMajorMinor(current);
    if (a == null || b == null) return true;
    if (a.$1 != b.$1) return a.$1 < b.$1;
    return a.$2 < b.$2;
  }

  static (int, int)? _versionMajorMinor(String version) {
    final cleaned = version.endsWith('.x')
        ? version.substring(0, version.length - 2)
        : version;
    final parts = cleaned.split('.');
    if (parts.length < 2) return null;
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    if (major == null || minor == null) return null;
    return (major, minor);
  }

  // —— Daily run ——————————————————————————————————————————————

  /// Stable `yyyy-mm-dd` key for the UTC calendar date of [utc].
  static String dailyDateKey(DateTime utc) {
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Deterministic seed for a given UTC date — same calendar date always
  /// yields the same seed. Derived from the date string's hash (stable,
  /// content-based) rather than raw integer math so it can't overflow
  /// differently across the VM vs. web (dart2js) number representations.
  static int dailySeed(DateTime utc) {
    final key = dailyDateKey(utc);
    return key.hashCode & 0x3fffffff;
  }

  /// Stable day-of-epoch counter (UTC), used to rotate the daily dungeon.
  static int _epochDay(DateTime utc) =>
      DateTime.utc(utc.year, utc.month, utc.day).millisecondsSinceEpoch ~/
      86400000;

  /// Rotates through the dungeon catalog by day-of-epoch so every unlocked
  /// (or not) zone gets a turn as the free Daily Run.
  static String dailyDungeonId(DateTime utc) {
    final all = DungeonCatalog.all;
    if (all.isEmpty) return 'sandy';
    final index = _epochDay(utc) % all.length;
    return all[index].id;
  }

  /// Whether today's Daily Run has already been claimed on [state].
  static bool isDailyClaimedToday(GameState state, {DateTime? now}) {
    final t = now ?? DateTime.now().toUtc();
    return state.lastDailyDate == dailyDateKey(t) && state.dailyClaimed;
  }

  /// Parses [dailyDateKey] (`YYYY-MM-DD`) to a UTC calendar day, or null.
  static DateTime? parseDailyDateKey(String? key) {
    if (key == null || key.isEmpty) return null;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime.utc(y, m, d);
  }

  /// True while inside a seeded Daily echo (one-floor trial).
  /// Identity is [lastDailyDate] + dungeon + layout seed — not wall-clock
  /// “today”, so midnight crossover mid-run still counts as Daily.
  /// When [now] is passed (tests), also require that calendar day.
  static bool isActiveDailyRun(GameState state, {DateTime? now}) {
    if (!state.inDungeon || state.inGauntlet) return false;
    final dayKey = state.lastDailyDate;
    if (dayKey == null || dayKey.isEmpty) return false;
    final day = parseDailyDateKey(dayKey);
    if (day == null) return false;
    if (now != null && dayKey != dailyDateKey(now.toUtc())) {
      return false;
    }
    if (state.dungeonId != dailyDungeonId(day)) return false;
    return state.layoutSeed == dailySeed(day);
  }

  // —— Collection score ——————————————————————————————————————

  /// Will-rank collection score (achievements, pets, relics, codex, trophies).
  static int collectionScore(GameState state) =>
      state.achievements.length * 2 +
      state.ownedPets.length +
      state.unlockedRelics.length * 3 +
      (state.codexEnemies.length + state.codexItems.length) ~/ 2 +
      state.metaDepth.zoneTrophies.length * 3 +
      state.metaDepth.titles.length;

  // —— Achievements ————————————————————————————————————————————

  static final Map<String, bool Function(GameState)> _conditions =
      <String, bool Function(GameState)>{
        'first_floor': (s) =>
            s.highestFloorCleared >= 1 || s.metaDepth.lifetimeFloorClears >= 1,
        'first_boss': (s) =>
            s.bossVictories >= 1 || s.metaDepth.lifetimeBossKills >= 1,
        'first_ascend': (s) =>
            s.ascensionLevel >= 1 || s.metaDepth.lifetimeAscends >= 1,
        'clear_goblin': (s) => s.highestDungeonCleared >= 1,
        'hatch_pet': (s) =>
            s.ownedPets.isNotEmpty || s.metaDepth.lifetimePetHatches >= 1,
        'daily_clear': (s) => s.dailyClaimed,
        'full_party': (s) => s.heroes.length >= 4,
        'party_five': (s) =>
            s.metaDepth.partySlot5Unlocked && s.heroes.length >= 5,
        'specs_10': (s) => s.metaDepth.unlockedSpecs.length >= 10,
        'specs_all': (s) =>
            s.metaDepth.unlockedSpecs.length >= HeroSpecId.values.length,
        'clear_sandy': (s) => s.highestDungeonCleared >= 0,
        'clear_king': (s) => s.highestDungeonCleared >= 2,
        'clear_underworld': (s) => s.highestDungeonCleared >= 3,
        'clear_dead': (s) => s.highestDungeonCleared >= 4,
        'clear_hell': (s) => s.highestDungeonCleared >= 5,
        'clear_crystal': (s) => s.highestDungeonCleared >= 6,
        'clear_tide': (s) => s.highestDungeonCleared >= 7,
        'clear_ember': (s) => s.highestDungeonCleared >= 8,
        'clear_grove': (s) => s.highestDungeonCleared >= 9,
        'clear_storm': (s) => s.highestDungeonCleared >= 10,
        'clear_rime': (s) => s.highestDungeonCleared >= 11,
        'clear_fen': (s) => s.highestDungeonCleared >= 12,
        'clear_brass': (s) => s.highestDungeonCleared >= 13,
        'clear_veil': (s) => s.highestDungeonCleared >= 14,
        'hm_1': (s) => s.metaDepth.highestHardmodeCleared >= 1,
        'hm_5': (s) => s.metaDepth.highestHardmodeCleared >= 5,
        'hm_10': (s) => s.metaDepth.highestHardmodeCleared >= 10,
        'gold_10k': (s) => s.lifetimeGoldEarned >= 10000,
        'gold_100k': (s) => s.lifetimeGoldEarned >= 100000,
        'gold_1m': (s) => s.lifetimeGoldEarned >= 1000000,
        'codex_10': (s) => s.codexEnemies.length + s.codexItems.length >= 10,
        'codex_25': (s) => s.codexEnemies.length + s.codexItems.length >= 25,
        'codex_50': (s) => s.codexEnemies.length + s.codexItems.length >= 50,
        'pets_3': (s) => s.ownedPets.length >= 3,
        'pet_merge': (s) => s.metaDepth.lifetimePetMerges >= 1,
        'pet_legendary': (s) =>
            s.ownedPets.any((p) => p.rarity == PetRarity.legendary),
        'favorite_pet': (s) => s.metaDepth.favoritePetSpecies.isNotEmpty,
        'ascend_streak_3': (s) => s.metaDepth.ascendStreak >= 3,
        'al_5': (s) => s.ascensionLevel >= 5,
        'al_10': (s) => s.ascensionLevel >= 10,
        'gauntlet_enter': (s) =>
            s.inGauntlet || s.metaDepth.lifetimeGauntletFloors > 0,
        'gauntlet_10': (s) => s.metaDepth.gauntletBestFloor >= 10,
        'casts_100': (s) => s.metaDepth.lifetimeAbilityCasts >= 100,
        'floors_50': (s) => s.metaDepth.lifetimeFloorClears >= 50,
        'relic_all': (s) =>
            s.hasRelic('war_banner') &&
            s.hasRelic('iron_ward') &&
            s.hasRelic('phoenix_ember') &&
            s.hasRelic('god_hand_focus') &&
            s.hasRelic('chamber_luck') &&
            s.hasRelic('iron_will'),
        'sanctuary_12': (s) =>
            s.sanctuaryGoldLevel >= 12 ||
            s.sanctuaryPowerLevel >= 12 ||
            s.sanctuaryVitalityLevel >= 12 ||
            s.metaDepth.sanctuaryXpLevel >= 12,
        'god_hand_5': (s) => s.godHandLevel >= 5,
        'weekly_clear': (s) => s.metaDepth.dailyVaultClaimed,
        'gauntlet_25': (s) => s.metaDepth.gauntletBestFloor >= 25,
        'gauntlet_50': (s) => s.metaDepth.gauntletBestFloor >= 50,
        'gauntlet_100': (s) => s.metaDepth.gauntletBestFloor >= 100,
        'apex_first': (s) => _apexPieces(s).isNotEmpty,
        'apex_set_r1': (s) => _hasFullApexSetR1(s),
        'apex_r3': (s) => _apexPieces(s).any((i) => i.apexRank >= 3),
        'hidden_egg': (s) => s.metaDepth.lifetimePetHatches >= 10,
      };

  static List<EquipmentItem> _apexPieces(GameState s) {
    final out = <EquipmentItem>[];
    for (final h in s.heroRoster) {
      for (final i in h.equipped.values) {
        if (i.isApex) out.add(i);
      }
    }
    out.addAll(s.apexVault.where((i) => i.isApex));
    out.addAll(s.gearStash.where((i) => i.isApex));
    return out;
  }

  static bool _hasFullApexSetR1(GameState s) {
    final pieces = _apexPieces(s);
    for (final classId in HeroClassId.values) {
      for (final role in ApexCraft.validRolesFor(classId)) {
        var ok = true;
        for (final slot in ApexCraft.craftSlotsFor(classId, role)) {
          final id = ApexCraft.pieceId(
            classId: classId,
            role: role,
            slot: slot,
          );
          if (!pieces.any((p) => p.id == id && p.apexRank >= 1)) {
            ok = false;
            break;
          }
        }
        if (ok) return true;
      }
    }
    return false;
  }

  /// Pure: adds any newly-met achievement ids and grants their essence reward.
  /// Never removes an id, so it's safe to call repeatedly.
  static GameState evaluateAchievements(GameState state) {
    final before = state.achievements.toSet();
    List<String>? unlocked;
    var essenceGain = 0;
    for (final entry in _conditions.entries) {
      if (!before.contains(entry.key) && entry.value(state)) {
        unlocked ??= List<String>.from(state.achievements);
        unlocked.add(entry.key);
        essenceGain += AchievementCatalog.byId(entry.key)?.essenceReward ?? 0;
      }
    }
    if (unlocked == null) return state;
    return state.copyWith(
      achievements: unlocked,
      essence: state.essence + essenceGain,
    );
  }

  /// Ascension levels that grant a one-time milestone essence bonus.
  static const List<int> ascendMilestones = <int>[1, 3, 5, 10, 15, 20];

  static int ascendMilestoneEssence(int level) => 2 + level;

  /// Essence for newly crossed AL milestones when going from [fromLevel] → [toLevel].
  static int ascendMilestoneReward(int fromLevel, int toLevel) {
    var total = 0;
    for (final m in ascendMilestones) {
      if (fromLevel < m && toLevel >= m) {
        total += ascendMilestoneEssence(m);
      }
    }
    return total;
  }

  /// Extra essence on floor clear during a keystone run / personal extras.
  /// Farm loops must not mint this (would be unbounded AFK essence).
  static int challengeClearEssenceBonus(
    GameState state, {
    bool farmLoop = false,
  }) {
    if (farmLoop) return 0;
    var bonus = 0;
    if (state.challengeBossRush) bonus += 2;
    if (state.challengeNoFlask) bonus += 2;
    final key = state.keystoneRunActive ? state.keystoneRunLevel : 0;
    bonus += key.clamp(0, state.effectiveMaxHardmode);
    return bonus;
  }

  // —— Codex —————————————————————————————————————————————————

  /// Registers every enemy currently on the floor as "discovered".
  static GameState registerEnemyEncounters(
    GameState state,
    List<EnemyUnit> enemies,
  ) {
    if (enemies.isEmpty) return state;
    Set<String>? known;
    for (final enemy in enemies) {
      if (!state.codexEnemies.contains(enemy.name)) {
        known ??= Set<String>.from(state.codexEnemies);
        known.add(enemy.name);
      }
    }
    if (known == null) return state;
    final list = known.toList()..sort();
    return state.copyWith(codexEnemies: list);
  }

  /// Registers every dropped equipment piece's display name as "discovered".
  static GameState registerItemDrops(GameState state, List<LootDrop> drops) {
    if (drops.isEmpty) return state;
    final names = <String>{};
    for (final drop in drops) {
      final item = drop.equipment;
      names.add(item != null ? item.name : drop.name);
    }
    return registerItemNames(state, names);
  }

  /// Adds item display names to the Codex (used by drops and inventory backfill).
  static GameState registerItemNames(GameState state, Iterable<String> names) {
    Set<String>? known;
    for (final key in names) {
      if (key.isEmpty) continue;
      if (!state.codexItems.contains(key)) {
        known ??= Set<String>.from(state.codexItems);
        known.add(key);
      }
    }
    if (known == null) return state;
    final list = known.toList()..sort();
    return state.copyWith(codexItems: list);
  }
}
