---
name: weekly-plan
description: >-
  Writes and reads Idle Party's plan for one ISO week, stored as one file
  per week. Use when the owner says "gör en veckoplan", "veckoplan för
  veckan 51", "vad är planen för vecka 48", "planen för vecka", or "den
  här veckan". That file is the plan they mean. Do not use for the
  12-month roadmap (year-roadmap), in-game Patch Notes
  (screenshotting-changelog), or uploading an AAB (play-store-prep).
---

# Weekly plan (Idle Party)

One ISO week, one file under `docs/weeks/`. That file is the only answer to
"vad är planen för vecka N". Do not answer from the year roadmap, play
notes, or an earlier chat. Those may feed a new file. They are not the plan.

Monday writes the file. Sunday that plan is what ships: a Play update
submitted, and a Discord announcement. Google often reviews overnight.
Sunday means submitted. The announcement names the build sent in, and the
version the store still shows if it has not changed.

Never upload an AAB here. Upload only when the owner asks in that turn
(`play-store-prep`). Never post to Discord unless they ask in that turn.

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
| vad är planen / planen för vecka N | Read that file. Reply in Swedish with the three rows, the one sentence, and which Sunday boxes are checked. Missing file: say there is no plan. Do not write one. |
| gör en veckoplan, file exists | Show it. Change a row only when they named the change. |
| gör en veckoplan, file missing | Write it, show it, stop. Do not start building the rows. |

## Write a missing plan

1. Read the Open section of `docs/PLAY_NOTES.md`. If the previous week file exists, read **Inte den här veckan**.
2. Three rows that can be done by that Sunday. Words they used in this turn win. If they only named the week, draft three from those notes.
3. Anything past three goes under **Inte den här veckan**.
4. One English sentence a new player understands. Keep KEY, Gauntlet, and Ascend out of that sentence unless they named that as the week.
5. Version aim: read `pubspec.yaml` `version:` and name the next patch. Do not bump it here.
6. Play lines and the Discord block match the three rows. English. Drafts, not sent.

## File shape

Swedish outside the Play and Discord blocks.

```markdown
# Vecka NN (YYYY-MM-DD – YYYY-MM-DD)

- **Version vi siktar på:**
- **En mening en ny spelare förstår:**

## Klart på söndag

1.
2.
3.

## Inte den här veckan

-

## Varför

-

## Under veckan

- [ ] 1
- [ ] 2
- [ ] 3

## Söndag — släpp

- [ ] De tre raderna är klara, eller medvetet flyttade
- [ ] Patch Notes på engelska
- [ ] Play-rader klara
- [ ] Du har tittat på bygget
- [ ] Du har sagt till att ladda upp AAB
- [ ] AAB inskickad
- [ ] Discord #announcements postad

## Play-rader

- 
- 
- 

## Discord

**Idle Party 1.x.y**

- 
- 
- 

Play: https://play.google.com/store/apps/details?id=com.idleparty.app
The store may still show the previous version until Google finishes review.
```

## Sunday

When they say this week is shipping ("släpp veckan", "det är söndag"):

- Open that week's file. Tick a box only when that step is actually done.
- In-game Patch Notes are `screenshotting-changelog`.
- Do not upload. Do not post unless they asked in that turn.
- A row that is not done waits. When they say the week slipped, move it to next week's **Inte den här veckan**. Do not send a half announcement.

## Done when

- A "gör" ask left the week file on disk. A "vad är planen" ask quoted that file, or said it is missing.
- No AAB was uploaded and no Discord post was sent.
