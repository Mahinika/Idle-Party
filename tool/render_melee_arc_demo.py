#!/usr/bin/env python3
"""Top-down sketch of melee arc slot assignment (combat_presence ring)."""
import math
from pathlib import Path

out = Path("/opt/cursor/artifacts/melee_arc_spread.png")
out.parent.mkdir(parents=True, exist_ok=True)

try:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError:
    print("matplotlib missing; skip render")
    raise SystemExit(0)

foe = (8.0, 5.0)
party_back = (-1.0, 0.0)
radius = 1.05
step = max(1.38, 1.45 / radius)
slots = 5

def ring_point(slot: int):
    if slot == 0:
        ang = 0.0
    else:
        mag = (slot + 1) // 2
        ang = mag * step if slot % 2 == 1 else -mag * step
    bx, by = party_back
    lx, ly = -by, bx
    c, s = math.cos(ang), math.sin(ang)
    fx = bx * c + lx * s
    fy = by * c + ly * s
    return (foe[0] + fx * radius, foe[1] + fy * radius)

pts = [ring_point(i) for i in range(slots)]

fig, ax = plt.subplots(figsize=(5.2, 4.2), dpi=144)
ax.set_aspect("equal")
ax.set_xlim(5.2, 10.2)
ax.set_ylim(2.5, 7.5)
ax.set_title("Melee arc around focus (demo)")
ax.add_patch(plt.Circle(foe, 0.22, color="#c85a5a", label="foe"))
colors = ["#f0c050", "#8ec8ff", "#9ad0a0", "#c8a0ff", "#e8a878"]
labels = ["tank", "DPS L", "DPS R", "DPS L2", "DPS R2"]
for i, (x, y) in enumerate(pts):
    ax.add_patch(plt.Circle((x, y), 0.18, color=colors[i]))
    ax.text(x, y + 0.35, labels[i], ha="center", fontsize=8)
ax.arrow(foe[0] + 0.3, foe[1], party_back[0] * 0.9, party_back[1] * 0.9, head_width=0.12, color="#888")
ax.grid(True, alpha=0.2)
fig.savefig(out, bbox_inches="tight")
print(out)