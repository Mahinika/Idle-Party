# UI/UX-plan: Premium Dark Fantasy Pixel

Skriven 2026-11-03 utifrån ChatGPT-chatten
<https://chatgpt.com/share/6ae9f80e-92f0-83eb-b208-a85e15797465> och en
genomläsning av `lib/ui/`. Ägaren väljer före/efter på A56 för varje fas som
byter en hel skärm. Tokens och regler står kvar i `docs/UI_THEME.md`; den här
filen är bara ordningen och vad varje steg rör.

## Beslut

Vi bygger en **premiumversion av det spelet redan är**, inte ett nytt
designsystem. ChatGPT:s stil (mörk sten, gammalt guld, dämpad turkos, pixelart
i världen, läsbar text i menyer) är redan grunden i `GameTheme`. Det som
saknas är **material** (sten/metall i stället för platta gradienter), **ett
enda sällsynthetsspråk**, och **striden som huvudscen**.

## Vad ChatGPT-prompten föreslog och vad som redan finns

| ChatGPT-fas | Läget i koden | Vad vi gör |
|---|---|---|
| 1 Analys | Klar nedan (hål 1–5) | Fas 0 tar bara baslinjebilder |
| 2 Designstrategi | `docs/UI_THEME.md`: familjer, knapphierarki, RUN/TODAY/ACCOUNT | Ingen ny strategi-fil |
| 3 Designsystem | `GameTheme` + `MenuChrome` + `GameButton` + `GameIcon`. `test/ui_theme_test.dart` stoppar rå färg. 0 Material `Icons` i `lib/ui` | Lägg till det som saknas, bygg inte om |
| 4 Implementation | — | Fas 1–7 nedan |
| 5 Visuell QA | `a56-playtest`, `tool/adb_see.py` | Före/efter per fas |
| 6 Rapport | Handoff + Patch Notes | Som vanligt |

Vi tar **inte** med: "vänta inte på godkännande" för hela skärmar, nya
beroenden, Material-komponenter, ett andra designsystem-dokument, eller att
göra om bottenraden från grunden.

## Hål i koden idag

1. **Panelerna är platta kodgradienter.** `MenuChrome.panel`, `cardBox` och
   `hubPanel` ritar gradient + tunn kant med radie 12/18. Det är just det
   ChatGPT varnade för: "överdrivet rundade kort", och ingen sten eller
   metall. I `assets/custom/ui/chrome/` finns `panel_*`, `button_*`, `bar_*`
   och `progress_*`, men ingen av dem ritas (`panel_brown` har bara en
   sökväg). **Kolla ursprunget** innan någon av dem används: namnen liknar
   ett färdigt UI-paket. Är de inte våra ritar vi nya (Legal-låset).
2. **Epic har tre färger.** I bagen är epic guld (`rarityBorderColor` →
   `GameTheme.borderLit`, `lib/ui/shell/shell_common.dart`), i tooltipen lila
   (`tooltipEpic`), och på golvet ljusgul (`dungeon_tile_painter.dart` rad
   ~425). Legendary är orange. Guld krockar också med "valt"-kanten
   (`torchHot`/`borderLit`). Spelaren kan inte lära sig skalan.
3. **Avstånd utanför token.** 167 `EdgeInsets` med siffror i `lib/ui`
   (mest i `menu_chrome`, `dungeon_party_hud`, `challenge_toggles`,
   `inventory_dock`), fast regeln säger `edgeGap` 12 / `clusterGap` 8.
4. **Feta UI-filer.** `dungeon_party_hud.dart` 1502 rader,
   `spatial_dungeon_view.dart` 1437, `dungeon_top_hud.dart` 1046,
   `inventory_dock.dart` 1046, `hub_screen.dart` 1033. Dela den fil en fas
   rör innan den växer.
5. **Tre typsnitt, VT323 som brödtext (17).** Press Start för HUD, Cinzel för
   rubriker, VT323 för allt annat. Om VT323 på 17 är för tunt på A56 vet vi
   inte än. Det är en hypotes som fas 0 ska titta på, inte ett fynd.

