# Feel-audit — 500 punkter (rapport endast)

**Datum:** 2026-08-26  
**Scope:** Spelarkänsla (hub, dungeon, menyer, kits, zoner, copy, AL20 endgame, telefon).  
**Inte inkluderat:** ren refaktor, dependensuppgraderingar, tester utan spelar-symptom.  
**Status:** **1.12.64** — third feel-audit wave (compact dungeon HUD, kit gates/priority, forge BEST, CLAIM sync). Remaining: true combat redesign (hold-at-stairs mode, pet panels, rune resources), heavy nav layout, loot pickup list.

Varje punkt: `ID · yta · allvar · mening · fil`

## Top 20 (börja här)

1. **P0** · GUIDE — WORLD PATH-guiden säger att lifetime gold låser upp zoner — spelet använder partynivå/clear.  
   `lib/core/game_guides.dart`

2. **P0** · GUIDE — ESSENCE SHOP-guiden lovar extra loadout-slots trots att Loadout Folio är avlistad och LOADOUTS gömd.  
   `lib/core/game_guides.dart`

3. **P0** · GUIDE — DAILY RUN-guiden säger att TODAY jagar Ascend/zoner/Daily — not KEY — aktivt fel på AL20+Lv100.  
   `lib/core/game_guides.dart`

4. **P0** · GUIDE — Ingen GUIDE-topic för Ashen Crown / biljetter / practice.  
   `lib/core/game_guides.dart`

5. **P0** · WHATS NEW — 1.12.59 "Ascend is a claim, not a wipe" vilseleder aktivt när man scrollar under 1.12.60 prestige-wipe.  
   `lib/core/meta_systems.dart`

6. **P0** · HUB CTA — När TODAY jagar Gauntlet/Rift/GR/Ashen kan stora knappen fortfarande bli ENTER DUNGEON i stället för jakten.  
   `lib/ui/hub_screen.dart`

7. **P0** · HUB ENDGAME — Efter borttagen endgame-knapprad syns Gauntlet/Rift/GR/Ashen mest via META→KEY eller liten TODAY-knapp.  
   `lib/ui/hub/hub_today_card.dart`

8. **P0** · ASHEN — PRACTICE för Ashen Crown försvann med endgame-stacken — biljetter känns riskabla utan övning.  
   `lib/ui/hub/hub_today_card.dart`

9. **P0** · ASHEN — Toast säger "try Practice" men ingen Practice-knapp syns i hub-UI.  
   `lib/core/game_director.dart`

10. **P0** · ASHEN — Ingen confirm — ASHEN CROWN kan spendera biljett direkt.  
   `lib/ui/hub_screen.dart`

11. **P0** · ASHEN — Chase lovar N biljetter men worldBossClearedWeek stoppar jakten efter första clear.  
   `lib/core/hub_chase.dart`

12. **P0** · ASHEN — Extra biljetter kan spenderas utan essence när week redan cleared — känns som scam.  
   `lib/core/ashen_crown.dart`

13. **P0** · TODAY — READY-jakter döljer detail-raden, så Ascend-reset/Blessing syns inte när du mest behöver dem.  
   `lib/ui/hub/hub_today_card.dart`

14. **P0** · HUB LAYOUT — På 360×780 stackas header+map+TODAY+POWERUPS+ENTER(+urgent) så kartan blir för kort för path-läsning.  
   `lib/ui/hub_screen.dart`

15. **P0** · MARKET — SELL STASH: ett tryck säljer direkt utan bekräftelse — lätt att tappa upgrade.  
   `lib/ui/shell/jobs_market_sanctuary.dart`

16. **P0** · FORGE — REBORN är röd och nära vanliga essence-köp — risk för oavsiktlig bag-wipe.  
   `lib/ui/shell/forge_overlay.dart`

17. **P0** · PRESTIGE — CAMP Prestige-knappen resetar nivå utan separat "är du säker"-dialog i UI-flödet.  
   `lib/ui/shell/jobs_market_sanctuary.dart`

18. **P0** · DUNGEON HUD — På telefon syns varken zonnamn, våning eller KEY-timer i kompakt toprad — man tappar var man är.  
   `lib/ui/shell/dungeon_top_hud.dart`

19. **P0** · FARM/PUSH — FARM och PUSH förklaras aldrig i chippen — byte mid-run utan att veta vad som händer nästa clear.  
   `lib/ui/spatial_dungeon_view.dart`

20. **P0** · FARM/PUSH — Man kan byta FARM/PUSH mid-fight utan bekräftelse.  
   `lib/ui/shell/dungeon_top_hud.dart`

## Alla 500

