"""Facit gate entry point.

The checks live in tool/facit/. This file keeps the historical name so the
gear build and test/visual/paper_doll_facit_test.dart can keep calling it.

    py -3 tool/check_paper_doll_facit.py
    py -3 tool/check_paper_doll_facit.py --fast --no-lock
    py -3 tool/check_paper_doll_facit.py --only style,unique
    py -3 tool/check_paper_doll_facit.py --selftest
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from facit.core import main

if __name__ == "__main__":
    raise SystemExit(main())
