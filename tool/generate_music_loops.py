"""Owned score cues and cave beds.

Does not overwrite:
  music/hub.ogg      — Heavenly Loop (isaiah658, CC0)
  music/dungeon.mp3  — owned ElevenLabs loop ("Deep Cave Hush")

Writes bed_*.ogg, boss.ogg, resolve.ogg, down.ogg, and ambience/*.ogg.
"""

from audio_synth.render_music import render

if __name__ == "__main__":
    render()
