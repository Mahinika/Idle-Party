# Idle Party

**Your party keeps fighting while you watch — or while you’re away.**

Idle Party is a cozy-but-crunchy **idle RPG**: a hero party crawls spatial dungeon floors, clears chambers, farms loot, and grows stronger between runs. Tap in for God Hand moments, or let the corridor combat cook offline.

<p align="center">
  <img src="assets/custom/ui/app_icon.png" alt="Idle Party app icon" width="160" />
</p>

**[Download Android APK (v1.9.2)](https://github.com/Mahinika/Idle-Party/releases/download/v1.9.2/app-release.apk)** · **[All releases](https://github.com/Mahinika/Idle-Party/releases)**

---

## Why you’ll want to try it

- **Real dungeon crawling, not a fake progress bar** — multi-chamber maps, gates that open after clears, and a party that actually walks the floor.
- **A full party with class kits** — 10 classes and ~30 talent specs (Warrior through Druid). Pick your starters on New Game; unlock more via Ascend and clears. Abilities, buffs, and a live DPS share meter.
- **Farm or Push** — milk a floor for loot, or shove deeper until the wipe. Your call.
- **God Hand** — tap the map to steer and smash. Upgrade it with essence.
- **Gear that feels good** — equip, auto-equip, sell junk, merge in the combinator, save loadouts.
- **Meta that survives Ascend** — sanctuary, relics, pets, prestige shop, contracts, weekly modifiers, achievements, codex.
- **Offline progress that respects the dungeon** — come back to gold, floors, and a clear summary.

Pixel art vibe powered by [Kenney](https://kenney.nl) (CC0) plus custom Idle Party identity art. Game systems and code are original.

---

## Quick start

### Android
Grab the latest APK from [Releases](https://github.com/Mahinika/Idle-Party/releases) and sideload it. No account. No ads in the build.

### From source (web / desktop / device)

```bash
flutter pub get
flutter run -d chrome
# or local web server:
flutter run -d web-server --web-hostname=localhost --web-port=8080
```

---

## What’s in the loop

| Layer | What you do |
|--------|-------------|
| **Hub** | Pick a zone, Hardmode, Boss Rush / No Flask, daily run, Ascend when ready |
| **Dungeon** | Clear chambers → loot → stairs. Watch the party fight live |
| **Bag & Forge** | Gear, combinator, training, relics, sanctuary |
| **Meta** | Pets, prestige sinks, contracts, weekly challenge, Will rank & titles |

Zones stretch from sandy caverns to hell and crystal — each with its own look, packs, and bosses.

---

## Build notes (devs)

```bash
flutter build apk --release
```

Without `android/key.properties`, release APKs are **debug-signed** (fine for sideload). For Play Store signing, copy `android/key.properties.example` → `android/key.properties` and point at your keystore.

CI builds an APK on tags matching `v*` (`.github/workflows/build-apk.yml`). Push runs analyze + tests (`.github/workflows/ci.yml`).

**Package id:** `com.idleparty.app` · **Saves:** SharedPreferences (`idle_party_save_v2`)

---

## License & art

- Game code: see repository license / project terms.
- Kenney assets: [CC0](https://kenney.nl/license).
- Do not drop commercial game dumps, APKs from other titles, or ripped sprites into this repo.

---

*Clear one more floor. Claim the contracts. Ascend when the bosses say you’re ready.*
