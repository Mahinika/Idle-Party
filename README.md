# Idle Party

A Flutter idle RPG: party combat on a spatial dungeon map, Farm/Push modes, gear, pets, sanctuary, and Ascend prestige.

Art uses [Kenney](https://kenney.nl) CC0 assets. Game systems and code are original to this project.

## Play

```bash
flutter pub get
flutter run -d web-server --web-hostname=localhost --web-port=8080
# or
flutter run -d chrome
flutter run   # Android / desktop
```

## Build APK

```bash
flutter build apk --release
```

Without `android/key.properties`, release APKs are **debug-signed** (fine for sideload). For Play / proper release:

1. Create a keystore and copy `android/key.properties.example` → `android/key.properties`
2. Point `storeFile` at your `.jks` (path relative to `android/app/`)
3. Rebuild — Gradle picks up the release signing config automatically

GitHub Actions builds an APK on tags matching `v*` (see `.github/workflows/build-apk.yml`). Optional secrets `KEYSTORE_BASE64`, `KEY_PROPERTIES` enable release signing in CI. Push also runs analyze + tests (`.github/workflows/ci.yml`).

## Layout

```
lib/
├── core/          # GameDirector, GameLogic, GameState
├── models/        # Heroes, loot, rooms, pets
├── spatial/       # Tile combat simulation
└── ui/            # Shell, dungeon view, hub overlays
```

## Notes

- Saves use SharedPreferences (`idle_party_save_v2`).
- Mute in Settings silences system SFX / haptics.
- Android application id: `com.idleparty.app`.
