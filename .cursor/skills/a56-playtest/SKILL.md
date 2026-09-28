---
name: a56-playtest
description: >-
  Default live look for Idle Party: Samsung A56 Android emulator + flutter run
  (hot reload). Use when the owner should see the app, after UI/hub/dungeon
  chrome, when the owner says "show me the app" / "visa spelet", or instead
  of Flutter web in a browser tab.
---

# A56 playtest (Idle Party)

**This is the default way we look at the running game.** Do not start Flutter
web (`web-server` / localhost:808x) for a human look. Web is fallback only
(see [browser-playtest](../browser-playtest/SKILL.md)).

Owner reference: **Samsung Galaxy A56** — **1080×2340 @ 480 dpi** → **360×780**.

## Device order

1. **USB A56** if `flutter devices` shows the real phone — use that.
2. Else **AVD `Samsung_A56`** (not `Pixel_6`).
3. Web / Cursor browser only if Android cannot run (no SDK, Playwright
   listing shots, or agent clicks via `WebClickBridge`).

## Loop

1. If a `flutter run` on the emulator is **already attached**, reuse it.
   Hot reload `r` / hot restart `R` in that session. Do not launch another
   server.
2. If the emulator is off:

```bash
flutter emulators --launch Samsung_A56
```

3. Wait until boot is done (`adb shell getprop sys.boot_completed` prints `1`).
   Installing too early fails with “device is still booting”.
4. Then:

```bash
flutter run -d emulator-5554
```

Use the android id from `flutter devices` if it is not `emulator-5554`.
5. Look at the **emulator window**. Never tell the owner to refresh a random
   localhost tab.

## One session only

Stacked `flutter run -d web-server` on 8080 / 8082–8088 is how we showed
**old UI**. If you find several of those, kill them. Keep **one** Android
`flutter run`.

## Recreate the AVD (only if missing)

```bash
avdmanager create avd -n Samsung_A56 -k "system-images;android-36;google_apis;x86_64" -d pixel_6 --force
```

Then set in `~/.android/avd/Samsung_A56.avd/config.ini`:

- `hw.lcd.width=1080` · `hw.lcd.height=2340` · `hw.lcd.density=480`
- `hw.device.manufacturer=Samsung` · `hw.device.name=Galaxy A56`
- `showDeviceFrame=no` · `skin.name=1080x2340`

Google does not ship One UI. **Screen size** is what we need.

## See the app (ADB)

Read structure first. One command dumps the UI tree (label, center, bounds)
and the recent `[IP]` lines. On this PC `python` is a store alias, so use
`py -3`:

```bash
py -3 tool/adb_see.py
py -3 tool/adb_see.py see GEAR
py -3 tool/adb_see.py tap CONTINUE
py -3 tool/adb_see.py swipe 540 1800 540 900
py -3 tool/adb_see.py key back
py -3 tool/adb_see.py log
```

`tap` / `swipe` / `text` / `key` act, wait, then print the new tree. Match
buttons by their label. Do not hard-code a tap coordinate when a label exists.

Take a PNG only when pixels matter (doll, gear art, color, overlap):

```bash
py -3 tool/adb_see.py shot playshots/now.png
```

Leave the layout-debug overlay off. Bounds are already in the dump, and the
overlay draws on the window the owner is watching. A video mirror (`scrcpy`)
is for human eyes; this loop reads the tree and the log.

Debug builds print `[IP]` into `flutter run` / logcat. Release stays quiet.

- `nav` — GEAR / GOLD/… / SHOP / ESSENCE/… / KEY / MORE / closed (`MenuRouter.debugWhere`)
- `toast` — what the player just saw
- `boot` / `continue` / `new_game` / `enter` / `leave` / `wipe` / `ascend`
- `state` — gold, essence, KEY, forge ATK/DEF/STA, bag, floor (tiny hub gold ticks skipped)

The attached `flutter run` terminal shows the same `[IP]` lines live.

## After code changes

**Hard rule:** never ask the owner to look / test on the phone until **this
batch** is running on the A56. A live `flutter run` started *before* the
edits still has the old isolate — that is not “the new build”.

1. Dart / logic / copy / HUD: hot **restart** (`R`) on the attached session.
   If you cannot send `R` (no stdin, tool detached, session older than the
   edits), **one** new `flutter run -d emulator-5554` (keeps the emu save).
2. Small widget-only tweaks: hot **reload** (`r`) is enough *after* you
   confirm this session compiled the new files.
3. **New / deleted PNGs or asset paths:** full `flutter run` (or
   `--purge-persistent-cache`). Hot reload will **not** ship new art.
4. Wait until this session shows the app is live (`Syncing files to device` /
   `Flutter run key commands` / `[IP]` boot). Then the short Swedish test
   list. If `flutter run` already exited or “Lost connection”, relaunch
   first — an idle emulator with an old APK is not “the new build”.
5. **“Installera om” / up to date:** stop the old `flutter run`, then one new
   `flutter run -d emulator-5554` (keeps the emu save). Prefer keep-save
   reinstall; `adb uninstall` wipes that save — OK when the batch needs a
   clean Play-style install. Do not stack a second `flutter run`.

## Related

- Hub checklist on this device: `hub-smoke`
- Agent-driven web clicks: `browser-playtest` (fallback)
- Analyze/tests: `flutter-verify`
