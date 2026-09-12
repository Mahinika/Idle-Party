"""Play high-res icon (512×512) from owned app_icon art.

Does not invent a new mark — same cave-party painting as the launcher.
"""
from __future__ import annotations

from pathlib import Path

try:
    from PIL import Image
except ImportError as e:
    raise SystemExit("Pillow required: py -3 -m pip install pillow") from e

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tool" / "art_backups" / "app_icon.png"
OUT = ROOT / "tool" / "store_listing" / "out" / "play_icon_512.png"
TRACKED = ROOT / "tool" / "art_backups" / "play_icon_512.png"


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"missing {SRC}")
    im = Image.open(SRC).convert("RGBA")
    icon = im.resize((512, 512), Image.Resampling.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.save(OUT, format="PNG", optimize=True)
    icon.save(TRACKED, format="PNG", optimize=True)
    print("wrote", OUT, icon.size)
    print("wrote", TRACKED, icon.size)


if __name__ == "__main__":
    main()