| ID | Allvar | Yta | Problem | Fil |
|----|--------|-----|---------|-----|
| 001 | P0 | GUIDE | WORLD PATH-guiden säger att lifetime gold låser upp zoner — spelet använder partynivå/clear. | `lib/core/game_guides.dart` |
| 002 | P0 | GUIDE | ESSENCE SHOP-guiden lovar extra loadout-slots trots att Loadout Folio är avlistad och LOADOUTS gömd. | `lib/core/game_guides.dart` |
| 003 | P0 | GUIDE | DAILY RUN-guiden säger att TODAY jagar Ascend/zoner/Daily — not KEY — aktivt fel på AL20+Lv100. | `lib/core/game_guides.dart` |
| 004 | P0 | GUIDE | Ingen GUIDE-topic för Ashen Crown / biljetter / practice. | `lib/core/game_guides.dart` |
| 005 | P0 | WHATS NEW | 1.12.59 "Ascend is a claim, not a wipe" vilseleder aktivt när man scrollar under 1.12.60 prestige-wipe. | `lib/core/meta_systems.dart` |
| 006 | P0 | HUB CTA | När TODAY jagar Gauntlet/Rift/GR/Ashen kan stora knappen fortfarande bli ENTER DUNGEON i stället för jakten. | `lib/ui/hub_screen.dart` |
| 007 | P0 | HUB ENDGAME | Efter borttagen endgame-knapprad syns Gauntlet/Rift/GR/Ashen mest via META→KEY eller liten TODAY-knapp. | `lib/ui/hub/hub_today_card.dart` |
| 008 | P0 | ASHEN | PRACTICE för Ashen Crown försvann med endgame-stacken — biljetter känns riskabla utan övning. | `lib/ui/hub/hub_today_card.dart` |
| 009 | P0 | ASHEN | Toast säger "try Practice" men ingen Practice-knapp syns i hub-UI. | `lib/core/game_director.dart` |
| 010 | P0 | ASHEN | Ingen confirm — ASHEN CROWN kan spendera biljett direkt. | `lib/ui/hub_screen.dart` |
| 011 | P0 | ASHEN | Chase lovar N biljetter men worldBossClearedWeek stoppar jakten efter första clear. | `lib/core/hub_chase.dart` |
| 012 | P0 | ASHEN | Extra biljetter kan spenderas utan essence när week redan cleared — känns som scam. | `lib/core/ashen_crown.dart` |
| 013 | P0 | TODAY | READY-jakter döljer detail-raden, så Ascend-reset/Blessing syns inte när du mest behöver dem. | `lib/ui/hub/hub_today_card.dart` |
| 014 | P0 | HUB LAYOUT | På 360×780 stackas header+map+TODAY+POWERUPS+ENTER(+urgent) så kartan blir för kort för path-läsning. | `lib/ui/hub_screen.dart` |
| 015 | P0 | MARKET | SELL STASH: ett tryck säljer direkt utan bekräftelse — lätt att tappa upgrade. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 016 | P0 | FORGE | REBORN är röd och nära vanliga essence-köp — risk för oavsiktlig bag-wipe. | `lib/ui/shell/forge_overlay.dart` |
| 017 | P0 | PRESTIGE | CAMP Prestige-knappen resetar nivå utan separat "är du säker"-dialog i UI-flödet. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 018 | P0 | DUNGEON HUD | På telefon syns varken zonnamn, våning eller KEY-timer i kompakt toprad — man tappar var man är. | `lib/ui/shell/dungeon_top_hud.dart` |
| 019 | P0 | FARM/PUSH | FARM och PUSH förklaras aldrig i chippen — byte mid-run utan att veta vad som händer nästa clear. | `lib/ui/spatial_dungeon_view.dart` |
| 020 | P0 | FARM/PUSH | Man kan byta FARM/PUSH mid-fight utan bekräftelse. | `lib/ui/shell/dungeon_top_hud.dart` |
| 021 | P0 | GOD HAND | Kartan är helskärmsknapp för God Hand — oavsiktliga tryck steerar partyt under AFK-tittning. | `lib/ui/spatial_dungeon_view.dart` |
| 022 | P0 | GOD HAND | God Hand-ringen visar ingen sekunder kvar, bara en båge — CD känns godtycklig. | `lib/ui/spatial_dungeon_view.dart` |
| 023 | P0 | PARTY HUD | Party-listen dimmar till 40% efter 5s på telefon — kritisk HP-info försvinner. | `lib/ui/shell/dungeon_party_hud.dart` |
| 024 | P0 | PARTY HUD | Kit-chips öppnas bara efter tap — man vet inte om abilitys är på CD utan att pilla. | `lib/ui/shell/dungeon_party_hud.dart` |
| 025 | P0 | PARTY HUD | På telefon visas HP som procent utan max — "47" är tvetydigt. | `lib/ui/shell/dungeon_party_hud.dart` |
| 026 | P0 | TARGET | Målet väljs närmast leader eller Living Bomb — spelaren kan inte välja fokus-target. | `lib/ui/shell/dungeon_target_hud.dart` |
| 027 | P0 | WIPE | Wipe-advice saknas ofta trots upprepade wipes — ingen "vad gör jag fel?"-känsla. | `lib/core/wipe_advice.dart` |
| 028 | P0 | WIPE | God Hand-hint efter wipe men God Hand går inte att trycka innan RETRY — timing-fel. | `lib/ui/spatial_dungeon_view.dart` |
| 029 | P0 | FLOOR | FLOOR ±1 saknar lista över upplåsta våningar — hopp känns blind. | `lib/ui/shell/dungeon_top_hud.dart` |
| 030 | P0 | FLOOR | Travel fullhealar partyt utan toast — svårt att märka ny våg vs samma fight. | `lib/core/game_logic.dart` |
| 031 | P0 | CLEAR | GO — stairs-bandet sitter under kartan och syns sent om man tittar på party-HUD. | `lib/ui/spatial_dungeon_view.dart` |
| 032 | P0 | CLEAR | Clear-summary toast försvinner på ~2s — gold/level-up går förbi. | `lib/core/game_director.dart` |
| 033 | P0 | KIT | Combat Rogue Eviscerate är showInHud:false — finisher-fantasyn syns aldrig i chips. | `lib/models/class_ability.dart` |
| 034 | P0 | KIT | Subtlety Eviscerate också showInHud:false — samma finisher-problem. | `lib/models/class_ability.dart` |
| 035 | P0 | KIT | Shadow priest renderas som warlock-sprite — HUD säger priest, dockan säger warlock. | `lib/core/hero_identity.dart` |
| 036 | P0 | ZONE | Hell's Gate brute/tank använder king-boss-sprite — mobbar ser ut som kungens soldater. | `lib/models/zone_art.dart` |
| 037 | P0 | ZONE | Stormwake elite=bat — storm-packar ser ut som fladdermöss. | `lib/models/zone_art.dart` |
| 038 | P0 | KIT HUD | maxChips phone=2 + chip-panel dold default gömmer rotationen för nästan alla 31 specs. | `lib/ui/shell/dungeon_party_hud.dart` |
| 039 | P1 | HUB | ENTER KEY +N sätter dial och går in utan att visa affixes eller par-timer. | `lib/ui/hub_screen.dart` |
| 040 | P1 | HUB | ENTER KEY byter zon internt men kartan kan fortfarande visa annan HERE. | `lib/ui/hub_screen.dart` |
| 041 | P1 | HUB | PATH för zone-unlock bara markerar zonen — CTA känns tom. | `lib/ui/hub_screen.dart` |
| 042 | P1 | HUB | CLAIM QUESTS plockar allt tyst utan att öppna META→QUESTS. | `lib/ui/hub_screen.dart` |
| 043 | P1 | HUB | Meet-hero CTA ack:ar reveals innan du hunnit läsa kit-fantasin. | `lib/ui/hub_screen.dart` |
| 044 | P1 | HUB | Equip-upgrade öppnar PARTY utan att peka vilket item. | `lib/core/hub_chase.dart` |
| 045 | P1 | HUB | MARKET-upgrade kan äga TODAY medan ENTER fortfarande handlar om dungeon. | `lib/core/hub_chase.dart` |
| 046 | P1 | HUB | Week · affix-raden döljs på korta telefonhöjder (A56-liknande). | `lib/ui/hub_screen.dart` |
| 047 | P1 | HUB | MetaPulse tystnar vid READY/ALMOST — vault-status försvinner när du jagar annat. | `lib/ui/hub/hub_today_card.dart` |
| 048 | P1 | HUB | Vault-progress kan synas både i MetaPulse och UrgentRow. | `lib/ui/hub/hub_today_card.dart` |
| 049 | P1 | HUB | DAILY RUN kan ligga kvar under ENTER när TODAY redan är Daily/KEY. | `lib/ui/hub/hub_today_card.dart` |
| 050 | P1 | HUB | Ascend kan ligga som röd urgent medan TODAY säger farm Daily — två "viktigast". | `lib/ui/hub_screen.dart` |
| 051 | P1 | HUB | Secondary ENTER tippas "Skip TODAY" även när farm är okej. | `lib/ui/hub_screen.dart` |
| 052 | P1 | HUB | META→KEY-länken försvinner när chase "äger" KEY-chrome. | `lib/ui/hub_screen.dart` |
| 053 | P1 | HUB | hubChaseOwnsEndgameRow finns men styr inte hub-CTA — endgame känns halv. | `lib/core/hub_chase.dart` |
| 054 | P1 | HUB | Knappen GREATER säger inte Greater Rift. | `lib/ui/hub_screen.dart` |
| 055 | P1 | HUB | RIFT vs GREATER vs KEY utan ikon — tre endgame-lägen svåra att skilja. | `lib/ui/hub_screen.dart` |
| 056 | P1 | HUB | Ashen-chase visar "tix" utan förklaring eller reset. | `lib/core/hub_chase.dart` |
| 057 | P1 | HUB | Rebuild your bag / Floor 1 efter Ascend känns som straff utan progress mot omkit. | `lib/core/hub_chase.dart` |
| 058 | P1 | HUB | Party-level-jakt blandar min/max i detail men progress visar bara lägsta. | `lib/core/hub_chase.dart` |
| 059 | P1 | HUB | KEY-habit kan slå Daily även när vault/Daily är dagens "färdiga" känsla. | `lib/core/hub_chase.dart` |
| 060 | P1 | HUB | GR→Gauntlet→Rift-ordning i TODAY matchar inte hur spelare rangordnar efter PB. | `lib/core/hub_chase.dart` |
| 061 | P1 | HUB | Will-jakt skickar till CODEX utan hur man får collection points. | `lib/core/hub_chase.dart` |
| 062 | P1 | HUB | Almost zone säger clear prev ELLER level, men PATH gör ingen av delarna. | `lib/core/hub_chase.dart` |
| 063 | P1 | HUB | Almost time KEY +2 efter KEY +1 känns som misslyckande i stället för halvvägs vault. | `lib/core/hub_chase.dart` |
| 064 | P1 | HUB | Start daily vault blandar "clear 1 floor or time KEY +2" i samma mening. | `lib/core/hub_chase.dart` |
| 065 | P1 | HUB | Claim daily vault · season bonus tränger ut vault-känslan bakom season-jargon. | `lib/core/hub_chase.dart` |
| 066 | P1 | HUB | Month-pass READY har CLAIM MONTH men ingen synlig månadsprogress i hub. | `lib/core/hub_chase.dart` |
| 067 | P1 | HUB | Week-goal ENTER gissar Gauntlet via title.contains — skört. | `lib/ui/hub_screen.dart` |
| 068 | P1 | HUB | TODAY title+chip+progress+knapp på en rad truncerar långa endgame-titlar på 360 px. | `lib/ui/hub/hub_today_card.dart` |
| 069 | P1 | HUB | compact detail maxLines:1 klipper Blessing/teaser mitt i meningen. | `lib/ui/hub/hub_today_card.dart` |
| 070 | P1 | HUB | READY utan detail gör claimables till "tryck knappen" utan payoff före toast. | `lib/ui/hub/hub_today_card.dart` |
| 071 | P1 | POWERUPS | Compact POWERUPS minHeight 36 under minTouch 44 — för liten att träffa säkert. | `lib/ui/hub/hub_powerups.dart` |
| 072 | P1 | POWERUPS | Chipet visar bara ×2 · tid och döljer +25% ATK tills sheet. | `lib/ui/hub/hub_powerups.dart` |
| 073 | P1 | POWERUPS | POWERUPS sitter mellan TODAY och ENTER och stjäl fokus från jakten på AL20. | `lib/ui/hub_screen.dart` |
| 074 | P1 | HEADER | Settings öppnas via dörr-ikon — läses som exit/leave. | `lib/ui/hub/hub_header.dart` |
| 075 | P1 | HEADER | Boss F$N i header saknar zonnamn. | `lib/ui/hub/hub_header.dart` |
| 076 | P1 | HUB | Offline+Play-update+Whats New i kö kan pressa World Path till en tunn remsa. | `lib/ui/hub_screen.dart` |
| 077 | P1 | MAP | Kartan auto-scrollar till selected och kämpar mot manuell panorering. | `lib/ui/hub/hub_world_map.dart` |
| 078 | P1 | MAP | Har du CLEAR vald snappar hubben till NEXT-frontier utan toast. | `lib/ui/hub_screen.dart` |
| 079 | P1 | MAP | 15 markörer på lång path gör late zones lätta att missa. | `lib/ui/hub/hub_world_map.dart` |
| 080 | P1 | HUB | Om vault claimable men annan READY äger TODAY kan vault missas. | `lib/ui/hub_screen.dart` |
| 081 | P1 | HUB | ALMOST Gauntlet visar liten GAUNTLET-knapp medan ENTER går in i vald zon. | `lib/ui/hub_screen.dart` |
| 082 | P1 | DUNGEON | ⋯-menyn blandar våning, quests och settings — feltryck kan teleportera under fight. | `lib/ui/shell/dungeon_top_hud.dart` |
| 083 | P1 | DUNGEON | Gold/min under HUD känns som hub-bokföring mitt i combat. | `lib/ui/shell/dungeon_top_hud.dart` |
| 084 | P1 | DUNGEON | Underleveled-banner utan CTA till FORGE/PARTY. | `lib/ui/shell/dungeon_top_hud.dart` |
| 085 | P1 | FARM/PUSH | Gauntlet/Rift-chip ser ut som FARM/PUSH men gör ingenting vid tryck. | `lib/ui/shell/dungeon_top_hud.dart` |
| 086 | P1 | RIFT HUD | Compact Rift-label R3 12/40 saknar timer och känns som score. | `lib/ui/shell/dungeon_top_hud.dart` |
| 087 | P1 | GOD HAND | Urgent efter två wipes ändrar bara färg — nudge syns knappt. | `lib/ui/spatial_dungeon_view.dart` |
| 088 | P1 | GOD HAND | Toast "steered" utan kill säger nästan ingenting. | `lib/core/game_director.dart` |
| 089 | P1 | GOD HAND | FOCUS/WIDE/BAL syns aldrig i dungeon-HUD — stilbyten osynliga i fight. | `lib/ui/shell/dungeon_top_hud.dart` |
| 090 | P1 | PARTY HUD | Roll-etikett kapas till Dam/Shi — tappar klassfantasi. | `lib/ui/shell/dungeon_party_hud.dart` |
| 091 | P1 | PARTY HUD | XP-bar under HP i combat läser som mana/shield. | `lib/ui/shell/dungeon_party_hud.dart` |
| 092 | P1 | PARTY HUD | FLASK-knappen saknar antal kvar. | `lib/ui/shell/dungeon_party_hud.dart` |
| 093 | P1 | PARTY HUD | FLASK! urgent 50% under boss vs 35% annars — inkonsekvent. | `lib/ui/shell/dungeon_party_hud.dart` |
| 094 | P1 | PARTY HUD | Max två ability-chips på telefon gömmer resten av kitet på boss. | `lib/ui/shell/dungeon_party_hud.dart` |
| 095 | P1 | PARTY HUD | Long-press öppnar gear mitt i fight utan bekräftelse. | `lib/ui/shell/dungeon_party_hud.dart` |
| 096 | P1 | TARGET | Endast procent HP — boss-TTK går inte att känna. | `lib/ui/shell/dungeon_target_hud.dart` |
| 097 | P1 | TARGET | Normala fiender saknar roll-etikett. | `lib/ui/shell/dungeon_target_hud.dart` |
| 098 | P1 | TARGET | Walk to stairs utan pil/minimap till exit. | `lib/ui/shell/dungeon_target_hud.dart` |
| 099 | P1 | WIPE | Hub-hint leder till leave-confirm, inte FORGE/PARTY-fix. | `lib/core/wipe_advice.dart` |
| 100 | P1 | WIPE | Bag-upgrade-tip säger inte vilken hjälte eller slot. | `lib/core/wipe_advice.dart` |
| 101 | P1 | WIPE | ATK/DEF/STA-tips kan bytas till MARKET utan pris/itemnamn. | `lib/core/wipe_advice.dart` |
| 102 | P1 | WIPE | RETRY → F$safe vs RETRY FLOOR byter label utan synlig varför. | `lib/ui/spatial_dungeon_view.dart` |
| 103 | P1 | WIPE | CLEAN BAG dyker upp sent när stash full under wipe-stress. | `lib/ui/spatial_dungeon_view.dart` |
| 104 | P1 | WIPE | Gauntlet/Rift wipe tar bort RETRY — copy utan synlig PB. | `lib/ui/spatial_dungeon_view.dart` |
| 105 | P1 | FLOOR | Compact ⋯ ser ut som settings, inte våningshopp. | `lib/ui/shell/dungeon_top_hud.dart` |
| 106 | P1 | FLOOR | Disabled FLOOR ±1 utan "låst tills clear". | `lib/ui/shell/dungeon_top_hud.dart` |
| 107 | P1 | CHAMBER | Sju-pixel-prickar utan legend för clear/active/locked. | `lib/ui/spatial_dungeon_view.dart` |
| 108 | P1 | CLEAR | Party går auto till stairs — kan inte stå kvar med avsikt. | `lib/ui/spatial_dungeon_view.dart` |
| 109 | P1 | CLEAR | GO-label kan döljas med Minimal VFX. | `lib/ui/spatial_dungeon_view.dart` |
| 110 | P1 | DPS | Metern blandar dps/hps/dtps — tank/heal läses som best DPS. | `lib/ui/shell/dungeon_party_hud.dart` |
| 111 | P1 | NAV | PARTY/POWER öppnas över live combat utan pause-känsla. | `lib/ui/is2_shell.dart` |
| 112 | P1 | NAV | Dungeon bottom bar saknar hub-style reason-rad för badges. | `lib/ui/shell/app_bottom_bar.dart` |
| 113 | P1 | MAP | Scrim+torch bloom mörkar hörnen — fiender svåra att se. | `lib/ui/is2_shell.dart` |
| 114 | P1 | MAP | Laddningsruta utan "loading floor" känns som freeze. | `lib/ui/spatial_dungeon_view.dart` |
| 115 | P1 | BAG | CLEAN BAG säger inte om den säljer guld eller skrotar essence. | `lib/ui/shell/inventory_dock.dart` |
| 116 | P1 | BAG | FILTERS öppnar SETTINGS mitt i BAG-flödet. | `lib/ui/shell/inventory_dock.dart` |
| 117 | P1 | BAG | MERGE kräver ADD TO MERGE i två steg utan BiS-risk-hint. | `lib/ui/shell/inventory_dock.dart` |
| 118 | P1 | BAG | Sell junk/Scrap gömda i FILTERS — dead chrome mer försvunnet än tydligt. | `lib/ui/shell/inventory_dock.dart` |
| 119 | P1 | GEAR | DAMAGE/ARMOR under dockan matchar inte ATK/DEF/STA i FORGE. | `lib/ui/character_equip_panel.dart` |
| 120 | P1 | GEAR | Score-delta UPGRADE syns bara när stash-item valt. | `lib/ui/character_equip_panel.dart` |
| 121 | P1 | GEAR | Jämförelse säger Score men inte ATK/DEF/STA-känsla. | `lib/ui/character_equip_panel.dart` |
| 122 | P1 | GEAR | Tap empty slot to filter-hint försvinner i scroll. | `lib/ui/character_equip_panel.dart` |
| 123 | P1 | MARKET | Slotfilter saknar boots/rings/charms. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 124 | P1 | MARKET | Copy "Farm still beats market" undergräver köplust utan alternativ jakt. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 125 | P1 | MARKET | Tap = gold sell stash konkurrerar med BAG long-press — samma finger, olika risk. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 126 | P1 | FORGE | GOLD-fliken wrappar sönder av långa BEST-etiketter. | `lib/ui/shell/forge_overlay.dart` |
| 127 | P1 | FORGE | SPEND ALL · EVEN förklarar inte vilken track som fick flest steg. | `lib/ui/shell/forge_overlay.dart` |
| 128 | P1 | FORGE | KEEP blandar Blessing, REBORN, Constellation, God Hand utan prioritet. | `lib/ui/shell/forge_overlay.dart` |
| 129 | P1 | FORGE | BEST-markering byter track tyst — jakt på etikett mer än fantasy-stat. | `lib/ui/shell/forge_overlay.dart` |
| 130 | P1 | QUESTS | Chain N/3 +5e syns i ingress men inte på CLAIM-knappen. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 131 | P1 | QUESTS | Progress-rad blandar mål och belöning. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 132 | P1 | QUESTS | CLAIM i QUESTS vs TODAY CLAIM QUESTS — dubbla ytor utan synk. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 133 | P1 | KEY | KEYSTONE startar collapsed — AL20 ser "off" trots aktiv KEY+N. | `lib/ui/meta_overlays.dart` |
| 134 | P1 | KEY | BOSS RUSH / NO FLASK / TINY saknar one-line feel-kostnad. | `lib/ui/meta_overlays.dart` |
| 135 | P1 | KEY | Power-score under KEY förklarar inte om du klarar dialen. | `lib/ui/meta_overlays.dart` |
| 136 | P1 | KEY | Loot +iLvl/goldMul visas bara när KEY>0 — KEY+0 känns meningslös. | `lib/ui/meta_overlays.dart` |
| 137 | P1 | SETTINGS | BAG CLEANUP bor i SETTINGS — långt från CLEAN BAG. | `lib/ui/shell/settings_overlay.dart` |
| 138 | P1 | SETTINGS | Near-full bag processcopy syns aldrig i BAG live. | `lib/ui/shell/settings_overlay.dart` |
| 139 | P1 | SETTINGS | FILTERS hoppar till BAG CLEANUP och tappar BAG-kontext. | `lib/ui/shell/settings_overlay.dart` |
| 140 | P1 | PRESTIGE | CAMP Prestige och Ascend prestige låter lika men gör olika saker. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 141 | P1 | PRESTIGE | Ingress Lv12-reset är väggtext — telefonen hoppar över varningen. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 142 | P1 | PRESTIGE | "Not a power jump" copy dödar trycklusten på Prestige. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 143 | P1 | POWER | CAMP syns först efter essence/Ascend — prestige-loop osynlig tidigt. | `lib/ui/shell/power_meta_pillars.dart` |
| 144 | P1 | MENU | KEY jargon gate — tab-tomrum känns trasigt före unlock. | `lib/ui/shell/power_meta_pillars.dart` |
| 145 | P1 | KIT PROT | Shield Wall/Last Stand konkurrerar bort Charge/Taunt på 2-chip HUD. | `lib/ui/shell/dungeon_party_hud.dart` |
| 146 | P1 | KIT PROT | Stance passiv syns inte — tank-fantasi startar utan "jag är tank". | `lib/models/class_ability.dart` |
| 147 | P1 | KIT DISC | PS/PI-chips kräver WoW-kunskap; tooltip är hover-vänlig, inte telefon. | `lib/ui/shell/dungeon_party_hud.dart` |
| 148 | P1 | KIT FIRE | Fireball shortLabel tar mer chip-yta än Pyro/Bomb. | `lib/models/class_ability.dart` |
| 149 | P1 | KIT COM | Sinister Strike dold — combo-builder saknas i HUD. | `lib/models/class_ability.dart` |
| 150 | P1 | KIT ARMS | Execute-gate syns inte på chip förrän gated/ready. | `lib/ui/shell/dungeon_party_hud.dart` |
| 151 | P1 | KIT FURY | EReg/Reck båda Lv12 — telefon-HUD visar bara två. | `lib/ui/shell/dungeon_party_hud.dart` |
| 152 | P1 | KIT HOLY_PAL | Beacon syns utan vem som är beacon. | `lib/models/class_ability.dart` |
| 153 | P1 | KIT PPROT | shortLabel PPROT nästan oläsligt vs PROT. | `lib/models/hero_spec.dart` |
| 154 | P1 | KIT PPROT | Hand of Reckoning HoR förväxlas med Hammer of the Righteous. | `lib/models/class_ability.dart` |
| 155 | P1 | KIT RET | Seal of Command dold — ret-fantasi saknar synlig seal. | `lib/models/class_ability.dart` |
| 156 | P1 | KIT BM | Kill Command KC utan pet-status i HUD. | `lib/models/class_ability.dart` |
| 157 | P1 | KIT MM | Steady/Aimed/Chim ser ut som tre shots utan fokus-gate. | `lib/models/class_ability.dart` |
| 158 | P1 | KIT SV | Trap Mastery dold — trap-kärna syns sent. | `lib/models/class_ability.dart` |
| 159 | P1 | KIT ASSASS | Improved Poisons dold — varför gift saknas i HUD. | `lib/models/class_ability.dart` |
| 160 | P1 | KIT SUB | MoS passiv dold — subtlety-fantasi bara i namnet. | `lib/models/class_ability.dart` |
| 161 | P1 | KIT HOLY_PRI | Spirit of Redemption dold. | `lib/models/class_ability.dart` |
| 162 | P1 | KIT SHADOW | Shadowform dold — shadow-fantasi saknar form-chip. | `lib/models/class_ability.dart` |
| 163 | P1 | KIT BLOOD | DS/HS/VB/DRW/IBF/DC är akronymlåda utan rune-feel. | `lib/models/class_ability.dart` |
| 164 | P1 | KIT FROST_DK | IBF delas med Blood/Unholy — defensiv chip generisk. | `lib/models/class_ability.dart` |
| 165 | P1 | KIT UNHOLY | Garg/Army utan pet-panel i party-HUD. | `lib/models/class_ability.dart` |
| 166 | P1 | KIT ELE | Elemental Focus dold — proc-fantasi osynlig. | `lib/models/class_ability.dart` |
| 167 | P1 | KIT ENH | Enhanced Weapons dold — dual-wield fantasi saknas. | `lib/models/class_ability.dart` |
| 168 | P1 | KIT RSHAM | Ancestral Awakening dold. | `lib/models/class_ability.dart` |
| 169 | P1 | KIT ARC | Arcane Brilliance dold. | `lib/models/class_ability.dart` |
| 170 | P1 | KIT FRMAGE | Frost Armor dold. | `lib/models/class_ability.dart` |
| 171 | P1 | KIT AFF | Soul Siphon dold. | `lib/models/class_ability.dart` |
| 172 | P1 | KIT DEMO | Demon Charge "Charge" kolliderar med Prot Charge. | `lib/models/class_ability.dart` |
| 173 | P1 | KIT DESTRO | Shadowfury "Fury" kolliderar med Fury Warrior. | `lib/models/class_ability.dart` |
| 174 | P1 | KIT BAL | Wrath-chip kolliderar med BM Bestial Wrath-etikett. | `lib/models/class_ability.dart` |
| 175 | P1 | KIT FERAL | Cat Form dold — cat DPS ser human i chip-lager. | `lib/models/class_ability.dart` |
| 176 | P1 | KIT GUARD | FR/Lac/SI/Bark trängs; Swipe delas med Feral. | `lib/models/class_ability.dart` |
| 177 | P1 | KIT RDRU | WG/NS/Tranq/Bloom kräver guide; Nourish tar plats. | `lib/models/class_ability.dart` |
| 178 | P1 | KIT HUD | Kit stängs vid andra tryck på samma hjälte mid-boss. | `lib/ui/shell/dungeon_party_hud.dart` |
| 179 | P1 | ZONE sandy | Elite=cyclops delas med king/brass — starterzon ej unik i packar. | `lib/models/zone_art.dart` |
| 180 | P1 | ZONE sandy | Boss Earth Kraken vs crab/slime trash — boss-fantasi landar inte. | `lib/models/dungeon_def.dart` |
| 181 | P1 | ZONE goblin | preferChoke stark men elite=spider mer cave än goblin. | `lib/models/zone_art.dart` |
| 182 | P1 | ZONE goblin | Blurb lovar chest ambushes utan UI-telegraph. | `lib/models/dungeon_def.dart` |
| 183 | P1 | ZONE king | Boss Corrupt King delar sprite-familj med hell brute/tank. | `lib/models/zone_art.dart` |
| 184 | P1 | ZONE king | glass=bat samma som sandy — fort glass-cannon saknas. | `lib/models/zone_art.dart` |
| 185 | P1 | ZONE underworld | layoutKind hideout delas med goblin/hell/veil — rum återbruk. | `lib/models/dungeon_def.dart` |
| 186 | P1 | ZONE underworld | preferChoke utan treasure-alcove — trång utan belöningssignatur. | `lib/models/zone_art.dart` |
| 187 | P1 | ZONE dead | layoutKind fort delas med king/ember — city känns murad fort igen. | `lib/models/dungeon_def.dart` |
| 188 | P1 | ZONE hell | elite/ranged/glass/support alla cultist — pack-variation kollapsar. | `lib/models/zone_art.dart` |
| 189 | P1 | ZONE hell | preferChoke utan alcove — bara trång eld, ingen gate prize. | `lib/models/zone_art.dart` |
| 190 | P1 | ZONE crystal | Elites = crystal boss clones — boss fight känns som pack+. | `lib/models/zone_art.dart` |
| 191 | P1 | ZONE tide | ranged=slime/glass=bat bryter tidehold. | `lib/models/zone_art.dart` |
| 192 | P1 | ZONE tide | treasureAlcove hög — hub lovar inte flooded vaults tydligt. | `lib/models/zone_art.dart` |
| 193 | P1 | ZONE ember | lava+anvil starkt vs hell, men bat/rat/cultist trash generisk. | `lib/models/zone_art.dart` |
| 194 | P1 | ZONE ember | wash orange nära hell-röd på telefon — kräver side-by-side. | `lib/models/zone_art.dart` |
| 195 | P1 | ZONE grove | elite/brute/tank=spider — Hollow Grove är spindelgrotta. | `lib/models/zone_art.dart` |
| 196 | P1 | ZONE grove | Blurb binder Tide/Ashen men props visar inte "between". | `lib/models/dungeon_def.dart` |
| 197 | P1 | ZONE grove | Wyrd Root-boss vs spider-wall — trash räddar inte identity. | `lib/models/zone_art.dart` |
| 198 | P1 | ZONE storm | trap landmarks utan synlig lightning-prop. | `lib/models/zone_art.dart` |
| 199 | P1 | ZONE rime | water/fountain kan läsas som tide, inte ice. | `lib/models/zone_art.dart` |
| 200 | P1 | ZONE rime | treasureAlcove 0.45 — loot stark, cold-fantasi svag. | `lib/models/zone_art.dart` |
| 201 | P1 | ZONE rime | Colossus boss vs golem trash — zonen läses golem-cave. | `lib/models/zone_art.dart` |
| 202 | P1 | ZONE fen | brute=slime underviker mire-horror vs hydra-boss. | `lib/models/zone_art.dart` |
| 203 | P1 | ZONE fen | trap landmarks utan trap-damage-feel i HUD. | `lib/models/zone_art.dart` |
| 204 | P1 | ZONE brass | elite=cyclops läcker fantasy; zone mer loot-vault än machine. | `lib/models/zone_art.dart` |
| 205 | P1 | ZONE veil | elite=spider — Mothveil blir spindelgrotta #4. | `lib/models/zone_art.dart` |
| 206 | P1 | ZONE veil | tank=ghost overlappar dead — Pale Monarch bärs av wash. | `lib/models/zone_art.dart` |
| 207 | P1 | ZONE veil | Pale Monarch vs spider/ghost trash — endgame climax ser ut som grove reprise. | `lib/models/zone_art.dart` |
| 208 | P1 | ZONE all | Bara fyra DungeonLayoutKind för 15 zoner — sen path känns som skin. | `lib/models/dungeon_def.dart` |
| 209 | P1 | ZONE all | Cyclops/bat/cultist/spider/golem återanvänds så hårt att wash gör jobbet ensam. | `lib/models/zone_art.dart` |
| 210 | P1 | ZONE all | Landmark barrel/crate/torch signerar sällan. | `lib/models/zone_art.dart` |
| 211 | P1 | GUIDE | BAG & GEAR tippar sell stash junk medan BAG Scrap/Sell är borta. | `lib/core/game_guides.dart` |
| 212 | P1 | GUIDE | CLASS UNLOCKS lägger Lv100-endgame i Ascend-listan — känns som AL-krav. | `lib/core/game_guides.dart` |
| 213 | P1 | GUIDE | MARKET-guiden tippar Sell stash junk som saknad knapp. | `lib/core/game_guides.dart` |
| 214 | P1 | GUIDE | GEAR PRESETS (hidden) syns i GUIDE och känns trasigt. | `lib/core/game_guides.dart` |
| 215 | P1 | GUIDE | KEYSTONE-guiden nämner inte Ashen Crown trots KEY-flik hem. | `lib/core/game_guides.dart` |
| 216 | P1 | GUIDE | ASCEND-guiden säger Lv100 men nämner inte AL20 utan KEY utan Lv100. | `lib/core/game_guides.dart` |
| 217 | P1 | GUIDE | Ingen GUIDE för Blessing Constellation. | `lib/core/game_guides.dart` |
| 218 | P1 | GUIDE | Ingen GUIDE för månadspass / CLAIM MONTH. | `lib/core/game_guides.dart` |
| 219 | P1 | GUIDE | Att visa hidden loadouts i GUIDE känns som bugg. | `lib/core/game_guides.dart` |
| 220 | P1 | GUIDE | Tips/GUIDE blandar party Lv100 med AL20 Blessing — lätt tro AL20=KEY. | `lib/core/game_guides.dart` |
| 221 | P1 | GUIDE | ESSENCE SHOP: God Hand CD "same as Forge KEEP" — dubbel sink. | `lib/core/game_guides.dart` |
| 222 | P1 | TIPS | SKIP ALL TIPS är grå sekundär — lätt att missa. | `lib/ui/first_session_tips.dart` |
| 223 | P1 | TIPS | SANCTUARY säger Spend essence here utan POWER→CAMP. | `lib/ui/first_session_tips.dart` |
| 224 | P1 | TIPS | MARKET tippar sell stash junk (dold vana). | `lib/ui/first_session_tips.dart` |
| 225 | P1 | TIPS | AFTER ASCEND och Rebuild-bag-chase kan dubbla copy. | `lib/ui/first_session_tips.dart` |
| 226 | P1 | TIPS | GAUNTLET-tip titel CRYSTAL SPIRE vs Infinity Gauntlet-confirm. | `lib/ui/first_session_tips.dart` |
| 227 | P1 | TIPS | PRESTIGE tip blandar SHOP och KEEP utan POWER-väg. | `lib/ui/first_session_tips.dart` |
| 228 | P1 | TIPS | Ingen tip för POWERUPS WATCH-chip. | `lib/ui/first_session_tips.dart` |
| 229 | P1 | TIPS | Ingen tip för Ashen Crown biljetter. | `lib/ui/first_session_tips.dart` |
| 230 | P1 | CONFIRM | Ascend-dialog lång utan scroll — riskerar klipp på 780 höjd. | `lib/ui/confirm_dialogs.dart` |
| 231 | P1 | CONFIRM | REBORN-confirm varnar inte att TODAY blir Rebuild bag. | `lib/ui/confirm_dialogs.dart` |
| 232 | P1 | OFFLINE | MARKET-knapp i Welcome Back stänger bara dialogen. | `lib/ui/meta_overlays.dart` |
| 233 | P1 | OFFLINE | KEY-chase i Welcome Back har ingen ENTER-handling. | `lib/ui/meta_overlays.dart` |
| 234 | P1 | OFFLINE | Lead Ascend moved på AL20-cap känns lögnaktigt. | `lib/core/game_logic.dart` |
| 235 | P1 | OFFLINE | READY visas bara om readyAction != null — KEY/unlockZone dör tyst. | `lib/ui/meta_overlays.dart` |
| 236 | P1 | CHASE | isClaimable inkluderar inte weekGoal trots Week READY i pulse. | `lib/core/chase_contract.dart` |
| 237 | P1 | TODAY | compact:true ger alltid 1 detail-rad — AL20-jakttext klipps. | `lib/ui/hub/hub_today_card.dart` |
| 238 | P1 | TODAY | Week READY syns utan CLAIM — spelaren vet inte auto-claim. | `lib/ui/hub/hub_today_card.dart` |
| 239 | P1 | AL20 | Run KEY +1 medan dial kan vara off tills ENTER. | `lib/core/hub_chase.dart` |
| 240 | P1 | AL20 | Ladder prioriterar GR före Gauntlet — fel one-hunt för Spire-fans. | `lib/core/hub_chase.dart` |
| 241 | P1 | AL20 | Ingen hub-yta för Ashen-biljettantal förutom chase-detail. | `lib/ui/hub_screen.dart` |
| 242 | P1 | AL20 | Practice nämns i toast/changelog men saknas som CTA. | `lib/core/game_director.dart` |
| 243 | P1 | AL20 | _weekGoalChase returnerar null när ready — ingen TODAY CLAIM WEEK. | `lib/core/hub_chase.dart` |
| 244 | P1 | AL20 | Constellation-poäng från Ashen/Trial förklaras inte i GUIDE/tips. | `lib/core/blessing_constellation.dart` |
| 245 | P1 | AL20 | Almost time KEY +2 cliff — offline saknar ENTER. | `lib/core/hub_chase.dart` |
| 246 | P1 | WHATS NEW | Äldre Loadout Folio-bullet motsäger 1.12.60. | `lib/core/meta_systems.dart` |
| 247 | P1 | WHATS NEW | Äldre SELL JUNK / SCRAP-buttons motsäger nuvarande BAG. | `lib/core/meta_systems.dart` |
| 248 | P1 | WHATS NEW | 1.12.60 och 1.12.59 bredvid varandra motsäger Ascend-wipe. | `lib/core/meta_systems.dart` |
| 249 | P1 | LAYOUT | Hub map blir frimärke under full chrome-stack. | `lib/ui/hub_screen.dart` |
| 250 | P1 | LAYOUT | Ascend-dialog actions kan hamna under fold. | `lib/ui/menu_chrome.dart` |
| 251 | P1 | A11Y | POWERUPS-chip under 44px touch floor. | `lib/ui/hub/hub_powerups.dart` |
| 252 | P1 | A11Y | composeTextScaler till 1.55 + Ascend dialog utan scroll = trasig layout. | `lib/ui/game_theme.dart` |
| 253 | P1 | OFFLINE | hasSummary ≥45s — kort AFK ger banner/dialog-inkonsekvens. | `lib/core/game_logic.dart` |
| 254 | P1 | AL20 | No tickets — try Practice utan Practice-entry är återvändsgränd. | `lib/core/game_director.dart` |
| 255 | P1 | LAYOUT | TODAY under map — ingen sticky chase på 360×780. | `lib/ui/hub_screen.dart` |
| 256 | P1 | LAYOUT | First tip maxHeight 42% + XL scale = GOT IT under fold. | `lib/ui/first_session_tips.dart` |
| 257 | P1 | AL20 | Rebuild bag "floors reset" kan tolkas som att zoner stängdes. | `lib/core/hub_chase.dart` |
| 258 | P1 | AL20 | Ingen tydlig +Xe week goal toast i Welcome Back. | `lib/ui/meta_overlays.dart` |
| 259 | P1 | POWERUPS | Guide/POWERUPS finns men tip-kö och chase nämner aldrig ad-boost. | `lib/ui/hub/hub_powerups.dart` |
| 260 | P2 | CHASE | ChaseContract readyActionLabel listar endgame-CTA:er som sällan blir primary. | `lib/core/chase_contract.dart` |
| 261 | P2 | CHASE | Up next ready: … upprepar urgency medan hub visar chip READY. | `lib/core/chase_contract.dart` |
| 262 | P2 | CHASE | marketUpgrade räknas inte claimable men beter sig som urgent ALMOST. | `lib/core/chase_contract.dart` |
| 263 | P2 | CHASE | progressLabel Ready bredvid chip READY är dubbel chrome. | `lib/core/hub_chase.dart` |
| 264 | P2 | CHASE | Chase-texter blandar ASCII-streck och tankstreck. | `lib/core/hub_chase.dart` |
| 265 | P2 | CHASE | KEY-detail nämner iLvl utan exempel på loot-hopp. | `lib/core/hub_chase.dart` |
| 266 | P2 | CHASE | Första Gauntlet-jakten utan wipe→hub eller boss-var-5. | `lib/core/hub_chase.dart` |
| 267 | P2 | CHASE | Rift-detail listar kills/timer utan dial/tier bredvid CTA. | `lib/core/hub_chase.dart` |
| 268 | P2 | CHASE | No mid-run gear i GR-detail lätt missad i 1-raders compact. | `lib/core/hub_chase.dart` |
| 269 | P2 | CHASE | När ladder tar slut jagar TODAY time KEY utan att säga fallback. | `lib/core/hub_chase.dart` |
| 270 | P2 | POWERUPS | Inaktiv WATCH · 3h säger inte gold/ATK — mystery-ad. | `lib/ui/hub/hub_powerups.dart` |
| 271 | P2 | POWERUPS | Header-multiplikator listar Ad ×2 gold / Ad +ATK medan chip säger ×2. | `lib/core/gold_income.dart` |
| 272 | P2 | POWERUPS | Sheet timing kring ad vs dismiss känns oklart. | `lib/ui/hub/hub_powerups.dart` |
| 273 | P2 | POWERUPS | STACKED TO 24H disabled utan nästa steg. | `lib/ui/hub/hub_powerups.dart` |
| 274 | P2 | HEADER | IDLE PARTY-titeln pulserar och konkurrerar med TODAY. | `lib/ui/hub/hub_header.dart` |
| 275 | P2 | HEADER | Guld/essence/AL-pills saknar labels. | `lib/ui/hub/hub_header.dart` |
| 276 | P2 | HEADER | AL 20 · MAX säger Ascend klar men inte nästa endgame-jakt. | `lib/ui/hub/hub_header.dart` |
| 277 | P2 | HEADER | Hub Xg/min syns alltid men irrelevant vid KEY/Gauntlet-TODAY. | `lib/ui/hub/hub_header.dart` |
| 278 | P2 | HEADER | Lång multiplikatorrad trunceras och gömmer Ad-delen. | `lib/ui/hub/hub_header.dart` |
| 279 | P2 | HEADER | När displayTitle finns döljs collectionScore. | `lib/ui/hub/hub_header.dart` |
| 280 | P2 | HEADER | Zone trophies döljs på phone-width. | `lib/ui/hub/hub_header.dart` |
| 281 | P2 | HEADER | Offline-rad säger TAP men headline kan redan vara wow-resultat. | `lib/ui/hub/hub_header.dart` |
| 282 | P2 | HEADER | Play-update-banner tar två knapprader för valfri nudge. | `lib/ui/hub/hub_header.dart` |
| 283 | P2 | MAP | HERE/CLEAR/OPEN/LOCKED utan NEXT-ord för frontier. | `lib/ui/hub/hub_world_map.dart` |
| 284 | P2 | MAP | Låsta zoner tryckbara men ENTER disabled — trasig select-känsla. | `lib/ui/hub/hub_world_map.dart` |
| 285 | P2 | MAP | Zonporträtt i cirklar ser lika Kenney-ikon ut. | `lib/ui/hub/hub_world_map.dart` |
| 286 | P2 | MAP | HERE-ringen pulserar som alarm bredvid TODAY ALMOST. | `lib/ui/hub/hub_world_map.dart` |
| 287 | P2 | MAP | Caption Name · Boss + blurb säger inte KEY/difficulty. | `lib/ui/hub/hub_world_map.dart` |
| 288 | P2 | MAP | Locked unlock text nämner inte clear av föregående zon. | `lib/ui/hub/hub_world_map.dart` |
| 289 | P2 | HUB | HubMetaPulse tom höjd även i first hour — död luft. | `lib/ui/hub/hub_today_card.dart` |
| 290 | P2 | HUB | KEY off i MetaPulse låter som bugg. | `lib/ui/hub/hub_today_card.dart` |
| 291 | P2 | HUB | CLAIM (2) säger inte QUESTS. | `lib/ui/hub/hub_today_card.dart` |
| 292 | P2 | HUB | DAILY · done disabled tar radplats efter claim. | `lib/ui/hub/hub_today_card.dart` |
| 293 | P2 | HUB | Urgent Ascend-label +Xe utan Blessing-rad — splittrad payoff. | `lib/ui/hub_screen.dart` |
| 294 | P2 | HUB | När Daily foldas till DAILY RUN försvinner TODAY-radens egen knapp. | `lib/ui/hub_screen.dart` |
| 295 | P2 | HUB | KEY-chase zoneId = recommended, inte den zon du tittar på. | `lib/core/hub_chase.dart` |
| 296 | P2 | HUB | Utan user pick syncas selected till recommended och flyttar HERE. | `lib/ui/hub_screen.dart` |
| 297 | P2 | HUB | Toast vid Alignment(0,-0.72) kan täcka guld-pills efter claim. | `lib/ui/hub_screen.dart` |
| 298 | P2 | HUB | Auto Whats New blockerar World Path innan TODAY syns. | `lib/ui/hub_screen.dart` |
| 299 | P2 | DUNGEON | Essence-chip saknas i compact-läge under KEY/Gauntlet. | `lib/ui/shell/dungeon_top_hud.dart` |
| 300 | P2 | DUNGEON | FittedBox krymper God Hand och guld tills svåra att träffa. | `lib/ui/shell/dungeon_top_hud.dart` |
| 301 | P2 | FARM/PUSH | Selected-state bara färg — ingen ikon loop vs climb. | `lib/ui/spatial_dungeon_view.dart` |
| 302 | P2 | FARM/PUSH | Efter boss-clear i PUSH till hub utan tydlig zon-klar-känsla i stage. | `lib/core/game_logic.dart` |
| 303 | P2 | GOD HAND | CD-ringen normaliserar mot 1.1s och ljuger när CD uppgraderad. | `lib/ui/spatial_dungeon_view.dart` |
| 304 | P2 | GOD HAND | Spacebar-God Hand finns för web — telefon utan quick smash-hint. | `lib/ui/is2_shell.dart` |
| 305 | P2 | GOD HAND | Fist-ikon 14px i 28px ring — lätt dekor, inte action. | `lib/ui/spatial_dungeon_view.dart` |
| 306 | P2 | PARTY HUD | Selected-hero-border tunn mot mörk panel. | `lib/ui/shell/dungeon_party_hud.dart` |
| 307 | P2 | PARTY HUD | Buff-taggar FLURRY/BEACON/ABS klipps på smal rad. | `lib/ui/shell/dungeon_party_hud.dart` |
| 308 | P2 | PARTY HUD | Shield-gated ability visar ! utan off-hand-förklaring. | `lib/ui/shell/dungeon_party_hud.dart` |
| 309 | P2 | PARTY HUD | Ability-tooltips kräver hover — telefon saknar long-press-beskrivning. | `lib/ui/shell/dungeon_party_hud.dart` |
| 310 | P2 | TARGET | Living Bomb hijackar target-HUD även när boss viktigare. | `lib/ui/shell/dungeon_target_hud.dart` |
| 311 | P2 | TARGET | Dormanta fiender i nästa chamber syns inte — tom karta-känsla. | `lib/ui/shell/dungeon_target_hud.dart` |
| 312 | P2 | TARGET | MaxWidth 168px klipper långa bossnamn. | `lib/ui/shell/dungeon_target_hud.dart` |
| 313 | P2 | WIPE | Daily echo-wipe-text tung att skanna. | `lib/ui/spatial_dungeon_view.dart` |
| 314 | P2 | WIPE | Advice kräver ≥2s fight — instant melt får tyst panel. | `lib/core/wipe_advice.dart` |
| 315 | P2 | WIPE | StreakNeeded=2 för FORGE men bag tippar wipe 1 — mönster oklart. | `lib/core/wipe_advice.dart` |
| 316 | P2 | FLOOR | Wide F± vs compact ⋯ — samma action, olika språk. | `lib/ui/shell/dungeon_top_hud.dart` |
| 317 | P2 | FLOOR | Gauntlet blockerar travel tyst — spelare söker menyn efter FARM-vana. | `lib/core/game_logic.dart` |
| 318 | P2 | FLOOR | Hoppa våning mid-chamber kastar progress utan varning. | `lib/ui/shell/dungeon_top_hud.dart` |
| 319 | P2 | CHAMBER | Prickar inte tryckbara — ingen chamber-översikt. | `lib/ui/spatial_dungeon_view.dart` |
| 320 | P2 | CHAMBER | Många chambers tränger God Hand i compact top. | `lib/ui/shell/dungeon_top_hud.dart` |
| 321 | P2 | CHAMBER | Active vs uncleared prickar svåra för färgblind utan formskillnad. | `lib/ui/spatial_dungeon_view.dart` |
| 322 | P2 | CLEAR | Boss-banner kan överlappa offline/clear-summary. | `lib/ui/spatial_dungeon_view.dart` |
| 323 | P2 | CLEAR | Gate closed/open saknar HUD-text chamber locked. | `lib/ui/spatial_dungeon_view.dart` |
| 324 | P2 | CLEAR | Loot vacuumas utan picked-up-lista — bara gold-chip. | `lib/ui/shell/dungeon_top_hud.dart` |
| 325 | P2 | DPS | Metern försvinner när peak=0 tidigt — tomt hörn sedan plötslig chip. | `lib/ui/shell/dungeon_party_hud.dart` |
| 326 | P2 | DPS | Öppen meter täcker karta utan dimma. | `lib/ui/is2_shell.dart` |
| 327 | P2 | DPS | Spec-taggar kapas till 4 tecken (COMBAT→COM). | `lib/ui/shell/dungeon_party_hud.dart` |
| 328 | P2 | NAV | Leave-copy mid-floor lost — FARM-loop-förlust otydlig. | `lib/ui/confirm_dialogs.dart` |
| 329 | P2 | NAV | Fyra nav-knappar på 360px trånga — HUB vs META under wipe. | `lib/ui/shell/app_bottom_bar.dart` |
| 330 | P2 | MAP | Zoom saknar in-dungeon kontroll för multi-chamber overview. | `lib/ui/spatial_dungeon_view.dart` |
| 331 | P2 | MAP | HudAboveNav kan täcka stairs nere till vänster. | `lib/ui/is2_shell.dart` |
| 332 | P2 | BAG | AUTO EQUIP och EQUIP N tävlar visuellt. | `lib/ui/shell/inventory_dock.dart` |
| 333 | P2 | BAG | Hint tap EQUIP N vs knappen AUTO EQUIP när count 0. | `lib/ui/shell/inventory_dock.dart` |
| 334 | P2 | BAG | AUTO MERGE lovar skippa upgrades utan lista vilka. | `lib/ui/shell/inventory_dock.dart` |
| 335 | P2 | BAG | Slotfilter via tom GEAR-ruta syns inte som chip i BAG. | `lib/ui/shell/inventory_dock.dart` |
| 336 | P2 | BAG | Statusrad blandar bättre items med generisk bagStatusLine. | `lib/ui/shell/inventory_dock.dart` |
| 337 | P2 | BAG | MERGE-kostnad syns men inte rarity/ilvl-utbyte. | `lib/ui/shell/inventory_dock.dart` |
| 338 | P2 | BAG | MERGE-tab syns sent via progressive menu. | `lib/ui/shell/inventory_dock.dart` |
| 339 | P2 | GEAR | Två RING-slots samma etikett. | `lib/ui/character_equip_panel.dart` |
| 340 | P2 | GEAR | Två CHARM-slots samma etikett. | `lib/ui/character_equip_panel.dart` |
| 341 | P2 | GEAR | OFFHAND kan bli SHIELD/TOME/OFFHAND utan sköld-krav-förklaring. | `lib/ui/character_equip_panel.dart` |
| 342 | P2 | GEAR | Hjälterad roleLabel·nivå utan kitnamn PROT/FIRE. | `lib/ui/character_equip_panel.dart` |
| 343 | P2 | GEAR | iLvl under dockan är snitt — stark vapen + svaga boots ser medel. | `lib/ui/character_equip_panel.dart` |
| 344 | P2 | GEAR | FLASK-slot ser ut som gear utan dungeon-hint. | `lib/ui/character_equip_panel.dart` |
| 345 | P2 | MARKET | Hero-filter visar inte om listing är upgrade. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 346 | P2 | MARKET | REFRESH-kostnad utan när gratis refresh återkommer. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 347 | P2 | MARKET | Flask/bandage-köp utan toast om bag full. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 348 | P2 | MARKET | Säljlista och gear listings delar scrollvärld. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 349 | P2 | MARKET | Ingen jämför-med-worn-badge innan köp. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 350 | P2 | FORGE | STA-köp visar +HP medan Blessing/CAMP säger STA. | `lib/ui/shell/forge_overlay.dart` |
| 351 | P2 | FORGE | ChoiceChip 1×/10×/ALL Material-default mitt i Kenney-meny. | `lib/ui/shell/forge_overlay.dart` |
| 352 | P2 | FORGE | Ascend-status claim on Hub i GOLD — knappen finns inte här. | `lib/ui/shell/forge_overlay.dart` |
| 353 | P2 | FORGE | Constellation LIGHT name (stat · N p) läses som kod. | `lib/ui/shell/forge_overlay.dart` |
| 354 | P2 | FORGE | God Hand BAL/FOCUS/WIDE utan radius/dmg-siffror på knappar. | `lib/ui/shell/forge_overlay.dart` |
| 355 | P2 | FORGE | Last floor Ns tippar sporadiskt — oregelbunden coaching. | `lib/ui/shell/forge_overlay.dart` |
| 356 | P2 | FORGE | HASTE/CRIT soft-cap nämns inte på knappen. | `lib/ui/shell/forge_overlay.dart` |
| 357 | P2 | FORGE | KEEP God Hand mastery CLAIM utan sektion milestones. | `lib/ui/shell/forge_overlay.dart` |
| 358 | P2 | QUESTS | DAILY/BOUNTY/SIDE-badges utan svårighetsförklaring. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 359 | P2 | QUESTS | IN PROGRESS-knapp disabled ser trasig ut. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 360 | P2 | QUESTS | ready to claim-rad duplicerar CLAIM och tar scrollplats. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 361 | P2 | KEY | Affix-sträng namnlista utan ikon/risknivå. | `lib/ui/meta_overlays.dart` |
| 362 | P2 | KEY | DAILY VAULT blandar season/clears/timed KEY som rapport. | `lib/ui/meta_overlays.dart` |
| 363 | P2 | KEY | Rifts/GR under samma KEY-flik konkurrerar utan en jakt. | `lib/ui/shell/power_meta_pillars.dart` |
| 364 | P2 | KEY | Week goal bits blandas in i KEYSTONE header — dial drunknar. | `lib/ui/meta_overlays.dart` |
| 365 | P2 | SETTINGS | iLvl-filter Off vs siffra utan preview. | `lib/ui/shell/settings_overlay.dart` |
| 366 | P2 | SETTINGS | Auto-sell och auto-disassemble nästan identiska UI. | `lib/ui/shell/settings_overlay.dart` |
| 367 | P2 | SETTINGS | Session log och Play Games nära RESET GAME. | `lib/ui/shell/settings_overlay.dart` |
| 368 | P2 | SETTINGS | Colorblind säger floaters — VFX-koppling otydlig. | `lib/ui/shell/settings_overlay.dart` |
| 369 | P2 | PRESTIGE | Progressbar 1–12 ser ut som XP men är prestige-cykel. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 370 | P2 | PRESTIGE | Gold-track har bulk; power/vitality/xp saknar motsvarande. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 371 | P2 | PRESTIGE | vitality-track vs STA i Blessing — samma grej, olika ord. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 372 | P2 | PRESTIGE | Blessing-rad i CAMP duplicerar FORGE KEEP. | `lib/ui/shell/jobs_market_sanctuary.dart` |
| 373 | P2 | POWER | FORGE/MARKET/CAMP scope RUN vs ACCOUNT tiny labels. | `lib/ui/shell/power_meta_pillars.dart` |
| 374 | P2 | META | QUESTS/KEY/SETTINGS — KEY kan kännas gömd bakom jargon. | `lib/ui/shell/power_meta_pillars.dart` |
| 375 | P2 | MENU | PARTY GEAR/BAG vs POWER MARKET sälj — två loot-hem. | `lib/ui/shell/power_meta_pillars.dart` |
| 376 | P2 | MENU | INCOME generator vs CAMP Gold Find — två guldkällor. | `lib/ui/shell/power_meta_pillars.dart` |
| 377 | P2 | KIT PROT | shortLabel Dvst för Devastate oläsbart utan WotLK-minne. | `lib/models/class_ability.dart` |
| 378 | P2 | KIT PROT | Revenge showInHud:false — block-fantasy syns aldrig. | `lib/models/class_ability.dart` |
| 379 | P2 | KIT DISC | Shield-chip förväxlas med warrior Shield Block. | `lib/models/class_ability.dart` |
| 380 | P2 | KIT DISC | PoM vs Arcane PoM delar förkortning. | `lib/models/class_ability.dart` |
| 381 | P2 | KIT FIRE | Frost Nova/Ice Block på Fire-kit utan utility-HUD-kontext. | `lib/models/class_ability.dart` |
| 382 | P2 | KIT FIRE | Combust/Pyro båda unlock 11 — HUD gömmer en signature. | `lib/models/class_ability.dart` |
| 383 | P2 | KIT FIRE | Living Bomb refresh-gate syns inte — DoT-uptid osynlig. | `lib/models/class_ability.dart` |
| 384 | P2 | KIT COM | SnD syns men combo-poäng syns inte bredvid. | `lib/models/class_ability.dart` |
| 385 | P2 | KIT COM | Blade Flurry Flurry generiskt vs Fury-fantasi. | `lib/models/class_ability.dart` |
| 386 | P2 | KIT ARMS | Storm-chip = Bladestorm kolliderar med Ret/Ele/Enh Storm. | `lib/models/class_ability.dart` |
| 387 | P2 | KIT ARMS | Overpower short Over säger inget om free proc. | `lib/models/class_ability.dart` |
| 388 | P2 | KIT ARMS | Rallying Cry Rally utan temporary HP-hint. | `lib/models/class_ability.dart` |
| 389 | P2 | KIT FURY | Slam delar etikett med Prot Shield Slam. | `lib/models/class_ability.dart` |
| 390 | P2 | KIT FURY | Wish/Ramp ser fluff tills tooltip. | `lib/models/class_ability.dart` |
| 391 | P2 | KIT HOLY_PAL | Shock-chip = Holy Shock vs Prot Shockwave Shock. | `lib/models/class_ability.dart` |
| 392 | P2 | KIT HOLY_PAL | SShield/Flash/Light trängs — heal-rotation synonymer. | `lib/models/class_ability.dart` |
| 393 | P2 | KIT HOLY_PAL | Consecration kan dyka sent i chip-prioritet. | `lib/models/class_ability.dart` |
| 394 | P2 | KIT PPROT | HotR/SoR/HoR/AShield/HShield akronymsoppa. | `lib/models/class_ability.dart` |
| 395 | P2 | KIT PPROT | Righteous Fury dold — holy-tank threat osynlig. | `lib/models/class_ability.dart` |
| 396 | P2 | KIT RET | TV/CS/HoW kräver guide — seal→CS→TV upptäcks inte. | `lib/models/class_ability.dart` |
| 397 | P2 | KIT RET | Bubble för Divine Shield — slang, inte invuln. | `lib/models/class_ability.dart` |
| 398 | P2 | KIT RET | Zealotry Zeal ser ut som resurs, inte CD. | `lib/models/class_ability.dart` |
| 399 | P2 | KIT BM | Aspect Hawk dold — hunter stance saknas. | `lib/models/class_ability.dart` |
| 400 | P2 | KIT BM | Wrath-chip = Bestial Wrath vs Balance Wrath. | `lib/models/class_ability.dart` |
| 401 | P2 | KIT MM | True/Trueshot Aura dold — MM aura osynlig. | `lib/models/class_ability.dart` |
| 402 | P2 | KIT MM | Volley/Rapid/True CD-trängsel gömmer signature. | `lib/models/class_ability.dart` |
| 403 | P2 | KIT SV | Mongo för Mongoose Bite oklart på telefon. | `lib/models/class_ability.dart` |
| 404 | P2 | KIT SV | Disengage Dis ser ut som disable. | `lib/models/class_ability.dart` |
| 405 | P2 | KIT ASSASS | Mut/Env/Gar/Rupt täta akronymer — poison syns inte. | `lib/models/class_ability.dart` |
| 406 | P2 | KIT ASSASS | FoK delas med Subtlety — AoE skiljer inte kits. | `lib/models/class_ability.dart` |
| 407 | P2 | KIT SUB | Dance/Step/Prem kräver WotLK — opener göms. | `lib/models/class_ability.dart` |
| 408 | P2 | KIT SUB | Preparation Prep läses som ready-check. | `lib/models/class_ability.dart` |
| 409 | P2 | KIT HOLY_PRI | DP = Desperate Prayer vs Shadow Devouring Plague DP. | `lib/models/class_ability.dart` |
| 410 | P2 | KIT HOLY_PRI | CoH/GS/Hymn trängs; Flash delas med Disc/Holy Pal. | `lib/models/class_ability.dart` |
| 411 | P2 | KIT SHADOW | VT/SWP/DP DoT-soppa utan hur många DoTs uppe. | `lib/models/class_ability.dart` |
| 412 | P2 | KIT SHADOW | Dispersion Disp ser ut som dispel. | `lib/models/class_ability.dart` |
| 413 | P2 | KIT BLOOD | Alla DK Presence heter Pres — skiljs inte. | `lib/models/class_ability.dart` |
| 414 | P2 | KIT BLOOD | Dark Command DC ser ut som disconnect. | `lib/models/class_ability.dart` |
| 415 | P2 | KIT BLOOD | Bone Shield Bones läses som prop, inte absorb. | `lib/models/class_ability.dart` |
| 416 | P2 | KIT FROST_DK | Oblit/FS/Howl OK för fans; Hunger/Pillar saknar frost-ikon. | `lib/models/class_ability.dart` |
| 417 | P2 | KIT UNHOLY | Blood Boil Boil delas med Blood DK. | `lib/models/class_ability.dart` |
| 418 | P2 | KIT UNHOLY | AMS kortform utan anti-magic-hint. | `lib/models/class_ability.dart` |
| 419 | P2 | KIT ELE | Storm = Thunderstorm kolliderar med melee Storm-chips. | `lib/models/class_ability.dart` |
| 420 | P2 | KIT ELE | Shock = Earth Shock vs Holy Shock. | `lib/models/class_ability.dart` |
| 421 | P2 | KIT ENH | Stormstrike Storm värst av Storm-kollisionerna. | `lib/models/class_ability.dart` |
| 422 | P2 | KIT ENH | SRage/FShock ser ut som typos. | `lib/models/class_ability.dart` |
| 423 | P2 | KIT RSHAM | Rip = Riptide vs Feral Rip. | `lib/models/class_ability.dart` |
| 424 | P2 | KIT RSHAM | Chain = Chain Heal vs Ele Chain Lightning. | `lib/models/class_ability.dart` |
| 425 | P2 | KIT RSHAM | Spirit Link Link säger inte damage-split. | `lib/models/class_ability.dart` |
| 426 | P2 | KIT ARC | PoM = Presence of Mind vs Disc Prayer of Mending. | `lib/models/class_ability.dart` |
| 427 | P2 | KIT ARC | AP-chip läses som Attack Power, inte Arcane Power. | `lib/models/class_ability.dart` |
| 428 | P2 | KIT FRMAGE | Block = Ice Block vs Prot Block. | `lib/models/class_ability.dart` |
| 429 | P2 | KIT FRMAGE | Water Elemental Water utan pet-timer. | `lib/models/class_ability.dart` |
| 430 | P2 | KIT FRMAGE | Nova = Frost Nova vs Fire Blast Wave party-noise. | `lib/models/class_ability.dart` |
| 431 | P2 | KIT AFF | UA/Corr/Agony/Seed DoT-alfabet — Haunt Burst säger inte DoT-pop. | `lib/models/class_ability.dart` |
| 432 | P2 | KIT AFF | Burn = Soulburn läses som destruction burn. | `lib/models/class_ability.dart` |
| 433 | P2 | KIT DEMO | HoG/Meta/Sac/Know hård WotLK-kod; Demonic Knowledge dold. | `lib/models/class_ability.dart` |
| 434 | P2 | KIT DEMO | Chaos Bolt delas med Destruction. | `lib/models/class_ability.dart` |
| 435 | P2 | KIT DEMO | Demonic Sacrifice Sac känns permanent loss. | `lib/models/class_ability.dart` |
| 436 | P2 | KIT DESTRO | Cata passiv dold; Conf/Draft/RoF/Immo kräver guide. | `lib/models/class_ability.dart` |
| 437 | P2 | KIT DESTRO | Ward-chip säger inte absorb/magic-shield. | `lib/models/class_ability.dart` |
| 438 | P2 | KIT BAL | Moonkin Form Form dold — owl-fantasi saknas. | `lib/models/class_ability.dart` |
| 439 | P2 | KIT BAL | Fall/Hurri/Typh avhuggna — Starfall tappas. | `lib/models/class_ability.dart` |
| 440 | P2 | KIT FERAL | TF/SI akronymer; Rip vs Riptide. | `lib/models/class_ability.dart` |
| 441 | P2 | KIT FERAL | Bite/Shred/Rake utan combo-punkt i HUD. | `lib/models/class_ability.dart` |
| 442 | P2 | KIT GUARD | Bear Form dold — bear-tank osynlig tills Growl. | `lib/models/class_ability.dart` |
| 443 | P2 | KIT GUARD | Berserk delas med Feral — ingen bear-skillnad. | `lib/models/class_ability.dart` |
| 444 | P2 | KIT GUARD | FR vs Fury EReg — två regen-akronymer. | `lib/models/class_ability.dart` |
| 445 | P2 | KIT RDRU | Tree of Life dold. | `lib/models/class_ability.dart` |
| 446 | P2 | KIT RDRU | NS delas med Resto Shaman. | `lib/models/class_ability.dart` |
| 447 | P2 | KIT HUD | Prioritering alfabetisk vid lika rank — rotation blir A–Z. | `lib/ui/shell/dungeon_party_hud.dart` |
| 448 | P2 | KIT HUD | Tooltip 350ms hover-modell; telefon behöver long-press hint. | `lib/ui/shell/dungeon_party_hud.dart` |
| 449 | P2 | KIT HUD | gated shield-abilities Name! utan equip shield-rad. | `lib/ui/shell/dungeon_party_hud.dart` |
| 450 | P2 | KIT | Flera shortLabels Stance/Pres/Form/Aura — kits utbytbara. | `lib/models/class_ability.dart` |
| 451 | P2 | KIT | Unlock hints syns i data men sällan som fantasy i Meet-flow. | `lib/models/hero_spec.dart` |
| 452 | P2 | ZONE sandy | Wash sandig men props mest barrel/crate. | `lib/models/zone_art.dart` |
| 453 | P2 | ZONE sandy | support=cultist läcker bakåt till senare zoner. | `lib/models/zone_art.dart` |
| 454 | P2 | ZONE sandy | normalRoomChestChance 0.05 — chest-fantasi svag vs hatch. | `lib/models/zone_art.dart` |
| 455 | P2 | ZONE sandy | glass=mite bra; brute crab utan water-theme. | `lib/models/zone_art.dart` |
| 456 | P2 | ZONE goblin | brute=crab delas med sandy/tide. | `lib/models/zone_art.dart` |
| 457 | P2 | ZONE goblin | support=ghost förväxlas med City of Dead. | `lib/models/zone_art.dart` |
| 458 | P2 | ZONE goblin | chest i props och landmarks — chest-spam-risk. | `lib/models/zone_art.dart` |
| 459 | P2 | ZONE king | wallBanner hjälper men trash fortfarande generic fort. | `lib/models/zone_art.dart` |
| 460 | P2 | ZONE king | anvil landmark läser forge mer än throne. | `lib/models/zone_art.dart` |
| 461 | P2 | ZONE king | Corrupt King vs king-mite — corrupt syns inte i trash. | `lib/models/zone_art.dart` |
| 462 | P2 | ZONE underworld | Beholder-boss men spider elite — eye-fantasi bara boss. | `lib/models/zone_art.dart` |
| 463 | P2 | ZONE underworld | purple wash OK; props overlappar dead/hell. | `lib/models/zone_art.dart` |
| 464 | P2 | ZONE underworld | corridorShade mer transparent — kan kännas ljusare än hell. | `lib/models/zone_art.dart` |
| 465 | P2 | ZONE dead | elite/tank/ranged/glass=ghost — pack monoton. | `lib/models/zone_art.dart` |
| 466 | P2 | ZONE dead | trash dead-mite svag mot ghost-väggen. | `lib/models/zone_art.dart` |
| 467 | P2 | ZONE dead | support cultist bryter undead-tema. | `lib/models/zone_art.dart` |
| 468 | P2 | ZONE dead | normalRoomChestChance 0.1 — inte grave goods. | `lib/models/zone_art.dart` |
| 469 | P2 | ZONE hell | lava landmarks bra; layoutKind hideout undergräver gate. | `lib/models/dungeon_def.dart` |
| 470 | P2 | ZONE hell | Cthulhu-boss vs cultist-pests — lore vs trash mismatch. | `lib/models/dungeon_def.dart` |
| 471 | P2 | ZONE hell | chtulu bossId stavning vs Cthulhu namn — glitch om synlig. | `lib/models/dungeon_def.dart` |
| 472 | P2 | ZONE crystal | arena+crystal roster starkt; fountain/anvil props svaga. | `lib/models/zone_art.dart` |
| 473 | P2 | ZONE crystal | Gauntlet återanvänder Crystal Spire — same-feel-risk. | `lib/models/dungeon_def.dart` |
| 474 | P2 | ZONE crystal | support/glass/ranged wraith — mite bär för mycket. | `lib/models/zone_art.dart` |
| 475 | P2 | ZONE crystal | landmarks pillar/fountain/chest — kristallprop saknas. | `lib/models/zone_art.dart` |
| 476 | P2 | ZONE tide | layoutKind cave — hold saknar fort-grammatik. | `lib/models/dungeon_def.dart` |
| 477 | P2 | ZONE tide | elite/brute/tank/support crab — crab overload. | `lib/models/zone_art.dart` |
| 478 | P2 | ZONE tide | support=crab gör healer-arketyp osynlig. | `lib/models/zone_art.dart` |
| 479 | P2 | ZONE tide | preferTreasureAlcove + water — pool+chest, inte drowned fort. | `lib/models/zone_art.dart` |
| 480 | P2 | ZONE ember | layoutKind fort overlappar king/dead. | `lib/models/dungeon_def.dart` |
| 481 | P2 | ZONE ember | brute=cyclops — vault-guards saknar ashen silhouette. | `lib/models/zone_art.dart` |
| 482 | P2 | ZONE ember | normalRoomChestChance 0.10 — vault borde vara chestigare. | `lib/models/zone_art.dart` |
| 483 | P2 | ZONE grove | layoutKind cave — saknar canopy/glänta. | `lib/models/dungeon_def.dart` |
| 484 | P2 | ZONE grove | support bat/ranged rat — skog bärs av wash. | `lib/models/zone_art.dart` |
| 485 | P2 | ZONE storm | layoutKind arena hjälper; purple wash kan läsas underworld. | `lib/models/zone_art.dart` |
| 486 | P2 | ZONE storm | projectileTint gul vs wash lila — splittrad feel. | `lib/models/zone_art.dart` |
| 487 | P2 | ZONE storm | glass=rat — storm glass-cannon saknar blixt-siluett. | `lib/models/zone_art.dart` |
| 488 | P2 | ZONE storm | Storm Tyrant vs bat elite — boss drop-off efter pull. | `lib/models/zone_art.dart` |
| 489 | P2 | ZONE rime | elite/brute/tank=golem — rimeglass bärs av mite+wash. | `lib/models/zone_art.dart` |
| 490 | P2 | ZONE rime | layoutKind cave — rift saknar glass-chasm grammar. | `lib/models/dungeon_def.dart` |
| 491 | P2 | ZONE rime | support/ranged=ghost — same as dead palette. | `lib/models/zone_art.dart` |
| 492 | P2 | ZONE fen | water+poison bra; elite/tank spider overlappar grove/veil. | `lib/models/zone_art.dart` |
| 493 | P2 | ZONE fen | layoutKind cave — mire vill ha open bog. | `lib/models/dungeon_def.dart` |
| 494 | P2 | ZONE fen | support cultist bryter blight-tema. | `lib/models/zone_art.dart` |
| 495 | P2 | ZONE fen | Fen Hydra vs spider/slime — hydra saknas i pack silhouette. | `lib/models/zone_art.dart` |
| 496 | P2 | ZONE brass | ranged bat/support cultist — saknar automaton trash. | `lib/models/zone_art.dart` |
| 497 | P2 | ZONE brass | layoutKind cave undergräver vault deep architecture. | `lib/models/dungeon_def.dart` |
| 498 | P2 | ZONE brass | hatch landmark = sandy hatch — samma prop. | `lib/models/zone_art.dart` |
| 499 | P2 | ZONE brass | Blurb something still ticks — ingen UI-tick-hint. | `lib/models/dungeon_def.dart` |
| 500 | P2 | ZONE veil | layoutKind hideout — silk/moth saknar chamber-grammar. | `lib/models/dungeon_def.dart` |

## Fördelning

- **P0:** 38
- **P1:** 221
- **P2:** 241
- **P3:** 0
- **Totalt:** 500

## Hur listan byggdes

Systematisk sweep: hub TODAY/CTA/map/POWERUPS → dungeon HUD/wipe/God Hand → BAG/GEAR/MARKET/FORGE/QUESTS/KEY → 31 kits (HUD/fantasi) → 15 zoner (art/layout) → guides/tips/dialogs/offline → AL20 endgame → 360×780/a11y. Deduplicerad och kapad till exakt 500.

När du vill fixa: säg **fixa top 20**, eller lista ID:n (t.ex. `001, 007, 044`).
