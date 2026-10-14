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
"vad är planen för vecka N". A question reads that file alone. A new file
is fed only by the reads under **Write a missing plan**.

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
| vad är planen / planen för vecka N | Read that file. Reply in Swedish with the status, the **Måste** rows, the other planned changes, the one sentence, player value, and which Sunday boxes are checked. Missing file: say there is no plan. Do not write one. |
| gör en veckoplan, file exists | Show it. Change a row only when they named the change. |
| gör en veckoplan, file missing | Write it from the template, show it, stop. Do not start building the rows. |
| onsdagskoll | Open that week's file. Fill **Onsdag — verklighetskoll**. A row that will not finish goes under **Flyttat till nästa vecka** in that section. A moved **Måste** row keeps that mark, and drops out of the Play and Discord drafts. |

A new idea mid-week goes under **Inte den här veckan**. Only a critical bug
may take a planned slot. The row it displaces moves with the Wednesday
leftovers.

## Write a missing plan

Read these. No web search. Do not run the year-roadmap skill.

1. Open section of `docs/PLAY_NOTES.md`.
2. Previous week file, if it exists: **Inte den här veckan** and both **Flyttat till nästa vecka** sections.
3. Newest release in `lib/core/changelog.dart`. Do not plan a change that release already shipped.
4. Operator status in `docs/PLAY_STORE.md`: which build is live, and which is in review. Do not invent Console numbers.
5. The **Nu** section of `docs/YEAR_ROADMAP.md` only.
6. Play reviews through the Play API (`play-store-prep` reference, § Play API). The API returns about the last week only. Read only. Reply only when the owner names that review.
7. Discord #bugs through the Discord tools (`user-omnicord`, read messages). Read only. Never post, reply, or react here.

If a read fails, write **inte läst** next to that source under **Varför
just det här**. Do not guess what it said.

Then write the file:

1. Status. This ISO week or the next: **Aktiv plan för veckan**. Any later Monday: **Tidigt utkast**. An early draft only gets rows those reads support. Leave the other numbers blank.
2. Up to 10 player-visible changes. Words they used in this turn win. If they only named the week, draft from the reads above.
3. At most five rows start with **Måste.** Those rows are the Play lines and the Discord bullets, in the same order. A row without that mark may move and stays out of the announcement.
4. Anything past 10 goes under **Inte den här veckan**.
5. One English sentence a new player understands. Keep KEY, Gauntlet, and Ascend out of that sentence unless they named that as the week.
6. **Varför just det här** names each source and its date. **Spelarvärde** is Swedish.
7. Version aim: the next patch after `pubspec.yaml` `version:` and after any build already in review. Do not bump the version here.
8. **Förra veckans version:** the newest build sent to Production and its state, from Operator status: live, in review, or built and not sent.
9. **Telefontest:** three steps a brand-new save can reach, one per **Måste** row where that fits. Add one endgame-save step only when a **Måste** row changes endgame.
10. **Butiksbilder** stays as written in the template. Add a store-shot row only when heroes, the hub, or the combat screen will look different to the player.
11. Wednesday, **Under veckan**, Sunday, and **Utfall** start unchecked and blank.

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
- Status är **Aktiv plan för veckan** när måndagen är den här veckan eller nästa. Längre fram är status **Tidigt utkast**, och tomma rader lämnas tomma.
- Högst fem rader börjar med **Måste.** De ska med i Play-raderna och Discord. Övriga rader får flyttas utan att annonsen nämner dem.

---

## Vecka

- **Måndag:** ÅÅÅÅ-MM-DD
- **Söndag:** ÅÅÅÅ-MM-DD
- **Version vi siktar på:** 1.x.y
- **Förra veckans version:** 1.x.y (ute / i granskning / byggd men inte inskickad)
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

Högst fem rader börjar med **Måste.**

---

## Inte den här veckan

-
-
-
-
-

---

## Varför just det här

Källa och datum: öppna PLAY_NOTES, förra veckans överblivna rader, senaste Patch Notes, vad som ligger inne på Play, Nu i årsplanen, Play-recensioner, Discord #bugs, eller egen observation. En källa som inte gick att läsa står som **inte läst**. Ingen webbsökning.

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

## Telefontest (ny save)

Tre steg du gör på telefonen innan du säger till om AAB.

1. 
2. 
3. 

---

## Söndag — släpp

- [ ] Planerade förändringar är klara eller medvetet flyttade
- [ ] Patch Notes på engelska (MORE → INFO → PATCH NOTES)
- [ ] Play-rader klara
- [ ] Du har gått igenom telefontestet
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
- Fill **Utfall**. **Släppt som** is the version submitted. Leftovers go under **Flyttat till nästa vecka** there. A moved **Måste** row keeps that mark.
- Play lines and Discord list only **Måste** rows that are done. Leave an unfinished **Måste** row out of the announcement.
- Read the Production track again. If an earlier build is still in review, the announcement names the version players will get, not only the one sent today.
- Do not upload. Do not post unless they asked in that turn.

## Done when

- A "gör" ask left the week file on disk, using the template. A "vad är planen" ask quoted that file, or said it is missing.
- No AAB was uploaded and no Discord post was sent.
