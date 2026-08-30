# Idle Party MCP

Local Cursor MCP server for balance iterates, Flutter verify, changelog honesty,
kit audits, save peek, zone identity, and hub playtest helpers.

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
| `verify` | analyze + ship_smoke (+ optional changelog / balance_gate) |
| `ship_smoke` | `test/ship_smoke_test.dart` |
| `balance_gate` | live-light DPS share CI gate |
| `balance_share` | Fast `--share-only` DPS board (+ optional `--focus`) |
| `read_balance_share` | Read `tool/out/class_balance_share.json` |
| `changelog_check` | `test/changelog_sync_test.dart` |
| `version_info` | pubspec ↔ MetaSystems.currentVersion peek |
| `flutter_analyze` | `flutter analyze lib test` |
| `flutter_test` | `flutter test` with optional path/name filter |
| `chase_tests` | `test/hub_chase_test.dart` |
| `chase_contract_doc` | `docs/CHASE_CONTRACT.md` |
| `kit_audit` | `tool/audit_kit_spell_coverage.py` |
| `aoe_audit` | `tool/audit_aoe_coverage.py` |
| `save_peek` | Summarize a save JSON (hub/AL/KEY/party) |
| `zone_identity` | Portrait/backdrop/boss vs neighbor |
| `hub_smoke_checklist` | Hub polish QA checklist |
| `playtest_bridge_snippet` | `WebClickBridge` JS helpers |
| `skill_read` | Read `.cursor/skills/<name>/SKILL.md` |
