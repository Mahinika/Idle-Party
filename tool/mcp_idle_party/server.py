"""Idle Party MCP — balance, Flutter verify, changelog, zone identity, playtest help.

Stdio server for Cursor. Keep stderr quiet (Cursor treats stderr as errors and
can stall tool discovery when the stream is noisy).
"""

import os
import re
import subprocess
import sys
import warnings
from pathlib import Path

# Pydantic/FastMCP emit IncompleteFieldDefinitionWarning on import; Cursor
# marks any stderr line as [error] and tool leases can stay at toolCount=0.
warnings.filterwarnings("ignore", category=UserWarning, module="pydantic")
warnings.filterwarnings("ignore", message=".*incomplete definition.*")
os.environ.setdefault("PYTHONWARNINGS", "ignore")

from mcp.server.fastmcp import FastMCP

mcp = FastMCP(
    "idle-party",
    instructions=(
        "Idle Party project tools: verify (analyze/ship_smoke/balance_gate), "
        "DPS share sims, changelog honesty, kit/AoE audits, save peek, "
        "zone art identity, chase contract docs, and hub playtest checklists."
    ),
    # INFO logs "Processing request of type PingRequest" to stderr.
    log_level="ERROR",
)


def _root() -> Path:
    env = os.environ.get("IDLE_PARTY_ROOT")
    if env:
        return Path(env).resolve()
    # tool/mcp_idle_party/server.py → repo root
    return Path(__file__).resolve().parents[2]


def _log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def _run(
    args: list[str],
    *,
    timeout: int = 600,
    cwd: Path | None = None,
) -> tuple[int, str]:
    root = cwd or _root()
    _log(f"run: {' '.join(args)} (cwd={root})")
    try:
        proc = subprocess.run(
            args,
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=timeout,
            shell=False,
        )
    except FileNotFoundError as e:
        return 127, f"command not found: {e}"
    except subprocess.TimeoutExpired:
        return 124, f"timeout after {timeout}s: {' '.join(args)}"
    out = (proc.stdout or "") + (("\n" + proc.stderr) if proc.stderr else "")
    return proc.returncode, out.strip()


def _flutter() -> str:
    return os.environ.get("FLUTTER_BIN", "flutter")


def _python() -> str:
    venv = Path(__file__).resolve().parent / ".venv" / "Scripts" / "python.exe"
    if venv.exists():
        return str(venv)
    return os.environ.get("PYTHON_BIN", "python")


