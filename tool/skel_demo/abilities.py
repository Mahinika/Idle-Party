"""Warrior ability poses for the skeleton demo. Outside the game.

Names match the kit. Each clip is a readable motion, not the combat numbers.
"""

from __future__ import annotations


def _clip(length: float, keys: list[dict], loop: bool = False) -> dict:
    return {"loop": loop, "length": length, "keys": keys}


def _k(t: float, root: tuple[float, float] = (0, 0), **bones: float) -> dict:
    return {"t": t, "root": [root[0], root[1]], "bones": bones}


# Order matches lib/models/kits/warrior.dart: Protection, Arms, Fury.
ABILITIES: list[tuple[str, dict]] = [
    (
        "Defensive Stance",
        _clip(0.8, [
            _k(0.0),
            _k(0.35, torso=4, upper_l=-28, fore_l=-18, upper_r=16, fore_r=12, sword=-8, thigh_l=8, thigh_r=-8),
            _k(1.0, torso=4, upper_l=-28, fore_l=-18, upper_r=16, fore_r=12, sword=-8, thigh_l=8, thigh_r=-8),
        ]),
    ),
    (
        "Charge",
        _clip(0.7, [
            _k(0.0),
            _k(0.25, (6, 2), torso=-14, upper_l=-36, fore_l=-10, upper_r=22, sword=12, thigh_l=28, shin_l=-30, thigh_r=-8),
            _k(0.55, (16, 0), torso=-8, upper_l=-20, upper_r=-16, sword=-36, thigh_l=-6, thigh_r=24, shin_r=-20),
            _k(1.0),
        ]),
    ),
    (
        "Shield Block",
        _clip(0.7, [
            _k(0.0),
            _k(0.3, torso=6, upper_l=-42, fore_l=-24, head=-4),
            _k(1.0, torso=6, upper_l=-42, fore_l=-24, head=-4),
        ]),
    ),
    (
        "Thunder Clap",
        _clip(0.8, [
            _k(0.0),
            _k(0.35, upper_l=46, fore_l=16, upper_r=-46, fore_r=-16, torso=-4),
            _k(0.55, (0, 3), upper_l=-18, fore_l=-20, upper_r=18, fore_r=20, torso=6),
            _k(1.0),
        ]),
    ),
    (
        "Devastate",
        _clip(0.75, [
            _k(0.0),
            _k(0.28, torso=8, upper_r=22, fore_r=-20, sword=-16),
            _k(0.48, torso=-14, upper_r=-18, fore_r=-6, sword=-48),
            _k(1.0),
        ]),
    ),
    (
        "Taunt",
        _clip(0.8, [
            _k(0.0),
            _k(0.4, (0, -2), torso=-6, head=-6, upper_l=34, upper_r=-34, fore_l=10, fore_r=-10),
            _k(1.0, (0, -2), torso=-6, head=-6, upper_l=34, upper_r=-34),
        ]),
    ),
    (
        "Demoralizing Shout",
        _clip(0.8, [
            _k(0.0),
            _k(0.35, torso=8, head=8, upper_l=20, upper_r=-20),
            _k(0.6, (0, 2), torso=12, head=10, upper_l=-10, upper_r=10),
            _k(1.0),
        ]),
    ),
    (
        "Shield Slam",
        _clip(0.7, [
            _k(0.0),
            _k(0.25, upper_l=30, fore_l=20),
            _k(0.45, (4, 1), torso=-8, upper_l=-40, fore_l=-16),
            _k(1.0),
        ]),
    ),
    (
        "Commanding Shout",
        _clip(0.8, [
            _k(0.0),
            _k(0.4, (0, -3), torso=-8, head=-8, upper_l=40, upper_r=-20, sword=10),
            _k(1.0, (0, -3), torso=-8, upper_l=40, upper_r=-20),
        ]),
    ),
    (
        "Revenge",
        _clip(0.65, [
            _k(0.0),
            _k(0.3, upper_l=-34, fore_l=-12, upper_r=14, sword=-10),
            _k(0.5, torso=-8, upper_l=-16, upper_r=-20, sword=-42),
            _k(1.0),
        ]),
    ),
    (
        "Shockwave",
        _clip(0.75, [
            _k(0.0),
            _k(0.3, (0, -2), upper_l=40, upper_r=-40),
            _k(0.5, (0, 6), torso=8, upper_l=8, upper_r=-8, thigh_l=14, thigh_r=-14),
            _k(1.0),
        ]),
    ),
    (
        "Last Stand",
        _clip(0.8, [
            _k(0.0),
            _k(0.4, (0, 4), torso=8, upper_l=-36, fore_l=-20, thigh_l=16, thigh_r=-16, shin_l=-12, shin_r=12),
            _k(1.0, (0, 4), torso=8, upper_l=-36, fore_l=-20, thigh_l=16, thigh_r=-16),
        ]),
    ),
    (
        "Shield Wall",
        _clip(0.8, [
            _k(0.0),
            _k(0.35, (0, 5), torso=12, head=6, upper_l=-48, fore_l=-28, upper_r=24, sword=8),
            _k(1.0, (0, 5), torso=12, upper_l=-48, fore_l=-28, upper_r=24),
        ]),
    ),
    (
        "Battle Stance",
        _clip(0.7, [
            _k(0.0),
            _k(0.4, torso=-4, upper_r=-12, fore_r=-8, sword=-6, upper_l=8),
            _k(1.0, torso=-4, upper_r=-12, fore_r=-8, sword=-6),
        ]),
    ),
    (
        "Mortal Strike",
        _clip(0.8, [
            _k(0.0),
            _k(0.3, torso=10, upper_r=28, fore_r=-24, sword=-8),
            _k(0.5, torso=-16, upper_r=-24, fore_r=-4, sword=-56),
            _k(1.0),
        ]),
    ),
    (
        "Overpower",
        _clip(0.55, [
            _k(0.0),
            _k(0.25, torso=6, upper_r=16, sword=-12),
            _k(0.45, torso=-10, upper_r=-14, sword=-36),
            _k(1.0),
        ]),
    ),
    (
        "Rend",
        _clip(0.7, [
            _k(0.0),
            _k(0.3, torso=6, upper_r=18, sword=20),
            _k(0.55, torso=-10, upper_r=-22, sword=-30),
            _k(1.0),
        ]),
    ),
    (
        "Sweeping Strikes",
        _clip(0.8, [
            _k(0.0),
            _k(0.3, torso=12, upper_r=24, sword=28, upper_l=-10),
            _k(0.6, torso=-14, upper_r=-26, sword=-34, upper_l=16),
            _k(1.0),
        ]),
    ),
    (
        "Bladestorm",
        _clip(0.9, [
            _k(0.0, upper_r=-8, sword=0),
            _k(0.25, torso=10, upper_r=-16, sword=70),
            _k(0.5, torso=-10, upper_r=-16, sword=150),
            _k(0.75, torso=10, upper_r=-16, sword=230),
            _k(1.0, sword=300),
        ]),
    ),
    (
        "Execute",
        _clip(0.8, [
            _k(0.0),
            _k(0.35, (0, -3), torso=12, upper_r=34, fore_r=-30, sword=6),
            _k(0.55, (0, 4), torso=-18, upper_r=-28, sword=-62),
            _k(1.0),
        ]),
    ),
    (
        "Rallying Cry",
        _clip(0.75, [
            _k(0.0),
            _k(0.4, (0, -4), torso=-10, head=-10, upper_l=36, upper_r=-30),
            _k(1.0, (0, -2), torso=-6, upper_l=28, upper_r=-22),
        ]),
    ),
    (
        "Berserker Stance",
        _clip(0.7, [
            _k(0.0),
            _k(0.4, torso=-10, head=-4, upper_r=-20, sword=-18, upper_l=22, fore_l=12),
            _k(1.0, torso=-10, upper_r=-20, sword=-18, upper_l=22),
        ]),
    ),
    (
        "Bloodthirst",
        _clip(0.7, [
            _k(0.0),
            _k(0.2, upper_r=14, sword=-28),
            _k(0.35),
            _k(0.55, torso=-8, upper_r=-12, sword=-40),
            _k(1.0),
        ]),
    ),
    (
        "Whirlwind",
        _clip(0.85, [
            _k(0.0, upper_l=20, upper_r=-20),
            _k(0.33, torso=16, upper_l=28, upper_r=-28, sword=80),
            _k(0.66, torso=-16, upper_l=28, upper_r=-28, sword=170),
            _k(1.0, sword=250),
        ]),
    ),
    (
        "Raging Blow",
        _clip(0.7, [
            _k(0.0),
            _k(0.2, upper_r=-10, sword=-32),
            _k(0.35, sword=8),
            _k(0.55, torso=-8, upper_r=-16, sword=-44),
            _k(1.0),
        ]),
    ),
    (
        "Enrage",
        _clip(0.6, [
            _k(0.0),
            _k(0.4, torso=-8, upper_l=16, upper_r=-18, sword=-8, head=-4),
            _k(0.7, torso=-4, upper_l=10, upper_r=-10),
            _k(1.0),
        ]),
    ),
    (
        "Death Wish",
        _clip(0.75, [
            _k(0.0),
            _k(0.4, torso=-12, head=-6, upper_r=20, sword=16, upper_l=-16),
            _k(1.0, torso=-12, upper_r=20, sword=16, upper_l=-16),
        ]),
    ),
    (
        "Rampage",
        _clip(0.85, [
            _k(0.0),
            _k(0.2, sword=-30, upper_r=-8),
            _k(0.35, sword=6),
            _k(0.55, sword=-38, torso=-6),
            _k(0.7, sword=4),
            _k(0.9, sword=-48, torso=-10, upper_r=-14),
            _k(1.0),
        ]),
    ),
    (
        "Enraged Regeneration",
        _clip(0.9, [
            _k(0.0),
            _k(0.4, (0, 5), torso=10, upper_l=-20, upper_r=18, thigh_l=18, thigh_r=-18),
            _k(0.75, (0, -2), torso=-4, upper_l=12, upper_r=-12),
            _k(1.0),
        ]),
    ),
    (
        "Recklessness",
        _clip(0.8, [
            _k(0.0),
            _k(0.25, torso=8, upper_r=20, sword=24, upper_l=24),
            _k(0.5, torso=-12, upper_r=-22, sword=-40, upper_l=-10),
            _k(0.75, torso=6, sword=18, upper_r=12),
            _k(1.0),
        ]),
    ),
]
