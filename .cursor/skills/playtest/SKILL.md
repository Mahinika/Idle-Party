---
name: playtest
description: >-
  Ten-minute phone playtest on the Samsung A56 that continues the existing
  save. Use when the owner says playtest, /playtest, testa spelet, spela
  igenom, kolla allt som är fel, rörigt, ser snett ut, or känns dåligt.
  Finds what disagrees with the code, what is correct but bad for the
  player, and art that looks wrong. Do not use for DPS-only balance
  (grinding-until-pass), one broken cast (add-ability), or a Play upload.
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

1. Read [docs/PLAYTEST_MEMORY.md](../../docs/PLAYTEST_MEMORY.md) and the
   Open section of [docs/PLAY_NOTES.md](../../docs/PLAY_NOTES.md). From
   memory, name what the last round actually opened and what is **OK**.
   Then pick the round: something that was not just tested and is not OK.
   An OK screen is not the point of the round. Open it only if the path
   runs through it. A **good** picture is a baseline, not a reason to
   spend the round there again.
2. Follow [a56-playtest](../a56-playtest/SKILL.md) until **this** batch is
   the build on the emulator. Keep the save. Do not `adb uninstall`.
3. Start the round:

```bash
py -3 tool/playtest_run.py start
py -3 tool/playtest_run.py start --new
py -3 tool/playtest_run.py start --scope GEAR
```

What `start` does: [reference.md](reference.md) § What start does.

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

Fight sheets and the UI tree fallback: [reference.md](reference.md) § Fight sheet and UI tree.

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

Three questions and the flags already caught: [reference.md](reference.md) § What counts as a finding.

## Research

For each finding the picture agrees with, research it (about 5 minutes each, 20 for the round). Rules: [reference.md](reference.md) § Research.

## Decide, log, fix

Each finding gets a type (`kod` / `ux` / `visuellt`), a severity
(`blockerar` / `forvirrar` / `kosmetiskt`), and **one** fix with its source.
A design fork: read the rule `.cursor/rules/decide-a-fork.mdc` quietly and pick once. A big change to
how a screen looks or feels is shown on the A56 before and after, and the
owner picks, before you build on (`20-how-we-work`).

Write Open notes in `docs/PLAY_NOTES.md`:

`date · what the player sees · type · severity · chosen fix (source)`

Fix in order: blocks, confuses, cosmetic. Each fix gets a Flutter test or a
new rule in `tool/playtest_checks.py`, so it cannot come back quietly.
Verify with the matching tests from `30-done`.

Re-run the same path on the A56 with this batch:

```bash
py -3 tool/playtest_run.py after f001
```

Move fixed notes to Done with the commit. Leave the rest under Open with
the reason.

## Memory for the next round

Before hand off, store 3–5 good / ok / learn notes. Commands: [reference.md](reference.md) § Memory for the next round.

## Done when

- `py -3 tool/playtest_run.py report` ran after a full round (not a tool check).
- Every finding the picture agrees with is fixed or written under Open in `docs/PLAY_NOTES.md`.
- Fixes pass the matching `30-done` tests, and `after` re-ran their path on the A56.

## Hand off

At most 5 lines in Swedish: how many findings were fixed, how many remain,
the most important change, and a short test list for **the save you just
played** (a new save only if this round used `--new`). Then wait.

## If Android will not run

Use [browser-playtest](../browser-playtest/SKILL.md) and say that the
automatic checks did not run. Never upload an AAB.

Checks without a phone: [reference.md](reference.md).
