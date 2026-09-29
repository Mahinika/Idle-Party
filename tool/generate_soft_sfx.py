"""Owned soft SFX (hits, swish, materials, crit, kill).

Writes OGG under assets/custom/audio/sfx via tool/audio_synth.
"""

from audio_synth.render_sfx import render_soft

if __name__ == "__main__":
    render_soft()
