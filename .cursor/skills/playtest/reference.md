# Playtest reference (Idle Party)

Read when you need tool details, research rules, or memory commands.

## Fight sheet and UI tree

`fight` takes a picture every 20 seconds and builds one contact sheet.
Read that sheet, not every fight frame.

The hub and a fight keep moving, so `uiautomator dump` often gives up.
The tool then reads the Flutter semantics tree from the debug VM. A snap
can still have a tree. A release build has no VM, so the tree stays empty.

## Research

For each finding the picture agrees with, and that is not a trivial
cosmetic fix, search the web (WebSearch / WebFetch). About 5 minutes a
finding, and about 20 minutes for the whole round. Prefer Material,
Android accessibility, Flutter docs and issues, and published game-UX
talks. Save 1–3 sources with one sentence each. Ideas only: no assets or
code from outside the repo.

Group findings that are the same pattern and research the group once.

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

## What start does

`start` copies the save, cold-starts the app (a live `flutter run` may
drop; leave it dropped until the round is over; `[IP]` still lands in
logcat), taps CONTINUE, then the occupied save, and checks Welcome back
against the save. If CONTINUE is missing it says so and uses PLAY / a new
game. Hub smoke's checklist is the hub part of this round, not a
separate pass.

## What counts as a finding

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

## Checks without a phone

Pillow is required for picture diffs: `py -3 -m pip install pillow`.
Checks without a phone: `py -3 -m pytest tool/test_playtest_checks.py tool/test_playtest_imgdiff.py tool/test_playtest_run.py`
