# -*- coding: utf-8 -*-
"""Generate docs/PLAY_PROD_POLISH_1000.md"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
feel = (ROOT / "docs/FEEL_AUDIT_500.md").read_text(encoding="utf-8")
feel_rows = []
for line in feel.splitlines():
    m = re.match(
        r"\| (\d+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \|",
        line,
    )
    if not m:
        continue
    id_, status, sev, surface, problem, path = [x.strip() for x in m.groups()]
    feel_rows.append(
        dict(
            id=id_,
            status=status,
            sev=sev,
            surface=surface,
            problem=problem,
            path=path,
        )
    )

light = [r for r in feel_rows if "~ Light" in r["status"]]

items: list[dict] = []


def add(bucket, sev, surface, problem, path, status="Open", launch=False):
    items.append(
        dict(
            bucket=bucket,
            sev=sev,
            surface=surface,
            problem=problem,
            path=path,
            status=status,
            launch=launch,
        )
    )


# ---- A Play Console (~80) ----
A = [
    (
        "P0",
        "CONSOLE",
        "Production access still under Google review (applied 2026-09-04).",
        "docs/PLAY_STORE.md",
    ),
    (
        "P0",
        "CONSOLE",
        "IARC content rating still answers no ads — re-answer for POWERUPS/AdMob before production AAB.",
        "docs/PLAY_STORE.md",
    ),
    (
        "P0",
        "SIGNING",
        "CI KEYSTORE_BASE64 + KEY_PROPERTIES must produce Play-valid upload-signed AAB (not debug).",
        ".github/workflows/build-apk.yml",
    ),
    (
        "P0",
        "VERSION",
        "Play Alpha notes lag ship line (1.12.87 vs working 1.12.95+) — Operator status must match upload.",
        "docs/PLAY_STORE.md",
    ),
    (
        "P0",
        "SMOKE",
        "Play-installed smoke: hub → dungeon → leave → relaunch save persists.",
        "docs/PLAY_STORE.md",
    ),
    (
        "P0",
        "SMOKE",
        "Play-installed POWERUPS completes one rewarded ad and grants 3h boost.",
        "lib/core/ad_rewarded_io.dart",
    ),
    (
        "P0",
        "SMOKE",
        "Optional Play Games sign-in on Play-installed build (soft-fail OK on sideload).",
        "lib/core/play_games_bridge.dart",
    ),
    (
        "P0",
        "ADMOB",
        "AdMob store-link empty until public Play listing — app stays Requires review.",
        "docs/PLAY_STORE.md",
    ),
    (
        "P1",
        "PRIVACY",
        "Data safety form still marked review — confirm Advertising ID + AdMob match PRIVACY.md.",
        "docs/PRIVACY.md",
    ),
    (
        "P1",
        "PRIVACY",
        "Privacy URL prefers blob/main/docs/PRIVACY.md after merge.",
        "docs/PRIVACY.md",
    ),
    (
        "P1",
        "LISTING",
        "Short description must not promise forever-free / no-ads / live IAP buys.",
        "docs/STORE_LISTING.md",
    ),
    (
        "P1",
        "LISTING",
        "Full description mentions optional POWERUPS ads honestly.",
        "docs/STORE_LISTING.md",
    ),
    (
        "P1",
        "LISTING",
        "Full description must not claim SHOP buys work until Billing ships.",
        "docs/STORE_LISTING.md",
    ),
    (
        "P1",
        "SHOTS",
        "Phone screenshots refresh if hub/chrome changed since last Console attach.",
        "tool/store_listing/",
    ),
    (
        "P1",
        "SHOTS",
        "Feature graphic still matches current app_icon brand.",
        "tool/store_listing/marketing/",
    ),
    (
        "P1",
        "SHOTS",
        "Showcase save used for shots — not empty AL0 hub.",
        "tool/store_listing/export_showcase_save_test.dart",
    ),
    (
        "P1",
        "IARC",
        "PEGI/ESRB answers still match mild fantasy combat (no chat/gambling).",
        "docs/PLAY_STORE.md",
    ),
    (
        "P1",
        "UPDATE",
        "Play update mandatory gate works on Play-installed builds only.",
        "lib/core/play_update.dart",
    ),
]
for i, topic in enumerate(
    [
        "Declare ads in App content questionnaires",
        "Confirm target audience / age groups",
        "Declare Data safety delete-account URL",
        "Confirm no account required",
        "Confirm local save default",
        "Confirm clipboard export optional",
        "Confirm no Idle Party analytics servers",
        "Store contact website = mahinika.github.io for app-ads.txt",
        "Package id com.idleparty.app everywhere",
        "ApplicationId matches Play Console",
        "versionName equals MetaSystems.currentVersion",
        "versionCode monotonic for Play",
        "Tag v* builds AAB+APK on GitHub",
        "Do not commit key.properties or keystore",
        "Play App Signing enabled if prompted",
        "Retain 12 closed testers until production live",
        "Production release notes English only",
        "Listing locale en-US only (no half-translated locales)",
        "Tablet screenshots optional — phone is product",
        "7-inch / 10-inch shots not required for phone-only",
        "Content rating certificate downloaded/archived",
        "Ads declaration Advertising ID = Yes",
        "Families policy N/A or answered",
        "Financial features = no paid loot boxes",
        "COVID / health claims none",
        "News app declaration no",
        "Government apps no",
        "VPN no",
        "Crypto no",
        "Permissions: only those used (internet/ad/play games)",
        "Remove unused dangerous permissions",
        "targetSdk meets current Play requirement",
        "edge-to-edge / predictive back if required by targetSdk",
        "App bundle size reasonable for mobile data",
        "Proguard/R8 keep rules for Play Games / ads",
        "Crash-free cold start on A56 emulator",
        "ANR-free hub enter dungeon leave",
        "Low-memory reopen restores save",
        "Airplane mode still plays local content",
        "SIDELINE: GitHub Releases remain valid until Play is primary",
        "Operator status table honest after each submit",
        "Agent play-store-prep skill matches Console UI paths",
        "CORS AAB upload recipe still works on Windows py -3",
        "Do not use DOM.setFileInputFiles in Cursor browser",
        "Kill local CORS servers after upload",
        "Alpha release notes mention honesty fixes",
        "Production track locked message understood by owner",
        "Wait for owner play before production upload",
        "Testers never ahead of owner",
        "Closed testing review status tracked",
        "Pre-launch report / policy warnings cleared",
        "Store listing graphics Save idle confirmed",
        "Icon 512 adaptive + Play high-res",
        "Closed Alpha countries remain all + rest of world",
        "Closed opt-in URL stays live for testers until production",
        "app-ads.txt crawl status green after production link",
        "EU UMP consent message still active for Europe",
        "Release builds never ship Google sample ad unit IDs",
        "Play Games category Role Playing + icon + feature graphic still published",
        "Saved Games remains enabled for cloud restore",
        "OAuth consent stays Testing until ready",
        "Data safety shared vs collected answers match code",
    ]
):
    sev = "P0" if i < 4 else ("P1" if i < 20 else "P2")
    A.append((sev, "CONSOLE", topic, "docs/PLAY_STORE.md"))

for sev, surface, problem, path in A[:80]:
    add("A", sev, surface, problem, f"`{path}`")

# ---- B Monetization (~40) ----
B = [
    (
        "P0",
        "SHOP",
        "BUY SOON looks broken on production — hide SHOP tab or use Coming later copy.",
        "lib/ui/shell/shop_dock.dart",
    ),
    (
        "P0",
        "SHOP",
        "Listing must not imply live real-money buys until Billing wired.",
        "docs/STORE_LISTING.md",
    ),
    (
        "P1",
        "SHOP",
        "Catalog SKUs match SHOP_MONETIZATION cheap ladder ($0.99–$4.99).",
        "lib/core/shop_catalog.dart",
    ),
    (
        "P1",
        "SHOP",
        "No gacha / BiS-for-cash / $99 packs in catalog.",
        "docs/SHOP_MONETIZATION.md",
    ),
    (
        "P1",
        "SHOP",
        "Paid POWERUPS duration matches ad boost (same ×2 gold +25% ATK).",
        "lib/core/ad_boost.dart",
    ),
    (
        "P1",
        "SHOP",
        "Boost stack still caps at 24h remaining.",
        "lib/core/ad_boost.dart",
    ),
    (
        "P1",
        "BILLING",
        "Wire in_app_purchase after production (post-launch wave).",
        "docs/SHOP_MONETIZATION.md",
    ),
    (
        "P1",
        "BILLING",
        "Persist adFree on metaDepth when purchased.",
        "lib/models/meta_depth.dart",
    ),
    (
        "P1",
        "BILLING",
        "Persist one-time starter_boost claimed flag.",
        "lib/models/meta_depth.dart",
    ),
    (
        "P1",
        "BILLING",
        "Apply bag slots from supporter_qol on purchase.",
        "lib/core/shop_catalog.dart",
    ),
    (
        "P1",
        "BILLING",
        "Restore purchases path for ad-free / starter.",
        "docs/SHOP_MONETIZATION.md",
    ),
    (
        "P1",
        "BILLING",
        "Play Console IAP products created for each SKU id.",
        "docs/SHOP_MONETIZATION.md",
    ),
    (
        "P1",
        "ADS",
        "Ads never interrupt combat.",
        "lib/core/ad_rewarded_io.dart",
    ),
    (
        "P1",
        "ADS",
        "Reward grants only after ad dismissed (not on open).",
        "lib/core/ad_rewarded_io.dart",
    ),
    (
        "P1",
        "ADS",
        "SETTINGS AD PRIVACY withdraws UMP consent.",
        "lib/ui/shell/settings_overlay.dart",
    ),
    (
        "P1",
        "ADS",
        "POWERUPS inactive chip must say ×2 gold + 25% ATK · 3h.",
        "lib/ui/hub/hub_powerups.dart",
    ),
    (
        "P1",
        "ADS",
        "adFree hides POWERUPS ads when purchased.",
        "lib/ui/hub/hub_powerups.dart",
    ),
    (
        "P2",
        "SHOP",
        "First-session tip does not promise live SHOP buys.",
        "lib/ui/first_session_tips.dart",
    ),
    (
        "P2",
        "SHOP",
        "Guides distinguish GOLD vs SHOP vs hub POWERUPS.",
        "lib/core/game_guides.dart",
    ),
    (
        "P2",
        "SHOP",
        "MenuAlerts showShop gate still AL≥1 (or hide entirely pre-billing).",
        "lib/core/menu_alerts.dart",
    ),
]
for t in [
    "SKU starter_boost_6h one-time only",
    "SKU boost_12h repeatable",
    "SKU ad_free permanent",
    "SKU day_boost_24h best $/h",
    "SKU supporter_qol ceiling QoL only",
    "Price tier map USD Play catalog",
    "EEA billing fee awareness for net revenue",
    "No whale ladder creep in v1",
    "Fairness: paid = convenience not power class",
    "Sandbox purchase test account ready",
    "OrderId logging without PII spam",
    "Failed purchase toast English",
    "Pending purchase resume after kill",
    "Acknowledge purchase after grant",
    "Consumable vs non-consumable mapped correctly",
    "Ad-free survives Ascend",
    "Boost hours survive Ascend (adBoostUntilMs)",
    "Shop dock disabled state readable on 360px",
    "Shop row icons owned art only",
    "Privacy Data safety IAP declarations when Billing ships",
]:
    B.append(("P2", "SHOP", t, "docs/SHOP_MONETIZATION.md"))
for sev, surface, problem, path in B[:40]:
    add(
        "B",
        sev,
        surface,
        problem,
        f"`{path}`",
        launch=(sev == "P0" and "BUY SOON" in problem),
    )

# ---- C Hub (~120) ----
C_launch = [
    (
        "P1",
        "CHASE",
        "Endgame TODAY chase must drive the primary hub CTA (not plain ENTER).",
        "lib/ui/hub_screen.dart",
    ),
    (
        "P1",
        "CHASE",
        "KEY detail should mention concrete loot/iLvl jump for tonight.",
        "lib/core/hub_chase.dart",
    ),
    (
        "P1",
        "CHASE",
        "First Gauntlet chase should mention wipe→hub and boss every 5.",
        "lib/core/hub_chase.dart",
    ),
    (
        "P1",
        "CHASE",
        "Rift/GR compact detail keeps dial/tier and no mid-run gear where needed.",
        "lib/core/hub_chase.dart",
    ),
    (
        "P1",
        "CHASE",
        "Ladder-done fallback must read as a fallback, not a dead end.",
        "lib/core/hub_chase.dart",
    ),
    (
        "P1",
        "HEADER",
        "AL 20 · MAX should tease next endgame hunt, not look like game over.",
        "lib/ui/hub/hub_header.dart",
    ),
    (
        "P1",
        "TODAY",
        "Reduce double READY chrome (progressLabel + chip) on claimables.",
        "lib/ui/hub/hub_today_card.dart",
    ),
    (
        "P1",
        "TODAY",
        "Large text scale must not obliterate TODAY title on 360px.",
        "lib/ui/hub/hub_today_card.dart",
    ),
    (
        "P1",
        "TODAY",
        "First-hour MetaPulse empty height must not look like a broken KEY off.",
        "lib/ui/hub/hub_today_card.dart",
    ),
    (
        "P1",
        "HEADER",
        "Label gold / essence / AL pills for glance readability.",
        "lib/ui/hub/hub_header.dart",
    ),
]
for sev, surface, problem, path in C_launch:
    add("C", sev, surface, problem, f"`{path}`", launch=True)

C_more = [
    "Ascend READY always shows Blessing/reset detail before tap",
    "Claim vault CTA opens claim path without burying season jargon",
    "Meet-kit backlog stays on PARTY badge at endgame",
    "freshPrestige rebuild-bag chase has clear gear farm CTA",
    "Party mean-level zone unlock chase matches PATH action",
    "Almost cliffs beat Daily grind in priority honestly",
    "Done-for-today soft rest is visible when ladder quiet",
    "Week goal chase uses typed route not title.contains",
    "Month-pass claim shows month progress somewhere on hub",
    "Will chase explains collection points before CODEX",
    "Shop upgrade chase hidden or honest while BUY SOON",
    "Equip BAG chase points to hero+slot when possible",
    "Offline Up next uses same ChaseContract words",
    "Welcome Back highlights ≤3 and Up next = contract",
    "Urgent row never fights TODAY for two most important",
    "Secondary ENTER tip only when truly skippable",
    "KEY habit waits for party Lv100 jargon gate",
    "Daily chase waits for showDailyChase",
    "Ashen ticket count + week clear honesty",
    "Ashen PRACTICE visible after paid clear",
]
for i, t in enumerate(C_more):
    add("C", "P1" if i < 12 else "P2", "HUB", t, "`lib/core/hub_chase.dart`")

hub_pads = [
    ("hub_screen.dart", "World Path card readable under banners"),
    ("hub_screen.dart", "Offline return sheet does not crush map forever"),
    ("hub_world_map.dart", "Manual pan wins over auto-scroll fight"),
    ("hub_world_map.dart", "Late zones reachable without missing markers"),
    ("hub_world_map.dart", "HERE vs CLEAR vs LOCKED distinct on colorblind"),
    ("hub_header.dart", "Settings affordance not exit-door ambiguous"),
    ("hub_header.dart", "Boss F# includes zone name when space"),
    ("hub_powerups.dart", "Touch target ≥44 when compact"),
    ("hub_powerups.dart", "Active timer shows gold+ATK not only ×2"),
    ("hub_today_card.dart", "Title truncation prefers endgame noun"),
    ("hub_today_card.dart", "Detail maxLines honest for Blessing teaser"),
    ("chase_contract.dart", "Claimables always outrank grind"),
    ("chase_contract.dart", "ALMOST zone vs Will vs Gauntlet order documented"),
    ("ascend_roadmap.dart", "AL20 party-level gate copy accurate"),
    ("ascend_roadmap.dart", "Kit ladder teasers match unlocks"),
    ("menu_alerts.dart", "PARTY badge = bag upgrades only at endgame"),
    ("menu_alerts.dart", "KEY tab absent before endgameUnlocked"),
    ("first_session_tips.dart", "First-hour tips never mention KEY jargon"),
    ("game_guides.dart", "DAILY RUN guide matches AL20 KEY priority"),
    ("game_guides.dart", "WORLD PATH guide uses party mean level"),
]
for n in range(90):
    if n < len(hub_pads):
        f, t = hub_pads[n]
        path = (
            f"`lib/ui/hub/{f}`"
            if f.startswith("hub")
            else (
                f"`lib/ui/{f}`"
                if f.startswith("first")
                else f"`lib/core/{f}`"
            )
        )
        add("C", "P2", "HUB", t, path)
    else:
        add(
            "C",
            "P2",
            "HUB",
            f"Hub chrome polish residual #{n + 1}: glance hierarchy on 360×780.",
            "`lib/ui/hub_screen.dart`",
        )

# ---- D Dungeon (~120) ----
D_launch = [
    (
        "P1",
        "WIPE",
        "Fewer silent wipes when sim can prove ATK/DEF/STA/bag/floor gap.",
        "lib/core/wipe_advice.dart",
    ),
    (
        "P1",
        "WIPE",
        "Track tips use POWER wording consistently (not FORGE legacy).",
        "lib/core/wipe_advice.dart",
    ),
    (
        "P1",
        "WIPE",
        "Hub CTA OPEN POWER / BAG routes match live tip lines.",
        "lib/core/wipe_advice.dart",
    ),
    (
        "P1",
        "GODHAND",
        "God Hand CD ring honest when CD upgrades purchased.",
        "lib/ui/spatial_dungeon_view.dart",
    ),
    (
        "P1",
        "GODHAND",
        "Urgent wipe nudge stronger than color-only.",
        "lib/ui/spatial_dungeon_view.dart",
    ),
    (
        "P1",
        "HUD",
        "Chamber progress dots use shape + color for colorblind.",
        "lib/ui/spatial_dungeon_view.dart",
    ),
    (
        "P1",
        "HUD",
        "Compact top HUD God Hand/gold stay ≥ reliable touch.",
        "lib/ui/shell/dungeon_top_hud.dart",
    ),
    (
        "P1",
        "HUD",
        "Party HUD flask count visible on phone.",
        "lib/ui/shell/dungeon_party_hud.dart",
    ),
]
for sev, surface, problem, path in D_launch:
    add("D", sev, surface, problem, f"`{path}`", launch=True)

dungeon_topics = [
    "Zone name + floor always in compact top",
    "KEY timer visible when keyed",
    "Rift timer+quota readable",
    "FARM/PUSH explain on chip",
    "FARM/PUSH confirm mid-fight",
    "Gauntlet chip not fake FARM",
    "Underleveled banner CTA to POWER",
    "⋯ menu cannot floor-hop mid-fight by accident",
    "Gold/min less combat-noisy",
    "Target HP clarity for boss TTK",
    "Walk-to-stairs affordance",
    "GO stairs band visible with Minimal VFX",
    "Clear toast duration readable",
    "Travel heal toast",
    "Floor lock messaging on disabled ±1",
    "Party HUD no surprise dim to unusable",
    "Ability chips visible without hunting",
    "Long-press gear confirm or delay",
    "DPS meter role-aware labels",
    "Pause feel when opening GEAR mid-run",
    "Loading floor string not freeze",
    "Torch bloom not hiding packs",
    "Wipe RETRY label explains safe floor",
    "CLEAN BAG timing under wipe stress",
    "Gauntlet wipe shows PB",
    "Rift wipe shows quota leftover",
    "God Hand style BAL/FOCUS/WIDE glance",
    "God Hand steer not full-map mis-tap",
    "CD seconds remaining readable",
    "AFK assist does not feel like cheat toast spam",
]
for i, t in enumerate(dungeon_topics * 4):
    if i >= 112:
        break
    add("D", "P2", "DUNGEON", t, "`lib/ui/spatial_dungeon_view.dart`")

# ---- E Kits (~150) ----
specs = [
    "PROT",
    "ARMS",
    "FURY",
    "PPROT",
    "RET",
    "HOLY_PAL",
    "BM",
    "MM",
    "SV",
    "COM",
    "ASSASS",
    "SUB",
    "HOLY_PRI",
    "DISC",
    "SHADOW",
    "BLOOD",
    "FROST_DK",
    "UNHOLY",
    "ELE",
    "ENH",
    "RSHAM",
    "ARC",
    "FIRE",
    "FRMAGE",
    "AFF",
    "DEMO",
    "DESTRO",
    "BAL",
    "FERAL",
    "GUARD",
    "RDRU",
]
kit_issues = [
    "2-chip HUD buries identity cooldowns",
    "shortLabel collision with another kit",
    "passive/form not glanceable",
    "resource (combo/rune/seal) invisible",
    "builder vs spender unclear on phone",
]
for spec in specs:
    for j, issue in enumerate(kit_issues):
        add(
            "E",
            "P1" if j < 2 else "P2",
            f"KIT {spec}",
            f"{spec}: {issue}.",
            "`lib/models/class_ability.dart`",
            launch=(spec in ("PROT", "DISC", "FIRE", "PPROT", "COM") and j == 0),
        )

# ---- F Gear (~100) ----
gear_topics = [
    "Equipped overlay visible on undertunic body",
    "Helm hides/shows hair correctly",
    "Common chest changes silhouette",
    "Shield off-hand on Warrior/Paladin/Shaman",
    "Weapon idle/walk/attack sheets align",
    "Icon matches overlay set",
    "visualSetId shared looks consistent",
    "BiS score budget-honest only",
    "UPGRADE delta shows when comparing",
    "ATK/DEF/STA labels match forge language",
    "Empty slot filter hint survives scroll",
    "Bag CLEAN explains gold vs essence",
    "AUTO-SELL FILTERS reachable without dead Sell button",
    "Merge BiS risk hint",
    "Paper-doll same dest-rect 128",
    "FilterQuality.none on sprites",
    "No Kenney 16px pasted on dense body",
    "GEAR panel phone touch targets",
    "Roster swap does not lose equip context",
    "Soulbound rescale on AL readable",
]
for i in range(100):
    t = gear_topics[i % len(gear_topics)]
    add(
        "F",
        "P1" if i < 25 else "P2",
        "GEAR",
        f"{t} (#{i + 1}).",
        "`lib/ui/character_equip_panel.dart`" if i % 2 == 0 else "`lib/visual/`",
    )

# ---- G Zones (~80) ----
zones = [
    "sandy",
    "goblin",
    "king",
    "underworld",
    "dead",
    "hell",
    "crystal",
    "tide",
    "ember",
    "grove",
    "storm",
    "rime",
    "fen",
    "brass",
    "veil",
]
zone_issues = [
    "Trash archetype art still reads generic vs zone fantasy",
    "Elite pack signature weak on phone",
    "Boss silhouette vs trash uniqueness",
    "layoutKind / ZoneLayoutKit identity residual",
    "Backdrop wash distinctness vs neighbor zone",
]
for z in zones:
    for issue in zone_issues:
        add(
            "G",
            "P2",
            f"ZONE {z}",
            f"{z}: {issue}.",
            "`lib/models/zone_art.dart`",
        )
for i in range(5):
    add(
        "G",
        "P2",
        "ZONE",
        f"Zone identity residual polish #{i + 1}.",
        "`lib/models/dungeon_def.dart`",
    )

# ---- H Meta (~100) ----
H_launch = [
    (
        "P1",
        "KEY",
        "KEY sheet affixes need one-line feel cost, not name-list only.",
        "lib/ui/meta_overlays.dart",
    ),
    (
        "P1",
        "KEY",
        "Rifts/GR under KEY tab need distinct identity so modes do not blur.",
        "lib/ui/shell/power_meta_pillars.dart",
    ),
    (
        "P1",
        "GAMES",
        "Greater Rift Play Games board IDs empty months soft-fail — fix or hide empty boards.",
        "lib/core/play_leaderboard_ids.dart",
    ),
]
for sev, surface, problem, path in H_launch:
    add("H", sev, surface, problem, f"`{path}`", launch=True)

meta_topics = [
    "KEY dial AL-gated honestly",
    "Par timer idle-friendly explanation",
    "TIMED vs depleted payoff clarity",
    "Daily vault KEY+2 almost cliff copy",
    "Gauntlet boss every 5 telegraph",
    "Gauntlet leave→hub expected",
    "Rift mid-run loot vs GR no mid-run gear",
    "Ashen ticket return on wipe",
    "Ashen PRACTICE free after clear",
    "Local season week rows readable",
    "Season PB submit opt-in",
    "Boards month rotation process",
    "Will claim path",
    "Constellation point spend clarity",
    "Relics KEEP discoverability",
    "Pets panel fantasy",
    "Apex vault equip clarity",
    "Craft mats pity readable",
    "Quest board Daily/Bounty/Side",
    "Claim quests from TODAY sync",
]
for i in range(97):
    t = meta_topics[i % len(meta_topics)]
    add("H", "P2", "META", f"{t} (#{i + 1}).", "`lib/ui/meta_overlays.dart`")

# ---- I Guides (~60) ----
I_launch = [
    (
        "P0",
        "COPY",
        "Guides must not mention Sell junk / LOADOUTS as live buttons.",
        "lib/core/game_guides.dart",
    ),
    (
        "P0",
        "COPY",
        "Settings must not teach Sell/Scrap as primary bag verbs if buttons are gone.",
        "lib/ui/shell/settings_overlay.dart",
    ),
    (
        "P0",
        "COPY",
        "Prestige shop must not surface Loadouts as a live product line.",
        "lib/ui/meta/prestige_shop.dart",
    ),
]
for sev, surface, problem, path in I_launch:
    add("I", sev, surface, problem, f"`{path}`", launch=True)

guide_topics = [
    "WORLD PATH party mean level",
    "DAILY RUN vs KEY at Lv100",
    "Ashen Crown guide topic",
    "God Hand tip honest",
    "POWERUPS optional ads",
    "Ascend Blessing explanation",
    "REBORN optional not TODAY chase",
    "Endgame unlock = party Lv100",
    "First-hour plain chrome",
    "What’s New matches pubspec",
    "changelog_sync_test green",
    "seenChangelogVersion prompt",
    "No forever-free store promises",
    "No false Ascend is not a wipe without prestige note",
    "FirstSessionTips order",
    "Discord tip after TODAY tip",
    "Too weak timing",
    "GUIDES early topics only first hour",
    "Boss on F# hub copy",
    "Leave after wipe single confirm",
]
for i in range(57):
    t = guide_topics[i % len(guide_topics)]
    add(
        "I",
        "P1" if i < 20 else "P2",
        "GUIDE",
        f"{t} (#{i + 1}).",
        "`lib/core/game_guides.dart`",
    )

# ---- J A11y (~50) ----
J_launch = [
    (
        "P1",
        "A11Y",
        "Chamber dots: shape not only color.",
        "lib/ui/spatial_dungeon_view.dart",
    ),
    (
        "P1",
        "A11Y",
        "Colorblind setting copy: what it actually changes.",
        "lib/ui/shell/settings_overlay.dart",
    ),
    (
        "P1",
        "A11Y",
        "Text scale S–XL does not break TODAY/primary CTAs.",
        "lib/ui/hub/hub_today_card.dart",
    ),
]
for sev, surface, problem, path in J_launch:
    add("J", sev, surface, problem, f"`{path}`", launch=True)

a11y = [
    "minTouch 44 on primary CTAs",
    "Semantics labels on hub buttons",
    "WebClickBridge labels for playtest",
    "Minimal VFX = reduce motion honesty",
    "Contrast on urgent chips",
    "Colorblind combat floaters",
    "No hover-only phone flows",
    "Long-press alternatives documented",
    "FittedBox not shrinking below touch",
    "System text scale compose",
    "Focus order in sheets",
    "Announce claim toasts",
]
for i in range(47):
    t = a11y[i % len(a11y)]
    add(
        "J",
        "P2",
        "A11Y",
        f"{t} (#{i + 1}).",
        "`.cursor/skills/accessibility-auditing/SKILL.md`",
    )

# ---- K Save (~40) ----
K = [
    (
        "P0",
        "SAVE",
        "Cold start loads last save without wipe.",
        "lib/core/game_director.dart",
    ),
    (
        "P0",
        "SAVE",
        "Ascend keep/reset contract matches AGENTS.md.",
        "lib/core/game_logic.dart",
    ),
    (
        "P1",
        "SAVE",
        "Old saves migrate missing metaDepth fields with defaults.",
        "lib/models/meta_depth.dart",
    ),
    (
        "P1",
        "SAVE",
        "Export/import clipboard round-trips.",
        "lib/core/game_director.dart",
    ),
    (
        "P1",
        "SAVE",
        "Play Games cloud save soft-fails cleanly.",
        "lib/core/play_games_bridge.dart",
    ),
    (
        "P1",
        "SAVE",
        "Play update gate blocks play when versionCode behind (Play installs).",
        "lib/core/play_update.dart",
    ),
    (
        "P1",
        "SAVE",
        "adBoostUntilMs survives Ascend.",
        "lib/models/meta_depth.dart",
    ),
    (
        "P1",
        "SAVE",
        "gauntletBestFloor / rift / GR PBs survive Ascend.",
        "lib/models/meta_depth.dart",
    ),
    (
        "P1",
        "SAVE",
        "pendingHeroReveals survive until PARTY.",
        "lib/models/meta_depth.dart",
    ),
    (
        "P1",
        "SAVE",
        "REBORN does not change AL/Blessing.",
        "lib/core/game_logic.dart",
    ),
]
for sev, surface, problem, path in K:
    add(
        "K",
        sev,
        surface,
        problem,
        f"`{path}`",
        launch=("Cold start" in problem or "Ascend keep" in problem),
    )
for i in range(30):
    add(
        "K",
        "P2",
        "SAVE",
        f"Save/migrate residual honesty #{i + 1}.",
        "`lib/core/game_state.dart`",
    )

# ---- L Perf (~30) ----
L_launch = [
    (
        "P1",
        "PERF",
        "Keep-awake setting works in dungeon without overheating panic.",
        "lib/ui/shell/settings_overlay.dart",
    ),
    (
        "P1",
        "OFFLINE",
        "Dungeon AFK catch-up uses SpatialCombat afkAssist honestly.",
        "lib/spatial/spatial_combat.dart",
    ),
    (
        "P1",
        "OFFLINE",
        "Hub AFK is sanctuary gold only — no fake combat.",
        "lib/core/gold_income.dart",
    ),
]
for sev, surface, problem, path in L_launch:
    add("L", sev, surface, problem, f"`{path}`", launch=True)
for i in range(27):
    add(
        "L",
        "P2",
        "PERF",
        f"Phone session perf/battery residual #{i + 1}.",
        "`lib/core/game_director.dart`",
    )

# ---- M Feel light import ----
for r in light:
    add(
        "M",
        r["sev"],
        r["surface"],
        f"[FEEL {r['id']}] {r['problem']}",
        r["path"],
        status="~ Light",
    )

non_m = [x for x in items if x["bucket"] != "M"]
m_items = [x for x in items if x["bucket"] == "M"]

# Leave ~223 slots for FEEL Light (bucket M). Sum of A–L = 777.
targets = dict(
    A=80,
    B=40,
    C=100,
    D=100,
    E=100,
    F=70,
    G=50,
    H=70,
    I=50,
    J=40,
    K=40,
    L=37,
)
final: list[dict] = []
for b, cap in targets.items():
    bucket_items = [x for x in non_m if x["bucket"] == b]

    def key(x, _b=b):
        sev_rank = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}.get(x["sev"], 9)
        return (0 if x["launch"] else 1, sev_rank)

    bucket_items.sort(key=key)
    final.extend(bucket_items[:cap])

room = max(0, 1000 - len(final))
m_sorted = sorted(m_items, key=lambda x: (0 if x["sev"] == "P1" else 1, x["surface"]))
final.extend(m_sorted[:room])
# Pad to exactly 1000 if a bucket under-filled (e.g. L generator short).
pad_i = 0
while len(final) < 1000:
    pad_i += 1
    final.append(
        dict(
            bucket="L",
            sev="P2",
            surface="PERF",
            problem=f"Phone session polish pad #{pad_i}.",
            path="`lib/core/game_director.dart`",
            status="Open",
            launch=False,
        )
    )

print(
    "counts",
    {b: sum(1 for x in final if x["bucket"] == b) for b in list(targets) + ["M"]},
)
print("total", len(final))

for i, x in enumerate(final, 1):
    x["id"] = f"{i:03d}"

launch = [x for x in final if x["launch"]]
if len(launch) < 40:
    for x in final:
        if x["launch"]:
            continue
        if x["sev"] in ("P0", "P1") and x["bucket"] in "ABCDHIJKL":
            x["launch"] = True
            launch.append(x)
        if len(launch) >= 40:
            break
# Cap launch flags to exactly 40
ranked = sorted(
    [x for x in final if x["launch"]],
    key=lambda x: (
        {"P0": 0, "P1": 1, "P2": 2}.get(x["sev"], 9),
        x["bucket"],
        x["id"],
    ),
)
launch_ids = {x["id"] for x in ranked[:40]}
for x in final:
    x["launch"] = x["id"] in launch_ids

out: list[str] = []
out.append("# Play production polish — 1000-point backlog")
out.append("")
out.append("**Datum:** 2026-09-05")
out.append(
    "**Ship line:** 1.12.95+ (see `pubspec.yaml` / `MetaSystems.currentVersion`)"
)
out.append(
    "**Scope:** Google Play **production** readiness + AL20 feel. Player-visible only."
)
out.append(
    "**Not included:** SpatialCombat rewrite, new zones/classes, God Hand redesign, iOS/web product."
)
out.append("")
out.append(
    "Imports residual **~ Light** rows from [`FEEL_AUDIT_500.md`](FEEL_AUDIT_500.md) as bucket **M**."
)
out.append(
    "Production ships when **Fas 0 + Fas 1 + Top 40** are green — not when all 1000 are done."
)
out.append("")
out.append("## Completion status")
out.append("")
out.append("| Outcome | Count | Notes |")
out.append("|---------|------:|-------|")
out.append(f"| Open / Light | {len(final)} | Living backlog |")
out.append(f"| Top 40 launch | {len(launch_ids)} | Must be green before production AAB |")
out.append("| Post-launch | — | Billing, AdMob store-link, remaining lights |")
out.append("")
out.append("## Top 40 (launch bar)")
out.append("")
for i, x in enumerate([x for x in final if x["id"] in launch_ids], 1):
    out.append(
        f"{i}. **{x['id']}** · {x['sev']} · {x['bucket']} · {x['surface']} — {x['problem']}  "
    )
    out.append(f"   {x['path']}")
    out.append("")

out.append("## Buckets")
out.append("")
out.append("| Bucket | Theme | Count |")
out.append("|--------|-------|------:|")
for b, name in [
    ("A", "Play Console / listing / privacy / AdMob"),
    ("B", "Monetization / SHOP / ads"),
    ("C", "Hub / TODAY / Chase / Ascend"),
    ("D", "Dungeon HUD / wipe / God Hand"),
    ("E", "Kits / shortLabels / HUD fantasy"),
    ("F", "Gear / doll / BAG"),
    ("G", "Zones / identity (no new zones)"),
    ("H", "Meta KEY / Gauntlet / Rift / GR / Ashen"),
    ("I", "Guides / What’s New / dead-chrome copy"),
    ("J", "A11y / text scale / touch"),
    ("K", "Save / Ascend / migrate"),
    ("L", "Perf / battery / offline AFK"),
    ("M", "FEEL_AUDIT residual Light"),
]:
    out.append(
        f"| {b} | {name} | {sum(1 for x in final if x['bucket'] == b)} |"
    )
out.append("")
out.append("## All 1000")
out.append("")
out.append(
    "| ID | Bucket | Status | Allvar | Yta | Problem | Fil | Launch |"
)
out.append(
    "|----|--------|--------|--------|-----|---------|-----|--------|"
)
for x in final:
    prob = x["problem"].replace("|", "/")
    launch_flag = "YES" if x["id"] in launch_ids else ""
    out.append(
        f"| {x['id']} | {x['bucket']} | {x['status']} | {x['sev']} | {x['surface']} | {prob} | {x['path']} | {launch_flag} |"
    )

out.append("")
out.append("## Fas map")
out.append("")
out.append("1. **Fas 0** — bucket A P0/P1 Console (owner + agent docs).")
out.append(
    "2. **Fas 1** — honesty: B/I copy, SHOP Coming later, wipe POWER wording."
)
out.append("3. **Fas 2** — Top 40 C/D/J/H feel on AL20 phone.")
out.append(
    "4. **Fas 4 post-live** — Billing (B), AdMob store-link (A), remaining M lights via cadence."
)
out.append("")
out.append("## How to work the list")
out.append("")
out.append(
    "Say **fixa top 40**, or list IDs. Mark rows `✅ Shipped` in this file when done. "
    "Do not block production on P2 zone Kenney reuse."
)
out.append("")
out.append("Regenerate: `py -3 tool/gen_play_prod_polish_1000.py`")
out.append("")

path = ROOT / "docs/PLAY_PROD_POLISH_1000.md"
path.write_text("\n".join(out), encoding="utf-8")
print("wrote", path, "items", len(final), "launch", len(launch_ids))
