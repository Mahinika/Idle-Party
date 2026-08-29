# Idle Party

**Your party keeps fighting while you watch — or while you’re away.**

Idle Party is a cozy-but-crunchy **idle RPG**: a hero party crawls spatial dungeon floors, clears chambers, farms loot, and grows stronger between runs. Tap in for God Hand moments, or let the corridor combat cook offline.

<p align="center">
  <img src="tool/art_backups/app_icon.png" alt="Idle Party app icon" width="160" />
</p>

**[Download Android APK (latest)](https://github.com/Mahinika/Idle-Party/releases/latest)** · **[All releases](https://github.com/Mahinika/Idle-Party/releases)**

Primary Android distribution is **GitHub Releases (sideload)**; Play Store is optional (see [docs/PLAY_STORE.md](docs/PLAY_STORE.md)).

---

## Why you’ll want to try it

- **Real dungeon crawling, not a fake progress bar** — multi-chamber maps, gates that open after clears, and a party that actually walks the floor.
- **A full party with class kits** — 10 classes and **31 specs**. Pick your starters on New Game; unlock more via Ascend and clears. Abilities, buffs, and a live DPS share meter.
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

### From source

```bash
flutter pub get
flutter emulators --launch Samsung_A56   # A56-sized phone (1080×2340)
flutter run -d emulator-5554
# USB phone if plugged in: flutter devices, then flutter run -d <id>
```

---

## What’s in the loop

| Layer | What you do |
|--------|-------------|
| **Hub** | TODAY chase, pick a zone, KEYSTONE, daily run, Ascend when ready |
| **Dungeon** | Clear chambers → loot → stairs. Watch the party fight live |
| **Bag & Forge** | Gear, combinator (MERGE SCORE), training, relics, sanctuary |
| **Meta** | Pets, prestige sinks, contracts, weekly challenge, Will rank & titles |

World Path is **15 zones** from Sandy Caverns through Mothveil Hollow
(Brassvault, Blightfen, Rimeglass, Stormwake, Grove, Tidehold, Ashen Vault on
the road) — each with its own look, packs, and bosses.

**Ship:** [latest GitHub Release](https://github.com/Mahinika/Idle-Party/releases/latest) (1.12.28 — What’s New is also in-game).

---

## Build notes (devs)

```bash
flutter build apk --release
```

Without `android/key.properties`, release APKs are **debug-signed** (fine for sideload). For Play Store signing, copy `android/key.properties.example` → `android/key.properties` and point at your keystore.

CI builds an APK (+ App Bundle) on tags matching `v*` (`.github/workflows/build-apk.yml`). Push runs analyze + tests (`.github/workflows/ci.yml`).

**Package id:** `com.idleparty.app` · **Saves:** SharedPreferences (`idle_party_save_v2`)

Privacy: [docs/PRIVACY.md](docs/PRIVACY.md) · Cadence: [docs/CONTENT_CADENCE.md](docs/CONTENT_CADENCE.md) · Play checklist: [docs/PLAY_STORE.md](docs/PLAY_STORE.md)

---

## License & art

- Game code: [MIT](LICENSE); Kenney under `assets/kenney/`: [CC0](https://kenney.nl/license); custom art under `assets/custom/`: all rights reserved.
- Do not drop commercial game dumps, APKs from other titles, or ripped sprites into this repo.

---

*Clear one more floor. Claim the contracts. Ascend when the bosses say you’re ready.*
