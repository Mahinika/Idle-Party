#!/usr/bin/env python3
"""Ensure google-services.json includes com.idleparty.app.test before test APK CI."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GOOGLE_SERVICES = ROOT / "android/app/google-services.json"
PLAY_PACKAGE = "com.idleparty.app"
TEST_PACKAGE = "com.idleparty.app.test"


def _package_names(data: dict) -> set[str]:
    names: set[str] = set()
    for client in data.get("client", []):
        info = client.get("client_info", {}).get("android_client_info", {})
        name = info.get("package_name")
        if isinstance(name, str) and name:
            names.add(name)
    return names


def main() -> None:
    override = os.environ.get("GOOGLE_SERVICES_JSON", "").strip()
    if override:
        GOOGLE_SERVICES.parent.mkdir(parents=True, exist_ok=True)
        GOOGLE_SERVICES.write_text(
            override if override.endswith("\n") else f"{override}\n",
            encoding="utf-8",
        )

    if not GOOGLE_SERVICES.exists():
        sys.exit(
            "Missing android/app/google-services.json. "
            "Release builds use the committed file; test APK CI needs the same file "
            f"with a Firebase client for {TEST_PACKAGE}."
        )

    data = json.loads(GOOGLE_SERVICES.read_text(encoding="utf-8"))
    packages = _package_names(data)
    if PLAY_PACKAGE not in packages:
        sys.exit(f"google-services.json is missing Play package {PLAY_PACKAGE}.")
    if TEST_PACKAGE not in packages:
        sys.exit(
            f"google-services.json is missing test package {TEST_PACKAGE}.\n"
            "Robert: Firebase console → project idle-party-4a2e9 → Add app → Android → "
            f"package {TEST_PACKAGE} → download google-services.json (must list both "
            f"{PLAY_PACKAGE} and {TEST_PACKAGE} under client[]) → commit to "
            "android/app/google-services.json OR set GitHub Actions secret "
            "GOOGLE_SERVICES_JSON to the full file contents."
        )
    print(f"Firebase clients OK: {', '.join(sorted(packages))}")


if __name__ == "__main__":
    main()
