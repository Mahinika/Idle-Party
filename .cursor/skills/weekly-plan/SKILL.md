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

The week file is the template below. Rules stay in this skill. Do not
copy them into the week file. A full week lists exactly 25 jobs. Sunday
ships the ones that are `spelbar`. The rest stay on the list until they
are `spelbar` or `flyttad`. At least one job is a new feature that makes
people want to play and keep playing.

Never upload an AAB here. Upload only when the owner asks in that turn
(`play-store-prep`). Never post to Discord unless they ask in that turn.
In-game Patch Notes are `screenshotting-changelog`.

Folder note: `docs/weeks/README.md`.

## Rules

- Exactly 25 numbered rows under **Att göra**. No blank numbers. Every row is **Måste**. Those rows are the week's work, in that order. Fill the first rows from the checked holes: open play notes, then jobs already named for this week and the next, then a **Nu** slice this build does not already do. When those are fewer than 25, the rest are the next distinct things a player can point at in the crawl and the five hunts, that this build does not already do. Do not stop early. Do not invent a new zone, class, hunt, gacha, or a second sim. A row the code and the patch notes already show is not a row, unless the phone has not shown it and the row is about how it sits.
- A row is one thing a player can point at. The same rule in every cave, rank, or sentence is one row. Do not split it into a row per floor, rank, or line of copy.
- Under each row, three lines start with `Klart när:`. That is the test for that row. It is not another job. Do not turn a `Klart när` line into its own row. The batch to build is the numbered row.
- Each row is `Måste · Content — change — why the player cares — status`, or the same with `Fix` or `Nytt`.
- Status is `ej klar`, `spelbar`, or `flyttad`. A row about whether something fits or reads on the phone (a hall, a clock, a line of text) stays `ej klar` until this chat has an A56 screenshot of it. Grip, helm, icon parity, and which PNG a neighbor uses are settled by facit or a path test: the fight draws them too small to judge. Do not mark the row `spelbar` and write "behöver en titt" under Källor.
- At least one row is **Nytt**, and more when the evidence supports them. A **Nytt** row can be something this game does not have yet. It comes from what another game or a developer measured, fitted to this game. Read `docs/YEAR_ROADMAP_SOURCES.md` first. If those grades do not cover the hole, open a few pages. A source counts only if you opened it in this chat and can name the URL. Grade A may add the row. Grade B is an example only after a hole in this game is already clear. Grade C must not decide. Name the player problem the source measured. Fit it to the three pillars in `docs/GROWTH_MANDATE.md`: the party walks the room, one reason to come back tomorrow, one Ascend loop. Another game shipping a feature is not by itself a reason. When this game's notes disagree, follow this game. **Nu** in `docs/YEAR_ROADMAP.md` is one source, not a ceiling. A new zone, class, hunt, or gacha still waits until the owner names it, or an A source and a hole in this game agree.
- **Content** and **Fix** are what should be ready by Sunday.
- A new idea mid-week goes under **Inte den här veckan**. Only a critical bug may take a planned slot. The row it displaces becomes `flyttad`.
- The file whose dates contain today is **Aktiv**. That is the file to build from. The following week is **Nästa**, with the same 25 rows, and it is not the build target while **Aktiv** still has an `ej klar` row. Any later week is **Tidigt utkast**: status, dates, and **En mening** only. Write its 25 rows when it becomes **Nästa**. An **Aktiv** week that already lists rows keeps those rows unless the owner asks to refill it.
- A week file already shipped, or an older file that still lists many rows, stays as the record. Do not rewrite it into this shape unless the owner asks.
- Sunday means submitted to Play, not approved. The plan is Swedish. Player text is English.
- One English sentence a new player understands. Keep KEY, Gauntlet, and Ascend out of it unless they named that as the week.
- Store shots only when heroes, the hub, or the combat screen will look different. That is a row, not a standing section.
- Play lines and Discord are written on Sunday, from **Måste** rows whose status is `spelbar`. One bullet per row. Do not put empty drafts in the file on Monday.

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
| vad är planen / planen för vecka N | Read that file. Reply in Swedish with status, the **Måste** rows, the **Klart när** lines under them, and the one sentence. A later week: the sentence, and that the jobs are written when it is next. Missing file: say there is no plan. Do not write one. |
| gör en veckoplan, file exists | Show it. Change a row only when they named the change. |
| gör en veckoplan, file missing | Write it from the template, show it, stop. Do not start building the rows. |
| onsdagskoll | Tick **Onsdag**. A row that will not finish becomes `flyttad` and moves under **Inte den här veckan**, still marked **Måste** if it was. |

