# Kenney audio (Idle Party)

SFX under `sfx/` are short clips from **Kenney RPG Audio** (CC0),
renamed to Idle Party event ids (`hit.ogg`, `ui.ogg`, `hit_blade.ogg`, …).

Original pack: https://kenney.nl/assets/rpg-audio  
License: Creative Commons Zero (CC0) — see `License.txt`.

**Gameplay SFX** now use Idle Party soft procedural one-shots under
`assets/custom/audio/sfx/` (see `tool/generate_soft_sfx.py` and
`tool/generate_combat_spell_sfx.py`). Kenney clips remain in-repo as CC0
reference; they are not loaded at runtime.

Kenney → Idle Party id mapping (historical):

| Idle Party id | Kenney source |
|---------------|---------------|
| hit / hit_blade | knifeSlice |
| hit_dagger | drawKnife1 |
| hit_blunt | metalPot2 |
| hit_axe | metalPot3 |
| hit_fist | cloth2 |
| hit_bow | creak2 |
| crit | knifeSlice2 |
| kill | chop |
| (UI / loot / doors) | metalClick, handleCoins*, doorOpen*, … |

Ambience loops live under `assets/custom/audio/ambience/` (Idle Party
procedural pads), not Kenney.

Background music loops live under `assets/custom/audio/music/` —
hub is Idle Party procedural (`hub.wav`); dungeon is owned ElevenLabs
(`dungeon.mp3`). Not Kenney.
