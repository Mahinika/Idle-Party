# Idle Party MCP

Local Cursor MCP server for balance iterates, Flutter verify, changelog honesty, zone identity, and hub playtest helpers.

## Setup

```bat
cd tool\mcp_idle_party
py -3 -m venv .venv
.venv\Scripts\pip install -r requirements.txt
```

Pinned to `mcp==1.12.4` (FastMCP API). `.venv` is gitignored.

## Cursor

Project config: `.cursor/mcp.json` → server `idle-party`.

After pull: restart Cursor (or reload MCP) so tools appear. Approve the server when prompted.

## Tools

| Tool | Purpose |
|------|---------|
| `balance_share` | Fast `--share-only` DPS board (+ optional `--focus`) |
| `read_balance_share` | Read `tool/out/class_balance_share.json` |
| `changelog_check` | `test/changelog_sync_test.dart` |
| `flutter_analyze` | `flutter analyze lib test` |
| `flutter_test` | `flutter test` with optional path/name filter |
| `zone_identity` | Portrait/backdrop/boss vs neighbor |
| `hub_smoke_checklist` | Hub polish QA checklist |
| `playtest_bridge_snippet` | `WebClickBridge` JS helpers |