## Faser

Varje fas: egen branch/PR, `flutter analyze lib test --no-fatal-infos` rent,
matchande tester gröna, före/efter-bild på A56 (360×780) när en hel skärm
ändras. Nytt UI under `lib/ui/shell/`. All konst via `CustomAssets`.

### Fas 0: Baslinje (inga kodändringar)

- Tolv bilder på A56 med samma sparning: start, hub (TODAY + PATH), hub
  ENDGAME, strid FARM, strid boss, wipe, GEAR, GOLD → FORGE, SHOP,
  ESSENCE → CAMP, MORE → QUESTS, What's New.
- Samma tolv igen med textskala 1.40 och färgblindläge.
- Lista vad som klipps, överlappar eller läses dåligt. Det blir checklistan
  för fas 1–7.
- Ut: bilder i `playshots/` (gitignorerad) + en kort lista i handoffen.

### Fas 1: Token-pass (små ändringar, skeppas utan före/efter)

- En sällsynthetsskala: lägg `GameTheme.rarityEpic` (lila, samma familj som
  `tooltipEpic`). Bag, tooltip, golvdrop och CODEX läser samma
  `rarityBorderColor`. Guld blir bara "valt" och "legendary-glöd".
- Ett test som låser att alla fem sällsyntheter har olika färg och att bag
  och tooltip är samma färgfamilj.
- Byt siffer-`EdgeInsets` mot `edgeGap`/`clusterGap` i de filer en fas ändå
  rör. Ingen massändring i ett svep.
- Filer: `game_theme.dart`, `shell/shell_common.dart`, `item_tooltip.dart`,
  `dungeon_tile_painter.dart`, `docs/UI_THEME.md` (en rad).

### Fas 2: Sten och metall (ny egen chrome-konst)

- Rita egna 9-slice-ramar: menypanel (mörk sten, guldnit i hörnen), kort
  (inset sten), flikrad, och tre knappytor (brown/grey/red) i samma stil som
  `tool/gear_style.py`. Generator: `tool/generate_ui_chrome.py` → 
  `assets/custom/ui/chrome/` (nya namn).
- `MenuChrome.panel`/`cardBox`/`listCard` ritar ramen via `CustomAssets`;
  gradienten finns kvar som reserv tills bilden är laddad.
- Radie ner: menypanel 12 → 6, kort 8 → 4. Pixelkänsla, inte app-kort.
- `GameButton` får en pressad yta (1 px ner + mörkare) i stället för bara
  färgbyte.
- Rör alla menyark: **före/efter krävs**. Visa GEAR och SHOP först. Ägaren
  väljer innan resten byts.
- Risk: läsbarhet på A56 och bildladdning vid kallstart. Förvärm i
  `dungeon_art_warmup.dart`-mönstret.

### Fas 3: Striden som huvudscen (ChatGPT:s prio 1)

- Partyraden (`dungeon_party_hud.dart`): dela först i rad, portrait, bar och
  status. Sedan: tjockare HP-bar med "skada-spår" (`hudHpDamage` som glider
  efter), tydligare mana och spirit.
- Bossbar (`dungeon_top_hud.dart`/`dungeon_target_hud.dart`): bred bar högst
  upp med namn i Cinzel, fasmarkörer på 75/50/25 när bossen har faser, och
  tellen som ikon på baren.
- Loot-feedback: färgad stråle på golvdropp efter sällsynthet (fas 1-skalan),
  en kort "puff" i bagikonen när något går till bagen.
- Bossdöd: en sekunds paus + guldtext + kamerazoom. Under `VfxQuality.minimal`
  bara texten.
- Prestanda: inget nytt får lägga en extra ram per steg. Kolla `[IP]`-loggen
  för hack på A56 före och efter.
- **Före/efter krävs** (hela striden).

### Fas 4: Hub och PATH

