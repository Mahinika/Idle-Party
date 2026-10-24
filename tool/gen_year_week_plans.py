#!/usr/bin/env python3
"""Generate 52 week plan files from docs/YEAR_ROADMAP.md."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEEKS_DIR = ROOT / "docs" / "weeks"

Row = tuple[str, str, str, str, str, str]  # kind, title, why, k1, k2, k3

ROADMAP: list[tuple[int, int, str, str, str]] = [
    (2026, 44, "2026-10-26 – 2026-11-01", "För alla. Du ser vem som svingar. Partyt står på en rad.", "Your party stands in a line, so you can see who is swinging."),
    (2026, 45, "2026-11-02 – 2026-11-08", "När alla är nivå 100. Klockvarvet och lootvarvet slutar med olika ord.", "The timed run and the loot run end in different words."),
    (2026, 46, "2026-11-09 – 2026-11-15", "För alla. Fighten ryms på telefonen.", "The fight fits on the phone."),
    (2026, 47, "2026-11-16 – 2026-11-22", "För alla. Fem hjältar står kvar i raden på en riktig våning.", "Five heroes stay in a line on a real floor."),
    (2026, 48, "2026-11-23 – 2026-11-29", "För alla. Vapnet syns bredvid kroppen, inte under grannen.", "Your weapon stays beside your body, not under your neighbor."),
    (2026, 49, "2026-11-30 – 2026-12-06", "För alla. En grind, en kista och första bossen ryms med raden.", "A gate, a chest, and the first boss fit with the line."),
    (2026, 50, "2026-12-07 – 2026-12-13", "För alla. En wipe visar raden på våningen under.", "A wipe shows the line on the floor below."),
    (2026, 51, "2026-12-14 – 2026-12-20", "För alla. Appen öppnad mitt i fighten visar raden.", "Reopening the app mid-fight still shows the line."),
    (2026, 52, "2026-12-21 – 2026-12-27", "För alla. Efter Ascend står raden på våning 1. Väskan är tom.", "After Ascend, the line is back on floor 1 with an empty bag."),
    (2026, 53, "2026-12-28 – 2027-01-03", "När alla är nivå 100. Ranked GR-kortet visar månaden och samma tid som fighten.", "The Ranked GR card names the month and the same time as the fight."),
    (2027, 1, "2027-01-04 – 2027-01-10", "Sandy Caverns. Earth Kraken syns, och nästa pack ryms med raden.", "In Sandy Caverns, Earth Kraken fits on screen with the party line."),
    (2027, 2, "2027-01-11 – 2027-01-17", "Goblin's Hideout. Hobgoblin Lord syns, och kistorna går att se.", "In Goblin's Hideout, Hobgoblin Lord and the chests read clearly."),
    (2027, 3, "2027-01-18 – 2027-01-24", "King's Fort. Corrupt King syns, och baneren går att skilja från sanden.", "In King's Fort, Corrupt King and the banners read apart from Sandy."),
    (2027, 4, "2027-01-25 – 2027-01-31", "Underworld. Beholder syns, och grottan går att skilja från fortet.", "In Underworld, the Beholder reads apart from King's Fort."),
    (2027, 5, "2027-02-01 – 2027-02-07", "City of Dead. The No-One syns, och staden går att skilja från grottan under.", "In City of Dead, The No-One reads apart from Underworld."),
    (2027, 6, "2027-02-08 – 2027-02-14", "Hell's Gate. Cthulhu syns, och porten går att skilja från de dödas stad.", "At Hell's Gate, Cthulhu reads apart from City of Dead."),
    (2027, 7, "2027-02-15 – 2027-02-21", "Crystal Spire, kampanjen. Crystal Warden syns. Tornjakten är ett annat varv.", "Crystal Spire's Crystal Warden reads as the campaign cave, not Gauntlet."),
    (2027, 8, "2027-02-22 – 2027-02-28", "Sunken Tidehold. Tide Leviathan syns, och vattnet går att skilja från kristallen.", "In Sunken Tidehold, Tide Leviathan reads apart from Crystal Spire."),
    (2027, 9, "2027-03-01 – 2027-03-07", "Ashen Vault. Cinder Sovereign syns, och valvet går att skilja från tidvattnet.", "In Ashen Vault, Cinder Sovereign reads apart from Tidehold."),
    (2027, 10, "2027-03-08 – 2027-03-14", "När alla är nivå 100. Mellan bossarna går Gauntlet-våningen att känna igen.", "Between bosses, a Gauntlet floor is easy to tell apart."),
    (2027, 11, "2027-03-15 – 2027-03-21", "Den trånga våningen ser trång ut, och raden håller.", "The tight Gauntlet floor looks tight, and the line holds."),
    (2027, 12, "2027-03-22 – 2027-03-28", "Svärmen syns som många, och raden blir inte en ruta.", "The swarm reads as many bodies, not one tile."),
    (2027, 13, "2027-03-29 – 2027-04-04", "Ekots ord syns innan slaget, och det täcker inte ett vapen.", "The echo word shows before the hit, and not over a weapon."),
    (2027, 14, "2027-04-05 – 2027-04-11", "Grindvåningen stoppar raden, och grinden är hel.", "The gate floor stops the line, and the gate is whole."),
    (2027, 15, "2027-04-12 – 2027-04-18", "Var femte våning är en boss, och bossen ryms med raden.", "Every fifth floor is a boss, and the boss fits with the line."),
    (2027, 16, "2027-04-19 – 2027-04-25", "MIGHT, WARD eller GREED syns innan klättringen. GREED visar dubbel essence.", "MIGHT, WARD, or GREED shows before the climb. GREED doubles essence."),
    (2027, 17, "2027-04-26 – 2027-05-02", "Hollow Grove. Wyrd Root syns, och lunden går att skilja från valvet.", "In Hollow Grove, Wyrd Root reads apart from Ashen Vault."),
    (2027, 18, "2027-05-03 – 2027-05-09", "Stormwake Hollow. Storm Tyrant syns, och stormen går att skilja från lunden.", "In Stormwake Hollow, Storm Tyrant reads apart from the grove."),
    (2027, 19, "2027-05-10 – 2027-05-16", "Rimeglass Rift. Rime Colossus syns, och glaset går att skilja från stormen.", "In Rimeglass Rift, Rime Colossus reads apart from Stormwake."),
    (2027, 20, "2027-05-17 – 2027-05-23", "Blightfen Mire. Fen Hydra syns, och träsket går att skilja från glaset.", "In Blightfen Mire, Fen Hydra reads apart from Rimeglass."),
    (2027, 21, "2027-05-24 – 2027-05-30", "Brassvault Deep. The Mainspring syns, och klockverket går att skilja från träsket.", "In Brassvault Deep, The Mainspring reads apart from Blightfen."),
    (2027, 22, "2027-05-31 – 2027-06-06", "Mothveil Hollow. The Pale Monarch syns, och siden går att skilja från mässingen.", "In Mothveil Hollow, The Pale Monarch reads apart from Brassvault."),
    (2027, 23, "2027-06-07 – 2027-06-13", "När alla är nivå 100. Du ser klockan, och dropen, medan varvet pågår.", "You see the clock and the drop while the run is still going."),
    (2027, 24, "2027-06-14 – 2027-06-20", "Ranked GR-klockan i Mothveil stämmer med sluttiden.", "The Ranked GR clock in Mothveil matches the finish time."),
    (2027, 25, "2027-06-21 – 2027-06-27", "Du ser att du ligger över par innan varvet tar slut.", "You see you are over par before the run ends."),
    (2027, 26, "2027-06-28 – 2027-07-04", "Ingen ny utrustning går att ta på mitt i Ranked GR.", "No new gear goes on mid-run in Ranked GR."),
    (2027, 27, "2027-07-05 – 2027-07-11", "Raden håller i Mothveil medan klockan syns.", "The line holds in Mothveil while the clock shows."),
    (2027, 28, "2027-07-12 – 2027-07-18", "Farm Rift i Stormwake namnger dropen när den faller.", "Farm Rift in Stormwake names the drop when it falls."),
    (2027, 29, "2027-07-19 – 2027-07-25", "Ett bättre föremål byter namnet. Ett sämre gör det inte.", "A better drop replaces the name. A worse one does not."),
    (2027, 30, "2027-07-26 – 2027-08-01", "Slutet namnger samma drop som föll, eller att inget föll.", "The end line names the same drop, or that nothing fell."),
    (2027, 31, "2027-08-02 – 2027-08-08", "Farm Rift visar ingen fail-timer. Guld och essence är egna meningar.", "Farm Rift shows no fail timer. Gold and essence are their own sentences."),
    (2027, 32, "2027-08-09 – 2027-08-15", "Raden håller i Stormwake när dropen faller. Namnet täcker inte ett vapen.", "The line holds in Stormwake when the drop falls."),
    (2027, 33, "2027-08-16 – 2027-08-22", "När alla är nivå 100. KEY är en grotta du kan namnge innan du går in.", "At party Lv100, KEY names the cave before you enter."),
    (2027, 34, "2027-08-23 – 2027-08-29", "Rummets ord i KEY är en rad, och det ryms bredvid partyt.", "The room word in KEY is one line beside the party."),
    (2027, 35, "2027-08-30 – 2027-09-05", "Raden håller på KEY-våningen. En sving går att följa.", "The line holds on a KEY floor. A swing is easy to follow."),
    (2027, 36, "2027-09-06 – 2027-09-12", "När alla är nivå 100. Ashen Crown varnar innan slaget.", "At party Lv100, Ashen Crown warns you before the hit."),
    (2027, 37, "2027-09-13 – 2027-09-19", "Varningen täcker inte partyt, och vapnet syns.", "The warning does not cover the party, and the weapon shows."),
    (2027, 38, "2027-09-20 – 2027-09-26", "Hubben namnger veckans grotta och samma varningsord som fighten.", "The hub names this week's cave and the same warning word as the fight."),
    (2027, 39, "2027-09-27 – 2027-10-03", "Veckans start har tre biljetter. En wipe eller ett leave lämnar tillbaka biljetten.", "The week starts with three tickets. A wipe or leave returns the ticket."),
    (2027, 40, "2027-10-04 – 2027-10-10", "Practice är gratis. Utan biljett går varvet inte att starta.", "Practice is free. Without a ticket, the run does not start."),
    (2027, 41, "2027-10-11 – 2027-10-17", "En ny vecka är en annan grotta du redan kan, med sitt eget varningsord.", "A new week is another cave you already have, with its own warning word."),
    (2027, 42, "2027-10-18 – 2027-10-24", "Efter Ascend är Blessing det som stannar, och imorgon är fortfarande ett jobb.", "After Ascend, Blessing stays, and tomorrow is still a job."),
]

SKIP = {"2026-w44.md", "2026-w45.md", "2026-w46.md", "2027-w10.md", "2027-w23.md", "2027-w36.md"}

ZONES: dict[int, tuple[str, str, str]] = {
    1: ("Sandy Caverns", "Earth Kraken", "Sandy"),
    2: ("Goblin's Hideout", "Hobgoblin Lord", "Goblin"),
    3: ("King's Fort", "Corrupt King", "King's Fort"),
    4: ("Underworld", "Beholder", "Underworld"),
    5: ("City of Dead", "The No-One", "City of Dead"),
    6: ("Hell's Gate", "Cthulhu", "Hell's Gate"),
    7: ("Crystal Spire", "Crystal Warden", "Crystal Spire kampanjen"),
    8: ("Sunken Tidehold", "Tide Leviathan", "Tidehold"),
    9: ("Ashen Vault", "Cinder Sovereign", "Ashen Vault"),
    17: ("Hollow Grove", "Wyrd Root", "Hollow Grove"),
    18: ("Stormwake Hollow", "Storm Tyrant", "Stormwake"),
    19: ("Rimeglass Rift", "Rime Colossus", "Rimeglass"),
    20: ("Blightfen Mire", "Fen Hydra", "Blightfen"),
    21: ("Brassvault Deep", "The Mainspring", "Brassvault"),
    22: ("Mothveil Hollow", "The Pale Monarch", "Mothveil"),
}


def pad(rows: list[Row], n: int = 25) -> list[Row]:
    return rows[:n] + rows[: max(0, n - len(rows))][:n]


def zone_rows(w: int) -> list[Row]:
    zone, boss, short = ZONES[w]
    a = "A56 visar det."
    return pad(
        [
            ("Content", f"{zone} våning 1: nästa pack ryms med raden.", "Hall-regeln.", "Pack i bild.", "Grind hel.", a),
            ("Content", f"{boss} syns i samma bild som partyt.", "Boss-vecka.", "Boss i bild.", "Rad i bild.", a),
            ("Content", f"Hub-ikon för {zone} är inte grannens.", "Identitet.", "Ikon unik.", "Inte kopia.", "Test grönt."),
            ("Content", f"Golv och props i {zone} skiljer sig från förra grottan.", "Look.", "Egna props.", "Egna färger.", a),
            ("Content", f"Boss-sprite för {boss} är inte grannens boss.", "Combat.", "Egen sprite.", "Codex match.", "Test grönt."),
            ("Content", f"Trash-pack i {zone} läses som {short}.", "Pack.", "Mix syns.", "Elite egen.", a),
            ("Content", f"PATH visar {zone} när den öppnas.", "Karta.", "Namn på PATH.", "Engelska.", "Hub."),
            ("Content", f"Sidorum eller kista i {zone} är ett rum, inte bara hall.", "Layout.", "Kista/sidorum.", "Rad bredvid.", a),
            ("Content", f"Elite-tell i {zone} sitter på eliten.", "Farligt.", "Tell på elite.", "Inte på hjälte.", a),
            ("Content", f"Grind i {zone} fyller öppningen.", "Choke.", "Grind hel.", "Rad före.", a),
            ("Content", f"Bossvåning i {zone} öppnar på bossen.", "Boss rum.", f"{boss} centrum.", "Rad kvar.", a),
            ("Content", f"Wipe-farm i {zone} visar pack i bild.", "Farm.", "Pack syns.", "Rad syns.", a),
            ("Content", f"Shrine i {zone} ger BLESSED på en hjälte.", "Shrine.", "Altare syns.", "Ord på en.", a),
            ("Content", f"Partyraden håller på {zone} våning 1.", "Rad.", "Tre+ kroppar.", "Vapen syns.", a),
            ("Content", f"Porträtt/backdrop för {zone} ≠ grannens.", "Assets.", "Egna filer.", "CustomAssets.", "Test grönt."),
            ("Content", f"Atmosfär-wash i {zone} skiljer sig från grann.", "Wash.", "Hue egen.", a, "Test grönt."),
            ("Content", f"Första minuten i {zone} når pack med rad.", "Session.", "Pack snabbt.", "Rad syns.", a),
            ("Content", f"{boss} tell eller BOMB syns i rummet.", "Boss.", "Tell synlig.", "Rad kvar.", a),
            ("Content", f"Offline genom {zone} behåller rad vid öppning.", "Offline.", "Rad vid retur.", "Inte hög.", a),
            ("Content", f"AUTO EQUIP i {zone} behåller rad.", "Gear.", "Byte under fight.", "Rad efter.", a),
            ("Content", f"Floor clear lämnar en rad i {zone}.", "Loot.", "En golvrad.", "Namn tonar.", a),
            ("Content", f"Codex-boss för {boss} matchar fight-sprite.", "Codex.", "Samma bild.", "Namn rätt.", "Test grönt."),
            ("Content", f"Apex-shard namn krockar inte med grann.", "Data.", "Unikt namn.", "Codex.", "Test grönt."),
            ("Fix", f"Early packs i {zone} delar inte bild med nästa rum.", "Hall.", "Test early packs.", "Telefon.", a),
            ("Content", f"Patch Notes nämner {zone} bara om spelaren ser den.", "Copy.", "Engelska.", "Ärlig.", "Ingen ny zon."),
        ]
    )


def gauntlet_rows(theme: str) -> list[Row]:
    a = "A56 visar det."
    base: dict[str, list[Row]] = {
        "overview": [
            ("Content", "Gauntlet-våning namnger klämmen som en rad.", "När alla är Lv100.", "Ord en rad.", "Inte vägg.", a),
            ("Content", "Trång, svärm, eko och grind går att skilja.", "Fyra klämmor.", "Två syns på telefon.", "Test namn.", a),
            ("Content", "Boss-våning namnger bossen, inte klämmen.", "V5 mönster.", "Boss namn.", "Klämm ord skiljs.", a),
            ("Content", "Raden håller på varje klämm-typ.", "Rad.", "Kroppar isär.", "Vapen syns.", a),
        ],
        "tight": [
            ("Content", "Trång-våningen säger att korridorerna klämmer.", "Klämm.", "Ord syns.", "En rad.", a),
            ("Content", "Raden får plats i den trånga hallen.", "Rad.", "Isär.", "Når pack.", a),
        ],
        "swarm": [
            ("Content", "Svärm-våningen syns som många fiender.", "Svärm.", "Flera kroppar.", "Ord syns.", a),
            ("Content", "Raden står kvar när svärmen kommer.", "Rad.", "Inte en ruta.", "Vapen syns.", a),
        ],
        "echo": [
            ("Content", "Eko-ord syns före träffen.", "Eko.", "Före hit.", "Inte över vapen.", a),
            ("Content", "Raden håller medan eko-ordet syns.", "Rad.", "Isär.", a, a),
        ],
        "gate": [
            ("Content", "Grind fyller öppningen på grind-våning.", "Grind.", "Hel grind.", "Rad före.", a),
            ("Content", "Raden går inte igenom grinden.", "Rad.", "Stannar.", "Pack bakom.", a),
        ],
        "boss": [
            ("Content", "Våning 5, 10, 15… är boss och syns med rad.", "Boss var 5.", "Boss+rad.", "Hel bild.", a),
            ("Content", "Nästa boss namnges mellan bossar.", "CLIMB rad.", "Boss namn.", "En rad.", a),
        ],
        "pact": [
            ("Nytt", "MIGHT, WARD eller GREED väljs innan klättring.", "Pact.", "Val syns.", "Inte byts.", a),
            ("Content", "GREED ger dubbel essence på våningen.", "Belöning.", "Essence x2.", "Syns.", a),
            ("Content", "Efter våning 100 pekar hubben på Ranked GR.", "Endgame ordning.", "Hub text.", "GR nästa.", a),
        ],
    }
    rows = list(base.get(theme, base["overview"]))
    while len(rows) < 25:
        i = len(rows) + 1
        rows.append(
            (
                "Content",
                f"Gauntlet {theme}: rad och klämm {i}.",
                "Endgame torn.",
                "Detalj syns.",
                "Rad håller.",
                a,
            )
        )
    return pad(rows)


def gr_rows(phase: str) -> list[Row]:
    a = "A56 visar det."
    phases: dict[str, list[Row]] = {
        "live": [
            ("Content", "Klockan syns under Ranked GR-klättring.", "Lv100.", "Klocka i fight.", "En rad.", a),
            ("Content", "Farm Rift namnger drop när den faller.", "Lv100.", "Namn vid drop.", "Tonar bort.", a),
            ("Content", "Raden håller i Mothveil med klocka.", "Rad.", "Isär.", a, a),
            ("Content", "Raden håller i Stormwake vid drop.", "Rad.", "Vapen fri.", a, a),
        ],
        "match": [
            ("Content", "Klockan under varvet matchar sluttid.", "Match.", "mm:ss samma.", "Test grönt.", a),
            ("Fix", "Miss säger sekunder över par.", "Miss.", "Inte failed.", a, a),
            ("Content", "Klarning säger sluttid.", "Clear.", "mm:ss.", a, a),
        ],
        "overpar": [
            ("Content", "Över par syns innan varvet tar slut.", "Early read.", "Text under fight.", "Före slut.", a),
        ],
        "nogear": [
            ("Content", "Ingen gear-bytes prompt mitt i Ranked GR.", "Regel.", "Ingen equip.", "Fight forts.", a),
        ],
        "lineclock": [
            ("Content", "Klocktext täcker inte raden.", "360 px.", "Rad synlig.", "Klocka vid sidan.", a),
        ],
    }
    rows = list(phases.get(phase, phases["live"]))
    while len(rows) < 25:
        n = len(rows) + 1
        rows.append(("Content", f"Ranked GR detalj {n}.", "Klocka.", "Syns.", "Test.", a))
    return pad(rows)


def farm_rows(phase: str) -> list[Row]:
    a = "A56 visar det."
    rows: list[Row] = []
    if phase == "drop":
        rows += [
            ("Content", "Drop-namn syns när föremålet faller.", "Stormwake.", "Namn.", "Kort liv.", a),
            ("Content", "Bättre drop byter namn under varvet.", "Best.", "Nytt namn.", "Sämre behåll.", "Test grönt."),
        ]
    elif phase == "end":
        rows += [
            ("Content", "Slutrad = samma drop som föll.", "Match.", "Namn samma.", "Tom = inget.", a),
            ("Content", "Guld och essence egna meningar.", "Slut.", "Tre meningar.", "Ingen klocka.", a),
        ]
    elif phase == "line":
        rows += [
            ("Content", "Drop-namn täcker inte vapen.", "Rad.", "Namn ovanför.", "Vapen fri.", a),
        ]
    while len(rows) < 25:
        n = len(rows) + 1
        rows.append(("Content", f"Farm Rift detalj {n}.", "Loot.", "Stormwake.", a, "Test grönt."))
    return pad(rows)


def key_rows(phase: str) -> list[Row]:
    a = "A56 visar det."
    rows: list[Row] = []
    if phase == "pick":
        rows.append(("Content", "KEY-tab namnger grotta innan ENTER.", "Lv100.", "Cave namn.", "Före start.", a))
    elif phase == "word":
        rows.append(("Content", "Rummets ord i fighten är en rad.", "KEY.", "Ord en rad.", "360 px.", a))
    elif phase == "line":
        rows.append(("Content", "Rad håller på KEY-våning.", "Rad.", "Sving följs.", a, a))
    while len(rows) < 25:
        n = len(rows) + 1
        rows.append(("Content", f"KEY detalj {n}.", "Daily jobb.", "Ord syns.", a, "Test grönt."))
    return pad(rows)


def ashen_rows(phase: str) -> list[Row]:
    a = "A56 visar det."
    rows: list[Row] = []
    if phase == "warn":
        rows.append(("Content", "Varning syns före smash.", "Telegraph.", "Före hit.", a, a))
    elif phase == "party":
        rows.append(("Content", "Varning täcker inte party eller vapen.", "Read.", "Boss ord.", "Rad fri.", a))
    elif phase == "hub":
        rows.append(("Content", "Hub = samma grotta och ord som fight.", "Match.", "Hub text.", "Fight text.", a))
    elif phase == "tickets":
        rows += [
            ("Content", "Tre biljetter vid veckostart.", "Tickets.", "Talet 3.", a, a),
            ("Content", "Wipe/leave returnerar biljett.", "Ticket.", "+1 tillbaka.", a, a),
        ]
    elif phase == "practice":
        rows += [
            ("Content", "Practice kostar ingen biljett.", "Free.", "Talet oförändrat.", a, a),
            ("Content", "Utan biljett startar inte betald run.", "Block.", "0 tickets.", a, a),
        ]
    elif phase == "rotate":
        rows.append(("Content", "Ny ISO-vecka = ny grotta och nytt ord.", "Rotate.", "Två veckor skiljs.", "Test.", a))
    while len(rows) < 25:
        n = len(rows) + 1
        rows.append(("Content", f"Ashen detalj {n}.", "Veckoboss.", "Biljett.", a, "Test grönt."))
    return pad(rows)


def party_rows(kind: str) -> list[Row]:
    a = "A56 visar det."
    builders: dict[str, list[Row]] = {
        "five": [
            ("Fix", "Femte plats köpt: fem kroppar på rad.", "Fem.", "Slot 5.", "Alla isär.", a),
            ("Fix", "Yttre slot landar inte på hjälte 0.", "Line.", "Sök längs rad.", "0 fri.", a),
            ("Content", "Parvis avstånd > 0,72 på riktig våning.", "Test+telefon.", "Mäts.", "Test grönt.", a),
            ("Content", "keepApart håller ≥1,05 mellan kroppar.", "Sprites.", "Avstånd.", "Vapen fri.", a),
        ],
        "weapons": [
            ("Fix", "Krigarens svärd syns fritt.", "Vapen.", "Svärd.", "Sköld.", a),
            ("Fix", "Magikerns stav syns fritt.", "Caster.", "Stav.", "Skott.", a),
            ("Fix", "Healerns fokus syns fritt.", "Healer.", "Ikoner.", "Rad.", a),
        ],
        "gate": [
            ("Content", "Grind + rad + nästa pack i bild.", "Grind.", "Hel.", "Pack.", a),
            ("Content", "Kistvåning: kista + rad.", "Chest.", "Kista.", "Rad bredvid.", a),
            ("Content", "Sandy boss + rad i bild.", "Boss.", "Earth Kraken.", "Rad.", a),
        ],
        "wipe": [
            ("Content", "Wipe 3s nedrättning syns.", "Wipe.", "3s.", "Farm floor.", a),
            ("Content", "Efter nedrättning: rad mot farm-pack.", "Farm.", "Rad.", "Pack.", a),
        ],
        "reopen": [
            ("Content", "Mid-fight reopen visar rad direkt.", "Offline.", "Rad.", "Inte hög.", a),
        ],
        "ascend": [
            ("Content", "Efter Ascend: v1 med tom bag och rad.", "Ascend.", "Rad.", "Tom bag.", a),
        ],
        "grcard": [
            ("Content", "Hub GR-kort visar månad + tid.", "Season.", "Månad.", "mm:ss.", a),
            ("Content", "Fight och kort samma tid.", "Match.", "Samma ms.", a, "Test grönt."),
        ],
    }
    rows = list(builders.get(kind, []))
    while len(rows) < 25:
        n = len(rows) + 1
        rows.append(("Content", f"Partyrad detalj {n}.", "Rad.", "Syns.", a, "Test grönt."))
    return pad(rows)


def close_rows() -> list[Row]:
    a = "A56 visar det."
    rows: list[Row] = [
        ("Content", "TODAY efter Ascend pekar på farm eller Blessing.", "Daily.", "Ärlig text.", "Inte Reborn chase.", "Hub."),
        ("Content", "Welcome Back nämner rätt plats.", "Retur.", "Zon.", "Engelska.", a),
        ("Content", "ESSENCE-köp stannar efter Ascend.", "Meta.", "Relics/pets.", "Kvar.", "Save test."),
        ("Content", "Ascend-dialog säger att bag och guld nollas.", "Copy.", "Rebuild bag.", "Engelska.", "Dialog."),
        ("Content", "Partyrad på v1 efter reset.", "Rad.", "Hjältar kvar.", a, a),
    ]
    while len(rows) < 25:
        n = len(rows) + 1
        rows.append(("Content", f"Årsavslut {n}: Blessing + daily.", "Stäng året.", "Ingen ny zon.", "Patch Notes.", a))
    return pad(rows)


def pick_rows(y: int, w: int) -> list[Row]:
    if y == 2026:
        return {
            47: party_rows("five"),
            48: party_rows("weapons"),
            49: party_rows("gate"),
            50: party_rows("wipe"),
            51: party_rows("reopen"),
            52: party_rows("ascend"),
            53: party_rows("grcard"),
        }[w]
    if w in ZONES:
        return zone_rows(w)
    if w == 11:
        return gauntlet_rows("tight")
    if w == 12:
        return gauntlet_rows("swarm")
    if w == 13:
        return gauntlet_rows("echo")
    if w == 14:
        return gauntlet_rows("gate")
    if w == 15:
        return gauntlet_rows("boss")
    if w == 16:
        return gauntlet_rows("pact")
    if w == 24:
        return gr_rows("match")
    if w == 25:
        return gr_rows("overpar")
    if w == 26:
        return gr_rows("nogear")
    if w == 27:
        return gr_rows("lineclock")
    if w == 28:
        return farm_rows("drop")
    if w == 29:
        return farm_rows("drop")
    if w == 30:
        return farm_rows("end")
    if w == 31:
        return farm_rows("end")
    if w == 32:
        return farm_rows("line")
    if w == 33:
        return key_rows("pick")
    if w == 34:
        return key_rows("word")
    if w == 35:
        return key_rows("line")
    if w == 37:
        return ashen_rows("party")
    if w == 38:
        return ashen_rows("hub")
    if w == 39:
        return ashen_rows("tickets")
    if w == 40:
        return ashen_rows("practice")
    if w == 41:
        return ashen_rows("rotate")
    if w == 42:
        return close_rows()
    return gauntlet_rows("overview")


def render_week(y: int, w: int, dates: str, headline: str, en: str) -> str:
    st = "Nästa" if y == 2026 and w == 44 else "Tidigt utkast"
    rows = pick_rows(y, w)
    att_lines: list[str] = []
    for i, (kind, title, why, k1, k2, k3) in enumerate(rows, start=1):
        att_lines.append(f"{i}. Måste · {kind} — {title} — {why} — ej klar")
        att_lines.append(f"   - Klart när: {k1}")
        att_lines.append(f"   - Klart när: {k2}")
        att_lines.append(f"   - Klart när: {k3}")

    endgame = "nivå 100" in headline or "Lv100" in en
    tele = [
        "1. Huvudraden för veckan syns på A56.",
        "2. En ny save om veckan gäller alla.",
        "3. En endgame-save om veckan kräver party Lv100." if endgame else "3. En save som redan klättrat flera grottor.",
    ]

    return f"""# Vecka {w}

