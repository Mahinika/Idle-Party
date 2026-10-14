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

The week file is the short template below. Rules stay in this skill. Do not
copy them into the week file. A week holds content and fixes that can be
ready by Sunday, and at least one new feature that makes people want to
play and keep playing.

Never upload an AAB here. Upload only when the owner asks in that turn
(`play-store-prep`). Never post to Discord unless they ask in that turn.
In-game Patch Notes are `screenshotting-changelog`.

Folder note: `docs/weeks/README.md`.

## Rules

- Up to 10 player-visible rows. Leave no blank numbers.
- Each row is `Måste · Content — change — why the player cares — status`, or the same with `Fix` or `Nytt`. Drop `Måste ·` when the row may slip.
- Status is `ej klar`, `spelbar`, or `flyttad`.
- At most five rows are **Måste**. Those are the Sunday announcement, in that order.
- At least one row is **Nytt**: a development to add, not a change already in an unsent build. It makes the game more attractive to start, or gives a reason to keep playing. Read the three pillars in `docs/GROWTH_MANDATE.md` and **Nu** in `docs/YEAR_ROADMAP.md`. Do not add a new zone, class, hunt, or gacha unless Nu or the owner already named it.
- **Content** and **Fix** are what should be ready by Sunday.
- A new idea mid-week goes under **Inte den här veckan**. Only a critical bug may take a planned slot. The row it displaces becomes `flyttad`.
- This ISO week or the next: status **Aktiv**. Any later Monday: **Tidigt utkast**, and only the rows the sources support.
- Sunday means submitted to Play, not approved. The plan is Swedish. Player text is English.
- One English sentence a new player understands. Keep KEY, Gauntlet, and Ascend out of it unless they named that as the week.
- Store shots only when heroes, the hub, or the combat screen will look different. That is a row, not a standing section.
- Play lines and Discord are written on Sunday, from **Måste** rows whose status is `spelbar`. Do not put empty drafts in the file on Monday.

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
| vad är planen / planen för vecka N | Read that file. Reply in Swedish with status, the **Måste** rows, the other rows, and the one sentence. Missing file: say there is no plan. Do not write one. |
| gör en veckoplan, file exists | Show it. Change a row only when they named the change. |
| gör en veckoplan, file missing | Write it from the template, show it, stop. Do not start building the rows. |
| onsdagskoll | Tick **Onsdag**. A row that will not finish becomes `flyttad` and moves under **Inte den här veckan**, still marked **Måste** if it was. |

## Write a missing plan

Read these. No web search. Do not run the year-roadmap skill.

1. Open section of `docs/PLAY_NOTES.md`.
2. Previous week file, if it exists: **Inte den här veckan**.
3. Newest release in `lib/core/changelog.dart`. Do not list a change the live Play build already has. Changes in an unsent build still go on the list.
4. Operator status in `docs/PLAY_STORE.md`: which build is live, and which is in review. Do not invent Console numbers. If the Play API track read disagrees, trust the track and say the doc is behind.
5. The **Nu** section of `docs/YEAR_ROADMAP.md` only, plus the three pillars in `docs/GROWTH_MANDATE.md` for the **Nytt** row.
6. Play reviews through the Play API (`play-store-prep` reference, § Play API). The API returns about the last week only. Read only. Reply only when the owner names that review.
7. Discord #bugs through the Discord tools (`user-omnicord`, read messages). Read only. Never post, reply, or react here.

If a read fails, write **inte läst** next to that source. Do not guess what it said.

Then write the file. Version aim: the next patch after `pubspec.yaml` `version:` and after any build already in review. Do not bump it here. **Förra** is the newest build sent to Production and its state: ute, i granskning, or byggd men inte inskickad.

**Telefontest:** three steps a new save can reach, tied to **Måste** rows where that fits. Add one endgame-save step only when a **Måste** row changes endgame.

Onsdag, Söndag, and Utfall start unchecked. No Play or Discord block yet.

## Template

````markdown
# Vecka NN

**Status:** Aktiv
**Datum:** YYYY-MM-DD – YYYY-MM-DD
**Version:** 1.x.y
**Förra:** 1.x.y (ute)
**En mening:** 

## Att göra

1. Måste · Content — … — … — ej klar
2. Måste · Nytt — … — … — ej klar

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

## Sunday

When they say this week is shipping ("släpp veckan", "det är söndag"):

- Tick a Sunday box only when that step is done.
- Set **Släppt som** to the version submitted. Leftover **Måste** rows become `flyttad`.
- Then write **Play** and **Discord** from **Måste** rows that are `spelbar`, in order, in English. One bullet each. Same facts.

```text
**Idle Party 1.x.y**

• 

Play: https://play.google.com/store/apps/details?id=com.idleparty.app

Google is reviewing this update. The Play Store may still show the previous version for a while.
```

- Read the Production track again. If an earlier build is still in review, the announcement names the version players will get.
- Do not upload. Do not post unless they asked in that turn.

## Done when

- A "gör" ask left the short week file on disk. A "vad är planen" ask quoted that file, or said it is missing.
- No AAB was uploaded and no Discord post was sent.
