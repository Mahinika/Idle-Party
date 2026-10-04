---
name: playtest
description: >-
  Ten-minute phone playtest on the Samsung A56 that continues the existing
  save. Use when the owner says playtest, /playtest, testa spelet, spela
  igenom, kolla allt som är fel, rörigt, ser snett ut, or känns dåligt.
  Finds what disagrees with the code, what is correct but bad for the
  player, and art that looks wrong. Do not use for DPS-only balance
  (share-fast), one broken cast (add-ability), or a Play upload.
---

# Playtest (Idle Party)

One round is about **10 minutes of play** on the Samsung A56, then notes,
research, and fixes. During the 10 minutes, do not fix anything and do not
read code. The clock is real time.

Default is the save already on the emulator. `ny save` or `första timmen`
starts a new game. Any other words (`GEAR`, `dungeon`, `endgame`) are the
scope: same round, about half the time on that part.

## Safety (it is the owner's save)

- Do not Ascend, REBORN, spend real money, Redeem, erase a save, or scrap
  good gear unless the scope says so. You may open the screen up to the
  confirm step, then back out. The tool refuses Overwrite, Erase, Reborn,
  Redeem, and Delete.
- Ads: only a playtest or preview button, never a real ad.
- If the save is damaged: `py -3 tool/playtest_run.py restore`

## Before the 10 minutes

1. Read [docs/PLAYTEST_MEMORY.md](../../docs/PLAYTEST_MEMORY.md) (what was
   good, patterns to hunt) and the Open section of
   [docs/PLAY_NOTES.md](../../docs/PLAY_NOTES.md).
2. Follow [a56-playtest](../a56-playtest/SKILL.md) until **this** batch is
   the build on the emulator. Keep the save. Do not `adb uninstall`.
3. Start the round:

```bash
py -3 tool/playtest_run.py start
py -3 tool/playtest_run.py start --new
py -3 tool/playtest_run.py start --scope GEAR
```

`start` copies the save, cold-starts the app (a live `flutter run` may
drop; leave it dropped until the round is over; `[IP]` still lands in
logcat), taps CONTINUE, then the occupied save, and checks Welcome back
against the save. If CONTINUE is missing it says so and uses PLAY / a new
game. Hub smoke's checklist is the hub part of this round, not a
separate pass.

## The 10 minutes

Play like a stranger. Before each tap, pass `--expect` with what you think
will happen. Run `status` about every two minutes. Open **look extra**
screens first (code changed since OK, or the baseline is stale).

Rough split: **4 minutes in a fight at normal speed** (at least one floor)
and **6 minutes in menus**. With a scope, give that about half the time.

```bash
py -3 tool/playtest_run.py status
py -3 tool/playtest_run.py snap gear
py -3 tool/playtest_run.py tap "ENTER DUNGEON" --expect "a floor loads"
py -3 tool/playtest_run.py back --expect "back on the hub"
py -3 tool/playtest_run.py swipe 540 1800 540 900
py -3 tool/playtest_run.py fight 240
py -3 tool/playtest_run.py note "two primaries on the hub" --type ux --sev forvirrar
```

`fight` takes a picture every 20 seconds and builds one contact sheet.
Read that sheet, not every fight frame.

The hub and a fight keep moving, so `uiautomator dump` often gives up.
The tool then reads the Flutter semantics tree from the debug VM. A snap
can still have a tree. A release build has no VM, so the tree stays empty.

Cover the list `status` prints. It depends on the save: early, mid, or
endgame (party mean level 100 or AL20). An OK from last time is **not** a
skip. Visit the screen again.

Stop after about 4 missed taps on the same control. Say which screen, which
label, and what you would try next.

While playing, only `snap`, `tap`, `fight`, and a short `note`. Save code
reading for after `report`.

## After the clock

```bash
py -3 tool/playtest_run.py report
```

The report says **tool check** when the round was under 8 minutes or a
screen on the list was never opened. That file is proof the tool ran. It
is not a list of what is wrong with the game. Stop there. Do not research
or fix those readings.

A full round still lists findings. Open that finding's snap PNG before it
counts. If the picture does not show the same thing, the tool misread.
Drop it. Do not research it and do not fix it. What the player sees wins.

