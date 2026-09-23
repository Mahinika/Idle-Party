---
name: assets-legal
description: >-
  Enforces Idle Party art rules: owned files under assets/custom/ only,
  CustomAssets and KenneyAssets helpers (the Kenney name is legacy),
  FilterQuality.none, no commercial dumps or foreign packs. Use when adding
  sprites, icons, portraits, backdrops, pets, or any assets path in UI.
  Do not use for paper-doll layering (character-paper-doll) or a cave that
  looks like its neighbor (zone-art-identity).
---

# Assets & legal (Idle Party)

## Legal (mandatory)

- Shipped art only from `assets/custom/` (owned)
- Never copy sprites/audio/code/text from other games; no APK/IPA/SWF/DEX dumps
- Delete stray third-party binaries; keep `.gitignore` covering them
- Gameplay *ideas* OK — original Dart only

## Path helpers (required)

| Helper | File |
|--------|------|
| `KenneyAssets` | `lib/assets/kenney_assets.dart` |
| `CustomAssets` | `lib/assets/custom_assets.dart` |
| `KenneySprite` | `lib/ui/kenney_sprite.dart` (sets `FilterQuality.none`) |

**UI must not hardcode** `'assets/...'` strings. Prefer `KenneySprite(asset: …)`.

## Layout

```
assets/custom/   # heroes, enemies, pets, icons, portraits, ui/, dungeon/, audio
assets/data/     # JSON (e.g. item_affixes)
```

Existing folders are listed in `pubspec.yaml`. New **top-level** asset folders need a pubspec entry.

Audio: **runtime SFX** under `assets/custom/audio/sfx/` (owned procedural + unlock; paths via `AudioAssets` / variation banks). Ambience + music under `assets/custom/audio/ambience/` and `…/music/`. Never raw `assets/...` in call sites. Never copy audio from other commercial games.

## Add a sprite

```
New sprite:
- [ ] 1. Place under `assets/custom/` (owned)
- [ ] 2. pubspec dir if new folder
- [ ] 3. Const/getter on CustomAssets and/or KenneyAssets
- [ ] 4. Wire resolvers (hero/enemy/portrait/pet/equipment) if needed
- [ ] 5. UI via helper + KenneySprite / FilterQuality.none
- [ ] 6. asset_catalog / custom_assets tests still pass
```

## Correct vs wrong

```dart
// Correct
KenneySprite(asset: KenneyAssets.iconDoor, size: 16);
KenneySprite(asset: KenneyAssets.dungeonPortraitFor(def.id));

// Wrong — raw path / missing nearest-neighbor / ripped art
Image.asset('assets/custom/heroes/knight.png');
Image.asset(KenneyAssets.iconSword); // missing FilterQuality.none
```

Do not hardcode `'assets/...'` in UI; use helpers.

Owned denser heroes (undertunic + 128 overlays): [character-paper-doll](../character-paper-doll/SKILL.md).
