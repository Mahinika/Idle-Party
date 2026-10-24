"""Twenty-five-row libraries for 2026 party-line weeks (no padding)."""

from __future__ import annotations

Row = tuple[str, str, str, str, str, str]
A = "A56 visar det."


def _pad25(rows: list[Row]) -> list[Row]:
    if len(rows) != 25:
        raise ValueError(f"expected 25 rows, got {len(rows)}")
    return rows


PARTY_FIVE: list[Row] = _pad25(
    [
        ("Fix", "Femte plats köpt: fem kroppar på rad.", "Fem.", "Slot 5.", "Alla isär.", A),
        ("Fix", "Yttre slot landar inte på hjälte 0.", "Line.", "Sök längs rad.", "0 fri.", A),
        ("Content", "Parvis avstånd > 0,72 på riktig våning.", "Test+telefon.", "Mäts.", "Test grönt.", A),
        ("Content", "keepApart håller ≥1,05 mellan kroppar.", "Sprites.", "Avstånd.", "Vapen fri.", A),
        ("Content", "Tre hjältar: kort rad framför pack.", "Sandy.", "Tre kroppar.", "Test grönt.", A),
        ("Content", "Fem hjältar: samma rad-regel.", "AL2 slot.", "Fem kroppar.", A, A),
        ("Fix", "AL2 essence-köp visar tom stol innan köp.", "Hub.", "80e.", "Stol syns.", A),
        ("Content", "Tank främst, melee vid sidor, backline bak.", "Ordning.", "Melee off line.", A, A),
        ("Content", "Caster på vinge har skott in i rummet.", "Vinge.", "Träff syns.", A, A),
        ("Content", "Healer på vinge når raden.", "Heal.", "Landar på hjälte.", A, A),
        ("Content", "Grind stoppar raden — pack bakom grind.", "Choke.", "Grind hel.", A, A),
        ("Content", "Kistvåning: rad bredvid kistan.", "Chest.", "Kista öppen.", A, A),
        ("Content", "Boss + rad i samma bild när det får plats.", "Boss.", "Boss synlig.", A, A),
        ("Content", "Wipe-farm visar pack på säker våning.", "Farm.", "Pack i bild.", A, A),
        ("Content", "Offline reopen: rad kvar direkt.", "Offline.", "Rad synlig.", A, A),
        ("Content", "Partyrad klipper inte namn på 360 px.", "HUD.", "Namn kort.", A, A),
        ("Fix", "Ingen hjälte delar tile med grannen.", "Spread.", "Egna tiles.", A, A),
        ("Content", "Formation vänder mot hot, inte karta-vänster.", "March.", "Mot fiende.", A, A),
        ("Content", "Retreat går till golv, inte in i vägg.", "AI.", "Walkable.", A, A),
        ("Content", "Elite-pack: rad håller mot flera kroppar.", "Swarm.", "Flera fiender.", A, A),
        ("Content", "Gauntlet: rad håller på trång våning.", "Endgame.", "Klämm.", A, A),
        ("Content", "KEY-våning: rad + sving följs.", "Lv100.", "Ordning.", A, A),
        ("Content", "Ranked GR: rad med klocka vid sidan.", "Klocka.", "Rad fri.", A, A),
        ("Content", "Farm Rift: rad när drop-namn syns.", "Drop.", "Namn tonar.", A, A),
        ("Content", "Ascend v1: rad på Sandy efter reset.", "Ascend.", "Tom bag.", A, A),
    ]
)

