# Custom audio (Idle Party)

## Music

| File | Source | License |
|------|--------|---------|
| `music/hub.ogg` | [Heavenly Loop](https://opengameart.org/content/heavenly-loop) by isaiah658 | CC0 |
| `music/dungeon.mp3` | Owned ElevenLabs loop (“Deep Cave Hush”). Kept as the spare cave bed. The game plays `bed_*.ogg` instead. | Owned |
| `music/bed_warm.ogg` | Owned synth, warm caves (Sandy, Goblin, King). `tool/audio_synth` | Owned |
| `music/bed_dark.ogg` | Owned synth, dark caves (Underworld, City of Dead, Hell) | Owned |
| `music/bed_ice.ogg` | Owned synth, ice caves (Crystal Spire, Rimeglass) | Owned |
| `music/bed_wet.ogg` | Owned synth, wet caves (Tidehold, Blightfen, Hollow Grove) | Owned |
| `music/bed_storm.ogg` | Owned synth, storm and machine caves (Ashen, Brassvault, Stormwake, Mothveil) | Owned |
| `music/boss.ogg` | Owned synth (“Unresolved Crown”) | Owned |
| `music/resolve.ogg` | Owned synth (“Floor Breath”) | Owned |
| `music/down.ogg` | Owned synth (“The Drop”) | Owned |

## SFX

All `sfx/*.ogg` are owned synth one-shots from `tool/audio_synth` (`tool/generate_soft_sfx.py`, `tool/generate_combat_spell_sfx.py`). Hits `_a`…`_f` (bow `_a`…`_d`), spells `_a`…`_f`, plus menu, loot, and body cues. Mix via `AudioVariationCatalog`.

## Ambience

`ambience/*.ogg` — owned synth air (`tool/generate_ambience_pads.py`). Hub plus one pad per cave mood.
