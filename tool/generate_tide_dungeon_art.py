#!/usr/bin/env py
"""Legacy entry — regenerates Tide only. Prefer tool/generate_dungeon_art.py."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_dungeon_art import Generator

if __name__ == "__main__":
    Generator("tide").generate_all()
    print("Done — Tidehold pixel art written.")
