"""Split SpatialCombat.step into named phases without changing the engine.

`step` was 1016 lines in one method. Each phase below is lifted verbatim into
a private helper on the same class — same order, same mutations, same single
combat authority — so the loop reads as: heroes, pets, enemies, projectiles,
loot, floor clear.
"""

import io

PATH = "lib/spatial/spatial_combat.dart"

# (first_line, last_line, call_lines, header, footer) — 1-indexed, inclusive.
PHASES = [
    (
        2988,
        3175,
        [
            "    final foes = _stepEnemies(",
            "      world,",
            "      nextState,",
            "      dt: dt,",
            "      rng: rng,",
            "      reducedVfx: state.reducedVfx,",
            "    );",
            "    nextState = foes.state;",
            "    goldFromKills += foes.gold;",
        ],
        [
            "  /// Enemies: prefer the tank, kite if ranged, path around walls.",
            "  static ({GameState state, int gold}) _stepEnemies(",
            "    SpatialWorld world,",
            "    GameState state, {",
            "    required double dt,",
            "    required math.Random rng,",
            "    required bool reducedVfx,",
            "  }) {",
            "    var nextState = state;",
            "    var goldFromKills = 0;",
        ],
        ["    return (state: nextState, gold: goldFromKills);", "  }"],
    ),
    (
        2670,
        2975,
        [
            "    final party = _stepHeroes(",
            "      world,",
            "      nextState,",
            "      dt: dt,",
            "      rng: rng,",
            "      guiding: guiding,",
            "      reducedVfx: state.reducedVfx,",
            "    );",
            "    nextState = party.state;",
            "    goldFromKills += party.gold;",
        ],
        [
            "  /// Heroes: formation + role ranges + optional God Hand steering.",
            "  static ({GameState state, int gold}) _stepHeroes(",
            "    SpatialWorld world,",
            "    GameState state, {",
            "    required double dt,",
            "    required math.Random rng,",
            "    required bool guiding,",
            "    required bool reducedVfx,",
            "  }) {",
            "    var nextState = state;",
            "    var goldFromKills = 0;",
        ],
        ["    return (state: nextState, gold: goldFromKills);", "  }"],
    ),
]

STEP_END = "    return _stepResult(world, nextState, goldFromKills: goldFromKills);"


def main() -> None:
    lines = io.open(PATH, encoding="utf-8").read().split("\n")
    helpers: list[str] = []
    for first, last, call, header, footer in PHASES:
        body = [
            ln.replace("state.reducedVfx", "reducedVfx")
            for ln in lines[first - 1 : last]
        ]
        helpers.append("")
        helpers.extend(header)
        helpers.extend(body)
        helpers.extend(footer)
        lines[first - 1 : last] = call

    end = next(i for i, ln in enumerate(lines) if ln == STEP_END)
    assert lines[end + 1] == "  }", lines[end + 1]
    lines[end + 2 : end + 2] = helpers
    io.open(PATH, "w", encoding="utf-8").write("\n".join(lines))
    print(f"extracted {len(PHASES)} phases out of step()")


if __name__ == "__main__":
    main()
