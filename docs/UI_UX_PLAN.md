# UI-ombyggnad: Brick Inc-struktur i Idle Party-stil

Skriven 2026-11-03. Källor: ägarens ChatGPT-chatt
(<https://chatgpt.com/share/6ae9f80e-92f0-83eb-b208-a85e15797465>), ägarens
20 skärmbilder från Brick Inc (Idle Breaker, v2.7.1) och en genomläsning av
`lib/ui/`. Tokens och regler står kvar i `docs/UI_THEME.md`; den här filen är
ombyggnadens ordning.

## Beslut

Vi **bygger om menyskalet**, inte spelet. `GameState`, `GameDirector`,
`MenuRouter`, `SpatialCombat` och all logik i dockorna står kvar. Det som
byts är hur varje sida ramas in, hur rader och kort ser ut, bottenraden och
hubbens upplägg.

Vi tar **Brick Inc:s struktur** (fast huvud, sidmall med scenbanner, en
radmall, flikar nere vid tummen, färg per avdelning). Vi tar **inte** deras
konst eller neon-tecknade stil. Färgerna förblir sten, fackla och pergament,
men varje avdelning får en starkare egen accentfärg, och alla rutor får tjock
mörk kontur och fasning (pixelteknik som passar oss).

Det går att bygga om utan att röra logiken därför att **alla menyer redan går
genom ett ställe**: `MenuSurface` → `OverlayScrim` → dock
(`lib/ui/shell/menu_surface.dart`). En ny sidmall ersätter `OverlayScrim`;
dockorna flyttar in i den en i taget.

## Vad Brick Inc gör (från bilderna)

| # | Mönster | Var i bilderna |
|---|---|---|
| A | **Fast huvud** på alla sidor: premiumvaluta, sidans valuta (byts per sida), rang-märke i mitten, kraft, x2-boost, meny | Alla |
| B | **Sidmall**: scenbanner med illustration + titelskylt, varningsrand, en regelrad, innehåll, **underflikar längst ner**, tillbaka-knapp nere till vänster | Epic Upgrade, Soul Altar, Innovation Lab, Demon Cult, War AI |
| C | **Färg per avdelning**: Epic lila, Soul orange, Enhancement grön, Corruption röd, Decay gul-grön, Curse lila | Alla avdelningar |
| D | **En radmall** för uppgraderingar: ikonruta, namn, effekt "nu → nästa", stapel `Lv x/y`, stor knapp till höger med pris och `×N`, eller svart `MAX` | Epic Upgrade, Soul Upgrade, Innovation, Corruption |
| E | **Massköp** `1% / 5% / 25% / 100%` och ett **Assist**-läge per sida; en egen sida med alla automatiseringar som brytare | Soul Upgrade, System Admin |
| F | **Samlingsrutnät** i band per sällsynthet (grå/grön/blå/lila), kort med `Lv`, delar `x/y`, "Not Obtained" | Card, Mythic Card |
| G | **Avdelningsrutnät**: 2×3 stora illustrerade rutor som dörrar | Epic / System Admin / Soul / Science / Dimension / Art Society |
| H | **Intäktsytor**: närvarokort 10 stämplar + pass, summon med 1/10 försök och pity-stapel `3/50` | Prism Shop |
| I | **Bottenrad** med 5 platser och **stor upphöjd mittknapp** (striden); X ersätter den flik man står i | Alla |
| J | Scen överst med nivåmärke och "Touch to Open" | Innovation Lab, Demon Cult, War AI |

Vi tar inte med: sifferregn över striden (ägaren klagade 2026-10-17 och det
är fixat), röd prick på nästan allt, eller enorma siffersuffix (`li`, `pb`).

## Hur det passar Idle Party

| Mönster | Hos oss idag | Ombyggt |
|---|---|---|
| A huvud | `WalletStrip` i varje ark, guld + essence | `GlobalHeader`: Cinders, sidans valuta (guld i GOLD, essence i ESSENCE), AL-märke i mitten, partykraft, SCROLLS-boost med timer, inställningar |
| B sidmall | `OverlayScrim` + `MenuChrome.tabRail` **överst** | `PageFrame`: banner, rand, regelrad, kropp, underflikar **nere**, tillbaka |
| C färg | `GameTheme.nav*` per bottenflik finns | Samma färg blir sidans accent (banner, rand, aktiv flik, radkant) |
| D rad | `PowerUpgradeRow` delas redan av FORGE och sanctuary | Bygg om den till mallen ovan; CAMP, BLESSING, Apex, relics och KEY-rader använder samma |
| E massköp | `MenuChrome.segmented` för ×1 / 5% finns i FORGE/sanctuary | En `BulkBuyBar` (1% / 5% / 25% / MAX) på alla köpsidor. Sidan **AUTO** under MORE: AUTO EQUIP, `autoCaveOnLeave`, sälj skräp, auto-merge |
| F samling | Relics, pets, CODEX är listor | `CollectionGrid` i sällsynthetsband; fixar samtidigt epic-färgen (se nedan) |
| G avdelningar | ESSENCE och MORE är flikrader | ESSENCE = 2×2 rutor (CAMP, BLESSING, RELICS, PETS). MORE = 2×2 (QUESTS, CRAFT, SETTINGS, INFO) |
| H intäkt | Daily Vault check-in 1/7, Supporter, scrolls | Närvarokortet ritas som stämpelkort. Piggy Bank och summon med pity är **nya IAP/gacha** (flaggas) |
| I bottenrad | GEAR · GOLD · SHOP · ESSENCE · MORE (+KEY, LEAVE) | Mittknapp = ENTER på hubben / FIGHT-vy i dungeon. GEAR, GOLD vänster; ESSENCE, SHOP höger; MORE flyttar till huvudet (menyknappen) |
| J scen | Hub-scen finns | Varje avdelning får en liten scenbanner i stället |

## Hål som ombyggnaden ska stänga

1. **Epic har tre färger**: guld i bagen (`rarityBorderColor` →
   `borderLit`, `shell/shell_common.dart`), lila i tooltip (`tooltipEpic`),
   ljusgul på golvet (`dungeon_tile_painter.dart` ~425). Brick Inc:s band
   grå/grön/blå/lila/orange är exakt den skala vi behöver. Ny
   `GameTheme.rarityEpic`, alla läser samma funktion.
2. **Platta gradientpaneler** (`MenuChrome.panel`/`cardBox`, radie 12/18).
   Ersätts av egna 9-slice-ramar. De oanvända PNG:erna i
   `assets/custom/ui/chrome/` har namn som liknar ett färdigt UI-paket.
   **Används inte** förrän ursprunget är bekräftat; vi ritar nya.
3. **167 siffer-`EdgeInsets`** i `lib/ui`. Nya mallar använder bara
   `edgeGap`/`clusterGap`; gamla försvinner när en sida flyttas.
4. **Feta filer**: `dungeon_party_hud` 1502, `spatial_dungeon_view` 1437,
   `dungeon_top_hud` 1046, `inventory_dock` 1046, `hub_screen` 1033. Den som
   flyttas till nya mallen delas först.

## Faser

Varje fas: egen PR, `flutter analyze lib test --no-fatal-infos` rent,
matchande tester gröna. Nytt UI under `lib/ui/shell/` (mallar i
`lib/ui/shell/frame/`). All konst egen, via `CustomAssets`. Knappetiketter
behålls så `WebClickBridge`, playtest och `hub_widget_smoke_test` hittar dem.

### R0: Stilprov på en sida (ägaren väljer)

- Bygg **ESSENCE** i ny mall bakom en dev-flagga: huvud, banner, 2×2-rutor,
  CAMP-sidan med nya raden och massköp.
- Rita egen konst för just det: en 9-slice-ram, en banner (lägereld), fyra
  rutbilder. Generator `tool/generate_ui_frame.py` i samma pixelstil som
  `tool/gear_style.py`.
- Före/efter på A56 (360×780), även textskala 1.40.
- **Ägaren väljer** stil här. Inget annat byggs om förrän det är klart.

### R1: Skalet

- `GlobalHeader`, `PageFrame` (banner, rand, regelrad, kropp, underflikar
  nere, tillbaka), ny `AppBottomBar` med mittknapp.
- `MenuSurface` byter `OverlayScrim` mot `PageFrame`. Dockorna står kvar
  inuti, så allt fungerar direkt, bara med ny ram.
- Flaggan tas bort när R1 är godkänd; gamla `OverlayScrim` raderas (vi håller
  inte två skal).
- Före/efter: hela appen.

### R2: Komponenterna

- `UpgradeRow` (ombyggd `PowerUpgradeRow`), `BulkBuyBar`, `CollectionGrid`
  med sällsynthetsband, `DeptTileGrid`, `PageBanner`, `StatPill`,
  `StampCard`.
- Epic-färgen fixas här (hål 1) med ett test som låser fem olika färger och
  samma familj i bag, tooltip och golv.
- Rad i `docs/UI_THEME.md` per ny helper.

### R3: Sidorna, en i taget

Ordning efter risk, enklast först:

1. **ESSENCE** (från R0): CAMP, BLESSING, RELICS (samlingsrutnät), PETS
   (samlingsrutnät).
2. **GOLD**: FORGE (radmall + massköp), MARKET.
3. **SHOP**: kort med ikon, vad du får i en mening, pris från Play. Inga
   påhittade "bästa värde"-märken. Forever-scrolls och Cinder-pouch syns bara
   när Play listar dem (som nu).
4. **MORE** som 2×2-rutor + ny **AUTO**-sida.
5. **KEY**.
6. **GEAR** sist: docka + bag + MERGE är mest komplext.
   `inventory_dock.dart` delas först.

Före/efter per sida.

### R4: Hubben

- Hubben får samma huvud. TODAY-kortet och PATH-atlasen får nya ramar;
  markörer låst sten / öppen fackla / rensad krona.
- Genvägar med prick längs kanten: SCROLLS, QUESTS, Daily Vault, erbjudande.
  En prick betyder "något att hämta", inget annat.
- `hub_screen.dart` delas först. Före/efter.

### R5: Striden

- Striden i övre ~55 %, en **fast panel** nedtill med hjältekort (bild,
  nivå, HP/mana, DPS) i stället för den svävande partyraden.
- Bossbar överst med namn och fasmarkörer.
- Inget nytt får lägga en extra ram per steg; jämför `[IP]`-loggen på A56
  före och efter. `VfxQuality.minimal` respekteras.
- `dungeon_party_hud.dart` delas först. Före/efter.

### R6: Intäktslagret (flaggas)

- **Närvarokort**: Daily Vault ritas som 7-stämpelkort (logiken finns).
- **Piggy Bank** (ny IAP): fylls med Cinders från strid, köps via Play.
  Kräver en produkt i Play Console innan den visas.
- **Summon med pity** (gacha, tillåten enligt SHOP-låset): 1/10 försök,
  synlig pity-stapel. Egen design-PR innan kod.
- x2-boost i huvudet läser befintliga SCROLLS-biljetter.
- Mät med events i `docs/ANALYTICS.md`. Inga påhittade procent.

### R7: Städning och QA

- Skill `accessibility-auditing`: etiketter, 44/48 px, textskala 1.40,
  färgblindläge, Minimal VFX.
- Radera gamla helpers som ingen använder (`OverlayScrim`, gamla `panel`-
  gradienter). Behåll JSON-fält som gamla sparningar har.
- `flutter test --exclude-tags sim`, `ship_smoke_test`, `ui_theme_test`,
  `hub_widget_smoke_test`. Patch Notes.
- Uppdatera `AGENTS.md` (arkitekturträdet: bottenrad och skal ändras) och
  `.cursor/rules/where-screens-live.mdc` (MORE flyttar, AUTO-sidan).
- Ny Play-uppsättning skärmbilder (skill `store-listing-shoot`); de gamla
  ljuger efter ombyggnaden.

## Storlek och risk

| Fas | Rör | Konst | Ägaren väljer | Risk |
|---|---|---|---|---|
| R0 | ESSENCE bakom flagga | Ram, 1 banner, 4 rutor | **Ja, stilen** | Låg |
| R1 | `MenuSurface`, ny `AppBottomBar`, huvud | Ram | Ja | Medel: navigering, tester som letar etiketter |
| R2 | Nya widgets, rarity | Ikonramar | Nej | Låg |
| R3 | 6 sidor | ~6 banners | Ja, per sida | Medel på GEAR |
| R4 | Hub | Markörer | Ja | Medel |
| R5 | Strids-HUD | Hjältekortsram | Ja | Medel–hög: bildhack, plats för striden |
| R6 | SHOP, ny IAP/gacha | Gris, summon | Ja | Play-produkt krävs |
| R7 | Tester, docs, städning | Play-bilder | — | Låg |

Mest arbete ligger i **konsten**: runt 15 egna bilder (ramar, banners,
rutor) innan R3 är klar. Mest risk ligger i **R1** (bottenraden ändras för
alla) och **R5** (striden).

R0 kan börja direkt. Allt efter väntar på ägarens val i R0.
