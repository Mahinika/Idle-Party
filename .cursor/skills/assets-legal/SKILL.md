---
name: assets-legal
description: >-
  Enforces Idle Party art and asset conventions (Kenney CC0, owned custom,
  KenneyAssets/CustomAssets helpers, FilterQuality.none, no commercial
  dumps). Use when adding sprites, icons, portraits, backdrops, pets, or
  any assets/... path in UI.
---

# Assets & legal (Idle Party)

## Legal (mandatory)

- Shipped art only from `assets/kenney/` (CC0) or `assets/custom/` (owned)
- Never copy sprites/audio/code/text from other games; no APK/IPA/SWF/DEX dumps
- Delete stray third-party binaries; keep `.gitignore` covering them
- Gameplay *ideas* OK — original Dart only

## Path helpers (required)

| Helper | File |
|--------|------|
| `KenneyAssets` | `lib/ui/kenney_assets.dart` |
| `CustomAssets` | `lib/ui/custom_assets.dart` |
| `KenneySprite` | `lib/ui/kenney_sprite.dart` (sets `FilterQuality.none`) |

**UI must not hardcode** `'assets/...'` strings. Prefer `KenneySprite(asset: …)`.

## Layout

```
assets/kenney/   # tiny_dungeon, icons, ui_*, runes, extras, roguelike_char
assets/custom/   # heroes, enemies, pets, icons, portraits, ui/, ui/backdrops/
assets/data/     # JSON (e.g. item_affixes)
```

Existing folders are listed in `pubspec.yaml`. New **top-level** asset folders need a pubspec entry.

## Add a sprite

```
New sprite:
- [ ] 1. Place under kenney/ or custom/ (legal source)
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

Do not copy the hardcoded atlas path in `hero_paper_doll.dart` for new assets.