**Status:** {st}
**Datum:** {dates}
**Version:** sätts när veckan blir nästa
**Förra:** den som då är ute
**En mening:** {en}

## Att göra

{chr(10).join(att_lines)}

## Inte den här veckan

- En ny grotta, en ny klass, gacha, eller en andra fight-sim.
- En andra daglig kalender och en iPhone-version.
- Nästa veckas rad i docs/YEAR_ROADMAP.md.

## Telefontest

{chr(10).join(tele)}

## Onsdag

- [ ] Planen håller
- [ ] Versionen är realistisk
- [ ] Inget behöver flyttas

## Söndag

- [ ] Måste-raderna är spelbara eller flyttade
- [ ] Patch Notes på engelska
- [ ] Telefontestet är gjort
- [ ] Du har sagt till om AAB
- [ ] AAB inskickad
- [ ] Discord #announcements postad

**Släppt som:**

## Källor

- 2026-10-24: docs/YEAR_ROADMAP.md — {headline}
"""


def main() -> None:
    written = skipped = 0
    for y, w, dates, headline, en in ROADMAP:
        fname = f"{y}-w{w:02d}.md"
        path = WEEKS_DIR / fname
        if fname in SKIP and path.exists():
            skipped += 1
            continue
        path.write_text(render_week(y, w, dates, headline, en), encoding="utf-8")
        written += 1
    print(f"written={written} skipped={skipped}")


if __name__ == "__main__":
    main()