- TODAY-kortet (`hub/hub_today_card.dart`): en primär brun knapp, en grå,
  resten länkar, som regeln redan säger. Ny är en stenram från fas 2 och en
  liten belöningsikon på knappen (vad du får).
- PATH-atlasen (`hub/hub_world_map.dart`): markörer i tre lägen (låst sten,
  öppen fackla, rensad krona), bossikon på zoner med obesegrad boss, och en
  tunn guldlinje för vägen.
- ENDGAME-kartan: samma markörspråk.
- `hub_screen.dart` delas innan något läggs till.
- **Före/efter krävs.**

### Fas 5: GEAR

- Större platser runt dockan, sällsynthetskant enligt fas 1.
- Jämförelsen: grön/röd pil + siffra direkt på bagplatsen (finns delvis som
  UP/BEST-chip), en rad "vs worn" i tooltipen.
- AUTO EQUIP ON/OFF finns redan i GEAR; den får fas 2-knappytan, inget
  nytt läge.
- `inventory_dock.dart` delas först.
- **Före/efter krävs.**

### Fas 6: ESSENCE, GOLD och SHOP (intäkt)

- SHOP (`shell/shop_dock.dart`): kort med ikon, vad du får i en mening, och
  pris från Play. Supporter och ad-free får samma ram som fas 2 med
  guldkant. Inga påhittade rabatter eller "bästa värde"-märken som koden inte
  backar. Forever-scrolls och Cinder-pouch syns bara när Play listar dem
  (som nu).
- ESSENCE/BLESSING: nivåer som en stege med låst/öppen/köpt, kostnad på
  knappen.
- GOLD → FORGE/MARKET: samma kortmall.
- Mät med befintliga events i `docs/ANALYTICS.md` (öppna SHOP, köp). Inga
  påhittade procent.
- **Före/efter krävs** för SHOP.

### Fas 7: Bottenraden

- Behåll GEAR · GOLD · SHOP · ESSENCE · MORE · KEY och `nav*`-färgerna.
- Ikonerna per flik finns redan (`UiIcon.gear/gold/star/essence/key/more`).
  Rita om dem i fas 2-stilen så de hör ihop med panelerna; SHOP är i dag en
  stjärna och kan bli en kista eller ett mynt.
- Aktiv flik: guldkant upptill + lite ljusare fyllning.
- Notisprick: en stil för alla flikar från `core/menu_alerts.dart`.
- Liten ändring, men den syns överallt: visa före/efter en gång.

### Fas 8: Tillgänglighet och slut-QA

- Kör skill `accessibility-auditing`: etiketter, 44/48 px-mål, textskala
  1.40, färgblindläge, Minimal VFX.
- Om fas 0 visade att VT323 17 är tunt: prova 18 eller en tjockare variant
  på brödtext. Före/efter.
- `flutter test --exclude-tags sim`, `ship_smoke_test`, `ui_theme_test`,
  `hub_widget_smoke_test`.
- Patch Notes för den version som skeppar fas 2–7.

## Ordning och storlek

| Fas | Rör | Före/efter | Risk |
|---|---|---|---|
| 0 | Inget | — | Ingen |
| 1 | 4–5 filer, tokens | Nej | Låg |
| 2 | Ny konst + `MenuChrome` + `GameButton` | Ja | Medel: läsbarhet, laddtid |
| 3 | 3 HUD-filer (delas först) | Ja | Medel: bildhack |
| 4 | Hub, karta | Ja | Låg–medel |
| 5 | GEAR (delas först) | Ja | Låg |
| 6 | SHOP, ESSENCE, GOLD | Ja (SHOP) | Låg; ärlig text |
| 7 | `app_bottom_bar.dart` | En gång | Låg |
| 8 | Tester, a11y | — | Låg |

Fas 1 kan börja direkt. Fas 2 sätter stilen för 4–7, så den går före dem.
Fas 3 kan gå parallellt med 2 eftersom striden är en egen familj.
