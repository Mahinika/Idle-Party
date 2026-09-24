"""Where the paper-doll scripts read and write art.

The gear build runs every step on a staging copy and only publishes a green
result. `IDLE_PARTY_CHAR_ROOT` points every doll script at that copy.
"""
from __future__ import annotations

import os
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
TOOL = REPO / "tool"
LIVE_CHAR = REPO / "assets" / "custom" / "char"
STAGE_CHAR = TOOL / "out" / "doll_stage" / "char"

_override = os.environ.get("IDLE_PARTY_CHAR_ROOT")
CHAR = Path(_override) if _override else LIVE_CHAR


def staged() -> bool:
    return CHAR != LIVE_CHAR