## Write a missing plan

Read these. Do not rebuild the 100-source year file. Do not run the year-roadmap skill.

1. Open section of `docs/PLAY_NOTES.md`.
2. Previous week file, if it exists: **Inte den här veckan**.
3. Newest release in `lib/core/changelog.dart`. Do not list a change the live Play build already has. Changes in an unsent build still go on the list.
4. Operator status in `docs/PLAY_STORE.md`: which build is live, and which is in review. Do not invent Console numbers. If the Play API track read disagrees, trust the track and say the doc is behind.
5. **De närmaste uppdateringarna** and **Senare i år** in `docs/YEAR_ROADMAP.md`, the three pillars in `docs/GROWTH_MANDATE.md`, and graded rows in `docs/YEAR_ROADMAP_SOURCES.md`. Open a few pages when the file does not cover the hole. Put each **Nytt** source under **Källor** with grade, title, and URL.
6. Play reviews through the Play API (`play-store-prep` reference, § Play API). The API returns about the last week only. Read only. Reply only when the owner names that review.
7. Discord #bugs through the Discord tools (`user-omnicord`, read messages). Read only. Never post, reply, or react here.

If a read fails, write **inte läst** next to that source. Do not guess what it said.

Then write the file. This week and the next use the full template. A later week is status, dates, and **En mening** only. Version aim: the next patch after `pubspec.yaml` `version:` and after any build already in review. Do not bump it here. **Förra** is the newest build sent to Production and its state: ute, i granskning, or byggd men inte inskickad.

**Telefontest:** three steps a new save can reach, tied to **Måste** rows where that fits. When one row covers many caves, the three steps are three places, not three more jobs. Add one endgame-save step only when a **Måste** row changes endgame.

Onsdag, Söndag, and Utfall start unchecked. No Play or Discord block yet.

## Template

Full week (this week, or the next). The list runs from 1 through 25. The block below is the shape of one row:

````markdown
# Vecka NN

**Status:** Aktiv
**Datum:** YYYY-MM-DD – YYYY-MM-DD
**Version:** 1.x.y
**Förra:** 1.x.y (ute)
**En mening:** 

## Att göra

1. Måste · Nytt — … — … — ej klar
   - Klart när: …
   - Klart när: …
   - Klart när: …

## Inte den här veckan

-

## Telefontest

1. 

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

-
````

The next week uses the same template with **Status:** Nästa. A later week is only this:

````markdown
# Vecka NN

**Status:** Tidigt utkast
**Datum:** YYYY-MM-DD – YYYY-MM-DD
**En mening:** 
````

## Sunday

When they say this week is shipping ("släpp veckan", "det är söndag"):

- Tick a Sunday box only when that step is done.
- Set **Släppt som** to the version submitted. Leftover **Måste** rows become `flyttad`.
- Then write **Play** and **Discord** from **Måste** rows that are `spelbar`, in order, in English. One bullet per row. Same facts.

```text
**Idle Party 1.x.y**

• 

Play: https://play.google.com/store/apps/details?id=com.idleparty.app

Google is reviewing this update. The Play Store may still show the previous version for a while.
```

- Read the Production track again. If an earlier build is still in review, the announcement names the version players will get.
- Do not upload. Do not post unless they asked in that turn.

## Done when

- A "gör" ask left the week file on disk. A full week has exactly 25 numbered rows, each with three **Klart när** lines. A later week has the one sentence. A "vad är planen" ask quoted that file, or said it is missing.
- No AAB was uploaded and no Discord post was sent.
