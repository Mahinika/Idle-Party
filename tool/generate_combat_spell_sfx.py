"""Owned spell-school SFX.

Writes OGG under assets/custom/audio/sfx via tool/audio_synth.
"""

from audio_synth.render_sfx import render_spells

if __name__ == "__main__":
    render_spells()
