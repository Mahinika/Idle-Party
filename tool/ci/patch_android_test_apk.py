#!/usr/bin/env python3
"""Temporarily point the Android app at com.idleparty.app.test for sideload QA."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GRADLE = ROOT / "android/app/build.gradle.kts"
MANIFEST = ROOT / "android/app/src/main/AndroidManifest.xml"
GOOGLE_SERVICES = ROOT / "android/app/google-services.json"
BACKUP_DIR = ROOT / "tool/ci/.test_apk_patch_backup"

APP_ID = 'applicationId = "com.idleparty.app"'
TEST_APP_ID = 'applicationId = "com.idleparty.app.test"'
LABEL = 'android:label="Idle Party"'
TEST_LABEL = 'android:label="Idle Party Test"'


def _backup(path: Path) -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    dest = BACKUP_DIR / path.name
    if path.exists():
        shutil.copy2(path, dest)
    else:
        dest.write_text("", encoding="utf-8")


def apply() -> None:
    if BACKUP_DIR.exists():
        raise SystemExit("Patch backup already exists; run restore first.")
    _backup(GRADLE)
    _backup(MANIFEST)
    if GOOGLE_SERVICES.exists():
        shutil.copy2(
            GOOGLE_SERVICES,
            BACKUP_DIR / "google-services.json.bak",
        )
        GOOGLE_SERVICES.unlink()

    gradle = GRADLE.read_text(encoding="utf-8")
    if gradle.count(APP_ID) != 1:
        raise SystemExit(f"Expected one {APP_ID}, found {gradle.count(APP_ID)}")
    if TEST_APP_ID in gradle:
        raise SystemExit("Test applicationId already present.")
    GRADLE.write_text(gradle.replace(APP_ID, TEST_APP_ID, 1), encoding="utf-8")

    manifest = MANIFEST.read_text(encoding="utf-8")
    if manifest.count(LABEL) != 1:
        raise SystemExit(f"Expected one {LABEL}, found {manifest.count(LABEL)}")
    if TEST_LABEL in manifest:
        raise SystemExit("Test label already present.")
    MANIFEST.write_text(manifest.replace(LABEL, TEST_LABEL, 1), encoding="utf-8")


def restore() -> None:
    if not BACKUP_DIR.exists():
        return
    for name in ("build.gradle.kts", "AndroidManifest.xml"):
        backup = BACKUP_DIR / name
        if backup.stat().st_size > 0:
            target = GRADLE if name == "build.gradle.kts" else MANIFEST
            shutil.copy2(backup, target)
    gs_bak = BACKUP_DIR / "google-services.json.bak"
    if gs_bak.exists() and gs_bak.stat().st_size > 0:
        shutil.copy2(gs_bak, GOOGLE_SERVICES)
    shutil.rmtree(BACKUP_DIR)


def main() -> None:
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "apply":
        apply()
    elif cmd == "restore":
        restore()
    else:
        raise SystemExit("Usage: patch_android_test_apk.py apply|restore")


if __name__ == "__main__":
    main()
