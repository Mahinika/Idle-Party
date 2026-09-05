# Play production polish — 1000-point backlog

**Datum:** 2026-09-05
**Ship line:** 1.12.95+ (see `pubspec.yaml` / `MetaSystems.currentVersion`)
**Scope:** Google Play **production** readiness + AL20 feel. Player-visible only.
**Not included:** SpatialCombat rewrite, new zones/classes, God Hand redesign, iOS/web product.

Imports residual **~ Light** rows from [`FEEL_AUDIT_500.md`](FEEL_AUDIT_500.md) as bucket **M**.
Production ships when **Fas 0 + Fas 1 + Top 40** are green — not when all 1000 are done.

## Completion status

| Outcome | Count | Notes |
|---------|------:|-------|
| Open / Light | 982 | Living backlog |
| Top 40 launch | 40 | Must be green before production AAB |
| ✅ Shipped (this pass) | 18 | Fas 1 honesty + billing persist scaffold + wipe POWER |

## Top 40 (launch bar)

1. **001** · P0 · A · CONSOLE — Production access still under Google review (applied 2026-09-04).  
   `docs/PLAY_STORE.md`

2. **002** · P0 · A · CONSOLE — IARC content rating still answers no ads — re-answer for POWERUPS/AdMob before production AAB.  
   `docs/PLAY_STORE.md`

3. **081** · P0 · B · SHOP — BUY SOON looks broken on production — hide SHOP tab or use Coming later copy.  
   `lib/ui/shell/shop_dock.dart`

4. **121** · P1 · C · CHASE — Endgame TODAY chase must drive the primary hub CTA (not plain ENTER).  
   `lib/ui/hub_screen.dart`

5. **122** · P1 · C · CHASE — KEY detail should mention concrete loot/iLvl jump for tonight.  
   `lib/core/hub_chase.dart`

6. **123** · P1 · C · CHASE — First Gauntlet chase should mention wipe→hub and boss every 5.  
   `lib/core/hub_chase.dart`

7. **124** · P1 · C · CHASE — Rift/GR compact detail keeps dial/tier and no mid-run gear where needed.  
   `lib/core/hub_chase.dart`

8. **125** · P1 · C · CHASE — Ladder-done fallback must read as a fallback, not a dead end.  
   `lib/core/hub_chase.dart`

9. **126** · P1 · C · HEADER — AL 20 · MAX should tease next endgame hunt, not look like game over.  
   `lib/ui/hub/hub_header.dart`

10. **127** · P1 · C · TODAY — Reduce double READY chrome (progressLabel + chip) on claimables.  
   `lib/ui/hub/hub_today_card.dart`

11. **128** · P1 · C · TODAY — Large text scale must not obliterate TODAY title on 360px.  
   `lib/ui/hub/hub_today_card.dart`

12. **129** · P1 · C · TODAY — First-hour MetaPulse empty height must not look like a broken KEY off.  
   `lib/ui/hub/hub_today_card.dart`

13. **130** · P1 · C · HEADER — Label gold / essence / AL pills for glance readability.  
   `lib/ui/hub/hub_header.dart`

14. **221** · P1 · D · WIPE — Fewer silent wipes when sim can prove ATK/DEF/STA/bag/floor gap.  
   `lib/core/wipe_advice.dart`

15. **222** · P1 · D · WIPE — Track tips use POWER wording consistently (not FORGE legacy).  
   `lib/core/wipe_advice.dart`

16. **223** · P1 · D · WIPE — Hub CTA OPEN POWER / BAG routes match live tip lines.  
   `lib/core/wipe_advice.dart`

17. **224** · P1 · D · GODHAND — God Hand CD ring honest when CD upgrades purchased.  
   `lib/ui/spatial_dungeon_view.dart`

18. **225** · P1 · D · GODHAND — Urgent wipe nudge stronger than color-only.  
   `lib/ui/spatial_dungeon_view.dart`

19. **226** · P1 · D · HUD — Chamber progress dots use shape + color for colorblind.  
   `lib/ui/spatial_dungeon_view.dart`

20. **227** · P1 · D · HUD — Compact top HUD God Hand/gold stay ≥ reliable touch.  
   `lib/ui/shell/dungeon_top_hud.dart`

21. **228** · P1 · D · HUD — Party HUD flask count visible on phone.  
   `lib/ui/shell/dungeon_party_hud.dart`

22. **321** · P1 · E · KIT PROT — PROT: 2-chip HUD buries identity cooldowns.  
   `lib/models/class_ability.dart`

23. **322** · P1 · E · KIT PPROT — PPROT: 2-chip HUD buries identity cooldowns.  
   `lib/models/class_ability.dart`

24. **323** · P1 · E · KIT COM — COM: 2-chip HUD buries identity cooldowns.  
   `lib/models/class_ability.dart`

25. **324** · P1 · E · KIT DISC — DISC: 2-chip HUD buries identity cooldowns.  
   `lib/models/class_ability.dart`

26. **325** · P1 · E · KIT FIRE — FIRE: 2-chip HUD buries identity cooldowns.  
   `lib/models/class_ability.dart`

27. **541** · P1 · H · KEY — KEY sheet affixes need one-line feel cost, not name-list only.  
   `lib/ui/meta_overlays.dart`

28. **542** · P1 · H · KEY — Rifts/GR under KEY tab need distinct identity so modes do not blur.  
   `lib/ui/shell/power_meta_pillars.dart`

29. **543** · P1 · H · GAMES — Greater Rift Play Games board IDs empty months soft-fail — fix or hide empty boards.  
   `lib/core/play_leaderboard_ids.dart`

30. **611** · P0 · I · COPY — Guides must not mention Sell junk / LOADOUTS as live buttons.  
   `lib/core/game_guides.dart`

31. **612** · P0 · I · COPY — Settings must not teach Sell/Scrap as primary bag verbs if buttons are gone.  
   `lib/ui/shell/settings_overlay.dart`

32. **613** · P0 · I · COPY — Prestige shop must not surface Loadouts as a live product line.  
   `lib/ui/meta/prestige_shop.dart`

33. **661** · P1 · J · A11Y — Chamber dots: shape not only color.  
   `lib/ui/spatial_dungeon_view.dart`

34. **662** · P1 · J · A11Y — Colorblind setting copy: what it actually changes.  
   `lib/ui/shell/settings_overlay.dart`

35. **663** · P1 · J · A11Y — Text scale S–XL does not break TODAY/primary CTAs.  
   `lib/ui/hub/hub_today_card.dart`

36. **701** · P0 · K · SAVE — Cold start loads last save without wipe.  
   `lib/core/game_director.dart`

37. **702** · P0 · K · SAVE — Ascend keep/reset contract matches AGENTS.md.  
   `lib/core/game_logic.dart`

38. **741** · P1 · L · PERF — Keep-awake setting works in dungeon without overheating panic.  
   `lib/ui/shell/settings_overlay.dart`

39. **742** · P1 · L · OFFLINE — Dungeon AFK catch-up uses SpatialCombat afkAssist honestly.  
   `lib/spatial/spatial_combat.dart`

40. **743** · P1 · L · OFFLINE — Hub AFK is sanctuary gold only — no fake combat.  
   `lib/core/gold_income.dart`

## Buckets

| Bucket | Theme | Count |
|--------|-------|------:|
| A | Play Console / listing / privacy / AdMob | 80 |
| B | Monetization / SHOP / ads | 40 |
| C | Hub / TODAY / Chase / Ascend | 100 |
| D | Dungeon HUD / wipe / God Hand | 100 |
| E | Kits / shortLabels / HUD fantasy | 100 |
| F | Gear / doll / BAG | 70 |
| G | Zones / identity (no new zones) | 50 |
| H | Meta KEY / Gauntlet / Rift / GR / Ashen | 70 |
| I | Guides / What’s New / dead-chrome copy | 50 |
| J | A11y / text scale / touch | 40 |
| K | Save / Ascend / migrate | 40 |
| L | Perf / battery / offline AFK | 37 |
| M | FEEL_AUDIT residual Light | 223 |

## All 1000