Three questions for every screen you actually opened, even ones that were
OK last time:

- **Code.** Read the screen's code (`MenuRouter`, the widget,
  `GameLogic`) and compare it to the saved tree, `[IP]` state, and toasts.
  Wrong number, a button that does nothing, copy that lies, or a lock that
  disagrees with `AGENTS.md`.
- **Player.** This counts even when the code is right. Is the next step
  obvious within about 3 seconds? Is there one main action? How many taps
  to get there? Is the text readable at 360 px? What do empty, loading, and
  error look like? Would a new player know that word?
- **Picture.** Look at the PNG and any diff image. Crooked, floating,
  clipped, overlapping, wrong scale, blurry pixels. What the player sees
  wins over what the code claims. Hand the fix to the skill that owns it:
  `armor-placement`, `weapon-grip-placement`, `gear-art`, `hero-rig`,
  `enemy-art`, `floor-feel`, `zone-art-identity`, `docs/UI_THEME.md`,
  `spatial-combat-change`.

Buttons smaller than the game's own tap size (44 dp, `GameTheme.minTouch`)
are already flagged. So are off-screen nodes, overlapping buttons, duplicate
labels, a screen with no way on, jargon on an AL0 save, and header numbers
that disagree with the save.

## Research

For each finding the picture agrees with, and that is not a trivial
cosmetic fix, search the web (WebSearch / WebFetch). About 5 minutes a
finding, and about 20 minutes for the whole round. Prefer Material,
Android accessibility, Flutter docs and issues, and published game-UX
talks. Save 1–3 sources with one sentence each. Ideas only: no assets or
code from outside the repo.

Group findings that are the same pattern and research the group once.

## Decide, log, fix

Each finding gets a type (`kod` / `ux` / `visuellt`), a severity
(`blockerar` / `forvirrar` / `kosmetiskt`), and **one** fix with its source.
A design fork: read `studio-seats` quietly and pick once. A big change to
how a screen looks or feels is shown on the A56 before and after, and the
owner picks, before you build on (`owner-preferences`).

Write Open notes in `docs/PLAY_NOTES.md`:

`date · what the player sees · type · severity · chosen fix (source)`

Fix in order: blocks, confuses, cosmetic. Each fix gets a Flutter test or a
new rule in `tool/playtest_checks.py`, so it cannot come back quietly.
Verify with the matching tests from `definition-of-done`.

Re-run the same path on the A56 with this batch:

```bash
py -3 tool/playtest_run.py after f001
```

Move fixed notes to Done with the commit. Leave the rest under Open with
the reason.

## Memory for the next round

```bash
py -3 tool/playtest_run.py good hub "One obvious ENTER DUNGEON"
py -3 tool/playtest_run.py ok gear
py -3 tool/playtest_run.py learn "numbers in buttons clip at 360 px" --rule touch_small
```

- `good` stores a baseline picture and tree (`tool/playtest_baseline/`).
  Next time, a missing button, a big move, a new main button, or a changed
  picture (fight field and changing numbers masked out) becomes a finding.
  Replace a baseline only when the screen was changed on purpose and is
  better. `good` resets the stale counter.
- `ok` records the commit. It never means skip. After 3 OKs the next round
  asks for a fresh baseline. If the screen's files changed since that
  commit, it is listed under look extra.
- `learn` stores the pattern, not only the one bug. A pattern that can be
  measured from the UI tree becomes a rule in `playtest_checks.py`.

Keep about 3–5 new "good" notes per round, not a diary of every button.

## Hand off

At most 5 lines in Swedish: how many findings were fixed, how many remain,
the most important change, and a short test list for **the save you just
played** (a new save only if this round used `--new`). Then wait.

## If Android will not run

Use [browser-playtest](../browser-playtest/SKILL.md) and say that the
automatic checks did not run. Never upload an AAB.

Pillow is required for picture diffs: `py -3 -m pip install pillow`.
Checks without a phone: `py -3 -m pytest tool/test_playtest_checks.py tool/test_playtest_imgdiff.py tool/test_playtest_run.py`
