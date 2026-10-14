---
name: weekly-plan
description: >-
  Writes and reads Idle Party's plan for one ISO week, stored as one file
  per week. Use when the owner says "gör en veckoplan", "veckoplan för
  veckan 51", "vad är planen för vecka 48", "planen för vecka", "den
  här veckan", or "onsdagskoll". That file is the plan they mean. Do not
  use for the 12-month roadmap (year-roadmap), in-game Patch Notes
  (screenshotting-changelog), or uploading an AAB (play-store-prep).
---

# Weekly plan (Idle Party)

One ISO week, one file under `docs/weeks/`. That file is the only answer to
"vad är planen för vecka N". Do not answer from the year roadmap, play
notes, or an earlier chat. Those may feed a new file. They are not the plan.

The week file is the template below. Keep its headings, rules, and section
order. Fill dates, the version, the one sentence, and the rows. Leave a
numbered line blank when that slot has no change. Do not pad the week to 10.

Never upload an AAB here. Upload only when the owner asks in that turn
(`play-store-prep`). Never post to Discord unless they ask in that turn.
In-game Patch Notes are `screenshotting-changelog`.

Folder note: `docs/weeks/README.md`.

## Which week

ISO weeks, Monday–Sunday. "veckan 51" and "vecka 51" are week 51. "den här
veckan" is today's ISO week.

If they name a year, use it. Otherwise set `week` and leave `named=None`:

```bash
py -3 -c "from datetime import date; week=51; named=None; t=date.today().isocalendar(); y=named or t.year; y=t.year-1 if named is None and t.week<=8 and week>=40 else (t.year+1 if named is None and t.week>=45 and week<=8 else y); print('%d-w%02d'%(y,week), date.fromisocalendar(y,week,1), date.fromisocalendar(y,week,7))"
```

Year rule when they omit it: today in ISO week 1–8 and they named week 40+
→ previous ISO year. Today in week 45–53 and they named week 1–8 → next
ISO year. Otherwise today's ISO year.

If `fromisocalendar` throws, that week does not exist. Say so.

File name is the printed token plus `.md` inside `docs/weeks/`. Week 51 of
2026 is `2026-w51.md` in that folder.

## Ask vs write

| They said | Do |
|---|---|
| vad är planen / planen för vecka N | Read that file. Reply in Swedish with the planned changes, the one sentence, player value, and which Sunday boxes are checked. Missing file: say there is no plan. Do not write one. |
| gör en veckoplan, file exists | Show it. Change a row only when they named the change. |
| gör en veckoplan, file missing | Write it from the template, show it, stop. Do not start building the rows. |
| onsdagskoll | Open that week's file. Fill **Onsdag — verklighetskoll**. A row that will not finish goes under **Flyttat till nästa vecka** in that section. |

A new idea mid-week goes under **Inte den här veckan**. Only a critical bug
may take a planned slot. The row it displaces moves with the Wednesday
leftovers.

## Write a missing plan

1. Read the Open section of `docs/PLAY_NOTES.md`. If the previous week file exists, read **Inte den här veckan** and both **Flyttat till nästa vecka** sections.
2. Up to 10 player-visible changes that can be done by that Sunday. Words they used in this turn win. If they only named the week, draft from those notes.
3. Anything past 10 goes under **Inte den här veckan**.
4. One English sentence a new player understands. Keep KEY, Gauntlet, and Ascend out of that sentence unless they named that as the week.
5. **Varför just det här** and **Spelarvärde** in Swedish. Name the play note or what they said.
6. Version aim: read `pubspec.yaml` `version:` and name the next patch. Do not bump it here.
7. Play lines and the Discord block: the changes a player will notice, English, at most the five bullets in the template. Drafts, not sent.
8. **Butiksbilder** stays as written in the template. Add a store-shot row only when heroes, the hub, or the combat screen will look different to the player.
9. Wednesday, **Under veckan**, Sunday, and **Utfall** start unchecked and blank.

## Template

Copy this into the week file.

````markdown
# Veckoplan — Idle Party

**Status:** Aktiv plan för veckan.
**Rytm:** Måndag sätts planen. Söndag är jobbet klart, Play-uppdatering skickas in och Discord-annons postas.

Regler:
- Planen innehåller upp till 10 spelarsynliga förändringar.
- Nya idéer som inte ryms skrivs under "Inte den här veckan".
- Endast kritiska buggar får tränga sig före planerat arbete.
- Söndag betyder att versionen är inskickad till Google Play, inte att Google redan godkänt den.
- AAB laddas bara upp när du säger till.
- In-game text, Patch Notes, Play-rader och Discord-annons skrivs på engelska.
- Planen skrivs på svenska.

---

## Vecka

- **Måndag:** ÅÅÅÅ-MM-DD
- **Söndag:** ÅÅÅÅ-MM-DD
- **Version vi siktar på:** 1.x.y
- **En mening en ny spelare förstår:**

---

## Måndag — det här ska vara klart på söndag

### Funktioner och förbättringar

1. 
2. 
3. 
4. 
5. 
6. 
7. 
8. 
9. 
10.

---

## Inte den här veckan

-
-
-
-
-

---

## Varför just det här

Anteckning från speltestning, PLAY_NOTES eller egen observation.

-
-
-

---

## Spelarvärde

Varför spelaren bryr sig.

-
-
-

---

## Onsdag — verklighetskoll

- [ ] Planen håller fortfarande.
- [ ] Versionnumret känns realistiskt.
- [ ] Inget behöver flyttas.

**Flyttat till nästa vecka:**

-
-

---

## Under veckan

Bocka av när något är spelbart.

- [ ] 1
- [ ] 2
- [ ] 3
- [ ] 4
- [ ] 5
- [ ] 6
- [ ] 7
- [ ] 8
- [ ] 9
- [ ] 10

---

## Söndag — släpp

- [ ] Planerade förändringar är klara eller medvetet flyttade
- [ ] Patch Notes på engelska (MORE → INFO → PATCH NOTES)
- [ ] Play-rader klara
- [ ] Du har tittat på bygget
- [ ] Du har sagt till att ladda upp AAB
- [ ] AAB inskickad till Production
- [ ] Discord #announcements postad

---

## Utfall

- **Släppt som:** 1.x.y

### Flyttat till nästa vecka

-
-
-

---

## Play-rader (engelska)

Sammanfattning av de viktigaste förändringarna spelaren märker.

```text
•
•
•
•
•
```

---

## Discord (engelska)

```text
**Idle Party 1.x.y**

•
•
•
•
•

Play: https://play.google.com/store/apps/details?id=com.idleparty.app

Google is reviewing this update. The Play Store may still show the previous version for a while.
```

---

## Butiksbilder

Uppdateras bara när spelare tydligt ser skillnad i:
- Hjältar
- Hubb
- Stridsskärm

Inte som del av varje veckosläpp.
````

## Sunday

When they say this week is shipping ("släpp veckan", "det är söndag"):

- Open that week's file. Tick a box only when that step is actually done.
- Fill **Utfall**. **Släppt som** is the version submitted. Leftovers go under **Flyttat till nästa vecka** there.
- Do not upload. Do not post unless they asked in that turn.
- Do not send a half announcement.

## Done when

- A "gör" ask left the week file on disk, using the template. A "vad är planen" ask quoted that file, or said it is missing.
- No AAB was uploaded and no Discord post was sent.
