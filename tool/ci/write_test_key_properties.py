#!/usr/bin/env python3
"""Write android/test-key.properties from env. Prints no secret values."""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "android/test-key.properties"
STORE_FILE = "../test-upload-keystore.jks"

REQUIRED = (
    "TEST_KEYSTORE_PASSWORD",
    "TEST_KEY_PASSWORD",
    "TEST_KEY_ALIAS",
)


def escape_prop(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace(":", "\\:")
        .replace("=", "\\=")
        .replace(" ", "\\ ")
        .replace("\n", "")
        .replace("\r", "")
    )


def main() -> int:
    missing = [name for name in REQUIRED if not os.environ.get(name)]
    if missing:
        print("missing env:", ", ".join(missing), file=sys.stderr)
        return 1
    body = (
        f"storePassword={escape_prop(os.environ['TEST_KEYSTORE_PASSWORD'])}\n"
        f"keyPassword={escape_prop(os.environ['TEST_KEY_PASSWORD'])}\n"
        f"keyAlias={escape_prop(os.environ['TEST_KEY_ALIAS'])}\n"
        f"storeFile={STORE_FILE}\n"
    )
    PROPS.parent.mkdir(parents=True, exist_ok=True)
    PROPS.write_text(body)
    PROPS.chmod(0o600)
    print(f"wrote {PROPS.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