PARTY_WEAPONS: list[Row] = _pad25(
    [
        ("Fix", "Krigarens svärd syns fritt bredvid kroppen.", "Vapen.", "Svärd.", "Sköld.", A),
        ("Fix", "Magikerns stav syns fritt.", "Caster.", "Stav.", "Skott.", A),
        ("Fix", "Healerns fokus/tome syns fritt.", "Healer.", "Tome.", "Rad.", A),
        ("Fix", "Rogues dubbeldaga syns på båda händer.", "Rogue.", "Dagger par.", A, A),
        ("Fix", "Hunter båge syns på main hand.", "Hunter.", "Bow.", "Pil.", A),
        ("Content", "Sköld sitter utanför bröst-sprite.", "Tank.", "Sköld kant.", A, A),
        ("Content", "Gloves ändrar grepp — vapen följer.", "Gear.", "Byte under fight.", A, A),
        ("Content", "Off-hand byts utan att täcka grannen.", "Off-hand.", "Synlig.", A, A),
        ("Content", "Ability pose lyfter vapen, inte grannens.", "Cast.", "Pose egen.", A, A),
        ("Content", "Slash VFX startar vid vapen, inte mitt i raden.", "VFX.", "Tydlig sving.", A, A),
        ("Content", "Ranged skott syns från vinge.", "Skott.", "Bana synlig.", A, A),
        ("Content", "Crit / CRIT text täcker inte vapen.", "Text.", "CRIT offset.", A, A),
        ("Content", "Floor loot-namn tonar före hjälte.", "Loot.", "Fade.", A, A),
        ("Content", "Party strip: vapen ikon matchar worn.", "HUD.", "Ikoner.", A, A),
        ("Content", "AUTO EQUIP byte syns på doll i fight.", "Auto.", "Doll uppd.", A, A),
        ("Content", "Form kit behåller silhuett med vapen.", "Kit.", "Silhuett.", A, A),
        ("Content", "Minimal VFX döljer inte vapen.", "A11y.", "Minimal.", A, A),
        ("Content", "Lite VFX: tells syns, vapen kvar.", "Lite.", "Tell ring.", A, A),
        ("Content", "Boss tell täcker inte party vapen.", "Boss.", "Tell ovan.", A, A),
        ("Content", "Echo-ord före hit, inte över svärd.", "Gauntlet.", "Eko.", A, A),
        ("Content", "Ashen telegraph fri för vapen.", "Ashen.", "Varning.", A, A),
        ("Content", "KEY affix-rad vid sidan av rad.", "KEY.", "Affix.", A, A),
        ("Content", "GR ingen gear — vapen oförändrat mid-run.", "GR.", "Ingen equip.", A, A),
        ("Content", "Paper doll / GEAR matchar fight-grepp.", "Gear tab.", "Samma håll.", A, A),
        ("Content", "Lookbook pixel: FilterQuality.none på ikoner.", "Art.", "Skarp pixel.", A, A),
    ]
)

PARTY_GATE: list[Row] = _pad25(
    [
        ("Content", "Grind + rad + nästa pack i bild.", "Grind.", "Hel.", "Pack.", A),
        ("Content", "Kistvåning: kista + rad.", "Chest.", "Kista.", "Rad bredvid.", A),
        ("Content", "Sandy boss + rad i bild.", "Boss.", "Earth Kraken.", "Rad.", A),
        ("Content", "Sandy F1: första pack nästa blick.", "New save.", "Pack snabbt.", A, A),
        ("Content", "Sandy F2: boss-ingång syns.", "Boss path.", "Ingång.", A, A),
        ("Content", "Goblin F1: hall slutar i bild.", "Goblin.", "Hall.", A, A),
        ("Content", "King's Fort F1: trappa i bild.", "Fort.", "Trappa.", A, A),
        ("Content", "Sidorum läses som rum, inte hall.", "Side.", "Eget rum.", A, A),
        ("Content", "Choke klämmer — trångt syns.", "Choke.", "Smalt.", A, A),
        ("Content", "Bossrum öppnar på boss.", "Boss room.", "Centrum.", A, A),
        ("Content", "Stängd grind stannar på skärmen.", "Gate rule.", "Grind hel.", A, A),
        ("Content", "Pack bakom grind när båda får plats.", "360 px.", "Pack synlig.", A, A),
        ("Content", "Hall kortas utan att bryta väg.", "Hall trim.", "Väg kvar.", A, A),
        ("Content", "Shrine i hall: BLESSED en hjälte.", "Shrine.", "Altare.", A, A),
        ("Content", "Tre våningar Sandy: pack nästa blick.", "Session.", "Kort sittande.", A, A),
        ("Content", "Missad push: safe floor pack syns.", "Wipe.", "Farm floor.", A, A),
        ("Content", "Boss tell syns innan SLAM.", "Tell.", "Vind-up.", A, A),
        ("Content", "Två pack samma grotta: olika jobb.", "Pack job.", "Olika tell.", A, A),
        ("Content", "Grannzon delar inte samma monster-silhuett.", "Art.", "Egen zon.", A, A),
        ("Content", "Open hall N/S — pack på en skärm.", "Camera.", "En skärm.", A, A),
        ("Content", "Stairs open: GO stairs rad.", "Clear.", "Stairs chip.", A, A),
        ("Content", "Chest floor: CLEAR på chest.", "Chest open.", "Loot.", A, A),
        ("Content", "Elite silhuett i tät hall.", "Elite.", "Synlig.", A, A),
        ("Content", "Party + pack när båda får plats.", "Fight room.", "En bild.", A, A),
        ("Content", "Butiksbild matchar grind-regeln.", "Play shots.", "Grind i bild.", A, A),
    ]
)