| ID | Bucket | Status | Allvar | Yta | Problem | Fil | Launch |
|----|--------|--------|--------|-----|---------|-----|--------|
| 001 | A | Open | P0 | CONSOLE | Production access still under Google review (applied 2026-09-04). | `docs/PLAY_STORE.md` | YES |
| 002 | A | Open | P0 | CONSOLE | IARC content rating still answers no ads — re-answer for POWERUPS/AdMob before production AAB. | `docs/PLAY_STORE.md` | YES |
| 003 | A | Open | P0 | SIGNING | CI KEYSTORE_BASE64 + KEY_PROPERTIES must produce Play-valid upload-signed AAB (not debug). | `.github/workflows/build-apk.yml` |  |
| 004 | A | Open | P0 | VERSION | Play Alpha notes lag ship line (1.12.87 vs working 1.12.95+) — Operator status must match upload. | `docs/PLAY_STORE.md` |  |
| 005 | A | Open | P0 | SMOKE | Play-installed smoke: hub → dungeon → leave → relaunch save persists. | `docs/PLAY_STORE.md` |  |
| 006 | A | Open | P0 | SMOKE | Play-installed POWERUPS completes one rewarded ad and grants 3h boost. | `lib/core/ad_rewarded_io.dart` |  |
| 007 | A | Open | P0 | SMOKE | Optional Play Games sign-in on Play-installed build (soft-fail OK on sideload). | `lib/core/play_games_bridge.dart` |  |
| 008 | A | Open | P0 | ADMOB | AdMob store-link empty until public Play listing — app stays Requires review. | `docs/PLAY_STORE.md` |  |
| 009 | A | Open | P0 | CONSOLE | Declare ads in App content questionnaires | `docs/PLAY_STORE.md` |  |
| 010 | A | Open | P0 | CONSOLE | Confirm target audience / age groups | `docs/PLAY_STORE.md` |  |
| 011 | A | Open | P0 | CONSOLE | Declare Data safety delete-account URL | `docs/PLAY_STORE.md` |  |
| 012 | A | Open | P0 | CONSOLE | Confirm no account required | `docs/PLAY_STORE.md` |  |
| 013 | A | Open | P1 | PRIVACY | Data safety form still marked review — confirm Advertising ID + AdMob match PRIVACY.md. | `docs/PRIVACY.md` |  |
| 014 | A | Open | P1 | PRIVACY | Privacy URL prefers blob/main/docs/PRIVACY.md after merge. | `docs/PRIVACY.md` |  |
| 015 | A | Open | P1 | LISTING | Short description must not promise forever-free / no-ads / live IAP buys. | `docs/STORE_LISTING.md` |  |
| 016 | A | Open | P1 | LISTING | Full description mentions optional POWERUPS ads honestly. | `docs/STORE_LISTING.md` |  |
| 017 | A | Open | P1 | LISTING | Full description must not claim SHOP buys work until Billing ships. | `docs/STORE_LISTING.md` |  |
| 018 | A | Open | P1 | SHOTS | Phone screenshots refresh if hub/chrome changed since last Console attach. | `tool/store_listing/` |  |
| 019 | A | Open | P1 | SHOTS | Feature graphic still matches current app_icon brand. | `tool/store_listing/marketing/` |  |
| 020 | A | Open | P1 | SHOTS | Showcase save used for shots — not empty AL0 hub. | `tool/store_listing/export_showcase_save_test.dart` |  |
| 021 | A | Open | P1 | IARC | PEGI/ESRB answers still match mild fantasy combat (no chat/gambling). | `docs/PLAY_STORE.md` |  |
| 022 | A | Open | P1 | UPDATE | Play update mandatory gate works on Play-installed builds only. | `lib/core/play_update.dart` |  |
| 023 | A | Open | P1 | CONSOLE | Confirm local save default | `docs/PLAY_STORE.md` |  |
| 024 | A | Open | P1 | CONSOLE | Confirm clipboard export optional | `docs/PLAY_STORE.md` |  |
| 025 | A | Open | P1 | CONSOLE | Confirm no Idle Party analytics servers | `docs/PLAY_STORE.md` |  |
| 026 | A | Open | P1 | CONSOLE | Store contact website = mahinika.github.io for app-ads.txt | `docs/PLAY_STORE.md` |  |
| 027 | A | Open | P1 | CONSOLE | Package id com.idleparty.app everywhere | `docs/PLAY_STORE.md` |  |
| 028 | A | Open | P1 | CONSOLE | ApplicationId matches Play Console | `docs/PLAY_STORE.md` |  |
| 029 | A | Open | P1 | CONSOLE | versionName equals MetaSystems.currentVersion | `docs/PLAY_STORE.md` |  |
| 030 | A | Open | P1 | CONSOLE | versionCode monotonic for Play | `docs/PLAY_STORE.md` |  |
| 031 | A | Open | P1 | CONSOLE | Tag v* builds AAB+APK on GitHub | `docs/PLAY_STORE.md` |  |
| 032 | A | Open | P1 | CONSOLE | Do not commit key.properties or keystore | `docs/PLAY_STORE.md` |  |
| 033 | A | Open | P1 | CONSOLE | Play App Signing enabled if prompted | `docs/PLAY_STORE.md` |  |
| 034 | A | Open | P1 | CONSOLE | Retain 12 closed testers until production live | `docs/PLAY_STORE.md` |  |
| 035 | A | Open | P1 | CONSOLE | Production release notes English only | `docs/PLAY_STORE.md` |  |
| 036 | A | Open | P1 | CONSOLE | Listing locale en-US only (no half-translated locales) | `docs/PLAY_STORE.md` |  |
| 037 | A | Open | P1 | CONSOLE | Tablet screenshots optional — phone is product | `docs/PLAY_STORE.md` |  |
| 038 | A | Open | P1 | CONSOLE | 7-inch / 10-inch shots not required for phone-only | `docs/PLAY_STORE.md` |  |
| 039 | A | Open | P2 | CONSOLE | Content rating certificate downloaded/archived | `docs/PLAY_STORE.md` |  |
| 040 | A | Open | P2 | CONSOLE | Ads declaration Advertising ID = Yes | `docs/PLAY_STORE.md` |  |
| 041 | A | Open | P2 | CONSOLE | Families policy N/A or answered | `docs/PLAY_STORE.md` |  |
| 042 | A | Open | P2 | CONSOLE | Financial features = no paid loot boxes | `docs/PLAY_STORE.md` |  |
| 043 | A | Open | P2 | CONSOLE | COVID / health claims none | `docs/PLAY_STORE.md` |  |
| 044 | A | Open | P2 | CONSOLE | News app declaration no | `docs/PLAY_STORE.md` |  |
| 045 | A | Open | P2 | CONSOLE | Government apps no | `docs/PLAY_STORE.md` |  |
| 046 | A | Open | P2 | CONSOLE | VPN no | `docs/PLAY_STORE.md` |  |
| 047 | A | Open | P2 | CONSOLE | Crypto no | `docs/PLAY_STORE.md` |  |
| 048 | A | Open | P2 | CONSOLE | Permissions: only those used (internet/ad/play games) | `docs/PLAY_STORE.md` |  |
| 049 | A | Open | P2 | CONSOLE | Remove unused dangerous permissions | `docs/PLAY_STORE.md` |  |
| 050 | A | Open | P2 | CONSOLE | targetSdk meets current Play requirement | `docs/PLAY_STORE.md` |  |
| 051 | A | Open | P2 | CONSOLE | edge-to-edge / predictive back if required by targetSdk | `docs/PLAY_STORE.md` |  |
| 052 | A | Open | P2 | CONSOLE | App bundle size reasonable for mobile data | `docs/PLAY_STORE.md` |  |
| 053 | A | Open | P2 | CONSOLE | Proguard/R8 keep rules for Play Games / ads | `docs/PLAY_STORE.md` |  |
| 054 | A | Open | P2 | CONSOLE | Crash-free cold start on A56 emulator | `docs/PLAY_STORE.md` |  |
| 055 | A | Open | P2 | CONSOLE | ANR-free hub enter dungeon leave | `docs/PLAY_STORE.md` |  |
| 056 | A | Open | P2 | CONSOLE | Low-memory reopen restores save | `docs/PLAY_STORE.md` |  |
| 057 | A | Open | P2 | CONSOLE | Airplane mode still plays local content | `docs/PLAY_STORE.md` |  |
| 058 | A | Open | P2 | CONSOLE | SIDELINE: GitHub Releases remain valid until Play is primary | `docs/PLAY_STORE.md` |  |
| 059 | A | Open | P2 | CONSOLE | Operator status table honest after each submit | `docs/PLAY_STORE.md` |  |
| 060 | A | Open | P2 | CONSOLE | Agent play-store-prep skill matches Console UI paths | `docs/PLAY_STORE.md` |  |
| 061 | A | Open | P2 | CONSOLE | CORS AAB upload recipe still works on Windows py -3 | `docs/PLAY_STORE.md` |  |
| 062 | A | Open | P2 | CONSOLE | Do not use DOM.setFileInputFiles in Cursor browser | `docs/PLAY_STORE.md` |  |
| 063 | A | Open | P2 | CONSOLE | Kill local CORS servers after upload | `docs/PLAY_STORE.md` |  |
| 064 | A | Open | P2 | CONSOLE | Alpha release notes mention honesty fixes | `docs/PLAY_STORE.md` |  |
| 065 | A | Open | P2 | CONSOLE | Production track locked message understood by owner | `docs/PLAY_STORE.md` |  |
| 066 | A | Open | P2 | CONSOLE | Wait for owner play before production upload | `docs/PLAY_STORE.md` |  |
| 067 | A | Open | P2 | CONSOLE | Testers never ahead of owner | `docs/PLAY_STORE.md` |  |
| 068 | A | Open | P2 | CONSOLE | Closed testing review status tracked | `docs/PLAY_STORE.md` |  |
| 069 | A | Open | P2 | CONSOLE | Pre-launch report / policy warnings cleared | `docs/PLAY_STORE.md` |  |
| 070 | A | Open | P2 | CONSOLE | Store listing graphics Save idle confirmed | `docs/PLAY_STORE.md` |  |
| 071 | A | Open | P2 | CONSOLE | Icon 512 adaptive + Play high-res | `docs/PLAY_STORE.md` |  |
| 072 | A | Open | P2 | CONSOLE | Closed Alpha countries remain all + rest of world | `docs/PLAY_STORE.md` |  |
| 073 | A | Open | P2 | CONSOLE | Closed opt-in URL stays live for testers until production | `docs/PLAY_STORE.md` |  |
| 074 | A | Open | P2 | CONSOLE | app-ads.txt crawl status green after production link | `docs/PLAY_STORE.md` |  |
| 075 | A | Open | P2 | CONSOLE | EU UMP consent message still active for Europe | `docs/PLAY_STORE.md` |  |
| 076 | A | Open | P2 | CONSOLE | Release builds never ship Google sample ad unit IDs | `docs/PLAY_STORE.md` |  |
| 077 | A | Open | P2 | CONSOLE | Play Games category Role Playing + icon + feature graphic still published | `docs/PLAY_STORE.md` |  |
| 078 | A | Open | P2 | CONSOLE | Saved Games remains enabled for cloud restore | `docs/PLAY_STORE.md` |  |
| 079 | A | Open | P2 | CONSOLE | OAuth consent stays Testing until ready | `docs/PLAY_STORE.md` |  |
| 080 | A | Open | P2 | CONSOLE | Data safety shared vs collected answers match code | `docs/PLAY_STORE.md` |  |
| 081 | B | ✅ Shipped | P0 | SHOP | BUY SOON looks broken on production — hide SHOP tab or use Coming later copy. | `lib/ui/shell/shop_dock.dart` | YES |
| 082 | B | ✅ Shipped | P0 | SHOP | Listing must not imply live real-money buys until Billing wired. | `docs/STORE_LISTING.md` |  |
| 083 | B | Open | P1 | SHOP | Catalog SKUs match SHOP_MONETIZATION cheap ladder ($0.99–$4.99). | `lib/core/shop_catalog.dart` |  |
| 084 | B | Open | P1 | SHOP | No gacha / BiS-for-cash / $99 packs in catalog. | `docs/SHOP_MONETIZATION.md` |  |
| 085 | B | Open | P1 | SHOP | Paid POWERUPS duration matches ad boost (same ×2 gold +25% ATK). | `lib/core/ad_boost.dart` |  |
| 086 | B | Open | P1 | SHOP | Boost stack still caps at 24h remaining. | `lib/core/ad_boost.dart` |  |
| 087 | B | Open | P1 | BILLING | Wire in_app_purchase after production (post-launch wave). | `docs/SHOP_MONETIZATION.md` |  |
| 088 | B | ✅ Shipped | P1 | BILLING | Persist adFree on metaDepth when purchased. | `lib/models/meta_depth.dart` |  |
| 089 | B | ✅ Shipped | P1 | BILLING | Persist one-time starter_boost claimed flag. | `lib/models/meta_depth.dart` |  |
| 090 | B | ✅ Shipped | P1 | BILLING | Apply bag slots from supporter_qol on purchase. | `lib/core/shop_catalog.dart` |  |
| 091 | B | Open | P1 | BILLING | Restore purchases path for ad-free / starter. | `docs/SHOP_MONETIZATION.md` |  |
| 092 | B | Open | P1 | BILLING | Play Console IAP products created for each SKU id. | `docs/SHOP_MONETIZATION.md` |  |
| 093 | B | Open | P1 | ADS | Ads never interrupt combat. | `lib/core/ad_rewarded_io.dart` |  |
| 094 | B | Open | P1 | ADS | Reward grants only after ad dismissed (not on open). | `lib/core/ad_rewarded_io.dart` |  |
| 095 | B | Open | P1 | ADS | SETTINGS AD PRIVACY withdraws UMP consent. | `lib/ui/shell/settings_overlay.dart` |  |
| 096 | B | Open | P1 | ADS | POWERUPS inactive chip must say ×2 gold + 25% ATK · 3h. | `lib/ui/hub/hub_powerups.dart` |  |
| 097 | B | ✅ Shipped | P1 | ADS | adFree hides POWERUPS ads when purchased. | `lib/ui/hub/hub_powerups.dart` |  |
| 098 | B | Open | P2 | SHOP | First-session tip does not promise live SHOP buys. | `lib/ui/first_session_tips.dart` |  |
| 099 | B | Open | P2 | SHOP | Guides distinguish GOLD vs SHOP vs hub POWERUPS. | `lib/core/game_guides.dart` |  |
| 100 | B | Open | P2 | SHOP | MenuAlerts showShop gate still AL≥1 (or hide entirely pre-billing). | `lib/core/menu_alerts.dart` |  |
| 101 | B | Open | P2 | SHOP | SKU starter_boost_6h one-time only | `docs/SHOP_MONETIZATION.md` |  |
| 102 | B | Open | P2 | SHOP | SKU boost_12h repeatable | `docs/SHOP_MONETIZATION.md` |  |
| 103 | B | Open | P2 | SHOP | SKU ad_free permanent | `docs/SHOP_MONETIZATION.md` |  |
| 104 | B | Open | P2 | SHOP | SKU day_boost_24h best $/h | `docs/SHOP_MONETIZATION.md` |  |
| 105 | B | Open | P2 | SHOP | SKU supporter_qol ceiling QoL only | `docs/SHOP_MONETIZATION.md` |  |
| 106 | B | Open | P2 | SHOP | Price tier map USD Play catalog | `docs/SHOP_MONETIZATION.md` |  |
| 107 | B | Open | P2 | SHOP | EEA billing fee awareness for net revenue | `docs/SHOP_MONETIZATION.md` |  |
| 108 | B | Open | P2 | SHOP | No whale ladder creep in v1 | `docs/SHOP_MONETIZATION.md` |  |
| 109 | B | Open | P2 | SHOP | Fairness: paid = convenience not power class | `docs/SHOP_MONETIZATION.md` |  |
| 110 | B | Open | P2 | SHOP | Sandbox purchase test account ready | `docs/SHOP_MONETIZATION.md` |  |
| 111 | B | Open | P2 | SHOP | OrderId logging without PII spam | `docs/SHOP_MONETIZATION.md` |  |
| 112 | B | Open | P2 | SHOP | Failed purchase toast English | `docs/SHOP_MONETIZATION.md` |  |
| 113 | B | Open | P2 | SHOP | Pending purchase resume after kill | `docs/SHOP_MONETIZATION.md` |  |
| 114 | B | Open | P2 | SHOP | Acknowledge purchase after grant | `docs/SHOP_MONETIZATION.md` |  |
| 115 | B | Open | P2 | SHOP | Consumable vs non-consumable mapped correctly | `docs/SHOP_MONETIZATION.md` |  |
| 116 | B | Open | P2 | SHOP | Ad-free survives Ascend | `docs/SHOP_MONETIZATION.md` |  |
| 117 | B | Open | P2 | SHOP | Boost hours survive Ascend (adBoostUntilMs) | `docs/SHOP_MONETIZATION.md` |  |
| 118 | B | Open | P2 | SHOP | Shop dock disabled state readable on 360px | `docs/SHOP_MONETIZATION.md` |  |
| 119 | B | Open | P2 | SHOP | Shop row icons owned art only | `docs/SHOP_MONETIZATION.md` |  |
| 120 | B | Open | P2 | SHOP | Privacy Data safety IAP declarations when Billing ships | `docs/SHOP_MONETIZATION.md` |  |
| 121 | C | Open | P1 | CHASE | Endgame TODAY chase must drive the primary hub CTA (not plain ENTER). | `lib/ui/hub_screen.dart` | YES |
| 122 | C | Open | P1 | CHASE | KEY detail should mention concrete loot/iLvl jump for tonight. | `lib/core/hub_chase.dart` | YES |
| 123 | C | Open | P1 | CHASE | First Gauntlet chase should mention wipe→hub and boss every 5. | `lib/core/hub_chase.dart` | YES |
| 124 | C | Open | P1 | CHASE | Rift/GR compact detail keeps dial/tier and no mid-run gear where needed. | `lib/core/hub_chase.dart` | YES |
| 125 | C | ✅ Shipped | P1 | CHASE | Ladder-done fallback must read as a fallback, not a dead end. | `lib/core/hub_chase.dart` | YES |
| 126 | C | Open | P1 | HEADER | AL 20 · MAX should tease next endgame hunt, not look like game over. | `lib/ui/hub/hub_header.dart` | YES |
| 127 | C | Open | P1 | TODAY | Reduce double READY chrome (progressLabel + chip) on claimables. | `lib/ui/hub/hub_today_card.dart` | YES |
| 128 | C | Open | P1 | TODAY | Large text scale must not obliterate TODAY title on 360px. | `lib/ui/hub/hub_today_card.dart` | YES |
| 129 | C | Open | P1 | TODAY | First-hour MetaPulse empty height must not look like a broken KEY off. | `lib/ui/hub/hub_today_card.dart` | YES |
| 130 | C | Open | P1 | HEADER | Label gold / essence / AL pills for glance readability. | `lib/ui/hub/hub_header.dart` | YES |
| 131 | C | Open | P1 | HUB | Ascend READY always shows Blessing/reset detail before tap | `lib/core/hub_chase.dart` |  |
| 132 | C | Open | P1 | HUB | Claim vault CTA opens claim path without burying season jargon | `lib/core/hub_chase.dart` |  |
| 133 | C | Open | P1 | HUB | Meet-kit backlog stays on PARTY badge at endgame | `lib/core/hub_chase.dart` |  |
| 134 | C | Open | P1 | HUB | freshPrestige rebuild-bag chase has clear gear farm CTA | `lib/core/hub_chase.dart` |  |
| 135 | C | Open | P1 | HUB | Party mean-level zone unlock chase matches PATH action | `lib/core/hub_chase.dart` |  |
| 136 | C | Open | P1 | HUB | Almost cliffs beat Daily grind in priority honestly | `lib/core/hub_chase.dart` |  |
| 137 | C | Open | P1 | HUB | Done-for-today soft rest is visible when ladder quiet | `lib/core/hub_chase.dart` |  |
| 138 | C | Open | P1 | HUB | Week goal chase uses typed route not title.contains | `lib/core/hub_chase.dart` |  |
| 139 | C | Open | P1 | HUB | Month-pass claim shows month progress somewhere on hub | `lib/core/hub_chase.dart` |  |
| 140 | C | Open | P1 | HUB | Will chase explains collection points before CODEX | `lib/core/hub_chase.dart` |  |
| 141 | C | Open | P1 | HUB | Shop upgrade chase hidden or honest while BUY SOON | `lib/core/hub_chase.dart` |  |
| 142 | C | Open | P1 | HUB | Equip BAG chase points to hero+slot when possible | `lib/core/hub_chase.dart` |  |
| 143 | C | Open | P2 | HUB | Offline Up next uses same ChaseContract words | `lib/core/hub_chase.dart` |  |
| 144 | C | Open | P2 | HUB | Welcome Back highlights ≤3 and Up next = contract | `lib/core/hub_chase.dart` |  |
| 145 | C | Open | P2 | HUB | Urgent row never fights TODAY for two most important | `lib/core/hub_chase.dart` |  |
| 146 | C | Open | P2 | HUB | Secondary ENTER tip only when truly skippable | `lib/core/hub_chase.dart` |  |
| 147 | C | Open | P2 | HUB | KEY habit waits for party Lv100 jargon gate | `lib/core/hub_chase.dart` |  |
| 148 | C | Open | P2 | HUB | Daily chase waits for showDailyChase | `lib/core/hub_chase.dart` |  |
| 149 | C | Open | P2 | HUB | Ashen ticket count + week clear honesty | `lib/core/hub_chase.dart` |  |
| 150 | C | Open | P2 | HUB | Ashen PRACTICE visible after paid clear | `lib/core/hub_chase.dart` |  |
| 151 | C | Open | P2 | HUB | World Path card readable under banners | `lib/ui/hub/hub_screen.dart` |  |
| 152 | C | Open | P2 | HUB | Offline return sheet does not crush map forever | `lib/ui/hub/hub_screen.dart` |  |
| 153 | C | Open | P2 | HUB | Manual pan wins over auto-scroll fight | `lib/ui/hub/hub_world_map.dart` |  |
| 154 | C | Open | P2 | HUB | Late zones reachable without missing markers | `lib/ui/hub/hub_world_map.dart` |  |
| 155 | C | Open | P2 | HUB | HERE vs CLEAR vs LOCKED distinct on colorblind | `lib/ui/hub/hub_world_map.dart` |  |
| 156 | C | Open | P2 | HUB | Settings affordance not exit-door ambiguous | `lib/ui/hub/hub_header.dart` |  |
| 157 | C | Open | P2 | HUB | Boss F# includes zone name when space | `lib/ui/hub/hub_header.dart` |  |
| 158 | C | Open | P2 | HUB | Touch target ≥44 when compact | `lib/ui/hub/hub_powerups.dart` |  |
| 159 | C | Open | P2 | HUB | Active timer shows gold+ATK not only ×2 | `lib/ui/hub/hub_powerups.dart` |  |
| 160 | C | Open | P2 | HUB | Title truncation prefers endgame noun | `lib/ui/hub/hub_today_card.dart` |  |
| 161 | C | Open | P2 | HUB | Detail maxLines honest for Blessing teaser | `lib/ui/hub/hub_today_card.dart` |  |
| 162 | C | Open | P2 | HUB | Claimables always outrank grind | `lib/core/chase_contract.dart` |  |
| 163 | C | Open | P2 | HUB | ALMOST zone vs Will vs Gauntlet order documented | `lib/core/chase_contract.dart` |  |
| 164 | C | Open | P2 | HUB | AL20 party-level gate copy accurate | `lib/core/ascend_roadmap.dart` |  |
| 165 | C | Open | P2 | HUB | Kit ladder teasers match unlocks | `lib/core/ascend_roadmap.dart` |  |
| 166 | C | Open | P2 | HUB | PARTY badge = bag upgrades only at endgame | `lib/core/menu_alerts.dart` |  |
| 167 | C | Open | P2 | HUB | KEY tab absent before endgameUnlocked | `lib/core/menu_alerts.dart` |  |
| 168 | C | Open | P2 | HUB | First-hour tips never mention KEY jargon | `lib/ui/first_session_tips.dart` |  |
| 169 | C | Open | P2 | HUB | DAILY RUN guide matches AL20 KEY priority | `lib/core/game_guides.dart` |  |
| 170 | C | Open | P2 | HUB | WORLD PATH guide uses party mean level | `lib/core/game_guides.dart` |  |
| 171 | C | Open | P2 | HUB | Hub chrome polish residual #21: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 172 | C | Open | P2 | HUB | Hub chrome polish residual #22: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 173 | C | Open | P2 | HUB | Hub chrome polish residual #23: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 174 | C | Open | P2 | HUB | Hub chrome polish residual #24: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 175 | C | Open | P2 | HUB | Hub chrome polish residual #25: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 176 | C | Open | P2 | HUB | Hub chrome polish residual #26: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 177 | C | Open | P2 | HUB | Hub chrome polish residual #27: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 178 | C | Open | P2 | HUB | Hub chrome polish residual #28: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 179 | C | Open | P2 | HUB | Hub chrome polish residual #29: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 180 | C | Open | P2 | HUB | Hub chrome polish residual #30: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 181 | C | Open | P2 | HUB | Hub chrome polish residual #31: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 182 | C | Open | P2 | HUB | Hub chrome polish residual #32: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 183 | C | Open | P2 | HUB | Hub chrome polish residual #33: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 184 | C | Open | P2 | HUB | Hub chrome polish residual #34: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 185 | C | Open | P2 | HUB | Hub chrome polish residual #35: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 186 | C | Open | P2 | HUB | Hub chrome polish residual #36: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 187 | C | Open | P2 | HUB | Hub chrome polish residual #37: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 188 | C | Open | P2 | HUB | Hub chrome polish residual #38: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 189 | C | Open | P2 | HUB | Hub chrome polish residual #39: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 190 | C | Open | P2 | HUB | Hub chrome polish residual #40: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 191 | C | Open | P2 | HUB | Hub chrome polish residual #41: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 192 | C | Open | P2 | HUB | Hub chrome polish residual #42: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 193 | C | Open | P2 | HUB | Hub chrome polish residual #43: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 194 | C | Open | P2 | HUB | Hub chrome polish residual #44: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 195 | C | Open | P2 | HUB | Hub chrome polish residual #45: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 196 | C | Open | P2 | HUB | Hub chrome polish residual #46: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 197 | C | Open | P2 | HUB | Hub chrome polish residual #47: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 198 | C | Open | P2 | HUB | Hub chrome polish residual #48: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 199 | C | Open | P2 | HUB | Hub chrome polish residual #49: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 200 | C | Open | P2 | HUB | Hub chrome polish residual #50: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 201 | C | Open | P2 | HUB | Hub chrome polish residual #51: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 202 | C | Open | P2 | HUB | Hub chrome polish residual #52: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 203 | C | Open | P2 | HUB | Hub chrome polish residual #53: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 204 | C | Open | P2 | HUB | Hub chrome polish residual #54: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 205 | C | Open | P2 | HUB | Hub chrome polish residual #55: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 206 | C | Open | P2 | HUB | Hub chrome polish residual #56: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 207 | C | Open | P2 | HUB | Hub chrome polish residual #57: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 208 | C | Open | P2 | HUB | Hub chrome polish residual #58: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 209 | C | Open | P2 | HUB | Hub chrome polish residual #59: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 210 | C | Open | P2 | HUB | Hub chrome polish residual #60: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 211 | C | Open | P2 | HUB | Hub chrome polish residual #61: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 212 | C | Open | P2 | HUB | Hub chrome polish residual #62: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 213 | C | Open | P2 | HUB | Hub chrome polish residual #63: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 214 | C | Open | P2 | HUB | Hub chrome polish residual #64: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 215 | C | Open | P2 | HUB | Hub chrome polish residual #65: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 216 | C | Open | P2 | HUB | Hub chrome polish residual #66: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 217 | C | Open | P2 | HUB | Hub chrome polish residual #67: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 218 | C | Open | P2 | HUB | Hub chrome polish residual #68: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 219 | C | Open | P2 | HUB | Hub chrome polish residual #69: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 220 | C | Open | P2 | HUB | Hub chrome polish residual #70: glance hierarchy on 360×780. | `lib/ui/hub_screen.dart` |  |
| 221 | D | Open | P1 | WIPE | Fewer silent wipes when sim can prove ATK/DEF/STA/bag/floor gap. | `lib/core/wipe_advice.dart` | YES |
| 222 | D | ✅ Shipped | P1 | WIPE | Track tips use POWER wording consistently (not FORGE legacy). | `lib/core/wipe_advice.dart` | YES |
| 223 | D | ✅ Shipped | P1 | WIPE | Hub CTA OPEN POWER / BAG routes match live tip lines. | `lib/core/wipe_advice.dart` | YES |
| 224 | D | Open | P1 | GODHAND | God Hand CD ring honest when CD upgrades purchased. | `lib/ui/spatial_dungeon_view.dart` | YES |
| 225 | D | Open | P1 | GODHAND | Urgent wipe nudge stronger than color-only. | `lib/ui/spatial_dungeon_view.dart` | YES |
| 226 | D | ✅ Shipped | P1 | HUD | Chamber progress dots use shape + color for colorblind. | `lib/ui/spatial_dungeon_view.dart` | YES |
| 227 | D | Open | P1 | HUD | Compact top HUD God Hand/gold stay ≥ reliable touch. | `lib/ui/shell/dungeon_top_hud.dart` | YES |
| 228 | D | Open | P1 | HUD | Party HUD flask count visible on phone. | `lib/ui/shell/dungeon_party_hud.dart` | YES |
| 229 | D | Open | P2 | DUNGEON | Zone name + floor always in compact top | `lib/ui/spatial_dungeon_view.dart` |  |
| 230 | D | Open | P2 | DUNGEON | KEY timer visible when keyed | `lib/ui/spatial_dungeon_view.dart` |  |
| 231 | D | Open | P2 | DUNGEON | Rift timer+quota readable | `lib/ui/spatial_dungeon_view.dart` |  |
| 232 | D | Open | P2 | DUNGEON | FARM/PUSH explain on chip | `lib/ui/spatial_dungeon_view.dart` |  |
| 233 | D | Open | P2 | DUNGEON | FARM/PUSH confirm mid-fight | `lib/ui/spatial_dungeon_view.dart` |  |
| 234 | D | Open | P2 | DUNGEON | Gauntlet chip not fake FARM | `lib/ui/spatial_dungeon_view.dart` |  |
| 235 | D | Open | P2 | DUNGEON | Underleveled banner CTA to POWER | `lib/ui/spatial_dungeon_view.dart` |  |
| 236 | D | Open | P2 | DUNGEON | ⋯ menu cannot floor-hop mid-fight by accident | `lib/ui/spatial_dungeon_view.dart` |  |
| 237 | D | Open | P2 | DUNGEON | Gold/min less combat-noisy | `lib/ui/spatial_dungeon_view.dart` |  |
| 238 | D | Open | P2 | DUNGEON | Target HP clarity for boss TTK | `lib/ui/spatial_dungeon_view.dart` |  |
| 239 | D | Open | P2 | DUNGEON | Walk-to-stairs affordance | `lib/ui/spatial_dungeon_view.dart` |  |
| 240 | D | Open | P2 | DUNGEON | GO stairs band visible with Minimal VFX | `lib/ui/spatial_dungeon_view.dart` |  |
| 241 | D | Open | P2 | DUNGEON | Clear toast duration readable | `lib/ui/spatial_dungeon_view.dart` |  |
| 242 | D | Open | P2 | DUNGEON | Travel heal toast | `lib/ui/spatial_dungeon_view.dart` |  |
| 243 | D | Open | P2 | DUNGEON | Floor lock messaging on disabled ±1 | `lib/ui/spatial_dungeon_view.dart` |  |
| 244 | D | Open | P2 | DUNGEON | Party HUD no surprise dim to unusable | `lib/ui/spatial_dungeon_view.dart` |  |
| 245 | D | Open | P2 | DUNGEON | Ability chips visible without hunting | `lib/ui/spatial_dungeon_view.dart` |  |
| 246 | D | Open | P2 | DUNGEON | Long-press gear confirm or delay | `lib/ui/spatial_dungeon_view.dart` |  |
| 247 | D | Open | P2 | DUNGEON | DPS meter role-aware labels | `lib/ui/spatial_dungeon_view.dart` |  |
| 248 | D | Open | P2 | DUNGEON | Pause feel when opening GEAR mid-run | `lib/ui/spatial_dungeon_view.dart` |  |
| 249 | D | Open | P2 | DUNGEON | Loading floor string not freeze | `lib/ui/spatial_dungeon_view.dart` |  |
| 250 | D | Open | P2 | DUNGEON | Torch bloom not hiding packs | `lib/ui/spatial_dungeon_view.dart` |  |
| 251 | D | Open | P2 | DUNGEON | Wipe RETRY label explains safe floor | `lib/ui/spatial_dungeon_view.dart` |  |
| 252 | D | Open | P2 | DUNGEON | CLEAN BAG timing under wipe stress | `lib/ui/spatial_dungeon_view.dart` |  |
| 253 | D | Open | P2 | DUNGEON | Gauntlet wipe shows PB | `lib/ui/spatial_dungeon_view.dart` |  |
| 254 | D | Open | P2 | DUNGEON | Rift wipe shows quota leftover | `lib/ui/spatial_dungeon_view.dart` |  |
| 255 | D | Open | P2 | DUNGEON | God Hand style BAL/FOCUS/WIDE glance | `lib/ui/spatial_dungeon_view.dart` |  |
| 256 | D | Open | P2 | DUNGEON | God Hand steer not full-map mis-tap | `lib/ui/spatial_dungeon_view.dart` |  |
| 257 | D | Open | P2 | DUNGEON | CD seconds remaining readable | `lib/ui/spatial_dungeon_view.dart` |  |
| 258 | D | Open | P2 | DUNGEON | AFK assist does not feel like cheat toast spam | `lib/ui/spatial_dungeon_view.dart` |  |
| 259 | D | Open | P2 | DUNGEON | Zone name + floor always in compact top | `lib/ui/spatial_dungeon_view.dart` |  |
| 260 | D | Open | P2 | DUNGEON | KEY timer visible when keyed | `lib/ui/spatial_dungeon_view.dart` |  |
| 261 | D | Open | P2 | DUNGEON | Rift timer+quota readable | `lib/ui/spatial_dungeon_view.dart` |  |
| 262 | D | Open | P2 | DUNGEON | FARM/PUSH explain on chip | `lib/ui/spatial_dungeon_view.dart` |  |
| 263 | D | Open | P2 | DUNGEON | FARM/PUSH confirm mid-fight | `lib/ui/spatial_dungeon_view.dart` |  |
| 264 | D | Open | P2 | DUNGEON | Gauntlet chip not fake FARM | `lib/ui/spatial_dungeon_view.dart` |  |
| 265 | D | Open | P2 | DUNGEON | Underleveled banner CTA to POWER | `lib/ui/spatial_dungeon_view.dart` |  |
| 266 | D | Open | P2 | DUNGEON | ⋯ menu cannot floor-hop mid-fight by accident | `lib/ui/spatial_dungeon_view.dart` |  |
| 267 | D | Open | P2 | DUNGEON | Gold/min less combat-noisy | `lib/ui/spatial_dungeon_view.dart` |  |
| 268 | D | Open | P2 | DUNGEON | Target HP clarity for boss TTK | `lib/ui/spatial_dungeon_view.dart` |  |
| 269 | D | Open | P2 | DUNGEON | Walk-to-stairs affordance | `lib/ui/spatial_dungeon_view.dart` |  |
| 270 | D | Open | P2 | DUNGEON | GO stairs band visible with Minimal VFX | `lib/ui/spatial_dungeon_view.dart` |  |
| 271 | D | Open | P2 | DUNGEON | Clear toast duration readable | `lib/ui/spatial_dungeon_view.dart` |  |
| 272 | D | Open | P2 | DUNGEON | Travel heal toast | `lib/ui/spatial_dungeon_view.dart` |  |
| 273 | D | Open | P2 | DUNGEON | Floor lock messaging on disabled ±1 | `lib/ui/spatial_dungeon_view.dart` |  |
| 274 | D | Open | P2 | DUNGEON | Party HUD no surprise dim to unusable | `lib/ui/spatial_dungeon_view.dart` |  |
| 275 | D | Open | P2 | DUNGEON | Ability chips visible without hunting | `lib/ui/spatial_dungeon_view.dart` |  |
| 276 | D | Open | P2 | DUNGEON | Long-press gear confirm or delay | `lib/ui/spatial_dungeon_view.dart` |  |
| 277 | D | Open | P2 | DUNGEON | DPS meter role-aware labels | `lib/ui/spatial_dungeon_view.dart` |  |
| 278 | D | Open | P2 | DUNGEON | Pause feel when opening GEAR mid-run | `lib/ui/spatial_dungeon_view.dart` |  |
| 279 | D | Open | P2 | DUNGEON | Loading floor string not freeze | `lib/ui/spatial_dungeon_view.dart` |  |
| 280 | D | Open | P2 | DUNGEON | Torch bloom not hiding packs | `lib/ui/spatial_dungeon_view.dart` |  |
| 281 | D | Open | P2 | DUNGEON | Wipe RETRY label explains safe floor | `lib/ui/spatial_dungeon_view.dart` |  |
| 282 | D | Open | P2 | DUNGEON | CLEAN BAG timing under wipe stress | `lib/ui/spatial_dungeon_view.dart` |  |
| 283 | D | Open | P2 | DUNGEON | Gauntlet wipe shows PB | `lib/ui/spatial_dungeon_view.dart` |  |
| 284 | D | Open | P2 | DUNGEON | Rift wipe shows quota leftover | `lib/ui/spatial_dungeon_view.dart` |  |
| 285 | D | Open | P2 | DUNGEON | God Hand style BAL/FOCUS/WIDE glance | `lib/ui/spatial_dungeon_view.dart` |  |
| 286 | D | Open | P2 | DUNGEON | God Hand steer not full-map mis-tap | `lib/ui/spatial_dungeon_view.dart` |  |
| 287 | D | Open | P2 | DUNGEON | CD seconds remaining readable | `lib/ui/spatial_dungeon_view.dart` |  |
| 288 | D | Open | P2 | DUNGEON | AFK assist does not feel like cheat toast spam | `lib/ui/spatial_dungeon_view.dart` |  |
| 289 | D | Open | P2 | DUNGEON | Zone name + floor always in compact top | `lib/ui/spatial_dungeon_view.dart` |  |
| 290 | D | Open | P2 | DUNGEON | KEY timer visible when keyed | `lib/ui/spatial_dungeon_view.dart` |  |
| 291 | D | Open | P2 | DUNGEON | Rift timer+quota readable | `lib/ui/spatial_dungeon_view.dart` |  |
| 292 | D | Open | P2 | DUNGEON | FARM/PUSH explain on chip | `lib/ui/spatial_dungeon_view.dart` |  |
| 293 | D | Open | P2 | DUNGEON | FARM/PUSH confirm mid-fight | `lib/ui/spatial_dungeon_view.dart` |  |
| 294 | D | Open | P2 | DUNGEON | Gauntlet chip not fake FARM | `lib/ui/spatial_dungeon_view.dart` |  |
| 295 | D | Open | P2 | DUNGEON | Underleveled banner CTA to POWER | `lib/ui/spatial_dungeon_view.dart` |  |
| 296 | D | Open | P2 | DUNGEON | ⋯ menu cannot floor-hop mid-fight by accident | `lib/ui/spatial_dungeon_view.dart` |  |
| 297 | D | Open | P2 | DUNGEON | Gold/min less combat-noisy | `lib/ui/spatial_dungeon_view.dart` |  |
| 298 | D | Open | P2 | DUNGEON | Target HP clarity for boss TTK | `lib/ui/spatial_dungeon_view.dart` |  |
| 299 | D | Open | P2 | DUNGEON | Walk-to-stairs affordance | `lib/ui/spatial_dungeon_view.dart` |  |
| 300 | D | Open | P2 | DUNGEON | GO stairs band visible with Minimal VFX | `lib/ui/spatial_dungeon_view.dart` |  |
| 301 | D | Open | P2 | DUNGEON | Clear toast duration readable | `lib/ui/spatial_dungeon_view.dart` |  |
| 302 | D | Open | P2 | DUNGEON | Travel heal toast | `lib/ui/spatial_dungeon_view.dart` |  |
| 303 | D | Open | P2 | DUNGEON | Floor lock messaging on disabled ±1 | `lib/ui/spatial_dungeon_view.dart` |  |
| 304 | D | Open | P2 | DUNGEON | Party HUD no surprise dim to unusable | `lib/ui/spatial_dungeon_view.dart` |  |
| 305 | D | Open | P2 | DUNGEON | Ability chips visible without hunting | `lib/ui/spatial_dungeon_view.dart` |  |
| 306 | D | Open | P2 | DUNGEON | Long-press gear confirm or delay | `lib/ui/spatial_dungeon_view.dart` |  |
| 307 | D | Open | P2 | DUNGEON | DPS meter role-aware labels | `lib/ui/spatial_dungeon_view.dart` |  |
| 308 | D | Open | P2 | DUNGEON | Pause feel when opening GEAR mid-run | `lib/ui/spatial_dungeon_view.dart` |  |
| 309 | D | Open | P2 | DUNGEON | Loading floor string not freeze | `lib/ui/spatial_dungeon_view.dart` |  |
| 310 | D | Open | P2 | DUNGEON | Torch bloom not hiding packs | `lib/ui/spatial_dungeon_view.dart` |  |
| 311 | D | Open | P2 | DUNGEON | Wipe RETRY label explains safe floor | `lib/ui/spatial_dungeon_view.dart` |  |
| 312 | D | Open | P2 | DUNGEON | CLEAN BAG timing under wipe stress | `lib/ui/spatial_dungeon_view.dart` |  |
| 313 | D | Open | P2 | DUNGEON | Gauntlet wipe shows PB | `lib/ui/spatial_dungeon_view.dart` |  |
| 314 | D | Open | P2 | DUNGEON | Rift wipe shows quota leftover | `lib/ui/spatial_dungeon_view.dart` |  |
| 315 | D | Open | P2 | DUNGEON | God Hand style BAL/FOCUS/WIDE glance | `lib/ui/spatial_dungeon_view.dart` |  |
| 316 | D | Open | P2 | DUNGEON | God Hand steer not full-map mis-tap | `lib/ui/spatial_dungeon_view.dart` |  |
| 317 | D | Open | P2 | DUNGEON | CD seconds remaining readable | `lib/ui/spatial_dungeon_view.dart` |  |
| 318 | D | Open | P2 | DUNGEON | AFK assist does not feel like cheat toast spam | `lib/ui/spatial_dungeon_view.dart` |  |
| 319 | D | Open | P2 | DUNGEON | Zone name + floor always in compact top | `lib/ui/spatial_dungeon_view.dart` |  |
| 320 | D | Open | P2 | DUNGEON | KEY timer visible when keyed | `lib/ui/spatial_dungeon_view.dart` |  |
| 321 | E | Open | P1 | KIT PROT | PROT: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` | YES |
| 322 | E | Open | P1 | KIT PPROT | PPROT: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` | YES |
| 323 | E | Open | P1 | KIT COM | COM: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` | YES |
| 324 | E | Open | P1 | KIT DISC | DISC: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` | YES |
| 325 | E | Open | P1 | KIT FIRE | FIRE: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` | YES |
| 326 | E | Open | P1 | KIT PROT | PROT: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 327 | E | Open | P1 | KIT ARMS | ARMS: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 328 | E | Open | P1 | KIT ARMS | ARMS: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 329 | E | Open | P1 | KIT FURY | FURY: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 330 | E | Open | P1 | KIT FURY | FURY: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 331 | E | Open | P1 | KIT PPROT | PPROT: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 332 | E | Open | P1 | KIT RET | RET: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 333 | E | Open | P1 | KIT RET | RET: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 334 | E | Open | P1 | KIT HOLY_PAL | HOLY_PAL: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 335 | E | Open | P1 | KIT HOLY_PAL | HOLY_PAL: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 336 | E | Open | P1 | KIT BM | BM: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 337 | E | Open | P1 | KIT BM | BM: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 338 | E | Open | P1 | KIT MM | MM: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 339 | E | Open | P1 | KIT MM | MM: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 340 | E | Open | P1 | KIT SV | SV: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 341 | E | Open | P1 | KIT SV | SV: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 342 | E | Open | P1 | KIT COM | COM: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 343 | E | Open | P1 | KIT ASSASS | ASSASS: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 344 | E | Open | P1 | KIT ASSASS | ASSASS: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 345 | E | Open | P1 | KIT SUB | SUB: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 346 | E | Open | P1 | KIT SUB | SUB: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 347 | E | Open | P1 | KIT HOLY_PRI | HOLY_PRI: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 348 | E | Open | P1 | KIT HOLY_PRI | HOLY_PRI: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 349 | E | Open | P1 | KIT DISC | DISC: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 350 | E | Open | P1 | KIT SHADOW | SHADOW: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 351 | E | Open | P1 | KIT SHADOW | SHADOW: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 352 | E | Open | P1 | KIT BLOOD | BLOOD: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 353 | E | Open | P1 | KIT BLOOD | BLOOD: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 354 | E | Open | P1 | KIT FROST_DK | FROST_DK: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 355 | E | Open | P1 | KIT FROST_DK | FROST_DK: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 356 | E | Open | P1 | KIT UNHOLY | UNHOLY: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 357 | E | Open | P1 | KIT UNHOLY | UNHOLY: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 358 | E | Open | P1 | KIT ELE | ELE: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 359 | E | Open | P1 | KIT ELE | ELE: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 360 | E | Open | P1 | KIT ENH | ENH: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 361 | E | Open | P1 | KIT ENH | ENH: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 362 | E | Open | P1 | KIT RSHAM | RSHAM: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 363 | E | Open | P1 | KIT RSHAM | RSHAM: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 364 | E | Open | P1 | KIT ARC | ARC: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 365 | E | Open | P1 | KIT ARC | ARC: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 366 | E | Open | P1 | KIT FIRE | FIRE: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 367 | E | Open | P1 | KIT FRMAGE | FRMAGE: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 368 | E | Open | P1 | KIT FRMAGE | FRMAGE: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 369 | E | Open | P1 | KIT AFF | AFF: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 370 | E | Open | P1 | KIT AFF | AFF: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 371 | E | Open | P1 | KIT DEMO | DEMO: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 372 | E | Open | P1 | KIT DEMO | DEMO: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 373 | E | Open | P1 | KIT DESTRO | DESTRO: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 374 | E | Open | P1 | KIT DESTRO | DESTRO: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 375 | E | Open | P1 | KIT BAL | BAL: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 376 | E | Open | P1 | KIT BAL | BAL: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 377 | E | Open | P1 | KIT FERAL | FERAL: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 378 | E | Open | P1 | KIT FERAL | FERAL: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 379 | E | Open | P1 | KIT GUARD | GUARD: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 380 | E | Open | P1 | KIT GUARD | GUARD: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 381 | E | Open | P1 | KIT RDRU | RDRU: 2-chip HUD buries identity cooldowns. | `lib/models/class_ability.dart` |  |
| 382 | E | Open | P1 | KIT RDRU | RDRU: shortLabel collision with another kit. | `lib/models/class_ability.dart` |  |
| 383 | E | Open | P2 | KIT PROT | PROT: passive/form not glanceable. | `lib/models/class_ability.dart` |  |
| 384 | E | Open | P2 | KIT PROT | PROT: resource (combo/rune/seal) invisible. | `lib/models/class_ability.dart` |  |
| 385 | E | Open | P2 | KIT PROT | PROT: builder vs spender unclear on phone. | `lib/models/class_ability.dart` |  |
| 386 | E | Open | P2 | KIT ARMS | ARMS: passive/form not glanceable. | `lib/models/class_ability.dart` |  |
| 387 | E | Open | P2 | KIT ARMS | ARMS: resource (combo/rune/seal) invisible. | `lib/models/class_ability.dart` |  |
| 388 | E | Open | P2 | KIT ARMS | ARMS: builder vs spender unclear on phone. | `lib/models/class_ability.dart` |  |
| 389 | E | Open | P2 | KIT FURY | FURY: passive/form not glanceable. | `lib/models/class_ability.dart` |  |
| 390 | E | Open | P2 | KIT FURY | FURY: resource (combo/rune/seal) invisible. | `lib/models/class_ability.dart` |  |
| 391 | E | Open | P2 | KIT FURY | FURY: builder vs spender unclear on phone. | `lib/models/class_ability.dart` |  |
| 392 | E | Open | P2 | KIT PPROT | PPROT: passive/form not glanceable. | `lib/models/class_ability.dart` |  |
| 393 | E | Open | P2 | KIT PPROT | PPROT: resource (combo/rune/seal) invisible. | `lib/models/class_ability.dart` |  |
| 394 | E | Open | P2 | KIT PPROT | PPROT: builder vs spender unclear on phone. | `lib/models/class_ability.dart` |  |
| 395 | E | Open | P2 | KIT RET | RET: passive/form not glanceable. | `lib/models/class_ability.dart` |  |
| 396 | E | Open | P2 | KIT RET | RET: resource (combo/rune/seal) invisible. | `lib/models/class_ability.dart` |  |
| 397 | E | Open | P2 | KIT RET | RET: builder vs spender unclear on phone. | `lib/models/class_ability.dart` |  |
| 398 | E | Open | P2 | KIT HOLY_PAL | HOLY_PAL: passive/form not glanceable. | `lib/models/class_ability.dart` |  |
| 399 | E | Open | P2 | KIT HOLY_PAL | HOLY_PAL: resource (combo/rune/seal) invisible. | `lib/models/class_ability.dart` |  |
| 400 | E | Open | P2 | KIT HOLY_PAL | HOLY_PAL: builder vs spender unclear on phone. | `lib/models/class_ability.dart` |  |
| 401 | E | Open | P2 | KIT BM | BM: passive/form not glanceable. | `lib/models/class_ability.dart` |  |
| 402 | E | Open | P2 | KIT BM | BM: resource (combo/rune/seal) invisible. | `lib/models/class_ability.dart` |  |
| 403 | E | Open | P2 | KIT BM | BM: builder vs spender unclear on phone. | `lib/models/class_ability.dart` |  |
| 404 | E | Open | P2 | KIT MM | MM: passive/form not glanceable. | `lib/models/class_ability.dart` |  |
| 405 | E | Open | P2 | KIT MM | MM: resource (combo/rune/seal) invisible. | `lib/models/class_ability.dart` |  |
| 406 | E | Open | P2 | KIT MM | MM: builder vs spender unclear on phone. | `lib/models/class_ability.dart` |  |
| 407 | E | Open | P2 | KIT SV | SV: passive/form not glanceable. | `lib/models/class_ability.dart` |  |
| 408 | E | Open | P2 | KIT SV | SV: resource (combo/rune/seal) invisible. | `lib/models/class_ability.dart` |  |
| 409 | E | Open | P2 | KIT SV | SV: builder vs spender unclear on phone. | `lib/models/class_ability.dart` |  |
| 410 | E | Open | P2 | KIT COM | COM: passive/form not glanceable. | `lib/models/class_ability.dart` |  |
| 411 | E | Open | P2 | KIT COM | COM: resource (combo/rune/seal) invisible. | `lib/models/class_ability.dart` |  |
| 412 | E | Open | P2 | KIT COM | COM: builder vs spender unclear on phone. | `lib/models/class_ability.dart` |  |
| 413 | E | Open | P2 | KIT ASSASS | ASSASS: passive/form not glanceable. | `lib/models/class_ability.dart` |  |
| 414 | E | Open | P2 | KIT ASSASS | ASSASS: resource (combo/rune/seal) invisible. | `lib/models/class_ability.dart` |  |
| 415 | E | Open | P2 | KIT ASSASS | ASSASS: builder vs spender unclear on phone. | `lib/models/class_ability.dart` |  |
| 416 | E | Open | P2 | KIT SUB | SUB: passive/form not glanceable. | `lib/models/class_ability.dart` |  |
| 417 | E | Open | P2 | KIT SUB | SUB: resource (combo/rune/seal) invisible. | `lib/models/class_ability.dart` |  |
| 418 | E | Open | P2 | KIT SUB | SUB: builder vs spender unclear on phone. | `lib/models/class_ability.dart` |  |
| 419 | E | Open | P2 | KIT HOLY_PRI | HOLY_PRI: passive/form not glanceable. | `lib/models/class_ability.dart` |  |
| 420 | E | Open | P2 | KIT HOLY_PRI | HOLY_PRI: resource (combo/rune/seal) invisible. | `lib/models/class_ability.dart` |  |
| 421 | F | Open | P1 | GEAR | Equipped overlay visible on undertunic body (#1). | `lib/ui/character_equip_panel.dart` |  |
| 422 | F | Open | P1 | GEAR | Helm hides/shows hair correctly (#2). | `lib/visual/` |  |
| 423 | F | Open | P1 | GEAR | Common chest changes silhouette (#3). | `lib/ui/character_equip_panel.dart` |  |
| 424 | F | Open | P1 | GEAR | Shield off-hand on Warrior/Paladin/Shaman (#4). | `lib/visual/` |  |
| 425 | F | Open | P1 | GEAR | Weapon idle/walk/attack sheets align (#5). | `lib/ui/character_equip_panel.dart` |  |
| 426 | F | Open | P1 | GEAR | Icon matches overlay set (#6). | `lib/visual/` |  |
| 427 | F | Open | P1 | GEAR | visualSetId shared looks consistent (#7). | `lib/ui/character_equip_panel.dart` |  |
| 428 | F | Open | P1 | GEAR | BiS score budget-honest only (#8). | `lib/visual/` |  |
| 429 | F | Open | P1 | GEAR | UPGRADE delta shows when comparing (#9). | `lib/ui/character_equip_panel.dart` |  |
| 430 | F | Open | P1 | GEAR | ATK/DEF/STA labels match forge language (#10). | `lib/visual/` |  |
| 431 | F | Open | P1 | GEAR | Empty slot filter hint survives scroll (#11). | `lib/ui/character_equip_panel.dart` |  |
| 432 | F | Open | P1 | GEAR | Bag CLEAN explains gold vs essence (#12). | `lib/visual/` |  |
| 433 | F | Open | P1 | GEAR | AUTO-SELL FILTERS reachable without dead Sell button (#13). | `lib/ui/character_equip_panel.dart` |  |
| 434 | F | Open | P1 | GEAR | Merge BiS risk hint (#14). | `lib/visual/` |  |
| 435 | F | Open | P1 | GEAR | Paper-doll same dest-rect 128 (#15). | `lib/ui/character_equip_panel.dart` |  |
| 436 | F | Open | P1 | GEAR | FilterQuality.none on sprites (#16). | `lib/visual/` |  |
| 437 | F | Open | P1 | GEAR | No Kenney 16px pasted on dense body (#17). | `lib/ui/character_equip_panel.dart` |  |
| 438 | F | Open | P1 | GEAR | GEAR panel phone touch targets (#18). | `lib/visual/` |  |
| 439 | F | Open | P1 | GEAR | Roster swap does not lose equip context (#19). | `lib/ui/character_equip_panel.dart` |  |
| 440 | F | Open | P1 | GEAR | Soulbound rescale on AL readable (#20). | `lib/visual/` |  |
| 441 | F | Open | P1 | GEAR | Equipped overlay visible on undertunic body (#21). | `lib/ui/character_equip_panel.dart` |  |
| 442 | F | Open | P1 | GEAR | Helm hides/shows hair correctly (#22). | `lib/visual/` |  |
| 443 | F | Open | P1 | GEAR | Common chest changes silhouette (#23). | `lib/ui/character_equip_panel.dart` |  |
| 444 | F | Open | P1 | GEAR | Shield off-hand on Warrior/Paladin/Shaman (#24). | `lib/visual/` |  |
| 445 | F | Open | P1 | GEAR | Weapon idle/walk/attack sheets align (#25). | `lib/ui/character_equip_panel.dart` |  |
| 446 | F | Open | P2 | GEAR | Icon matches overlay set (#26). | `lib/visual/` |  |
| 447 | F | Open | P2 | GEAR | visualSetId shared looks consistent (#27). | `lib/ui/character_equip_panel.dart` |  |
| 448 | F | Open | P2 | GEAR | BiS score budget-honest only (#28). | `lib/visual/` |  |
| 449 | F | Open | P2 | GEAR | UPGRADE delta shows when comparing (#29). | `lib/ui/character_equip_panel.dart` |  |
| 450 | F | Open | P2 | GEAR | ATK/DEF/STA labels match forge language (#30). | `lib/visual/` |  |
| 451 | F | Open | P2 | GEAR | Empty slot filter hint survives scroll (#31). | `lib/ui/character_equip_panel.dart` |  |
| 452 | F | Open | P2 | GEAR | Bag CLEAN explains gold vs essence (#32). | `lib/visual/` |  |
| 453 | F | Open | P2 | GEAR | AUTO-SELL FILTERS reachable without dead Sell button (#33). | `lib/ui/character_equip_panel.dart` |  |
| 454 | F | Open | P2 | GEAR | Merge BiS risk hint (#34). | `lib/visual/` |  |
| 455 | F | Open | P2 | GEAR | Paper-doll same dest-rect 128 (#35). | `lib/ui/character_equip_panel.dart` |  |
| 456 | F | Open | P2 | GEAR | FilterQuality.none on sprites (#36). | `lib/visual/` |  |
| 457 | F | Open | P2 | GEAR | No Kenney 16px pasted on dense body (#37). | `lib/ui/character_equip_panel.dart` |  |
| 458 | F | Open | P2 | GEAR | GEAR panel phone touch targets (#38). | `lib/visual/` |  |
| 459 | F | Open | P2 | GEAR | Roster swap does not lose equip context (#39). | `lib/ui/character_equip_panel.dart` |  |
| 460 | F | Open | P2 | GEAR | Soulbound rescale on AL readable (#40). | `lib/visual/` |  |
| 461 | F | Open | P2 | GEAR | Equipped overlay visible on undertunic body (#41). | `lib/ui/character_equip_panel.dart` |  |
| 462 | F | Open | P2 | GEAR | Helm hides/shows hair correctly (#42). | `lib/visual/` |  |
| 463 | F | Open | P2 | GEAR | Common chest changes silhouette (#43). | `lib/ui/character_equip_panel.dart` |  |
| 464 | F | Open | P2 | GEAR | Shield off-hand on Warrior/Paladin/Shaman (#44). | `lib/visual/` |  |
| 465 | F | Open | P2 | GEAR | Weapon idle/walk/attack sheets align (#45). | `lib/ui/character_equip_panel.dart` |  |
| 466 | F | Open | P2 | GEAR | Icon matches overlay set (#46). | `lib/visual/` |  |
| 467 | F | Open | P2 | GEAR | visualSetId shared looks consistent (#47). | `lib/ui/character_equip_panel.dart` |  |
| 468 | F | Open | P2 | GEAR | BiS score budget-honest only (#48). | `lib/visual/` |  |
| 469 | F | Open | P2 | GEAR | UPGRADE delta shows when comparing (#49). | `lib/ui/character_equip_panel.dart` |  |
| 470 | F | Open | P2 | GEAR | ATK/DEF/STA labels match forge language (#50). | `lib/visual/` |  |
| 471 | F | Open | P2 | GEAR | Empty slot filter hint survives scroll (#51). | `lib/ui/character_equip_panel.dart` |  |
| 472 | F | Open | P2 | GEAR | Bag CLEAN explains gold vs essence (#52). | `lib/visual/` |  |
| 473 | F | Open | P2 | GEAR | AUTO-SELL FILTERS reachable without dead Sell button (#53). | `lib/ui/character_equip_panel.dart` |  |
| 474 | F | Open | P2 | GEAR | Merge BiS risk hint (#54). | `lib/visual/` |  |
| 475 | F | Open | P2 | GEAR | Paper-doll same dest-rect 128 (#55). | `lib/ui/character_equip_panel.dart` |  |
| 476 | F | Open | P2 | GEAR | FilterQuality.none on sprites (#56). | `lib/visual/` |  |
| 477 | F | Open | P2 | GEAR | No Kenney 16px pasted on dense body (#57). | `lib/ui/character_equip_panel.dart` |  |
| 478 | F | Open | P2 | GEAR | GEAR panel phone touch targets (#58). | `lib/visual/` |  |
| 479 | F | Open | P2 | GEAR | Roster swap does not lose equip context (#59). | `lib/ui/character_equip_panel.dart` |  |
| 480 | F | Open | P2 | GEAR | Soulbound rescale on AL readable (#60). | `lib/visual/` |  |
| 481 | F | Open | P2 | GEAR | Equipped overlay visible on undertunic body (#61). | `lib/ui/character_equip_panel.dart` |  |
| 482 | F | Open | P2 | GEAR | Helm hides/shows hair correctly (#62). | `lib/visual/` |  |
| 483 | F | Open | P2 | GEAR | Common chest changes silhouette (#63). | `lib/ui/character_equip_panel.dart` |  |
| 484 | F | Open | P2 | GEAR | Shield off-hand on Warrior/Paladin/Shaman (#64). | `lib/visual/` |  |
| 485 | F | Open | P2 | GEAR | Weapon idle/walk/attack sheets align (#65). | `lib/ui/character_equip_panel.dart` |  |
| 486 | F | Open | P2 | GEAR | Icon matches overlay set (#66). | `lib/visual/` |  |
| 487 | F | Open | P2 | GEAR | visualSetId shared looks consistent (#67). | `lib/ui/character_equip_panel.dart` |  |
| 488 | F | Open | P2 | GEAR | BiS score budget-honest only (#68). | `lib/visual/` |  |
| 489 | F | Open | P2 | GEAR | UPGRADE delta shows when comparing (#69). | `lib/ui/character_equip_panel.dart` |  |
| 490 | F | Open | P2 | GEAR | ATK/DEF/STA labels match forge language (#70). | `lib/visual/` |  |
| 491 | G | Open | P2 | ZONE sandy | sandy: Trash archetype art still reads generic vs zone fantasy. | `lib/models/zone_art.dart` |  |
| 492 | G | Open | P2 | ZONE sandy | sandy: Elite pack signature weak on phone. | `lib/models/zone_art.dart` |  |
| 493 | G | Open | P2 | ZONE sandy | sandy: Boss silhouette vs trash uniqueness. | `lib/models/zone_art.dart` |  |
| 494 | G | Open | P2 | ZONE sandy | sandy: layoutKind / ZoneLayoutKit identity residual. | `lib/models/zone_art.dart` |  |
| 495 | G | Open | P2 | ZONE sandy | sandy: Backdrop wash distinctness vs neighbor zone. | `lib/models/zone_art.dart` |  |
| 496 | G | Open | P2 | ZONE goblin | goblin: Trash archetype art still reads generic vs zone fantasy. | `lib/models/zone_art.dart` |  |
| 497 | G | Open | P2 | ZONE goblin | goblin: Elite pack signature weak on phone. | `lib/models/zone_art.dart` |  |
| 498 | G | Open | P2 | ZONE goblin | goblin: Boss silhouette vs trash uniqueness. | `lib/models/zone_art.dart` |  |
| 499 | G | Open | P2 | ZONE goblin | goblin: layoutKind / ZoneLayoutKit identity residual. | `lib/models/zone_art.dart` |  |
| 500 | G | Open | P2 | ZONE goblin | goblin: Backdrop wash distinctness vs neighbor zone. | `lib/models/zone_art.dart` |  |
| 501 | G | Open | P2 | ZONE king | king: Trash archetype art still reads generic vs zone fantasy. | `lib/models/zone_art.dart` |  |
| 502 | G | Open | P2 | ZONE king | king: Elite pack signature weak on phone. | `lib/models/zone_art.dart` |  |
| 503 | G | Open | P2 | ZONE king | king: Boss silhouette vs trash uniqueness. | `lib/models/zone_art.dart` |  |
| 504 | G | Open | P2 | ZONE king | king: layoutKind / ZoneLayoutKit identity residual. | `lib/models/zone_art.dart` |  |
| 505 | G | Open | P2 | ZONE king | king: Backdrop wash distinctness vs neighbor zone. | `lib/models/zone_art.dart` |  |
| 506 | G | Open | P2 | ZONE underworld | underworld: Trash archetype art still reads generic vs zone fantasy. | `lib/models/zone_art.dart` |  |
| 507 | G | Open | P2 | ZONE underworld | underworld: Elite pack signature weak on phone. | `lib/models/zone_art.dart` |  |
| 508 | G | Open | P2 | ZONE underworld | underworld: Boss silhouette vs trash uniqueness. | `lib/models/zone_art.dart` |  |
| 509 | G | Open | P2 | ZONE underworld | underworld: layoutKind / ZoneLayoutKit identity residual. | `lib/models/zone_art.dart` |  |
| 510 | G | Open | P2 | ZONE underworld | underworld: Backdrop wash distinctness vs neighbor zone. | `lib/models/zone_art.dart` |  |
| 511 | G | Open | P2 | ZONE dead | dead: Trash archetype art still reads generic vs zone fantasy. | `lib/models/zone_art.dart` |  |
| 512 | G | Open | P2 | ZONE dead | dead: Elite pack signature weak on phone. | `lib/models/zone_art.dart` |  |
| 513 | G | Open | P2 | ZONE dead | dead: Boss silhouette vs trash uniqueness. | `lib/models/zone_art.dart` |  |
| 514 | G | Open | P2 | ZONE dead | dead: layoutKind / ZoneLayoutKit identity residual. | `lib/models/zone_art.dart` |  |
| 515 | G | Open | P2 | ZONE dead | dead: Backdrop wash distinctness vs neighbor zone. | `lib/models/zone_art.dart` |  |
| 516 | G | Open | P2 | ZONE hell | hell: Trash archetype art still reads generic vs zone fantasy. | `lib/models/zone_art.dart` |  |
| 517 | G | Open | P2 | ZONE hell | hell: Elite pack signature weak on phone. | `lib/models/zone_art.dart` |  |
| 518 | G | Open | P2 | ZONE hell | hell: Boss silhouette vs trash uniqueness. | `lib/models/zone_art.dart` |  |
| 519 | G | Open | P2 | ZONE hell | hell: layoutKind / ZoneLayoutKit identity residual. | `lib/models/zone_art.dart` |  |
| 520 | G | Open | P2 | ZONE hell | hell: Backdrop wash distinctness vs neighbor zone. | `lib/models/zone_art.dart` |  |
| 521 | G | Open | P2 | ZONE crystal | crystal: Trash archetype art still reads generic vs zone fantasy. | `lib/models/zone_art.dart` |  |
| 522 | G | Open | P2 | ZONE crystal | crystal: Elite pack signature weak on phone. | `lib/models/zone_art.dart` |  |
| 523 | G | Open | P2 | ZONE crystal | crystal: Boss silhouette vs trash uniqueness. | `lib/models/zone_art.dart` |  |
| 524 | G | Open | P2 | ZONE crystal | crystal: layoutKind / ZoneLayoutKit identity residual. | `lib/models/zone_art.dart` |  |
| 525 | G | Open | P2 | ZONE crystal | crystal: Backdrop wash distinctness vs neighbor zone. | `lib/models/zone_art.dart` |  |
| 526 | G | Open | P2 | ZONE tide | tide: Trash archetype art still reads generic vs zone fantasy. | `lib/models/zone_art.dart` |  |
| 527 | G | Open | P2 | ZONE tide | tide: Elite pack signature weak on phone. | `lib/models/zone_art.dart` |  |
| 528 | G | Open | P2 | ZONE tide | tide: Boss silhouette vs trash uniqueness. | `lib/models/zone_art.dart` |  |
| 529 | G | Open | P2 | ZONE tide | tide: layoutKind / ZoneLayoutKit identity residual. | `lib/models/zone_art.dart` |  |
| 530 | G | Open | P2 | ZONE tide | tide: Backdrop wash distinctness vs neighbor zone. | `lib/models/zone_art.dart` |  |
| 531 | G | Open | P2 | ZONE ember | ember: Trash archetype art still reads generic vs zone fantasy. | `lib/models/zone_art.dart` |  |
| 532 | G | Open | P2 | ZONE ember | ember: Elite pack signature weak on phone. | `lib/models/zone_art.dart` |  |
| 533 | G | Open | P2 | ZONE ember | ember: Boss silhouette vs trash uniqueness. | `lib/models/zone_art.dart` |  |
| 534 | G | Open | P2 | ZONE ember | ember: layoutKind / ZoneLayoutKit identity residual. | `lib/models/zone_art.dart` |  |
| 535 | G | Open | P2 | ZONE ember | ember: Backdrop wash distinctness vs neighbor zone. | `lib/models/zone_art.dart` |  |
| 536 | G | Open | P2 | ZONE grove | grove: Trash archetype art still reads generic vs zone fantasy. | `lib/models/zone_art.dart` |  |
| 537 | G | Open | P2 | ZONE grove | grove: Elite pack signature weak on phone. | `lib/models/zone_art.dart` |  |
| 538 | G | Open | P2 | ZONE grove | grove: Boss silhouette vs trash uniqueness. | `lib/models/zone_art.dart` |  |
| 539 | G | Open | P2 | ZONE grove | grove: layoutKind / ZoneLayoutKit identity residual. | `lib/models/zone_art.dart` |  |
| 540 | G | Open | P2 | ZONE grove | grove: Backdrop wash distinctness vs neighbor zone. | `lib/models/zone_art.dart` |  |
| 541 | H | Open | P1 | KEY | KEY sheet affixes need one-line feel cost, not name-list only. | `lib/ui/meta_overlays.dart` | YES |
| 542 | H | Open | P1 | KEY | Rifts/GR under KEY tab need distinct identity so modes do not blur. | `lib/ui/shell/power_meta_pillars.dart` | YES |
| 543 | H | Open | P1 | GAMES | Greater Rift Play Games board IDs empty months soft-fail — fix or hide empty boards. | `lib/core/play_leaderboard_ids.dart` | YES |
| 544 | H | Open | P2 | META | KEY dial AL-gated honestly (#1). | `lib/ui/meta_overlays.dart` |  |
| 545 | H | Open | P2 | META | Par timer idle-friendly explanation (#2). | `lib/ui/meta_overlays.dart` |  |
| 546 | H | Open | P2 | META | TIMED vs depleted payoff clarity (#3). | `lib/ui/meta_overlays.dart` |  |
| 547 | H | Open | P2 | META | Daily vault KEY+2 almost cliff copy (#4). | `lib/ui/meta_overlays.dart` |  |
| 548 | H | Open | P2 | META | Gauntlet boss every 5 telegraph (#5). | `lib/ui/meta_overlays.dart` |  |
| 549 | H | Open | P2 | META | Gauntlet leave→hub expected (#6). | `lib/ui/meta_overlays.dart` |  |
| 550 | H | Open | P2 | META | Rift mid-run loot vs GR no mid-run gear (#7). | `lib/ui/meta_overlays.dart` |  |
| 551 | H | Open | P2 | META | Ashen ticket return on wipe (#8). | `lib/ui/meta_overlays.dart` |  |
| 552 | H | Open | P2 | META | Ashen PRACTICE free after clear (#9). | `lib/ui/meta_overlays.dart` |  |
| 553 | H | Open | P2 | META | Local season week rows readable (#10). | `lib/ui/meta_overlays.dart` |  |
| 554 | H | Open | P2 | META | Season PB submit opt-in (#11). | `lib/ui/meta_overlays.dart` |  |
| 555 | H | Open | P2 | META | Boards month rotation process (#12). | `lib/ui/meta_overlays.dart` |  |
| 556 | H | Open | P2 | META | Will claim path (#13). | `lib/ui/meta_overlays.dart` |  |
| 557 | H | Open | P2 | META | Constellation point spend clarity (#14). | `lib/ui/meta_overlays.dart` |  |
| 558 | H | Open | P2 | META | Relics KEEP discoverability (#15). | `lib/ui/meta_overlays.dart` |  |
| 559 | H | Open | P2 | META | Pets panel fantasy (#16). | `lib/ui/meta_overlays.dart` |  |
| 560 | H | Open | P2 | META | Apex vault equip clarity (#17). | `lib/ui/meta_overlays.dart` |  |
| 561 | H | ✅ Shipped | P2 | META | Craft mats pity readable (#18). | `lib/ui/meta_overlays.dart` |  |
| 562 | H | ✅ Shipped | P2 | META | Quest board Daily/Bounty/Side (#19). | `lib/ui/meta_overlays.dart` |  |
| 563 | H | ✅ Shipped | P2 | META | Claim quests from TODAY sync (#20). | `lib/ui/meta_overlays.dart` |  |
| 564 | H | Open | P2 | META | KEY dial AL-gated honestly (#21). | `lib/ui/meta_overlays.dart` |  |
| 565 | H | Open | P2 | META | Par timer idle-friendly explanation (#22). | `lib/ui/meta_overlays.dart` |  |
| 566 | H | Open | P2 | META | TIMED vs depleted payoff clarity (#23). | `lib/ui/meta_overlays.dart` |  |
| 567 | H | Open | P2 | META | Daily vault KEY+2 almost cliff copy (#24). | `lib/ui/meta_overlays.dart` |  |
| 568 | H | Open | P2 | META | Gauntlet boss every 5 telegraph (#25). | `lib/ui/meta_overlays.dart` |  |
| 569 | H | Open | P2 | META | Gauntlet leave→hub expected (#26). | `lib/ui/meta_overlays.dart` |  |
| 570 | H | Open | P2 | META | Rift mid-run loot vs GR no mid-run gear (#27). | `lib/ui/meta_overlays.dart` |  |
| 571 | H | Open | P2 | META | Ashen ticket return on wipe (#28). | `lib/ui/meta_overlays.dart` |  |
| 572 | H | Open | P2 | META | Ashen PRACTICE free after clear (#29). | `lib/ui/meta_overlays.dart` |  |
| 573 | H | Open | P2 | META | Local season week rows readable (#30). | `lib/ui/meta_overlays.dart` |  |
| 574 | H | Open | P2 | META | Season PB submit opt-in (#31). | `lib/ui/meta_overlays.dart` |  |
| 575 | H | Open | P2 | META | Boards month rotation process (#32). | `lib/ui/meta_overlays.dart` |  |
| 576 | H | Open | P2 | META | Will claim path (#33). | `lib/ui/meta_overlays.dart` |  |
| 577 | H | Open | P2 | META | Constellation point spend clarity (#34). | `lib/ui/meta_overlays.dart` |  |
| 578 | H | Open | P2 | META | Relics KEEP discoverability (#35). | `lib/ui/meta_overlays.dart` |  |
| 579 | H | Open | P2 | META | Pets panel fantasy (#36). | `lib/ui/meta_overlays.dart` |  |
| 580 | H | Open | P2 | META | Apex vault equip clarity (#37). | `lib/ui/meta_overlays.dart` |  |
| 581 | H | Open | P2 | META | Craft mats pity readable (#38). | `lib/ui/meta_overlays.dart` |  |
| 582 | H | Open | P2 | META | Quest board Daily/Bounty/Side (#39). | `lib/ui/meta_overlays.dart` |  |
| 583 | H | Open | P2 | META | Claim quests from TODAY sync (#40). | `lib/ui/meta_overlays.dart` |  |
| 584 | H | Open | P2 | META | KEY dial AL-gated honestly (#41). | `lib/ui/meta_overlays.dart` |  |
| 585 | H | Open | P2 | META | Par timer idle-friendly explanation (#42). | `lib/ui/meta_overlays.dart` |  |
| 586 | H | Open | P2 | META | TIMED vs depleted payoff clarity (#43). | `lib/ui/meta_overlays.dart` |  |
| 587 | H | Open | P2 | META | Daily vault KEY+2 almost cliff copy (#44). | `lib/ui/meta_overlays.dart` |  |
| 588 | H | Open | P2 | META | Gauntlet boss every 5 telegraph (#45). | `lib/ui/meta_overlays.dart` |  |
| 589 | H | Open | P2 | META | Gauntlet leave→hub expected (#46). | `lib/ui/meta_overlays.dart` |  |
| 590 | H | Open | P2 | META | Rift mid-run loot vs GR no mid-run gear (#47). | `lib/ui/meta_overlays.dart` |  |
| 591 | H | Open | P2 | META | Ashen ticket return on wipe (#48). | `lib/ui/meta_overlays.dart` |  |
| 592 | H | Open | P2 | META | Ashen PRACTICE free after clear (#49). | `lib/ui/meta_overlays.dart` |  |
| 593 | H | Open | P2 | META | Local season week rows readable (#50). | `lib/ui/meta_overlays.dart` |  |
| 594 | H | Open | P2 | META | Season PB submit opt-in (#51). | `lib/ui/meta_overlays.dart` |  |
| 595 | H | Open | P2 | META | Boards month rotation process (#52). | `lib/ui/meta_overlays.dart` |  |
| 596 | H | Open | P2 | META | Will claim path (#53). | `lib/ui/meta_overlays.dart` |  |
| 597 | H | Open | P2 | META | Constellation point spend clarity (#54). | `lib/ui/meta_overlays.dart` |  |
| 598 | H | Open | P2 | META | Relics KEEP discoverability (#55). | `lib/ui/meta_overlays.dart` |  |
| 599 | H | Open | P2 | META | Pets panel fantasy (#56). | `lib/ui/meta_overlays.dart` |  |
| 600 | H | Open | P2 | META | Apex vault equip clarity (#57). | `lib/ui/meta_overlays.dart` |  |
| 601 | H | Open | P2 | META | Craft mats pity readable (#58). | `lib/ui/meta_overlays.dart` |  |
| 602 | H | Open | P2 | META | Quest board Daily/Bounty/Side (#59). | `lib/ui/meta_overlays.dart` |  |
| 603 | H | Open | P2 | META | Claim quests from TODAY sync (#60). | `lib/ui/meta_overlays.dart` |  |
| 604 | H | Open | P2 | META | KEY dial AL-gated honestly (#61). | `lib/ui/meta_overlays.dart` |  |
| 605 | H | Open | P2 | META | Par timer idle-friendly explanation (#62). | `lib/ui/meta_overlays.dart` |  |
| 606 | H | Open | P2 | META | TIMED vs depleted payoff clarity (#63). | `lib/ui/meta_overlays.dart` |  |
| 607 | H | Open | P2 | META | Daily vault KEY+2 almost cliff copy (#64). | `lib/ui/meta_overlays.dart` |  |
| 608 | H | Open | P2 | META | Gauntlet boss every 5 telegraph (#65). | `lib/ui/meta_overlays.dart` |  |
| 609 | H | Open | P2 | META | Gauntlet leave→hub expected (#66). | `lib/ui/meta_overlays.dart` |  |
| 610 | H | Open | P2 | META | Rift mid-run loot vs GR no mid-run gear (#67). | `lib/ui/meta_overlays.dart` |  |
| 611 | I | ✅ Shipped | P0 | COPY | Guides must not mention Sell junk / LOADOUTS as live buttons. | `lib/core/game_guides.dart` | YES |
| 612 | I | ✅ Shipped | P0 | COPY | Settings must not teach Sell/Scrap as primary bag verbs if buttons are gone. | `lib/ui/shell/settings_overlay.dart` | YES |
| 613 | I | ✅ Shipped | P0 | COPY | Prestige shop must not surface Loadouts as a live product line. | `lib/ui/meta/prestige_shop.dart` | YES |
| 614 | I | Open | P1 | GUIDE | WORLD PATH party mean level (#1). | `lib/core/game_guides.dart` |  |
| 615 | I | Open | P1 | GUIDE | DAILY RUN vs KEY at Lv100 (#2). | `lib/core/game_guides.dart` |  |
| 616 | I | Open | P1 | GUIDE | Ashen Crown guide topic (#3). | `lib/core/game_guides.dart` |  |
| 617 | I | Open | P1 | GUIDE | God Hand tip honest (#4). | `lib/core/game_guides.dart` |  |
| 618 | I | Open | P1 | GUIDE | POWERUPS optional ads (#5). | `lib/core/game_guides.dart` |  |
| 619 | I | Open | P1 | GUIDE | Ascend Blessing explanation (#6). | `lib/core/game_guides.dart` |  |
| 620 | I | Open | P1 | GUIDE | REBORN optional not TODAY chase (#7). | `lib/core/game_guides.dart` |  |
| 621 | I | Open | P1 | GUIDE | Endgame unlock = party Lv100 (#8). | `lib/core/game_guides.dart` |  |
| 622 | I | Open | P1 | GUIDE | First-hour plain chrome (#9). | `lib/core/game_guides.dart` |  |
| 623 | I | Open | P1 | GUIDE | What’s New matches pubspec (#10). | `lib/core/game_guides.dart` |  |
| 624 | I | Open | P1 | GUIDE | changelog_sync_test green (#11). | `lib/core/game_guides.dart` |  |
| 625 | I | Open | P1 | GUIDE | seenChangelogVersion prompt (#12). | `lib/core/game_guides.dart` |  |
| 626 | I | Open | P1 | GUIDE | No forever-free store promises (#13). | `lib/core/game_guides.dart` |  |
| 627 | I | Open | P1 | GUIDE | No false Ascend is not a wipe without prestige note (#14). | `lib/core/game_guides.dart` |  |
| 628 | I | Open | P1 | GUIDE | FirstSessionTips order (#15). | `lib/core/game_guides.dart` |  |
| 629 | I | Open | P1 | GUIDE | Discord tip after TODAY tip (#16). | `lib/core/game_guides.dart` |  |
| 630 | I | Open | P1 | GUIDE | Too weak timing (#17). | `lib/core/game_guides.dart` |  |
| 631 | I | Open | P1 | GUIDE | GUIDES early topics only first hour (#18). | `lib/core/game_guides.dart` |  |
| 632 | I | Open | P1 | GUIDE | Boss on F# hub copy (#19). | `lib/core/game_guides.dart` |  |
| 633 | I | Open | P1 | GUIDE | Leave after wipe single confirm (#20). | `lib/core/game_guides.dart` |  |
| 634 | I | Open | P2 | GUIDE | WORLD PATH party mean level (#21). | `lib/core/game_guides.dart` |  |
| 635 | I | Open | P2 | GUIDE | DAILY RUN vs KEY at Lv100 (#22). | `lib/core/game_guides.dart` |  |
| 636 | I | Open | P2 | GUIDE | Ashen Crown guide topic (#23). | `lib/core/game_guides.dart` |  |
| 637 | I | Open | P2 | GUIDE | God Hand tip honest (#24). | `lib/core/game_guides.dart` |  |
| 638 | I | Open | P2 | GUIDE | POWERUPS optional ads (#25). | `lib/core/game_guides.dart` |  |
| 639 | I | Open | P2 | GUIDE | Ascend Blessing explanation (#26). | `lib/core/game_guides.dart` |  |
| 640 | I | Open | P2 | GUIDE | REBORN optional not TODAY chase (#27). | `lib/core/game_guides.dart` |  |
| 641 | I | Open | P2 | GUIDE | Endgame unlock = party Lv100 (#28). | `lib/core/game_guides.dart` |  |
| 642 | I | Open | P2 | GUIDE | First-hour plain chrome (#29). | `lib/core/game_guides.dart` |  |
| 643 | I | Open | P2 | GUIDE | What’s New matches pubspec (#30). | `lib/core/game_guides.dart` |  |
| 644 | I | Open | P2 | GUIDE | changelog_sync_test green (#31). | `lib/core/game_guides.dart` |  |
| 645 | I | Open | P2 | GUIDE | seenChangelogVersion prompt (#32). | `lib/core/game_guides.dart` |  |
| 646 | I | Open | P2 | GUIDE | No forever-free store promises (#33). | `lib/core/game_guides.dart` |  |
| 647 | I | Open | P2 | GUIDE | No false Ascend is not a wipe without prestige note (#34). | `lib/core/game_guides.dart` |  |
| 648 | I | Open | P2 | GUIDE | FirstSessionTips order (#35). | `lib/core/game_guides.dart` |  |
| 649 | I | Open | P2 | GUIDE | Discord tip after TODAY tip (#36). | `lib/core/game_guides.dart` |  |
| 650 | I | Open | P2 | GUIDE | Too weak timing (#37). | `lib/core/game_guides.dart` |  |
| 651 | I | Open | P2 | GUIDE | GUIDES early topics only first hour (#38). | `lib/core/game_guides.dart` |  |
| 652 | I | Open | P2 | GUIDE | Boss on F# hub copy (#39). | `lib/core/game_guides.dart` |  |
| 653 | I | Open | P2 | GUIDE | Leave after wipe single confirm (#40). | `lib/core/game_guides.dart` |  |
| 654 | I | Open | P2 | GUIDE | WORLD PATH party mean level (#41). | `lib/core/game_guides.dart` |  |
| 655 | I | Open | P2 | GUIDE | DAILY RUN vs KEY at Lv100 (#42). | `lib/core/game_guides.dart` |  |
| 656 | I | Open | P2 | GUIDE | Ashen Crown guide topic (#43). | `lib/core/game_guides.dart` |  |
| 657 | I | Open | P2 | GUIDE | God Hand tip honest (#44). | `lib/core/game_guides.dart` |  |
| 658 | I | Open | P2 | GUIDE | POWERUPS optional ads (#45). | `lib/core/game_guides.dart` |  |
| 659 | I | Open | P2 | GUIDE | Ascend Blessing explanation (#46). | `lib/core/game_guides.dart` |  |
| 660 | I | Open | P2 | GUIDE | REBORN optional not TODAY chase (#47). | `lib/core/game_guides.dart` |  |
| 661 | J | ✅ Shipped | P1 | A11Y | Chamber dots: shape not only color. | `lib/ui/spatial_dungeon_view.dart` | YES |
| 662 | J | ✅ Shipped | P1 | A11Y | Colorblind setting copy: what it actually changes. | `lib/ui/shell/settings_overlay.dart` | YES |
| 663 | J | Open | P1 | A11Y | Text scale S–XL does not break TODAY/primary CTAs. | `lib/ui/hub/hub_today_card.dart` | YES |
| 664 | J | Open | P2 | A11Y | minTouch 44 on primary CTAs (#1). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 665 | J | Open | P2 | A11Y | Semantics labels on hub buttons (#2). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 666 | J | Open | P2 | A11Y | WebClickBridge labels for playtest (#3). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 667 | J | Open | P2 | A11Y | Minimal VFX = reduce motion honesty (#4). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 668 | J | Open | P2 | A11Y | Contrast on urgent chips (#5). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 669 | J | Open | P2 | A11Y | Colorblind combat floaters (#6). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 670 | J | Open | P2 | A11Y | No hover-only phone flows (#7). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 671 | J | Open | P2 | A11Y | Long-press alternatives documented (#8). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 672 | J | Open | P2 | A11Y | FittedBox not shrinking below touch (#9). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 673 | J | Open | P2 | A11Y | System text scale compose (#10). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 674 | J | Open | P2 | A11Y | Focus order in sheets (#11). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 675 | J | Open | P2 | A11Y | Announce claim toasts (#12). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 676 | J | Open | P2 | A11Y | minTouch 44 on primary CTAs (#13). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 677 | J | Open | P2 | A11Y | Semantics labels on hub buttons (#14). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 678 | J | Open | P2 | A11Y | WebClickBridge labels for playtest (#15). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 679 | J | Open | P2 | A11Y | Minimal VFX = reduce motion honesty (#16). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 680 | J | Open | P2 | A11Y | Contrast on urgent chips (#17). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 681 | J | Open | P2 | A11Y | Colorblind combat floaters (#18). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 682 | J | Open | P2 | A11Y | No hover-only phone flows (#19). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 683 | J | Open | P2 | A11Y | Long-press alternatives documented (#20). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 684 | J | Open | P2 | A11Y | FittedBox not shrinking below touch (#21). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 685 | J | Open | P2 | A11Y | System text scale compose (#22). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 686 | J | Open | P2 | A11Y | Focus order in sheets (#23). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 687 | J | Open | P2 | A11Y | Announce claim toasts (#24). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 688 | J | Open | P2 | A11Y | minTouch 44 on primary CTAs (#25). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 689 | J | Open | P2 | A11Y | Semantics labels on hub buttons (#26). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 690 | J | Open | P2 | A11Y | WebClickBridge labels for playtest (#27). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 691 | J | Open | P2 | A11Y | Minimal VFX = reduce motion honesty (#28). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 692 | J | Open | P2 | A11Y | Contrast on urgent chips (#29). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 693 | J | Open | P2 | A11Y | Colorblind combat floaters (#30). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 694 | J | Open | P2 | A11Y | No hover-only phone flows (#31). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 695 | J | Open | P2 | A11Y | Long-press alternatives documented (#32). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 696 | J | Open | P2 | A11Y | FittedBox not shrinking below touch (#33). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 697 | J | Open | P2 | A11Y | System text scale compose (#34). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 698 | J | Open | P2 | A11Y | Focus order in sheets (#35). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 699 | J | Open | P2 | A11Y | Announce claim toasts (#36). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 700 | J | Open | P2 | A11Y | minTouch 44 on primary CTAs (#37). | `.cursor/skills/accessibility-auditing/SKILL.md` |  |
| 701 | K | Open | P0 | SAVE | Cold start loads last save without wipe. | `lib/core/game_director.dart` | YES |
| 702 | K | Open | P0 | SAVE | Ascend keep/reset contract matches AGENTS.md. | `lib/core/game_logic.dart` | YES |
| 703 | K | Open | P1 | SAVE | Old saves migrate missing metaDepth fields with defaults. | `lib/models/meta_depth.dart` |  |
| 704 | K | Open | P1 | SAVE | Export/import clipboard round-trips. | `lib/core/game_director.dart` |  |
| 705 | K | Open | P1 | SAVE | Play Games cloud save soft-fails cleanly. | `lib/core/play_games_bridge.dart` |  |
| 706 | K | Open | P1 | SAVE | Play update gate blocks play when versionCode behind (Play installs). | `lib/core/play_update.dart` |  |
| 707 | K | Open | P1 | SAVE | adBoostUntilMs survives Ascend. | `lib/models/meta_depth.dart` |  |
| 708 | K | Open | P1 | SAVE | gauntletBestFloor / rift / GR PBs survive Ascend. | `lib/models/meta_depth.dart` |  |
| 709 | K | Open | P1 | SAVE | pendingHeroReveals survive until PARTY. | `lib/models/meta_depth.dart` |  |
| 710 | K | Open | P1 | SAVE | REBORN does not change AL/Blessing. | `lib/core/game_logic.dart` |  |
| 711 | K | Open | P2 | SAVE | Save/migrate residual honesty #1. | `lib/core/game_state.dart` |  |
| 712 | K | Open | P2 | SAVE | Save/migrate residual honesty #2. | `lib/core/game_state.dart` |  |
| 713 | K | Open | P2 | SAVE | Save/migrate residual honesty #3. | `lib/core/game_state.dart` |  |
| 714 | K | Open | P2 | SAVE | Save/migrate residual honesty #4. | `lib/core/game_state.dart` |  |
| 715 | K | Open | P2 | SAVE | Save/migrate residual honesty #5. | `lib/core/game_state.dart` |  |
| 716 | K | Open | P2 | SAVE | Save/migrate residual honesty #6. | `lib/core/game_state.dart` |  |
| 717 | K | Open | P2 | SAVE | Save/migrate residual honesty #7. | `lib/core/game_state.dart` |  |
| 718 | K | Open | P2 | SAVE | Save/migrate residual honesty #8. | `lib/core/game_state.dart` |  |
| 719 | K | Open | P2 | SAVE | Save/migrate residual honesty #9. | `lib/core/game_state.dart` |  |
| 720 | K | Open | P2 | SAVE | Save/migrate residual honesty #10. | `lib/core/game_state.dart` |  |
| 721 | K | Open | P2 | SAVE | Save/migrate residual honesty #11. | `lib/core/game_state.dart` |  |
| 722 | K | Open | P2 | SAVE | Save/migrate residual honesty #12. | `lib/core/game_state.dart` |  |
| 723 | K | Open | P2 | SAVE | Save/migrate residual honesty #13. | `lib/core/game_state.dart` |  |
| 724 | K | Open | P2 | SAVE | Save/migrate residual honesty #14. | `lib/core/game_state.dart` |  |
| 725 | K | Open | P2 | SAVE | Save/migrate residual honesty #15. | `lib/core/game_state.dart` |  |
| 726 | K | Open | P2 | SAVE | Save/migrate residual honesty #16. | `lib/core/game_state.dart` |  |
| 727 | K | Open | P2 | SAVE | Save/migrate residual honesty #17. | `lib/core/game_state.dart` |  |
| 728 | K | Open | P2 | SAVE | Save/migrate residual honesty #18. | `lib/core/game_state.dart` |  |
| 729 | K | Open | P2 | SAVE | Save/migrate residual honesty #19. | `lib/core/game_state.dart` |  |
| 730 | K | Open | P2 | SAVE | Save/migrate residual honesty #20. | `lib/core/game_state.dart` |  |
| 731 | K | Open | P2 | SAVE | Save/migrate residual honesty #21. | `lib/core/game_state.dart` |  |
| 732 | K | Open | P2 | SAVE | Save/migrate residual honesty #22. | `lib/core/game_state.dart` |  |
| 733 | K | Open | P2 | SAVE | Save/migrate residual honesty #23. | `lib/core/game_state.dart` |  |
| 734 | K | Open | P2 | SAVE | Save/migrate residual honesty #24. | `lib/core/game_state.dart` |  |
| 735 | K | Open | P2 | SAVE | Save/migrate residual honesty #25. | `lib/core/game_state.dart` |  |
| 736 | K | Open | P2 | SAVE | Save/migrate residual honesty #26. | `lib/core/game_state.dart` |  |
| 737 | K | Open | P2 | SAVE | Save/migrate residual honesty #27. | `lib/core/game_state.dart` |  |
| 738 | K | Open | P2 | SAVE | Save/migrate residual honesty #28. | `lib/core/game_state.dart` |  |
| 739 | K | Open | P2 | SAVE | Save/migrate residual honesty #29. | `lib/core/game_state.dart` |  |
| 740 | K | Open | P2 | SAVE | Save/migrate residual honesty #30. | `lib/core/game_state.dart` |  |
| 741 | L | Open | P1 | PERF | Keep-awake setting works in dungeon without overheating panic. | `lib/ui/shell/settings_overlay.dart` | YES |
| 742 | L | Open | P1 | OFFLINE | Dungeon AFK catch-up uses SpatialCombat afkAssist honestly. | `lib/spatial/spatial_combat.dart` | YES |
| 743 | L | Open | P1 | OFFLINE | Hub AFK is sanctuary gold only — no fake combat. | `lib/core/gold_income.dart` | YES |
| 744 | L | Open | P2 | PERF | Phone session perf/battery residual #1. | `lib/core/game_director.dart` |  |
| 745 | L | Open | P2 | PERF | Phone session perf/battery residual #2. | `lib/core/game_director.dart` |  |
| 746 | L | Open | P2 | PERF | Phone session perf/battery residual #3. | `lib/core/game_director.dart` |  |
| 747 | L | Open | P2 | PERF | Phone session perf/battery residual #4. | `lib/core/game_director.dart` |  |
| 748 | L | Open | P2 | PERF | Phone session perf/battery residual #5. | `lib/core/game_director.dart` |  |
| 749 | L | Open | P2 | PERF | Phone session perf/battery residual #6. | `lib/core/game_director.dart` |  |
| 750 | L | Open | P2 | PERF | Phone session perf/battery residual #7. | `lib/core/game_director.dart` |  |
| 751 | L | Open | P2 | PERF | Phone session perf/battery residual #8. | `lib/core/game_director.dart` |  |
| 752 | L | Open | P2 | PERF | Phone session perf/battery residual #9. | `lib/core/game_director.dart` |  |
| 753 | L | Open | P2 | PERF | Phone session perf/battery residual #10. | `lib/core/game_director.dart` |  |
| 754 | L | Open | P2 | PERF | Phone session perf/battery residual #11. | `lib/core/game_director.dart` |  |
| 755 | L | Open | P2 | PERF | Phone session perf/battery residual #12. | `lib/core/game_director.dart` |  |
| 756 | L | Open | P2 | PERF | Phone session perf/battery residual #13. | `lib/core/game_director.dart` |  |
| 757 | L | Open | P2 | PERF | Phone session perf/battery residual #14. | `lib/core/game_director.dart` |  |
| 758 | L | Open | P2 | PERF | Phone session perf/battery residual #15. | `lib/core/game_director.dart` |  |
| 759 | L | Open | P2 | PERF | Phone session perf/battery residual #16. | `lib/core/game_director.dart` |  |
| 760 | L | Open | P2 | PERF | Phone session perf/battery residual #17. | `lib/core/game_director.dart` |  |
| 761 | L | Open | P2 | PERF | Phone session perf/battery residual #18. | `lib/core/game_director.dart` |  |
| 762 | L | Open | P2 | PERF | Phone session perf/battery residual #19. | `lib/core/game_director.dart` |  |
| 763 | L | Open | P2 | PERF | Phone session perf/battery residual #20. | `lib/core/game_director.dart` |  |
| 764 | L | Open | P2 | PERF | Phone session perf/battery residual #21. | `lib/core/game_director.dart` |  |
| 765 | L | Open | P2 | PERF | Phone session perf/battery residual #22. | `lib/core/game_director.dart` |  |
| 766 | L | Open | P2 | PERF | Phone session perf/battery residual #23. | `lib/core/game_director.dart` |  |
| 767 | L | Open | P2 | PERF | Phone session perf/battery residual #24. | `lib/core/game_director.dart` |  |
| 768 | L | Open | P2 | PERF | Phone session perf/battery residual #25. | `lib/core/game_director.dart` |  |
| 769 | L | Open | P2 | PERF | Phone session perf/battery residual #26. | `lib/core/game_director.dart` |  |
| 770 | L | Open | P2 | PERF | Phone session perf/battery residual #27. | `lib/core/game_director.dart` |  |
| 771 | M | ~ Light | P1 | KIT AFF | [FEEL 171] Soul Siphon dold. | `lib/models/class_ability.dart` |  |
| 772 | M | ~ Light | P1 | KIT ARC | [FEEL 169] Arcane Brilliance dold. | `lib/models/class_ability.dart` |  |
| 773 | M | ~ Light | P1 | KIT ARMS | [FEEL 150] Execute-gate syns inte på chip förrän gated/ready. | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 774 | M | ~ Light | P1 | KIT ASSASS | [FEEL 159] Improved Poisons dold — varför gift saknas i HUD. | `lib/models/class_ability.dart` |  |
| 775 | M | ~ Light | P1 | KIT BAL | [FEEL 174] Wrath-chip kolliderar med BM Bestial Wrath-etikett. | `lib/models/class_ability.dart` |  |
| 776 | M | ~ Light | P1 | KIT BM | [FEEL 156] Kill Command KC utan pet-status i HUD. | `lib/models/class_ability.dart` |  |
| 777 | M | ~ Light | P1 | KIT COM | [FEEL 149] Sinister Strike dold — combo-builder saknas i HUD. | `lib/models/class_ability.dart` |  |
| 778 | M | ~ Light | P1 | KIT DEMO | [FEEL 172] Demon Charge "Charge" kolliderar med Prot Charge. | `lib/models/class_ability.dart` |  |
| 779 | M | ~ Light | P1 | KIT DESTRO | [FEEL 173] Shadowfury "Fury" kolliderar med Fury Warrior. | `lib/models/class_ability.dart` |  |
| 780 | M | ~ Light | P1 | KIT DISC | [FEEL 147] PS/PI-chips kräver WoW-kunskap; tooltip är hover-vänlig, inte telefon. | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 781 | M | ~ Light | P1 | KIT ELE | [FEEL 166] Elemental Focus dold — proc-fantasi osynlig. | `lib/models/class_ability.dart` |  |
| 782 | M | ~ Light | P1 | KIT ENH | [FEEL 167] Enhanced Weapons dold — dual-wield fantasi saknas. | `lib/models/class_ability.dart` |  |
| 783 | M | ~ Light | P1 | KIT FERAL | [FEEL 175] Cat Form dold — cat DPS ser human i chip-lager. | `lib/models/class_ability.dart` |  |
| 784 | M | ~ Light | P1 | KIT FIRE | [FEEL 148] Fireball shortLabel tar mer chip-yta än Pyro/Bomb. | `lib/models/class_ability.dart` |  |
| 785 | M | ~ Light | P1 | KIT FRMAGE | [FEEL 170] Frost Armor dold. | `lib/models/class_ability.dart` |  |
| 786 | M | ~ Light | P1 | KIT FROST_DK | [FEEL 164] IBF delas med Blood/Unholy — defensiv chip generisk. | `lib/models/class_ability.dart` |  |
| 787 | M | ~ Light | P1 | KIT FURY | [FEEL 151] EReg/Reck båda Lv12 — telefon-HUD visar bara två. | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 788 | M | ~ Light | P1 | KIT GUARD | [FEEL 176] FR/Lac/SI/Bark trängs; Swipe delas med Feral. | `lib/models/class_ability.dart` |  |
| 789 | M | ~ Light | P1 | KIT HOLY_PAL | [FEEL 152] Beacon syns utan vem som är beacon. | `lib/models/class_ability.dart` |  |
| 790 | M | ~ Light | P1 | KIT HOLY_PRI | [FEEL 161] Spirit of Redemption dold. | `lib/models/class_ability.dart` |  |
| 791 | M | ~ Light | P1 | KIT HUD | [FEEL 178] Kit stängs vid andra tryck på samma hjälte mid-boss. | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 792 | M | ~ Light | P1 | KIT MM | [FEEL 157] Steady/Aimed/Chim ser ut som tre shots utan fokus-gate. | `lib/models/class_ability.dart` |  |
| 793 | M | ~ Light | P1 | KIT PPROT | [FEEL 153] shortLabel PPROT nästan oläsligt vs PROT. | `lib/models/hero_spec.dart` |  |
| 794 | M | ~ Light | P1 | KIT PPROT | [FEEL 154] Hand of Reckoning HoR förväxlas med Hammer of the Righteous. | `lib/models/class_ability.dart` |  |
| 795 | M | ~ Light | P1 | KIT PROT | [FEEL 145] Shield Wall/Last Stand konkurrerar bort Charge/Taunt på 2-chip HUD. | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 796 | M | ~ Light | P1 | KIT PROT | [FEEL 146] Stance passiv syns inte — tank-fantasi startar utan "jag är tank". | `lib/models/class_ability.dart` |  |
| 797 | M | ~ Light | P1 | KIT RDRU | [FEEL 177] WG/NS/Tranq/Bloom kräver guide; Nourish tar plats. | `lib/models/class_ability.dart` |  |
| 798 | M | ~ Light | P1 | KIT RET | [FEEL 155] Seal of Command dold — ret-fantasi saknar synlig seal. | `lib/models/class_ability.dart` |  |
| 799 | M | ~ Light | P1 | KIT RSHAM | [FEEL 168] Ancestral Awakening dold. | `lib/models/class_ability.dart` |  |
| 800 | M | ~ Light | P1 | KIT SHADOW | [FEEL 162] Shadowform dold — shadow-fantasi saknar form-chip. | `lib/models/class_ability.dart` |  |
| 801 | M | ~ Light | P1 | KIT SUB | [FEEL 160] MoS passiv dold — subtlety-fantasi bara i namnet. | `lib/models/class_ability.dart` |  |
| 802 | M | ~ Light | P1 | KIT SV | [FEEL 158] Trap Mastery dold — trap-kärna syns sent. | `lib/models/class_ability.dart` |  |
| 803 | M | ~ Light | P1 | ZONE all | [FEEL 209] Cyclops/bat/cultist/spider/golem återanvänds så hårt att wash gör jobbet ensam. | `lib/models/zone_art.dart` |  |
| 804 | M | ~ Light | P1 | ZONE all | [FEEL 210] Landmark barrel/crate/torch signerar sällan. | `lib/models/zone_art.dart` |  |
| 805 | M | ~ Light | P2 | BAG | [FEEL 332] AUTO EQUIP och EQUIP N tävlar visuellt. | `lib/ui/shell/inventory_dock.dart` |  |
| 806 | M | ~ Light | P2 | BAG | [FEEL 333] Hint tap EQUIP N vs knappen AUTO EQUIP när count 0. | `lib/ui/shell/inventory_dock.dart` |  |
| 807 | M | ~ Light | P2 | BAG | [FEEL 334] AUTO MERGE lovar skippa upgrades utan lista vilka. | `lib/ui/shell/inventory_dock.dart` |  |
| 808 | M | ~ Light | P2 | BAG | [FEEL 335] Slotfilter via tom GEAR-ruta syns inte som chip i BAG. | `lib/ui/shell/inventory_dock.dart` |  |
| 809 | M | ~ Light | P2 | BAG | [FEEL 336] Statusrad blandar bättre items med generisk bagStatusLine. | `lib/ui/shell/inventory_dock.dart` |  |
| 810 | M | ~ Light | P2 | BAG | [FEEL 337] MERGE-kostnad syns men inte rarity/ilvl-utbyte. | `lib/ui/shell/inventory_dock.dart` |  |
| 811 | M | ~ Light | P2 | BAG | [FEEL 338] MERGE-tab syns sent via progressive menu. | `lib/ui/shell/inventory_dock.dart` |  |
| 812 | M | ~ Light | P2 | CHAMBER | [FEEL 319] Prickar inte tryckbara — ingen chamber-översikt. | `lib/ui/spatial_dungeon_view.dart` |  |
| 813 | M | ~ Light | P2 | CHAMBER | [FEEL 320] Många chambers tränger God Hand i compact top. | `lib/ui/shell/dungeon_top_hud.dart` |  |
| 814 | M | ~ Light | P2 | CHAMBER | [FEEL 321] Active vs uncleared prickar svåra för färgblind utan formskillnad. | `lib/ui/spatial_dungeon_view.dart` |  |
| 815 | M | ~ Light | P2 | CHASE | [FEEL 260] ChaseContract readyActionLabel listar endgame-CTA:er som sällan blir primary. | `lib/core/chase_contract.dart` |  |
| 816 | M | ~ Light | P2 | CHASE | [FEEL 261] Up next ready: … upprepar urgency medan hub visar chip READY. | `lib/core/chase_contract.dart` |  |
| 817 | M | ~ Light | P2 | CHASE | [FEEL 262] marketUpgrade räknas inte claimable men beter sig som urgent ALMOST. | `lib/core/chase_contract.dart` |  |
| 818 | M | ~ Light | P2 | CHASE | [FEEL 263] progressLabel Ready bredvid chip READY är dubbel chrome. | `lib/core/hub_chase.dart` |  |
| 819 | M | ~ Light | P2 | CHASE | [FEEL 264] Chase-texter blandar ASCII-streck och tankstreck. | `lib/core/hub_chase.dart` |  |
| 820 | M | ~ Light | P2 | CHASE | [FEEL 265] KEY-detail nämner iLvl utan exempel på loot-hopp. | `lib/core/hub_chase.dart` |  |
| 821 | M | ~ Light | P2 | CHASE | [FEEL 266] Första Gauntlet-jakten utan wipe→hub eller boss-var-5. | `lib/core/hub_chase.dart` |  |
| 822 | M | ~ Light | P2 | CHASE | [FEEL 267] Rift-detail listar kills/timer utan dial/tier bredvid CTA. | `lib/core/hub_chase.dart` |  |
| 823 | M | ~ Light | P2 | CHASE | [FEEL 268] No mid-run gear i GR-detail lätt missad i 1-raders compact. | `lib/core/hub_chase.dart` |  |
| 824 | M | ~ Light | P2 | CHASE | [FEEL 269] När ladder tar slut jagar TODAY time KEY utan att säga fallback. | `lib/core/hub_chase.dart` |  |
| 825 | M | ~ Light | P2 | CLEAR | [FEEL 322] Boss-banner kan överlappa offline/clear-summary. | `lib/ui/spatial_dungeon_view.dart` |  |
| 826 | M | ~ Light | P2 | CLEAR | [FEEL 323] Gate closed/open saknar HUD-text chamber locked. | `lib/ui/spatial_dungeon_view.dart` |  |
| 827 | M | ~ Light | P2 | CLEAR | [FEEL 324] Loot vacuumas utan picked-up-lista — bara gold-chip. | `lib/ui/shell/dungeon_top_hud.dart` |  |
| 828 | M | ~ Light | P2 | DPS | [FEEL 325] Metern försvinner när peak=0 tidigt — tomt hörn sedan plötslig chip. | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 829 | M | ~ Light | P2 | DPS | [FEEL 326] Öppen meter täcker karta utan dimma. | `lib/ui/is2_shell.dart` |  |
| 830 | M | ~ Light | P2 | DPS | [FEEL 327] Spec-taggar kapas till 4 tecken (COMBAT→COM). | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 831 | M | ~ Light | P2 | DUNGEON | [FEEL 299] Essence-chip saknas i compact-läge under KEY/Gauntlet. | `lib/ui/shell/dungeon_top_hud.dart` |  |
| 832 | M | ~ Light | P2 | DUNGEON | [FEEL 300] FittedBox krymper God Hand och guld tills svåra att träffa. | `lib/ui/shell/dungeon_top_hud.dart` |  |
| 833 | M | ~ Light | P2 | FARM/PUSH | [FEEL 301] Selected-state bara färg — ingen ikon loop vs climb. | `lib/ui/spatial_dungeon_view.dart` |  |
| 834 | M | ~ Light | P2 | FARM/PUSH | [FEEL 302] Efter boss-clear i PUSH till hub utan tydlig zon-klar-känsla i stage. | `lib/core/game_logic.dart` |  |
| 835 | M | ~ Light | P2 | FLOOR | [FEEL 316] Wide F± vs compact ⋯ — samma action, olika språk. | `lib/ui/shell/dungeon_top_hud.dart` |  |
| 836 | M | ~ Light | P2 | FLOOR | [FEEL 317] Gauntlet blockerar travel tyst — spelare söker menyn efter FARM-vana. | `lib/core/game_logic.dart` |  |
| 837 | M | ~ Light | P2 | FLOOR | [FEEL 318] Hoppa våning mid-chamber kastar progress utan varning. | `lib/ui/shell/dungeon_top_hud.dart` |  |
| 838 | M | ~ Light | P2 | FORGE | [FEEL 350] STA-köp visar +HP medan Blessing/CAMP säger STA. | `lib/ui/shell/forge_overlay.dart` |  |
| 839 | M | ~ Light | P2 | FORGE | [FEEL 351] ChoiceChip 1×/10×/ALL Material-default mitt i Kenney-meny. | `lib/ui/shell/forge_overlay.dart` |  |
| 840 | M | ~ Light | P2 | FORGE | [FEEL 352] Ascend-status claim on Hub i GOLD — knappen finns inte här. | `lib/ui/shell/forge_overlay.dart` |  |
| 841 | M | ~ Light | P2 | FORGE | [FEEL 353] Constellation LIGHT name (stat · N p) läses som kod. | `lib/ui/shell/forge_overlay.dart` |  |
| 842 | M | ~ Light | P2 | FORGE | [FEEL 354] God Hand BAL/FOCUS/WIDE utan radius/dmg-siffror på knappar. | `lib/ui/shell/forge_overlay.dart` |  |
| 843 | M | ~ Light | P2 | FORGE | [FEEL 355] Last floor Ns tippar sporadiskt — oregelbunden coaching. | `lib/ui/shell/forge_overlay.dart` |  |
| 844 | M | ~ Light | P2 | FORGE | [FEEL 356] HASTE/CRIT soft-cap nämns inte på knappen. | `lib/ui/shell/forge_overlay.dart` |  |
| 845 | M | ~ Light | P2 | FORGE | [FEEL 357] KEEP God Hand mastery CLAIM utan sektion milestones. | `lib/ui/shell/forge_overlay.dart` |  |
| 846 | M | ~ Light | P2 | GEAR | [FEEL 339] Två RING-slots samma etikett. | `lib/ui/character_equip_panel.dart` |  |
| 847 | M | ~ Light | P2 | GEAR | [FEEL 340] Två CHARM-slots samma etikett. | `lib/ui/character_equip_panel.dart` |  |
| 848 | M | ~ Light | P2 | GEAR | [FEEL 341] OFFHAND kan bli SHIELD/TOME/OFFHAND utan sköld-krav-förklaring. | `lib/ui/character_equip_panel.dart` |  |
| 849 | M | ~ Light | P2 | GEAR | [FEEL 342] Hjälterad roleLabel·nivå utan kitnamn PROT/FIRE. | `lib/ui/character_equip_panel.dart` |  |
| 850 | M | ~ Light | P2 | GEAR | [FEEL 343] iLvl under dockan är snitt — stark vapen + svaga boots ser medel. | `lib/ui/character_equip_panel.dart` |  |
| 851 | M | ~ Light | P2 | GEAR | [FEEL 344] FLASK-slot ser ut som gear utan dungeon-hint. | `lib/ui/character_equip_panel.dart` |  |
| 852 | M | ~ Light | P2 | GOD HAND | [FEEL 303] CD-ringen normaliserar mot 1.1s och ljuger när CD uppgraderad. | `lib/ui/spatial_dungeon_view.dart` |  |
| 853 | M | ~ Light | P2 | GOD HAND | [FEEL 304] Spacebar-God Hand finns för web — telefon utan quick smash-hint. | `lib/ui/is2_shell.dart` |  |
| 854 | M | ~ Light | P2 | GOD HAND | [FEEL 305] Fist-ikon 14px i 28px ring — lätt dekor, inte action. | `lib/ui/spatial_dungeon_view.dart` |  |
| 855 | M | ~ Light | P2 | HEADER | [FEEL 274] IDLE PARTY-titeln pulserar och konkurrerar med TODAY. | `lib/ui/hub/hub_header.dart` |  |
| 856 | M | ~ Light | P2 | HEADER | [FEEL 275] Guld/essence/AL-pills saknar labels. | `lib/ui/hub/hub_header.dart` |  |
| 857 | M | ~ Light | P2 | HEADER | [FEEL 276] AL 20 · MAX säger Ascend klar men inte nästa endgame-jakt. | `lib/ui/hub/hub_header.dart` |  |
| 858 | M | ~ Light | P2 | HEADER | [FEEL 277] Hub Xg/min syns alltid men irrelevant vid KEY/Gauntlet-TODAY. | `lib/ui/hub/hub_header.dart` |  |
| 859 | M | ~ Light | P2 | HEADER | [FEEL 278] Lång multiplikatorrad trunceras och gömmer Ad-delen. | `lib/ui/hub/hub_header.dart` |  |
| 860 | M | ~ Light | P2 | HEADER | [FEEL 279] När displayTitle finns döljs collectionScore. | `lib/ui/hub/hub_header.dart` |  |
| 861 | M | ~ Light | P2 | HEADER | [FEEL 280] Zone trophies döljs på phone-width. | `lib/ui/hub/hub_header.dart` |  |
| 862 | M | ~ Light | P2 | HEADER | [FEEL 281] Offline-rad säger TAP men headline kan redan vara wow-resultat. | `lib/ui/hub/hub_header.dart` |  |
| 863 | M | ~ Light | P2 | HEADER | [FEEL 282] Play-update-banner tar två knapprader för valfri nudge. | `lib/ui/hub/hub_header.dart` |  |
| 864 | M | ~ Light | P2 | HUB | [FEEL 289] HubMetaPulse tom höjd även i first hour — död luft. | `lib/ui/hub/hub_today_card.dart` |  |
| 865 | M | ~ Light | P2 | HUB | [FEEL 290] KEY off i MetaPulse låter som bugg. | `lib/ui/hub/hub_today_card.dart` |  |
| 866 | M | ~ Light | P2 | HUB | [FEEL 291] CLAIM (2) säger inte QUESTS. | `lib/ui/hub/hub_today_card.dart` |  |
| 867 | M | ~ Light | P2 | HUB | [FEEL 292] DAILY · done disabled tar radplats efter claim. | `lib/ui/hub/hub_today_card.dart` |  |
| 868 | M | ~ Light | P2 | HUB | [FEEL 293] Urgent Ascend-label +Xe utan Blessing-rad — splittrad payoff. | `lib/ui/hub_screen.dart` |  |
| 869 | M | ~ Light | P2 | HUB | [FEEL 294] När Daily foldas till DAILY RUN försvinner TODAY-radens egen knapp. | `lib/ui/hub_screen.dart` |  |
| 870 | M | ~ Light | P2 | HUB | [FEEL 295] KEY-chase zoneId = recommended, inte den zon du tittar på. | `lib/core/hub_chase.dart` |  |
| 871 | M | ~ Light | P2 | HUB | [FEEL 296] Utan user pick syncas selected till recommended och flyttar HERE. | `lib/ui/hub_screen.dart` |  |
| 872 | M | ~ Light | P2 | HUB | [FEEL 297] Toast vid Alignment(0,-0.72) kan täcka guld-pills efter claim. | `lib/ui/hub_screen.dart` |  |
| 873 | M | ~ Light | P2 | HUB | [FEEL 298] Auto Whats New blockerar World Path innan TODAY syns. | `lib/ui/hub_screen.dart` |  |
| 874 | M | ~ Light | P2 | KEY | [FEEL 361] Affix-sträng namnlista utan ikon/risknivå. | `lib/ui/meta_overlays.dart` |  |
| 875 | M | ~ Light | P2 | KEY | [FEEL 362] DAILY VAULT blandar season/clears/timed KEY som rapport. | `lib/ui/meta_overlays.dart` |  |
| 876 | M | ~ Light | P2 | KEY | [FEEL 363] Rifts/GR under samma KEY-flik konkurrerar utan en jakt. | `lib/ui/shell/power_meta_pillars.dart` |  |
| 877 | M | ~ Light | P2 | KEY | [FEEL 364] Week goal bits blandas in i KEYSTONE header — dial drunknar. | `lib/ui/meta_overlays.dart` |  |
| 878 | M | ~ Light | P2 | KIT | [FEEL 450] Flera shortLabels Stance/Pres/Form/Aura — kits utbytbara. | `lib/models/class_ability.dart` |  |
| 879 | M | ~ Light | P2 | KIT | [FEEL 451] Unlock hints syns i data men sällan som fantasy i Meet-flow. | `lib/models/hero_spec.dart` |  |
| 880 | M | ~ Light | P2 | KIT AFF | [FEEL 431] UA/Corr/Agony/Seed DoT-alfabet — Haunt Burst säger inte DoT-pop. | `lib/models/class_ability.dart` |  |
| 881 | M | ~ Light | P2 | KIT AFF | [FEEL 432] Burn = Soulburn läses som destruction burn. | `lib/models/class_ability.dart` |  |
| 882 | M | ~ Light | P2 | KIT ARC | [FEEL 426] PoM = Presence of Mind vs Disc Prayer of Mending. | `lib/models/class_ability.dart` |  |
| 883 | M | ~ Light | P2 | KIT ARC | [FEEL 427] AP-chip läses som Attack Power, inte Arcane Power. | `lib/models/class_ability.dart` |  |
| 884 | M | ~ Light | P2 | KIT ARMS | [FEEL 386] Storm-chip = Bladestorm kolliderar med Ret/Ele/Enh Storm. | `lib/models/class_ability.dart` |  |
| 885 | M | ~ Light | P2 | KIT ARMS | [FEEL 387] Overpower short Over säger inget om free proc. | `lib/models/class_ability.dart` |  |
| 886 | M | ~ Light | P2 | KIT ARMS | [FEEL 388] Rallying Cry Rally utan temporary HP-hint. | `lib/models/class_ability.dart` |  |
| 887 | M | ~ Light | P2 | KIT ASSASS | [FEEL 405] Mut/Env/Gar/Rupt täta akronymer — poison syns inte. | `lib/models/class_ability.dart` |  |
| 888 | M | ~ Light | P2 | KIT ASSASS | [FEEL 406] FoK delas med Subtlety — AoE skiljer inte kits. | `lib/models/class_ability.dart` |  |
| 889 | M | ~ Light | P2 | KIT BAL | [FEEL 438] Moonkin Form Form dold — owl-fantasi saknas. | `lib/models/class_ability.dart` |  |
| 890 | M | ~ Light | P2 | KIT BAL | [FEEL 439] Fall/Hurri/Typh avhuggna — Starfall tappas. | `lib/models/class_ability.dart` |  |
| 891 | M | ~ Light | P2 | KIT BLOOD | [FEEL 413] Alla DK Presence heter Pres — skiljs inte. | `lib/models/class_ability.dart` |  |
| 892 | M | ~ Light | P2 | KIT BLOOD | [FEEL 414] Dark Command DC ser ut som disconnect. | `lib/models/class_ability.dart` |  |
| 893 | M | ~ Light | P2 | KIT BLOOD | [FEEL 415] Bone Shield Bones läses som prop, inte absorb. | `lib/models/class_ability.dart` |  |
| 894 | M | ~ Light | P2 | KIT BM | [FEEL 399] Aspect Hawk dold — hunter stance saknas. | `lib/models/class_ability.dart` |  |
| 895 | M | ~ Light | P2 | KIT BM | [FEEL 400] Wrath-chip = Bestial Wrath vs Balance Wrath. | `lib/models/class_ability.dart` |  |
| 896 | M | ~ Light | P2 | KIT COM | [FEEL 384] SnD syns men combo-poäng syns inte bredvid. | `lib/models/class_ability.dart` |  |
| 897 | M | ~ Light | P2 | KIT COM | [FEEL 385] Blade Flurry Flurry generiskt vs Fury-fantasi. | `lib/models/class_ability.dart` |  |
| 898 | M | ~ Light | P2 | KIT DEMO | [FEEL 433] HoG/Meta/Sac/Know hård WotLK-kod; Demonic Knowledge dold. | `lib/models/class_ability.dart` |  |
| 899 | M | ~ Light | P2 | KIT DEMO | [FEEL 434] Chaos Bolt delas med Destruction. | `lib/models/class_ability.dart` |  |
| 900 | M | ~ Light | P2 | KIT DEMO | [FEEL 435] Demonic Sacrifice Sac känns permanent loss. | `lib/models/class_ability.dart` |  |
| 901 | M | ~ Light | P2 | KIT DESTRO | [FEEL 436] Cata passiv dold; Conf/Draft/RoF/Immo kräver guide. | `lib/models/class_ability.dart` |  |
| 902 | M | ~ Light | P2 | KIT DESTRO | [FEEL 437] Ward-chip säger inte absorb/magic-shield. | `lib/models/class_ability.dart` |  |
| 903 | M | ~ Light | P2 | KIT DISC | [FEEL 379] Shield-chip förväxlas med warrior Shield Block. | `lib/models/class_ability.dart` |  |
| 904 | M | ~ Light | P2 | KIT DISC | [FEEL 380] PoM vs Arcane PoM delar förkortning. | `lib/models/class_ability.dart` |  |
| 905 | M | ~ Light | P2 | KIT ELE | [FEEL 419] Storm = Thunderstorm kolliderar med melee Storm-chips. | `lib/models/class_ability.dart` |  |
| 906 | M | ~ Light | P2 | KIT ELE | [FEEL 420] Shock = Earth Shock vs Holy Shock. | `lib/models/class_ability.dart` |  |
| 907 | M | ~ Light | P2 | KIT ENH | [FEEL 421] Stormstrike Storm värst av Storm-kollisionerna. | `lib/models/class_ability.dart` |  |
| 908 | M | ~ Light | P2 | KIT ENH | [FEEL 422] SRage/FShock ser ut som typos. | `lib/models/class_ability.dart` |  |
| 909 | M | ~ Light | P2 | KIT FERAL | [FEEL 440] TF/SI akronymer; Rip vs Riptide. | `lib/models/class_ability.dart` |  |
| 910 | M | ~ Light | P2 | KIT FERAL | [FEEL 441] Bite/Shred/Rake utan combo-punkt i HUD. | `lib/models/class_ability.dart` |  |
| 911 | M | ~ Light | P2 | KIT FIRE | [FEEL 381] Frost Nova/Ice Block på Fire-kit utan utility-HUD-kontext. | `lib/models/class_ability.dart` |  |
| 912 | M | ~ Light | P2 | KIT FIRE | [FEEL 382] Combust/Pyro båda unlock 11 — HUD gömmer en signature. | `lib/models/class_ability.dart` |  |
| 913 | M | ~ Light | P2 | KIT FIRE | [FEEL 383] Living Bomb refresh-gate syns inte — DoT-uptid osynlig. | `lib/models/class_ability.dart` |  |
| 914 | M | ~ Light | P2 | KIT FRMAGE | [FEEL 428] Block = Ice Block vs Prot Block. | `lib/models/class_ability.dart` |  |
| 915 | M | ~ Light | P2 | KIT FRMAGE | [FEEL 429] Water Elemental Water utan pet-timer. | `lib/models/class_ability.dart` |  |
| 916 | M | ~ Light | P2 | KIT FRMAGE | [FEEL 430] Nova = Frost Nova vs Fire Blast Wave party-noise. | `lib/models/class_ability.dart` |  |
| 917 | M | ~ Light | P2 | KIT FROST_DK | [FEEL 416] Oblit/FS/Howl OK för fans; Hunger/Pillar saknar frost-ikon. | `lib/models/class_ability.dart` |  |
| 918 | M | ~ Light | P2 | KIT FURY | [FEEL 389] Slam delar etikett med Prot Shield Slam. | `lib/models/class_ability.dart` |  |
| 919 | M | ~ Light | P2 | KIT FURY | [FEEL 390] Wish/Ramp ser fluff tills tooltip. | `lib/models/class_ability.dart` |  |
| 920 | M | ~ Light | P2 | KIT GUARD | [FEEL 442] Bear Form dold — bear-tank osynlig tills Growl. | `lib/models/class_ability.dart` |  |
| 921 | M | ~ Light | P2 | KIT GUARD | [FEEL 443] Berserk delas med Feral — ingen bear-skillnad. | `lib/models/class_ability.dart` |  |
| 922 | M | ~ Light | P2 | KIT GUARD | [FEEL 444] FR vs Fury EReg — två regen-akronymer. | `lib/models/class_ability.dart` |  |
| 923 | M | ~ Light | P2 | KIT HOLY_PAL | [FEEL 391] Shock-chip = Holy Shock vs Prot Shockwave Shock. | `lib/models/class_ability.dart` |  |
| 924 | M | ~ Light | P2 | KIT HOLY_PAL | [FEEL 392] SShield/Flash/Light trängs — heal-rotation synonymer. | `lib/models/class_ability.dart` |  |
| 925 | M | ~ Light | P2 | KIT HOLY_PAL | [FEEL 393] Consecration kan dyka sent i chip-prioritet. | `lib/models/class_ability.dart` |  |
| 926 | M | ~ Light | P2 | KIT HOLY_PRI | [FEEL 409] DP = Desperate Prayer vs Shadow Devouring Plague DP. | `lib/models/class_ability.dart` |  |
| 927 | M | ~ Light | P2 | KIT HOLY_PRI | [FEEL 410] CoH/GS/Hymn trängs; Flash delas med Disc/Holy Pal. | `lib/models/class_ability.dart` |  |
| 928 | M | ~ Light | P2 | KIT HUD | [FEEL 447] Prioritering alfabetisk vid lika rank — rotation blir A–Z. | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 929 | M | ~ Light | P2 | KIT HUD | [FEEL 448] Tooltip 350ms hover-modell; telefon behöver long-press hint. | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 930 | M | ~ Light | P2 | KIT HUD | [FEEL 449] gated shield-abilities Name! utan equip shield-rad. | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 931 | M | ~ Light | P2 | KIT MM | [FEEL 401] True/Trueshot Aura dold — MM aura osynlig. | `lib/models/class_ability.dart` |  |
| 932 | M | ~ Light | P2 | KIT MM | [FEEL 402] Volley/Rapid/True CD-trängsel gömmer signature. | `lib/models/class_ability.dart` |  |
| 933 | M | ~ Light | P2 | KIT PPROT | [FEEL 394] HotR/SoR/HoR/AShield/HShield akronymsoppa. | `lib/models/class_ability.dart` |  |
| 934 | M | ~ Light | P2 | KIT PPROT | [FEEL 395] Righteous Fury dold — holy-tank threat osynlig. | `lib/models/class_ability.dart` |  |
| 935 | M | ~ Light | P2 | KIT PROT | [FEEL 377] shortLabel Dvst för Devastate oläsbart utan WotLK-minne. | `lib/models/class_ability.dart` |  |
| 936 | M | ~ Light | P2 | KIT PROT | [FEEL 378] Revenge showInHud:false — block-fantasy syns aldrig. | `lib/models/class_ability.dart` |  |
| 937 | M | ~ Light | P2 | KIT RDRU | [FEEL 445] Tree of Life dold. | `lib/models/class_ability.dart` |  |
| 938 | M | ~ Light | P2 | KIT RDRU | [FEEL 446] NS delas med Resto Shaman. | `lib/models/class_ability.dart` |  |
| 939 | M | ~ Light | P2 | KIT RET | [FEEL 396] TV/CS/HoW kräver guide — seal→CS→TV upptäcks inte. | `lib/models/class_ability.dart` |  |
| 940 | M | ~ Light | P2 | KIT RET | [FEEL 397] Bubble för Divine Shield — slang, inte invuln. | `lib/models/class_ability.dart` |  |
| 941 | M | ~ Light | P2 | KIT RET | [FEEL 398] Zealotry Zeal ser ut som resurs, inte CD. | `lib/models/class_ability.dart` |  |
| 942 | M | ~ Light | P2 | KIT RSHAM | [FEEL 423] Rip = Riptide vs Feral Rip. | `lib/models/class_ability.dart` |  |
| 943 | M | ~ Light | P2 | KIT RSHAM | [FEEL 424] Chain = Chain Heal vs Ele Chain Lightning. | `lib/models/class_ability.dart` |  |
| 944 | M | ~ Light | P2 | KIT RSHAM | [FEEL 425] Spirit Link Link säger inte damage-split. | `lib/models/class_ability.dart` |  |
| 945 | M | ~ Light | P2 | KIT SHADOW | [FEEL 411] VT/SWP/DP DoT-soppa utan hur många DoTs uppe. | `lib/models/class_ability.dart` |  |
| 946 | M | ~ Light | P2 | KIT SHADOW | [FEEL 412] Dispersion Disp ser ut som dispel. | `lib/models/class_ability.dart` |  |
| 947 | M | ~ Light | P2 | KIT SUB | [FEEL 407] Dance/Step/Prem kräver WotLK — opener göms. | `lib/models/class_ability.dart` |  |
| 948 | M | ~ Light | P2 | KIT SUB | [FEEL 408] Preparation Prep läses som ready-check. | `lib/models/class_ability.dart` |  |
| 949 | M | ~ Light | P2 | KIT SV | [FEEL 403] Mongo för Mongoose Bite oklart på telefon. | `lib/models/class_ability.dart` |  |
| 950 | M | ~ Light | P2 | KIT SV | [FEEL 404] Disengage Dis ser ut som disable. | `lib/models/class_ability.dart` |  |
| 951 | M | ~ Light | P2 | KIT UNHOLY | [FEEL 417] Blood Boil Boil delas med Blood DK. | `lib/models/class_ability.dart` |  |
| 952 | M | ~ Light | P2 | KIT UNHOLY | [FEEL 418] AMS kortform utan anti-magic-hint. | `lib/models/class_ability.dart` |  |
| 953 | M | ~ Light | P2 | MAP | [FEEL 283] HERE/CLEAR/OPEN/LOCKED utan NEXT-ord för frontier. | `lib/ui/hub/hub_world_map.dart` |  |
| 954 | M | ~ Light | P2 | MAP | [FEEL 284] Låsta zoner tryckbara men ENTER disabled — trasig select-känsla. | `lib/ui/hub/hub_world_map.dart` |  |
| 955 | M | ~ Light | P2 | MAP | [FEEL 285] Zonporträtt i cirklar ser lika Kenney-ikon ut. | `lib/ui/hub/hub_world_map.dart` |  |
| 956 | M | ~ Light | P2 | MAP | [FEEL 286] HERE-ringen pulserar som alarm bredvid TODAY ALMOST. | `lib/ui/hub/hub_world_map.dart` |  |
| 957 | M | ~ Light | P2 | MAP | [FEEL 287] Caption Name · Boss + blurb säger inte KEY/difficulty. | `lib/ui/hub/hub_world_map.dart` |  |
| 958 | M | ~ Light | P2 | MAP | [FEEL 288] Locked unlock text nämner inte clear av föregående zon. | `lib/ui/hub/hub_world_map.dart` |  |
| 959 | M | ~ Light | P2 | MAP | [FEEL 330] Zoom saknar in-dungeon kontroll för multi-chamber overview. | `lib/ui/spatial_dungeon_view.dart` |  |
| 960 | M | ~ Light | P2 | MAP | [FEEL 331] HudAboveNav kan täcka stairs nere till vänster. | `lib/ui/is2_shell.dart` |  |
| 961 | M | ~ Light | P2 | MARKET | [FEEL 345] Hero-filter visar inte om listing är upgrade. | `lib/ui/shell/jobs_market_sanctuary.dart` |  |
| 962 | M | ~ Light | P2 | MARKET | [FEEL 346] REFRESH-kostnad utan när gratis refresh återkommer. | `lib/ui/shell/jobs_market_sanctuary.dart` |  |
| 963 | M | ~ Light | P2 | MARKET | [FEEL 347] Flask/bandage-köp utan toast om bag full. | `lib/ui/shell/jobs_market_sanctuary.dart` |  |
| 964 | M | ~ Light | P2 | MARKET | [FEEL 348] Säljlista och gear listings delar scrollvärld. | `lib/ui/shell/jobs_market_sanctuary.dart` |  |
| 965 | M | ~ Light | P2 | MARKET | [FEEL 349] Ingen jämför-med-worn-badge innan köp. | `lib/ui/shell/jobs_market_sanctuary.dart` |  |
| 966 | M | ~ Light | P2 | NAV | [FEEL 328] Leave-copy mid-floor lost — FARM-loop-förlust otydlig. | `lib/ui/confirm_dialogs.dart` |  |
| 967 | M | ~ Light | P2 | NAV | [FEEL 329] Fyra nav-knappar på 360px trånga — HUB vs META under wipe. | `lib/ui/shell/app_bottom_bar.dart` |  |
| 968 | M | ~ Light | P2 | PARTY HUD | [FEEL 306] Selected-hero-border tunn mot mörk panel. | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 969 | M | ~ Light | P2 | PARTY HUD | [FEEL 307] Buff-taggar FLURRY/BEACON/ABS klipps på smal rad. | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 970 | M | ~ Light | P2 | PARTY HUD | [FEEL 308] Shield-gated ability visar ! utan off-hand-förklaring. | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 971 | M | ~ Light | P2 | PARTY HUD | [FEEL 309] Ability-tooltips kräver hover — telefon saknar long-press-beskrivning. | `lib/ui/shell/dungeon_party_hud.dart` |  |
| 972 | M | ~ Light | P2 | POWERUPS | [FEEL 270] Inaktiv WATCH · 3h säger inte gold/ATK — mystery-ad. | `lib/ui/hub/hub_powerups.dart` |  |
| 973 | M | ~ Light | P2 | POWERUPS | [FEEL 271] Header-multiplikator listar Ad ×2 gold / Ad +ATK medan chip säger ×2. | `lib/core/gold_income.dart` |  |
| 974 | M | ~ Light | P2 | POWERUPS | [FEEL 272] Sheet timing kring ad vs dismiss känns oklart. | `lib/ui/hub/hub_powerups.dart` |  |
| 975 | M | ~ Light | P2 | POWERUPS | [FEEL 273] STACKED TO 24H disabled utan nästa steg. | `lib/ui/hub/hub_powerups.dart` |  |
| 976 | M | ~ Light | P2 | PRESTIGE | [FEEL 369] Progressbar 1–12 ser ut som XP men är prestige-cykel. | `lib/ui/shell/jobs_market_sanctuary.dart` |  |
| 977 | M | ~ Light | P2 | PRESTIGE | [FEEL 370] Gold-track har bulk; power/vitality/xp saknar motsvarande. | `lib/ui/shell/jobs_market_sanctuary.dart` |  |
| 978 | M | ~ Light | P2 | PRESTIGE | [FEEL 371] vitality-track vs STA i Blessing — samma grej, olika ord. | `lib/ui/shell/jobs_market_sanctuary.dart` |  |
| 979 | M | ~ Light | P2 | PRESTIGE | [FEEL 372] Blessing-rad i CAMP duplicerar FORGE KEEP. | `lib/ui/shell/jobs_market_sanctuary.dart` |  |
| 980 | M | ~ Light | P2 | QUESTS | [FEEL 358] DAILY/BOUNTY/SIDE-badges utan svårighetsförklaring. | `lib/ui/shell/jobs_market_sanctuary.dart` |  |
| 981 | M | ~ Light | P2 | QUESTS | [FEEL 359] IN PROGRESS-knapp disabled ser trasig ut. | `lib/ui/shell/jobs_market_sanctuary.dart` |  |
| 982 | M | ~ Light | P2 | QUESTS | [FEEL 360] ready to claim-rad duplicerar CLAIM och tar scrollplats. | `lib/ui/shell/jobs_market_sanctuary.dart` |  |
| 983 | M | ~ Light | P2 | SETTINGS | [FEEL 365] iLvl-filter Off vs siffra utan preview. | `lib/ui/shell/settings_overlay.dart` |  |
| 984 | M | ~ Light | P2 | SETTINGS | [FEEL 366] Auto-sell och auto-disassemble nästan identiska UI. | `lib/ui/shell/settings_overlay.dart` |  |
| 985 | M | ~ Light | P2 | SETTINGS | [FEEL 367] Session log och Play Games nära RESET GAME. | `lib/ui/shell/settings_overlay.dart` |  |
| 986 | M | ~ Light | P2 | SETTINGS | [FEEL 368] Colorblind säger floaters — VFX-koppling otydlig. | `lib/ui/shell/settings_overlay.dart` |  |
| 987 | M | ~ Light | P2 | TARGET | [FEEL 310] Living Bomb hijackar target-HUD även när boss viktigare. | `lib/ui/shell/dungeon_target_hud.dart` |  |
| 988 | M | ~ Light | P2 | TARGET | [FEEL 311] Dormanta fiender i nästa chamber syns inte — tom karta-känsla. | `lib/ui/shell/dungeon_target_hud.dart` |  |
| 989 | M | ~ Light | P2 | TARGET | [FEEL 312] MaxWidth 168px klipper långa bossnamn. | `lib/ui/shell/dungeon_target_hud.dart` |  |
| 990 | M | ~ Light | P2 | WIPE | [FEEL 313] Daily echo-wipe-text tung att skanna. | `lib/ui/spatial_dungeon_view.dart` |  |
| 991 | M | ~ Light | P2 | WIPE | [FEEL 314] Advice kräver ≥2s fight — instant melt får tyst panel. | `lib/core/wipe_advice.dart` |  |
| 992 | M | ~ Light | P2 | WIPE | [FEEL 315] StreakNeeded=2 för FORGE men bag tippar wipe 1 — mönster oklart. | `lib/core/wipe_advice.dart` |  |
| 993 | M | ~ Light | P2 | ZONE grove | [FEEL 483] layoutKind cave — saknar canopy/glänta. | `lib/models/dungeon_def.dart` |  |
| 994 | L | Open | P2 | PERF | Phone session polish pad #1. | `lib/core/game_director.dart` |  |
| 995 | L | Open | P2 | PERF | Phone session polish pad #2. | `lib/core/game_director.dart` |  |
| 996 | L | Open | P2 | PERF | Phone session polish pad #3. | `lib/core/game_director.dart` |  |
| 997 | L | Open | P2 | PERF | Phone session polish pad #4. | `lib/core/game_director.dart` |  |
| 998 | L | Open | P2 | PERF | Phone session polish pad #5. | `lib/core/game_director.dart` |  |
| 999 | L | Open | P2 | PERF | Phone session polish pad #6. | `lib/core/game_director.dart` |  |
| 1000 | L | Open | P2 | PERF | Phone session polish pad #7. | `lib/core/game_director.dart` |  |

## Fas map

1. **Fas 0** — bucket A P0/P1 Console (owner + agent docs).
2. **Fas 1** — honesty: B/I copy, SHOP Coming later, wipe POWER wording.
3. **Fas 2** — Top 40 C/D/J/H feel on AL20 phone.
4. **Fas 4 post-live** — Billing (B), AdMob store-link (A), remaining M lights via cadence.

## How to work the list

Say **fixa top 40**, or list IDs. Mark rows `✅ Shipped` in this file when done. Do not block production on P2 zone Kenney reuse.

Regenerate: `py -3 tool/gen_play_prod_polish_1000.py`
