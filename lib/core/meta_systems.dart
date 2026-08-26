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
  static const String currentVersion = '1.12.64';

  /// Structured releases, newest first. Older highlights are condensed.
  static const List<ChangelogRelease> releases = <ChangelogRelease>[
    ChangelogRelease(
      version: '1.12.64',
      bullets: <String>[
        'Dungeon HUD: compact top shows zone + floor + KEY timer; God Hand ring uses real CD; LOOP/CLIMB labels; floor-hop confirms mid-fight; Execute/Living Bomb gates on chips; kit priority not A–Z. Prestige Ascend still Rebuild your bag; AL20 KEEP still has optional REBORN. TODAY still owns Gauntlet / GREATER / KEY hunts.',
        'Forge BEST shorter + toast when track moves; CLAIM QUESTS synced; Trap Mastery / DK / Fire chip labels clearer. World Path still Sandy through Mothveil (Tidehold, Ashen Vault, Hollow Grove, Stormwake, Rimeglass, Blightfen, Brassvault).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.63',
      bullets: <String>[
        'Hub TODAY: week goals can CLAIM WEEK; equip chase names the bag item; PATH farms the open road; Gauntlet leads Greater when that is the hunt; vault/Ascend no longer double-shout. Prestige Ascend still Rebuild your bag; AL20 KEEP still has optional REBORN. TODAY still owns Gauntlet / GREATER / KEY hunts.',
        'Phone hub: TODAY wraps long titles and shows READY why; map HERE syncs with KEY enter; META → KEY stays visible; endgame buttons carry icons; month/week progress stays on the card. Dungeon: pin target, stairs hint, chamber dots, ability long-press, PARTY pause toast. Zones: ember/storm wash + landmarks. World Path still Sandy through Mothveil (Tidehold, Ashen Vault, Hollow Grove, Stormwake, Rimeglass, Blightfen, Brassvault).',
      ],
    ),

    ChangelogRelease(
      version: '1.12.62',
      bullets: <String>[
        'Feel audit pass: hub week affix + POWERUPS under ENTER, tap map to pin target mid-fight, floor jump list, clearer wipe tips, kit HUD labels, zone packs less copy-paste. Prestige Ascend still Rebuild your bag; AL20 KEEP still has optional REBORN. TODAY still owns Gauntlet / Greater Rift / KEY hunts.',
        'Guides/tips honesty (no sell-junk / loadouts ghosts). MARKET upgrade badges, FORGE STA wording, KEY affix risk words. World Path still Sandy through Mothveil (Tidehold, Ashen Vault, Hollow Grove, Stormwake, Rimeglass, Blightfen, Brassvault).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.61',
      bullets: <String>[
        'Hub feel: TODAY endgame hunts (Gauntlet / Rift / Greater Rift / Ashen / KEY) drive the big button; READY shows why; Ashen has confirm + PRACTICE; tickets stop after the paid weekly clear. Prestige Ascend still Rebuild your bag until you loot; AL20 KEEP still has optional REBORN.',
        'Guides honesty + MARKET tap-sell stash hidden (BAG CLEAN / SETTINGS auto-sell). Dungeon: zone/floor/KEY in compact top, FARM/PUSH tips, God Hand CD seconds, kit chips open, GO stairs on top.',
        'Hell packs less King-like; Stormwake elites less bat-heavy. Shadow keeps priest art. Eviscerate shows in HUD. World Path still Sandy through Mothveil (Tidehold, Ashen Vault, Hollow Grove, Stormwake, Rimeglass, Blightfen, Brassvault).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.60',
      bullets: <String>[
        'Ascend is prestige again: your party stays (levels, open zones, Apex, Blessing) but gold, forge, bag drops, market, and floors reset. TODAY says Rebuild your bag — not ENTER KEY — until you loot real gear. AL20 Forge KEEP has optional REBORN (same wipe, no extra Blessing).',
        'KEY / Gauntlet / Greater Rifts still unlock at party Lv100. World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.59',
      bullets: <String>[
        'Was briefly claim-only (kept gold/gear/floors); 1.12.60 restored prestige '
            'Ascend bag wipe — keep levels/zones/Apex, rebuild the bag. (superseded)',
        'KEY / Gauntlet / Greater Rifts still unlock at party Lv100. World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.58',
      bullets: <String>[
        'Combat XP: harder kills (enemy above your hero level) pay more XP; heroes behind the party catch up faster. Push deeper floors to level quicker.',
        'KEY / Gauntlet / Greater Rifts still unlock at party Lv100. World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.57',
      bullets: <String>[
        'Ascend Blessing packs are stronger: each Ascend keeps +5 ATK · +20 DEF · +60 STA · +8% gold (was +2/+8/+24/+3%). Existing Blessing stacks use the new rates. KEY / Gauntlet / Greater Rifts still unlock at party Lv100.',
        'First Ascend on a new save is optional - TODAY leads Daily / farming after the first boss; Ascend stays on the hub as a side button.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.56',
      bullets: <String>[
        'AL20 TODAY: after KEY at dial cap, chase Greater Rift -> Gauntlet -> Rift -> Ashen Crown (ticket week) before Daily - one hunt, not a meta shuffle.',
        'Endgame fallback is a single Time KEY / push GR line - no multi-stat dump on the hub card.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.55',
      bullets: <String>[
        'Endgame honesty: Tiny only shrinks the fight party (not your saved roster). Ticket World Boss no longer soft-clears on AFK — use PRACTICE to learn the fight.',
        'Blessing Constellation points are earned (AL20 starter + boss/trial), not double-dipped from Blessing stacks. Crit / gold / block / loot / KEY par / boss ATK nodes actually apply.',
        'Month pass tracks Greater Rift progress this month; Apex Trial resets each month; TODAY only CLAIM MONTH when ready; mirror month picks the featured zone when unlocked.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.54',
      bullets: <String>[
        'Endgame pack: month season pass, extended QUESTS bounty (to 25k kills), Tiny challenge, Party Power score, Ashen Crown world boss, Blessing Constellation (AL20), Apex Trial, God Hand mastery, and Full Bench roster exhibition.',
        'Mirror weeks reuse season affix + layout seed on existing zones — no separate mode. KEY / Gauntlet / farm Rifts / Greater Rifts still unlock at party Lv100.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.53',
      bullets: <String>[
        'Hero level cap is 100 — combat XP only (no gold Train). KEY, Gauntlet, farm Rifts, and Greater Rifts unlock when every active hero is Lv100.',
        'AL20 stays the Ascension cap (kits / Blessing). Endgame content is no longer gated on AL alone.',
        'World Path unlocks by party mean level in even steps (Sandy from Lv1 … Mothveil at Lv100), or by clearing the previous zone — still Sandy through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.52',
      bullets: <String>[
        'Greater Rifts at AL20: harder timed kill ladder, no mid-run gear, big clear payouts — ranks on META → KEY · BOARDS (Play Games).',
        'Farm Rifts stay loot-friendly and unranked; hub shows both RIFT and GREATER.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.51',
      bullets: <String>[
        'AL20 endgame: KEYSTONE and Infinity Gauntlet unlock at AL20 — mid-game chases Ascend, zones, Daily, and vault clears.',
        'New Rifts at AL20: timed kill challenges with escalating tiers, essence/gold payouts, and hub + META → KEY entry.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.50',
      bullets: <String>[
        'Infinity Gauntlet unlocks at AL20 — endgame climb, not mid-progress.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.49',
      bullets: <String>[
        'AL20 is now the Ascension cap — endgame lives here (KEY +20, Gauntlet, vault, boards). Hub and Forge say MAX at AL20.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.48',
      bullets: <String>[
        'Season boards live under META → KEY (Timed KEY + Gauntlet). SETTINGS keeps Play Games sign-in and cloud backup.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.47',
      bullets: <String>[
        'Economy tune: stacked gold-find soft-caps near AL20 so KEY runs stay rich without infinite wallet gold.',
        'FORGE gold costs scale with Ascension Level — late runs spend gold on upgrades, not just MARKET.',
        'Daily vault pays a bit more essence at high KEY; hub AFK essence ticks slightly faster.',
        'MARKET paid refresh costs a little more at high AL (still one floor or two, not a tax).',
        'MARKET gap listings re-roll for UPGRADE or show GAP FILL; bag hint when backups fill the stash.',
        'Auto Equip swaps 1H + off-hand without leaving an empty weapon slot.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.46',
      bullets: <String>[
        'Play installs: cold start blocks until you update when Google Play has a newer build.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.45',
      bullets: <String>[
        'Title screen: first launch shows one Start button; restore a clipboard save from the title.',
        'Name your party on New Game (blocked swears, slurs, and political slogans).',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.43',
      bullets: <String>[
        'Hub welcome: thank-you message with JOIN DISCORD (once per save).',
        'CLEAN BAG now sells/scraps everything matching your auto-sell filters — no silent keeps.',
        'TODAY chases MARKET when an affordable listing beats your gear; BAG equip wins first.',
        'Wipe advice points at POWER → MARKET when listings fix the same gap as FORGE.',
        'MARKET listings refresh when you reach the hub; UPGRADE badge only when you can afford it.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.42',
      bullets: <String>[
        'Combat pass: tanks can DODGE / PARRY / BLOCK melee — mastery block trims blocked hits.',
        'Casters roll Spell Power; melee kits use Physical Attack — spells and swings read separately on the sheet.',
        'Spec mastery hooks (Deep Healing, Ignite-style fire, tank block value, and more) shape kit identity in fights.',
        'Spirit regen slows in combat after you take damage; CC roots shorten when spammed on the same pack.',
        'Loot uses zone drop tables; gear can roll Mastery as a secondary stat.',
        'POWER → MARKET gear listings: browse slot filters when drops miss your upgrade (AH-style, run-only; refreshes every 6h).',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.41',
      bullets: <String>[
        'All 15 dungeons use owned custom floor/wall/prop art — each zone has its own palette (Hell bloodstone vs Ember forge, Sandy sand, Tide silt, and more).',
        'UI architecture pass: one primary brown per screen (BAG, CAMP, SETTINGS); scoped labels on SETTINGS/APEX/META.',
        'Gear rarity + tooltip stats + combat HUD bars use shared GameTheme tokens — fewer stray hex colors.',
        'Hub cards use hubPanel; GEAR/META menus use body text instead of pixel glitter on labels.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.40',
      bullets: <String>[
        'UI theme audit: POWER tabs and FORGE sections show RUN / ACCOUNT scope chips.',
        'Hub ALMOST claims use one brown CTA; META → KEY is a text link under TODAY.',
        'Hub banners use hubPanel (not menu sheet boxes); bag colors and tooltips use GameTheme tokens.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.39',
      bullets: <String>[
        'BAG → FILTERS jumps to META → SETTINGS bag cleanup (auto-sell / disassemble).',
        'Menu buttons and +/- steppers use the same Kenney chrome — fewer stray Material buttons.',
        'POWER INCOME section headers show ACCOUNT scope chips (RUN / TODAY / ACCOUNT pattern).',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.38',
      bullets: <String>[
        'Hub READY: one big button for TODAY (claim or enter) — ENTER drops to grey when a claim is ready.',
        'KEY / vault live in META → KEY; hub shows META → KEY instead of a second KEYSTONE panel.',
        'META claim hints only on JOBS (and What\'s New on GUIDE) — no stale yellow row on CODEX/KEY.',
        'CODEX layout fixed on phone (no overflow stripe). SETTINGS tab renamed; hub gear opens the same META screen.',
        'POWER copy labels RUN vs ACCOUNT; hub header shows AL instead of Ascend.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault, Hollow Grove on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.37',
      bullets: <String>[
        'Two wipes on the same floor: dungeon names God Hand as a steer + smash nudge (ring highlights when ready).',
        'Ashen Vault, Hollow Grove, and Stormwake layouts read more distinct — lava choke, root fences, trap corridors.',
        'Hub TODAY stays one primary CTA when READY; wipe help lands sooner when the fight proves it.',
        'Optional SETTINGS session log (local only) for chase, wipes, and God Hand taps.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.36',
      bullets: <String>[
        'Hub TODAY stays one primary CTA when READY — KEY/vault crumbs and extra claim rows hide so ENTER / CLAIM owns the strip.',
        'Dungeon wipe help lands sooner when the fight proves it: bag upgrades, “floor too far”, and early melts on wipe 1; FORGE ATK/DEF/STA after two wipes on the same floor (was three).',
        'Dead chrome cleanup: item tooltips no longer tease Sell/Scrap; guides call LOADOUTS hidden presets.',
        'Optional SETTINGS session log (local only) — chase kind, wipes, God Hand taps for your own play notes.',
        'Zone identity pass on Sunken Tidehold, Brassvault Deep, and Mothveil Hollow — wet chokes, treasure vaults, silk-trap corridors.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Stormwake, Rimeglass, Blightfen, Brassvault, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.35',
      bullets: <String>[
        'SETTINGS: text presets S/M/L/XL (wider slider), dungeon zoom Close / Normal / Wide, haptics on/off, keep screen on in dungeon, and RESET DISPLAY DEFAULTS — phone comfort without changing OS resolution.',
        'POWER → FORGE → GOLD still has ×1 / 5% / 25% / 50% / 100% spend and SPEND ALL · EVEN.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.34',
      bullets: <String>[
        'POWER → FORGE → GOLD: pick ×1 / 5% / 25% / 50% / 100% of wallet gold when buying ATK / DEF / STA / MOVE / HASTE / CRIT, or SPEND ALL · EVEN to split gold round-robin across every track.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.33',
      bullets: <String>[
        'Spells look like the spell: Fireball flames, Frost shards, Lightning zigzags, Holy crosses, Shadow coils, nature drips, rain for Blizzard/Hurricane/Healing Rain, and Consecration/Bladestorm ground that matches the kit — not a generic colored ring.',
        'Combat reads cleaner on phone: fewer hit/crit numbers (crits still pop), no cleave spam, and chamber doors shout OPEN once — not a stuck stack of labels.',
        'Dungeon pathing is lighter on phone: faster soft-lock unlocks, less frame hitching on big packs and busy bolt fights.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.32',
      bullets: <String>[
        'POWER → SHOP no longer sells Loadout Folio — LOADOUTS stays hidden. Extra slots you already bought still sit on the save.',
        'Safer title screen: sitting there will not overwrite a real save with a blank one if boot hiccups.',
        'Party fights feel less robotic: soft run-up and turn, idle breathe, Fire kites farther, Arcane sidesteps, and low-HP DPS limp toward the healer. Combat barks sit in small bubbles.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.30',
      bullets: <String>[
        'Dense-pack fairness (big pulls): Arms Sweeping / Bladestorm and Combat Flurry / Spree are trimmed; caster spell tax and soft casters (Balance, Shadow, Ele, Arcane, Aff/Destro, Frost) are lifted so AoE share sits closer.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.29',
      bullets: <String>[
        'Combat Rogue pack damage was stomping peers — Blade Flurry cleave, Killing Spree haste/hits, and execute whites are trimmed so AoE sits with other DPS.',
        'Caster kits were paying a heavy spell tax, and Arms / Ret / Frost DK / Balance sat soft — passives and key hits are lifted so the field feels closer without anyone going HIGH.',
        'Three wipes on the same floor: the dungeon names a real fix when the fight proves it — equip bag upgrades, drop a floor, or FORGE ATK / DEF / STA after two same-floor wipes (high-confidence tips on wipe 1). PUSH retreats keep that streak (clearing a lower floor does not erase it). No guessed tips.',
        'BAG/GEAR dropped SELL JUNK, SCRAP, GEAR Sell, and LOADOUTS. CLEAN BAG + FILTERS + MARKET still clear junk.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.28',
      bullets: <String>[
        'Healers open a floor with mana, and Spirit actually refills it — Disc can heal on the pull instead of waiting half the fight.',
        'Hub gold/min at the keep is a real overnight trickle (enough to buy forge), not a 2g/min joke next to a dungeon run.',
        'KEY gold now tracks the harder packs. KEY +10 shows gold ×5.5 next to the +20 iLvl jump — not a gold tax.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.27',
      bullets: <String>[
        'Hub POWERUPS: watch an optional ad for 3 hours of double gold and +25% attack. Watch again to add another 3 hours (up to 24h). Ads never interrupt a fight.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.26',
      bullets: <String>[
        'Play installs can see a hub notice when a newer Idle Party is ready on Google Play (sideload APKs stay quiet). SETTINGS has GET UPDATE when that notice is up.',
        'Warrior, Paladin, and Shaman can wear shields — Protection Paladin (and Resto/Ele Shaman) no longer get stuck on a two-hander that blocked the off-hand.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.25',
      bullets: <String>[
        'Companions read as yours: bigger pet sprites, ally rings, cyan pet hits. MERGE RESULT shows the SCORE jump. Charms always drop with a real on-item effect.',
        'KEEP relics spell the next tier (and CAMP lists what you already own). TODAY names the essence on Will, Gauntlet, and the week goal.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.23',
      bullets: <String>[
        'Healer drops lean Mp5 and Crit — Haste was sitting unused (heals do not haste). Rogue-family Auto Equip stops chasing Crit once you are near the 75% cap.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.22',
      bullets: <String>[
        'POWER → SHOP: Loadout Folio, Apothecary Writ, Junk Magnifier, and Away Ledger — permanent QoL that survives Ascend (extra loadouts, cheaper flasks, higher auto-sell/scrap caps, more Welcome Back rows). (superseded — Loadout Folio delisted; LOADOUTS hidden)',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.21',
      bullets: <String>[
        "Goblin's Hideout: stolen-stash chests (richer pouches + Stolen Coin) wake Stash Guard / Loot Snatcher ambushes — more alcoves, choke dens, and a distinct raider pack.",
        'Hideout identity polish: dirt floors, boarded door rims, spider/crab/ghost mid-pack (not King twins). Codex slingers match combat bats.',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
    ChangelogRelease(
      version: '1.12.20',
      bullets: <String>[
        'Apex target meter resets when you change craft goal or locked mat — no free carry into the next shortage.',
        'Safer Continue: corrupt v2 tries legacy v1 before wipe. Soft enemy save parse. META SET closes cleanly (incl. DEV Gauntlet).',
        'World Path still runs Sandy Caverns through Mothveil Hollow (Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on the road).',
      ],
    ),
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
        'Near-full bag: AUTO MERGE → sell → scrap. CLEAN BAG / SELL JUNK / SCRAP buttons in the bag. (superseded — SELL JUNK / SCRAP buttons removed; use CLEAN BAG + FILTERS)',
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
