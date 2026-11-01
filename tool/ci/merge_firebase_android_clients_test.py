#!/usr/bin/env python3
"""Tests for merge_firebase_android_clients.py"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from merge_firebase_android_clients import merge_into


class MergeFirebaseAndroidClientsTest(unittest.TestCase):
    def test_adds_second_client_without_dropping_play(self) -> None:
        base = {
            "project_info": {"project_id": "idle-party-4a2e9"},
            "client": [
                {
                    "client_info": {
                        "mobilesdk_app_id": "1:1:android:play",
                        "android_client_info": {
                            "package_name": "com.idleparty.app",
                        },
                    },
                },
            ],
        }
        extra = {
            "client": [
                {
                    "client_info": {
                        "mobilesdk_app_id": "1:1:android:test",
                        "android_client_info": {
                            "package_name": "com.idleparty.app.test",
                        },
                    },
                },
            ],
        }
        with tempfile.TemporaryDirectory() as tmp:
            base_path = Path(tmp) / "google-services.json"
            extra_path = Path(tmp) / "test-snippet.json"
            base_path.write_text(json.dumps(base), encoding="utf-8")
            extra_path.write_text(json.dumps(extra), encoding="utf-8")
            merge_into(base_path, extra_path)
            merged = json.loads(base_path.read_text(encoding="utf-8"))
        packages = {
            c["client_info"]["android_client_info"]["package_name"]
            for c in merged["client"]
        }
        self.assertEqual(
            packages,
            {"com.idleparty.app", "com.idleparty.app.test"},
        )


if __name__ == "__main__":
    unittest.main()
