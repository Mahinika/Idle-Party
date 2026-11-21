#!/usr/bin/env python3
"""Delete Firebase App Distribution releases older than N days (test app only)."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

# Idle Party Test — same as test-apk-prerelease.yml upload step.
PROJECT_NUMBER = "900067828121"
APP_ID = "1:900067828121:android:a612149094a9324290b308"
BASE = (
    f"https://firebaseappdistribution.googleapis.com/v1/"
    f"projects/{PROJECT_NUMBER}/apps/{urllib.parse.quote(APP_ID, safe='')}"
)


def _access_token(sa_json: dict) -> str:
    try:
        from google.oauth2 import service_account
        import google.auth.transport.requests
    except ImportError:
        print(
            "google-auth not installed; skip FAD prune in CI or pip install google-auth.",
            file=sys.stderr,
        )
        sys.exit(0)

    creds = service_account.Credentials.from_service_account_info(
        sa_json,
        scopes=["https://www.googleapis.com/auth/cloud-platform"],
    )
    creds.refresh(google.auth.transport.requests.Request())
    return creds.token


def main() -> int:
    raw = os.environ.get("FIREBASE_APP_DISTRIBUTION_CREDENTIALS", "").strip()
    if not raw:
        print("No FIREBASE_APP_DISTRIBUTION_CREDENTIALS; skipping App Distribution cleanup.")
        return 0

    days = int(os.environ.get("MAX_AGE_DAYS", "14"))
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    sa = json.loads(raw)
    token = _access_token(sa)

    deleted = 0
    page_token = ""
    while True:
        url = f"{BASE}/releases?pageSize=100"
        if page_token:
            url += f"&pageToken={urllib.parse.quote(page_token)}"
        req = urllib.request.Request(
            url,
            headers={"Authorization": f"Bearer {token}"},
        )
        with urllib.request.urlopen(req, timeout=120) as resp:
            payload = json.load(resp)
        for rel in payload.get("releases", []):
            name = rel.get("name", "")
            create_time = rel.get("createTime", "")
            if not create_time:
                continue
            created = datetime.fromisoformat(create_time.replace("Z", "+00:00"))
            if created >= cutoff:
                continue
            del_url = f"https://firebaseappdistribution.googleapis.com/v1/{name}"
            del_req = urllib.request.Request(
                del_url,
                headers={"Authorization": f"Bearer {token}"},
                method="DELETE",
            )
            try:
                with urllib.request.urlopen(del_req, timeout=60):
                    pass
            except urllib.error.HTTPError as e:
                print(f"Failed to delete {name}: HTTP {e.code}", file=sys.stderr)
                continue
            deleted += 1
            print(f"Deleted FAD release {name} ({create_time})")

        page_token = payload.get("nextPageToken", "")
        if not page_token:
            break

    print(f"Firebase App Distribution: deleted {deleted} release(s) older than {days} days.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())