PARTY_WIPE: list[Row] = _pad25(
    [
        ("Content", "Wipe 3s nedrättning syns.", "Wipe.", "3s.", "Farm floor.", A),
        ("Content", "Efter nedrättning: rad mot farm-pack.", "Farm.", "Rad.", "Pack.", A),
        ("Content", "Två missar på ny våning → farm under.", "Push rule.", "Två miss.", A, A),
        ("Content", "En clear på safe → push igen.", "Recovery.", "Push.", A, A),
        ("Content", "Offline wipe farmar safe, stoppar inte.", "Offline.", "Safe farm.", A, A),
        ("Content", "WIPED-rad på telefon.", "Copy.", "WIPED.", A, A),
        ("Content", "Wipe gömmer party-keeps-fighting rad.", "Toast.", "En rad.", A, A),
        ("Content", "OPEN BAG på wipe fungerar.", "Bag.", "Öppnas.", A, A),
        ("Content", "Reopen wipe: skada kvar, inte nollor.", "Save.", "HP kvar.", A, A),
        ("Content", "Wipe menu-knapp öppnar rätt flik.", "Hint.", "GEAR/GOLD.", A, A),
        ("Content", "Flask tip på wipe → GOLD.", "Flask.", "GOLD öppnas.", A, A),
        ("Content", "Safe floor pack i bild efter dubbelmiss.", "Visual.", "Pack.", A, A),
        ("Content", "Partyrad håller på farm-våning.", "Rad.", "Isär.", A, A),
        ("Content", "Countdown fortsätter fight automatiskt.", "AFK.", "Auto retry.", A, A),
        ("Content", "Boss wipe: samma regler som trash.", "Boss.", "3s.", A, A),
        ("Content", "Gauntlet leave/wipe namnger hunt.", "Leave.", "Hunt namn.", A, A),
        ("Content", "GR wipe säger wipe, inte over par.", "GR.", "wipe ord.", A, A),
        ("Content", "GR clock miss: over par, inte wipe.", "GR miss.", "Sekunder.", A, A),
        ("Content", "Farm Rift: ingen fail wipe timer.", "Farm.", "Ingen timer.", A, A),
        ("Content", "KEY depleted: over par text.", "KEY.", "Timer.", A, A),
        ("Content", "Welcome Back efter wipe offline.", "Welcome.", "Sammanfattning.", A, A),
        ("Content", "Hub return efter leave live hunt.", "Leave.", "ended ord.", A, A),
        ("Content", "Wipe rad täcker inte hjältar.", "360 px.", "Placering.", A, A),
        ("Content", "FARM efter wipe på samma våning.", "Mode.", "Repeat.", A, A),
        ("Content", "PUSH igen efter safe clear.", "Push.", "Nästa våning.", A, A),
    ]
)

