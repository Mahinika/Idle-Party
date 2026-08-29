---
name: a56-playtest
description: >-
  Default live look for Idle Party: Samsung A56 Android emulator + flutter run
  (hot reload). Use when the owner should see the app, after UI/hub/dungeon
  chrome, or instead of Flutter web in a browser tab.
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

## After code changes

- Copy / menu labels: hot **restart** (`R`) so the owner sees new English.
- Small widget tweaks: hot **reload** (`r`) is enough.
- Then a short phone test list (Swedish). Wait. No APK unless they asked.

## Related

- Hub checklist on this device: `hub-smoke`
- Agent-driven web clicks: `browser-playtest` (fallback)
- Analyze/tests: `flutter-verify`
