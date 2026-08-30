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

- Open **Idle-Party** as the folder: `.cursor/mcp.json` uses `${workspaceFolder}\tool\...`
- Open parent **idle party** folder: parent `.cursor/mcp.json` points at `Idle-Party\tool\...`
- User absolute fallback: `~/.cursor/mcp.json` (direct `.venv\Scripts\python.exe -u server.py`)

After pull / MCP change: **Cursor Settings → MCP → idle-party → Refresh** (or reload window). Approve when prompted.

Tools advertise **unstructured** string results (`structured_output=False`) and keep stderr quiet so Cursor’s tool lease does not stick at `toolCount: 0`.

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
