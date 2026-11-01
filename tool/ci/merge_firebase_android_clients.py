#!/usr/bin/env python3
"""Merge Firebase Android client entries into google-services.json."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


def _clients(data: dict[str, Any]) -> list[dict[str, Any]]:
    raw = data.get("client")
    if not isinstance(raw, list):
        return []
    return [c for c in raw if isinstance(c, dict)]


def _package_name(client: dict[str, Any]) -> str | None:
    try:
        info = client["client_info"]["android_client_info"]["package_name"]
    except (KeyError, TypeError):
        return None
    return info if isinstance(info, str) and info else None


def merge_into(base_path: Path, *snippet_paths: Path) -> None:
    base = json.loads(base_path.read_text(encoding="utf-8"))
    if not isinstance(base, dict):
        raise SystemExit(f"{base_path} is not a JSON object")

    clients = _clients(base)
    by_package = {_package_name(c): c for c in clients if _package_name(c)}

    for path in snippet_paths:
        snippet = json.loads(path.read_text(encoding="utf-8"))
        for client in _clients(snippet):
            pkg = _package_name(client)
            if not pkg or pkg in by_package:
                continue
            clients.append(client)
            by_package[pkg] = client

    base["client"] = clients
    base_path.write_text(json.dumps(base, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit(
            "Usage: merge_firebase_android_clients.py BASE.json SNIPPET.json [SNIPPET2.json ...]"
        )
    base_path = Path(sys.argv[1])
    snippets = [Path(p) for p in sys.argv[2:]]
    merge_into(base_path, *snippets)


if __name__ == "__main__":
    main()