PARTY_REOPEN: list[Row] = _pad25(
    [
        ("Content", "Mid-fight reopen visar rad direkt.", "Offline.", "Rad.", "Inte hög.", A),
        ("Content", "Welcome Back efter cave offline.", "Card.", "En kort.", A, A),
        ("Content", "Spatial offline fortsätter fight.", "Sim.", "AFK assist.", A, A),
        ("Content", "Hub AFK: guld/essence, inte combat.", "Hub.", "AFK bank.", A, A),
        ("Content", "Boot: party keeps fighting copy.", "Boot.", "Engelska.", A, A),
        ("Content", "1 min cave utan clear → Welcome Back.", "Timer.", "Öppnas.", A, A),
        ("Content", "Continue knapp → rätt save slot.", "Save.", "Slot 0.", A, A),
        ("Content", "Mid-fight: loot log en rad.", "Loot log.", "Ellipsis.", A, A),
        ("Content", "Toast dedupe — inte spam.", "Toast.", "8s bag.", A, A),
        ("Content", "Late frame: ett fight step.", "Perf.", "Ingen dubbel.", A, A),
        ("Content", "App kill mid-fight: rad vid return.", "Process.", "Rad kvar.", A, A),
        ("Content", "Dungeon zoom sparad efter reopen.", "Zoom.", "Pinch.", A, A),
        ("Content", "Sound muted listing shot sparar.", "Mute.", "Shot.", A, A),
        ("Content", "Party mark line på floor.", "Mark.", "Engelska rad.", A, A),
        ("Content", "God Hand / fist efter first clear.", "First hour.", "Unlock.", A, A),
        ("Content", "GEAR+MORE bar före first boss.", "Bar.", "Två tabs.", A, A),
        ("Content", "Offline gold essence i Welcome Back.", "Payoff.", "Separata rader.", A, A),
        ("Content", "Catch-up stop reason ärlig.", "Welcome.", "Varför stopp.", A, A),
        ("Content", "Reopen under GR: klocka kvar.", "GR.", "Timer.", A, A),
        ("Content", "Reopen under Farm: progress bar.", "Farm.", "Guardian.", A, A),
        ("Content", "Reopen Gauntlet: pact kvar.", "Gauntlet.", "Pact.", A, A),
        ("Content", "Minimal VFX efter reopen.", "Settings.", "Minimal.", A, A),
        ("Content", "Enemy HP bars setting respekteras.", "Settings.", "HP bar.", A, A),
        ("Content", "Party HUD fade efter idle — tap bright.", "HUD.", "Fade 3s phone.", A, A),
        ("Content", "Low HP håller HUD bright.", "Crit HP.", "<35%.", A, A),
    ]
)

PARTY_ASCEND: list[Row] = _pad25(
    [
        ("Content", "Efter Ascend: v1 med tom bag och rad.", "Ascend.", "Rad.", "Tom bag.", A),
        ("Content", "Ascend dialog: Rebuild your bag.", "Copy.", "Engelska.", A, A),
        ("Content", "Guld och forge nollas.", "Reset.", "Wallet.", A, A),
        ("Content", "Hjältar + nivåer kvar.", "Keep.", "Levels.", A, A),
        ("Content", "Blessing / essence / relics kvar.", "Meta.", "ESSENCE tab.", A, A),
        ("Content", "AUTO EQUIP kvar efter Ascend.", "Setting.", "Toggle.", A, A),
        ("Content", "Zones öppna kvar.", "PATH.", "Unlock.", A, A),
        ("Content", "Hub toast: nästa run snabbare.", "Toast.", "freshPrestige.", A, A),
        ("Content", "TODAY efter Ascend — inte Reborn chase.", "Chase.", "Ärlig.", A, A),
        ("Content", "Fourth hero join first Ascend.", "Roster.", "4:e.", A, A),
        ("Content", "Fifth slot AL2 80e efter Ascend.", "Slot 5.", "Köp.", A, A),
        ("Content", "Spire Trophies behålls.", "Gauntlet.", "Trophies.", A, A),
        ("Content", "Ranked season PB behålls månad.", "GR.", "Season.", A, A),
        ("Content", "Leave dungeon clear på Ascend.", "Leave.", "Hub.", A, A),
        ("Content", "highestFloorCleared reset.", "Push.", "F1.", A, A),
        ("Content", "Boss victories clear.", "Boss.", "Reset.", A, A),
        ("Content", "Market/loadouts reset.", "Economy.", "Market.", A, A),
        ("Content", "Partyrad Sandy F1 efter reset.", "Fight.", "Tre/fem.", A, A),
        ("Content", "Patch notes nämner Ascend keep/reset.", "Honest.", "What's New.", A, A),
        ("Content", "AL counter på hub.", "AL.", "Syns.", A, A),
        ("Content", "BLESSING REBORN optional AL20.", "Reborn.", "Optional.", A, A),
        ("Content", "Essence shop entitlements kvar.", "Shop.", "Forever.", A, A),
        ("Content", "Ad tickets / scrolls kvar.", "SCROLLS.", "Tickets.", A, A),
        ("Content", "Settings + race lock kvar.", "Settings.", "Race lock.", A, A),
        ("Content", "Play opt-in / notify kvar.", "MetaDepth.", "Save migrate.", A, A),
    ]
)

