#!/usr/bin/env python3
"""Emit batch-2 med gaps (ids 66-165) as a Cursor canvas table."""
from __future__ import annotations

import re
from pathlib import Path

SRC = Path(
    r"C:\Users\Ropbe\.cursor\projects\d-Projects-Personal-idle-party-Idle-Party"
    r"\canvases\honesty-gaps-300-batch2.canvas.tsx"
)
OUT = Path(
    r"C:\Users\Ropbe\.cursor\projects\d-Projects-Personal-idle-party-Idle-Party"
    r"\canvases\honesty-gaps-100-new.canvas.tsx"
)

pat = re.compile(
    r'\{ id: (\d+), sev: "(\w+)", area: "(\w+)", claim: "((?:\\"|[^"])*)", where: "((?:\\"|[^"])*)" \}'
)


def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main() -> None:
    text = SRC.read_text(encoding="utf-8")
    gaps = []
    for m in pat.finditer(text):
        gid = int(m.group(1))
        if 66 <= gid <= 165:
            gaps.append(
                (
                    gid,
                    m.group(2),
                    m.group(3),
                    m.group(4).replace('\\"', '"'),
                    m.group(5).replace('\\"', '"'),
                )
            )
    gaps.sort(key=lambda x: x[0])
    lines = [
        "import { Callout, H1, H2, Pill, Row, Select, Stack, Stat, Table, Text, useState } from \"cursor/canvas\";",
        "",
        "type Gap = { id: number; sev: string; area: string; claim: string; where: string };",
        "",
        "const GAPS: Gap[] = [",
    ]
    for g in gaps:
        lines.append(
            f'  {{ id: {g[0]}, sev: "{esc(g[1])}", area: "{esc(g[2])}", claim: "{esc(g[3])}", where: "{esc(g[4])}" }},'
        )
    lines.append("];")
    lines.append("")
    lines.extend(
        [
            "const AREA_OPTS = [",
            '  { value: "all", label: "All areas" },',
            '  { value: "kit", label: "Kits" },',
            '  { value: "hub", label: "Hub / shop" },',
            '  { value: "combat", label: "Combat" },',
            '  { value: "endgame", label: "Endgame" },',
            '  { value: "gear", label: "Gear" },',
            "];",
            "",
            "export default function HonestyGaps100New() {",
            '  const [area, setArea] = useState("all");',
            "  const filtered = GAPS.filter((g) => area === \"all\" || g.area === area);",
            "  return (",
            '    <Stack gap={16} style={{ padding: 20, maxWidth: 1100 }}>',
            "      <H1>100 new honesty gaps (batch 2 med)</H1>",
            "      <Text tone=\"secondary\">",
            "        Fresh catalog 2026-10-03 — not the Sept high-100 list. Mostly med:",
            "        kit gates, hub chrome, combat HUD, endgame chase, gear tooltips.",
            "      </Text>",
            "      <Row gap={12} align=\"center\">",
            '        <Stat value="100" label="Listed" tone="warning" />',
            '        <Pill>{filtered.length} shown</Pill>',
            "      </Row>",
            '      <Callout tone="warning" title="Not fixed yet">',
            "        Audit backlog. Say fix med kits or fix hub to batch-fix copy.",
            "      </Callout>",
            "      <Select value={area} onChange={setArea} options={AREA_OPTS} placeholder=\"Area\" />",
            "      <H2>Gaps</H2>",
            "      <Table",
            '        headers={["#", "Sev", "Area", "Claim", "Where"]}',
            '        columnAlign={["right", "left", "left", "left", "left"]}',
            "        rows={filtered.map((g) => [",
            '          String(g.id), g.sev.toUpperCase(), g.area, g.claim, g.where,',
            "        ])}",
            "      />",
            "    </Stack>",
            "  );",
            "}",
            "",
        ]
    )
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {len(gaps)} gaps -> {OUT}")


if __name__ == "__main__":
    main()