def _truncate(out: str, limit: int = 12000) -> str:
    if len(out) <= limit:
        return out
    return out[: limit // 2] + "\n...\n" + out[-(limit // 2) :]


def _run_flutter_test(path: str, *, timeout: int = 300) -> str:
    code, out = _run(
        [_flutter(), "test", path, "--reporter", "expanded"],
        timeout=timeout,
    )
    return f"exit={code}\n{_truncate(out)}"


# structured_output=False: avoid outputSchema. Cursor agent lease sometimes
# keeps toolCount=0 when FastMCP advertises structured result schemas.


@mcp.tool(structured_output=False)
def balance_share(
    focus: str = "",
    trials: int = 2,
    mode: str = "live",
) -> str:
    """Run a fast live DPS share-only balance board.

    Writes tool/out/class_balance_share.json and returns the report text.
    Use focus as comma-separated HeroSpecId names (e.g. demonology,balance)
    to iterate quickly while nerfing kits. Empty focus = all DPS specs.
    """
    trials = max(1, min(int(trials), 8))
    args = [
        _flutter(),
        "test",
        "test/class_balance_share_fast_test.dart",
        "--reporter",
        "expanded",
    ]

    focus = focus.strip()
    if not focus and trials == 2 and mode == "live":
        code, out = _run(args, timeout=300)
        share = _root() / "tool" / "out" / "class_balance_share.json"
        extra = ""
        if share.exists():
            extra = "\n\n--- class_balance_share.json ---\n" + share.read_text(
                encoding="utf-8"
            )
        return f"exit={code}\n{out}{extra}"

    out_dir = _root() / "tool" / "out"
    out_dir.mkdir(parents=True, exist_ok=True)
    gen = out_dir / "_mcp_balance_share_test.dart"
    gen.write_text(
        f"""
import 'package:flutter_test/flutter_test.dart';
import '../../tool/sim_class_balance.dart';

void main() {{
  test('mcp share-only', () {{
    final report = runClassBalanceSim(const [
      '--share-only',
      '--trials={trials}',
      '--mode={mode}',
    ]);
    expect(report, contains('share-only: true'));
  }}, timeout: const Timeout(Duration(minutes: 8)));
}}
""".strip()
        + "\n",
        encoding="utf-8",
    )
    test_path = _root() / "test" / "_mcp_balance_share_test.dart"
    focus_literal = focus.replace("'", "")
    test_path.write_text(
        f"""
import 'package:flutter_test/flutter_test.dart';
import '../tool/sim_class_balance.dart';

void main() {{
  test('mcp share-only', () {{
    final report = runClassBalanceSim([
      '--share-only',
      '--trials={trials}',
      '--mode={mode}',
      {f"'--focus={focus_literal}'," if focus_literal else ""}
    ]);
    expect(report, contains('share-only: true'));
  }}, timeout: const Timeout(Duration(minutes: 8)));
}}
""".strip()
        + "\n",
        encoding="utf-8",
    )
    try:
        code, out = _run(
            [_flutter(), "test", str(test_path), "--reporter", "expanded"],
            timeout=480,
        )
        share = _root() / "tool" / "out" / "class_balance_share.json"
        extra = ""
        if share.exists():
            extra = "\n\n--- class_balance_share.json ---\n" + share.read_text(
                encoding="utf-8"
            )
        return f"exit={code}\n{out}{extra}"
    finally:
        if test_path.exists():
            test_path.unlink()
        if gen.exists():
            gen.unlink()


@mcp.tool(structured_output=False)
def read_balance_share() -> str:
    """Read the last tool/out/class_balance_share.json if present."""
    path = _root() / "tool" / "out" / "class_balance_share.json"
    if not path.exists():
        return "No share JSON yet. Run balance_share first."
    return path.read_text(encoding="utf-8")


@mcp.tool(structured_output=False)
def changelog_check() -> str:
    """Verify pubspec, MetaSystems.currentVersion, and What's New zone tokens."""
    code, out = _run(
        [_flutter(), "test", "test/changelog_sync_test.dart", "--reporter", "expanded"],
        timeout=180,
    )
    return f"exit={code}\n{out}"


@mcp.tool(structured_output=False)
def flutter_analyze() -> str:
    """Run flutter analyze on lib/ and test/ (hold to zero issues)."""
    code, out = _run([_flutter(), "analyze", "lib", "test"], timeout=300)
    return f"exit={code}\n{out}"


@mcp.tool(structured_output=False)
def flutter_test(filter: str = "") -> str:
    """Run flutter test. Optional filter is a path under test/ or a name substring."""
    args = [_flutter(), "test", "--reporter", "compact"]
    f = filter.strip()
    if f:
        candidate = _root() / f
        if candidate.exists():
            args.append(str(candidate))
        else:
            args.extend(["--name", f])
    code, out = _run(args, timeout=900)
    return f"exit={code}\n{_truncate(out)}"


@mcp.tool(structured_output=False)
def zone_identity(dungeon_id: str = "", neighbor_id: str = "") -> str:
    """Check zone art identity signals vs a neighbor (remap / wash / boss).

    Defaults: tide vs crystal, ember vs hell when dungeon_id empty (reports both).
    """
    root = _root()
    custom = (root / "lib" / "ui" / "custom_assets.dart").read_text(encoding="utf-8")
    zone_art = (root / "lib" / "models" / "zone_art.dart").read_text(encoding="utf-8")

    pairs: list[tuple[str, str]] = []
    d = dungeon_id.strip()
    n = neighbor_id.strip()
    if d and n:
        pairs.append((d, n))
    elif d:
        guess = {"tide": "crystal", "ember": "hell", "goblin": "sandy"}.get(d, "")
        if not guess:
            return f"Provide neighbor_id for dungeon_id={d}"
        pairs.append((d, guess))
    else:
        pairs = [("tide", "crystal"), ("ember", "hell")]

    lines: list[str] = []
    for a, b in pairs:
        lines.append(f"## {a} vs {b}")
        name_a = "Tide" if a == "tide" else ("Ember" if a == "ember" else a.capitalize())
        name_b = (
            "Crystal"
            if b == "crystal"
            else ("Hell" if b == "hell" else b.capitalize())
        )
        ra = re.search(rf"portrait{name_a}\s*=\s*([^;]+);", custom)
        rb = re.search(rf"portrait{name_b}\s*=\s*([^;]+);", custom)
        ba = re.search(rf"backdrop{name_a}\s*=\s*([^;]+);", custom)
        bb = re.search(rf"backdrop{name_b}\s*=\s*([^;]+);", custom)
        lines.append(f"- portrait {a}: {ra.group(1).strip() if ra else 'missing'}")
        lines.append(f"- portrait {b}: {rb.group(1).strip() if rb else 'missing'}")
        if ra and rb and ra.group(1).strip() == rb.group(1).strip():
            lines.append("  FAIL: portraits identical")
        elif ra and rb:
            lines.append("  OK: portraits differ")
        lines.append(f"- backdrop {a}: {ba.group(1).strip() if ba else 'missing'}")
        lines.append(f"- backdrop {b}: {bb.group(1).strip() if bb else 'missing'}")
        if ba and bb and ba.group(1).strip() == bb.group(1).strip():
            lines.append("  FAIL: backdrops identical")
        elif ba and bb:
            lines.append("  OK: backdrops differ")

        def _boss_asset(zid: str) -> str | None:
            m = re.search(
                rf"'{zid}'\s*:\s*ZoneArtDef\((.*?)enemies:\s*ZoneEnemyArt\((.*?)\)",
                zone_art,
                re.S,
            )
            if not m:
                return None
            bm = re.search(r"boss:\s*([^,\n]+)", m.group(2))
            return bm.group(1).strip() if bm else None

        sa, sb = _boss_asset(a), _boss_asset(b)
        lines.append(f"- boss {a}: {sa or 'missing'}")
        lines.append(f"- boss {b}: {sb or 'missing'}")
        if sa and sb and sa == sb:
            lines.append("  FAIL: boss sprites identical")
        elif sa and sb:
            lines.append("  OK: boss sprites differ")

        env_hit = re.search(rf"'{a}'\s*:\s*ZoneArtDef", zone_art) is not None
        lines.append(
            f"- environment entries for {a}: {'present' if env_hit else 'MISSING'}"
        )
        lines.append("")
    lines.append("See .cursor/skills/zone-art-identity/SKILL.md for full checklist.")
    return "\n".join(lines)


@mcp.tool(structured_output=False)
def hub_smoke_checklist() -> str:
    """Return the hub polish smoke checklist and WebClickBridge helpers."""
    skill = _root() / ".cursor" / "skills" / "hub-smoke" / "SKILL.md"
    if skill.exists():
        return skill.read_text(encoding="utf-8")
    return (
        "Hub smoke:\n"
        "1. ENTER DUNGEON visible\n"
        "2. Weekly n/3 on hub\n"
        "3. MORE · NEW / !\n"
        "4. Guides + LOADOUTS\n"
        "Bridge: window.__idlePartyClick('MORE')"
    )


@mcp.tool(structured_output=False)
def playtest_bridge_snippet() -> str:
    """JS snippets to drive Idle Party Flutter web via WebClickBridge."""
    return """
// After flutter run -d web-server --web-hostname=localhost --web-port=8080
typeof window.__idlePartyClick
window.__idlePartyButtons()
window.__idlePartyClick('CONTINUE') // or NEW GAME
window.__idlePartyClick('SKIP ALL TIPS')
window.__idlePartyClick('MORE')
window.__idlePartyClick('MORE · NEW')
window.__idlePartyClick('GUIDES')
window.__idlePartyClick('ENTER DUNGEON')
window.__idlePartySetSpeed(10)
""".strip()


@mcp.tool(structured_output=False)
def ship_smoke() -> str:
    """Fast honesty: world path / unlock / guides / chase surfaces."""
    return _run_flutter_test("test/ship_smoke_test.dart", timeout=240)


@mcp.tool(structured_output=False)
def balance_gate() -> str:
    """CI live-light DPS share gate (fails on HIGH outside +/-20% band)."""
    return _run_flutter_test("test/class_balance_gate_test.dart", timeout=420)


@mcp.tool(structured_output=False)
def chase_tests() -> str:
    """HubChase priority tests (TODAY / claimables / endgame ladder)."""
    return _run_flutter_test("test/hub_chase_test.dart", timeout=240)


@mcp.tool(structured_output=False)
def verify(include_changelog: bool = True, include_balance_gate: bool = False) -> str:
    """Batch verify: flutter analyze + ship_smoke (+ optional changelog / balance_gate)."""
    parts: list[str] = []
    code_a, out_a = _run([_flutter(), "analyze", "lib", "test"], timeout=300)
    parts.append(f"## flutter_analyze exit={code_a}\n{_truncate(out_a, 6000)}")
    if code_a != 0:
        return "\n\n".join(parts) + "\n\nSTOPPED: analyze failed"

    smoke = ship_smoke()
    parts.append(f"## ship_smoke\n{smoke}")
    if not smoke.startswith("exit=0"):
        return "\n\n".join(parts) + "\n\nSTOPPED: ship_smoke failed"

    if include_changelog:
        clog = changelog_check()
        parts.append(f"## changelog_check\n{clog}")
        if not clog.startswith("exit=0"):
            return "\n\n".join(parts) + "\n\nSTOPPED: changelog_check failed"

    if include_balance_gate:
        gate = balance_gate()
        parts.append(f"## balance_gate\n{gate}")
        if not gate.startswith("exit=0"):
            return "\n\n".join(parts) + "\n\nSTOPPED: balance_gate failed"

    parts.append("## summary\nOK")
    return "\n\n".join(parts)


@mcp.tool(structured_output=False)
def kit_audit() -> str:
    """Kit spell coverage board (thin kits, missing fantasy crumbs, tiers)."""
    script = _root() / "tool" / "audit_kit_spell_coverage.py"
    if not script.exists():
        return f"missing {script}"
    code, out = _run([_python(), str(script)], timeout=60)
    return f"exit={code}\n{_truncate(out)}"


@mcp.tool(structured_output=False)
def aoe_audit() -> str:
    """AoE / cleave coverage per HeroSpecId."""
    script = _root() / "tool" / "audit_aoe_coverage.py"
    if not script.exists():
        return f"missing {script}"
    code, out = _run([_python(), str(script)], timeout=60)
    return f"exit={code}\n{_truncate(out)}"


@mcp.tool(structured_output=False)
def version_info() -> str:
    """pubspec versionName/build vs MetaSystems.currentVersion (quick sync peek)."""
    root = _root()
    pub = (root / "pubspec.yaml").read_text(encoding="utf-8")
    meta = (root / "lib" / "core" / "meta_systems.dart").read_text(encoding="utf-8")
    pv = re.search(r"^version:\s*([^\s#]+)", pub, re.M)
    mv = re.search(
        r"static\s+const\s+String\s+currentVersion\s*=\s*'([^']+)'",
        meta,
    )
    pubspec_v = pv.group(1).strip() if pv else "missing"
    meta_v = mv.group(1).strip() if mv else "missing"
    name = pubspec_v.split("+", 1)[0]
    ok = name == meta_v
    return (
        f"pubspec: {pubspec_v}\n"
        f"MetaSystems.currentVersion: {meta_v}\n"
        f"sync: {'OK' if ok else 'MISMATCH — run changelog_check'}"
    )


@mcp.tool(structured_output=False)
def chase_contract_doc() -> str:
    """Return docs/CHASE_CONTRACT.md (TODAY priority source of truth)."""
    path = _root() / "docs" / "CHASE_CONTRACT.md"
    if not path.exists():
        return "missing docs/CHASE_CONTRACT.md"
    return path.read_text(encoding="utf-8")


@mcp.tool(structured_output=False)
def save_peek(path: str = "") -> str:
    """Summarize a save JSON for hub/AL20 debugging (levels, zones, KEY, vault).

    Empty path defaults to tool/store_listing/showcase_save.json.
    Accepts absolute paths or paths relative to the repo root.
    """
    import json

    root = _root()
    raw = path.strip()
    if not raw:
        candidate = root / "tool" / "store_listing" / "showcase_save.json"
    else:
        candidate = Path(raw)
        if not candidate.is_absolute():
            candidate = root / raw
    if not candidate.exists():
        return f"missing save: {candidate}"

    try:
        data = json.loads(candidate.read_text(encoding="utf-8"))
    except Exception as e:
        return f"parse fail: {e}"

    if not isinstance(data, dict):
        return "save root is not an object"

    md = data.get("metaDepth") if isinstance(data.get("metaDepth"), dict) else {}
    heroes = data.get("heroes") if isinstance(data.get("heroes"), list) else []
    levels: list[int] = []
    specs: list[str] = []
    for h in heroes:
        if not isinstance(h, dict):
            continue
        try:
            levels.append(int(h.get("level", 0)))
        except (TypeError, ValueError):
            levels.append(0)
        hid = str(h.get("id") or h.get("specId") or "?")
        specs.append(hid)

    mean = round(sum(levels) / len(levels), 1) if levels else 0
    all_max = bool(levels) and all(lv >= 100 for lv in levels)

    missions = data.get("missions") if isinstance(data.get("missions"), list) else []
    claimable = 0
    for m in missions:
        if not isinstance(m, dict):
            continue
        try:
            if int(m.get("progress", 0)) >= int(m.get("target", 1)):
                claimable += 1
        except (TypeError, ValueError):
            pass

    stash = data.get("gearStash") if isinstance(data.get("gearStash"), list) else []
    lines = [
        f"file: {candidate}",
        f"AL: {data.get('ascensionLevel')}",
        f"gold: {data.get('gold')}  essence: {data.get('essence')}",
        f"inDungeon: {data.get('inDungeon')}  dungeonId: {data.get('dungeonId')}  "
        f"floorHighest: {data.get('highestFloorCleared')}",
        f"zones cleared idx: {data.get('highestDungeonCleared')}",
        f"KEY dial: {data.get('hardmodeLevel')}  "
        f"best timed key (meta): {md.get('dailyBestTimedKey')}  "
        f"highestHardmodeCleared: {md.get('highestHardmodeCleared')}",
        f"vault: clears={md.get('dailyVaultClears')} claimed={md.get('dailyVaultClaimed')} "
        f"date={md.get('dailyVaultDate')}",
        f"gauntletBest: {md.get('gauntletBestFloor', 0)}  "
        f"riftBest: {md.get('riftBestTier', 0)}  grBest: {md.get('grBestTier', 0)}",
        f"ascendBlessings: {md.get('ascendBlessings', 0)}  "
        f"freshPrestige: {md.get('freshPrestige', False)}",
        f"party n={len(levels)} levels={levels} mean={mean} endgameUnlocked~={all_max}",
        f"specs: {', '.join(specs) or '(none)'}",
        f"bag stash: {len(stash)}  claimable quests~: {claimable}",
        f"godHandLevel: {data.get('godHandLevel')}  "
        f"bossVictories: {data.get('bossVictories')}",
    ]
    return "\n".join(lines)


@mcp.tool(structured_output=False)
def skill_read(name: str = "flutter-verify") -> str:
    """Read a .cursor/skills/<name>/SKILL.md (e.g. a56-playtest, hub-smoke)."""
    key = name.strip().strip("/\\")
    if not key or ".." in key or "/" in key or "\\" in key:
        return "pass a skill folder name like flutter-verify or a56-playtest"
    path = _root() / ".cursor" / "skills" / key / "SKILL.md"
    if not path.exists():
        skills = _root() / ".cursor" / "skills"
        names = sorted(p.name for p in skills.iterdir() if p.is_dir()) if skills.exists() else []
        return f"missing {path}\navailable: {', '.join(names)}"
    text = path.read_text(encoding="utf-8")
    return _truncate(text, 14000)


if __name__ == "__main__":
    mcp.run(transport="stdio")