PARTY_GRCARD: list[Row] = _pad25(
    [
        ("Content", "Hub GR-kort visar månad + tid.", "Season.", "Månad.", "mm:ss.", A),
        ("Content", "Fight och kort samma tid.", "Match.", "Samma ms.", "Test grönt.", A),
        ("Content", "Miss säger sekunder over par.", "Miss.", "00:12 over par.", A, A),
        ("Content", "Clear säger sluttid.", "Clear.", "cleared · mm:ss.", A, A),
        ("Content", "Snabbare clear byter PB.", "PB.", "Season ms.", A, A),
        ("Content", "Långsammare högre rank byter inte PB.", "PB rule.", "Tier 1 kvar.", A, A),
        ("Content", "Ny månad nollställer season PB.", "Rollover.", "Tom tid.", A, A),
        ("Content", "Kort: Best GR{tier} · tid · månad.", "Card.", "En rad.", A, A),
        ("Content", "GR fight: no gear mid-run.", "Rule.", "Ingen equip.", A, A),
        ("Content", "GR room line: clock visible.", "HUD.", "Timer.", A, A),
        ("Content", "GR wipe säger wipe.", "Wipe.", "Inte par.", A, A),
        ("Content", "Leave live GR säger ended.", "Leave.", "Inte wipe.", A, A),
        ("Content", "GR packs scale rank only.", "Fairness.", "Forge tax.", A, A),
        ("Content", "GR chests: gold only mid-run.", "Loot.", "Ingen gear.", A, A),
        ("Content", "GR Guardian under timer.", "Guardian.", "Progress.", A, A),
        ("Content", "GR past 20 selectable.", "Tier.", "GR250.", A, A),
        ("Content", "Play board ID wired monthly.", "Play.", "Leaderboard.", A, A),
        ("Content", "Local PB om Play av.", "Fallback.", "Hub card.", A, A),
        ("Content", "Ranked GR on ENDGAME map.", "Hub.", "ENDGAME.", A, A),
        ("Content", "After Spire 100 hub names GR.", "Chase.", "First GR.", A, A),
        ("Content", "Farm Rift separat ord från GR.", "Farm.", "Stormwake.", A, A),
        ("Content", "360 px: kortet klipper inte.", "Phone.", "Widget test.", A, A),
        ("Content", "Endgame unlock party Lv100.", "Gate.", "All Lv100.", A, A),
        ("Content", "Mothveil GR dungeon id.", "Zone.", "veil.", A, A),
        ("Content", "Season key leaderboardSeasonKey.", "Save.", "2026-10.", A, A),
    ]
)

PARTY_BUILDERS: dict[str, list[Row]] = {
    "five": PARTY_FIVE,
    "weapons": PARTY_WEAPONS,
    "gate": PARTY_GATE,
    "wipe": PARTY_WIPE,
    "reopen": PARTY_REOPEN,
    "ascend": PARTY_ASCEND,
    "grcard": PARTY_GRCARD,
}
