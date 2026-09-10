"""Generate soft Idle Party background music loops (owned procedural).

Hub music is now CC0 Heavenly Loop (`hub.ogg`) — this script only documents
that. Dungeon music is owned ElevenLabs (`dungeon.mp3`).
"""

from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "custom" / "audio" / "music"


def main() -> None:
    # hub.ogg: Heavenly Loop (isaiah658, CC0) — do not overwrite.
    # dungeon.mp3: owned ElevenLabs — do not overwrite.
    print("music assets (skip regenerate):", sorted(p.name for p in OUT.iterdir()))


if __name__ == "__main__":
    main()
