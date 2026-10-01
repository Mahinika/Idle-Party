"""Per-family cut constants for the hero skeleton baker.

The dressed `_src/body_idle.png` is the silhouette. Live undertunics and gear
overlays are split later with the same label map.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class FamilyCut:
    name: str
    head_y: int
    head_chin_y: int
    chin_x0: int
    chin_x1: int
    arm_y: int
    upper_y: int
    fore_y: int
    pauldron_x_l: int
    pauldron_x_r: int
    leg_y: int
    leg_split_x: int
    thigh_y: int
    shin_y: int
    # Robes: pixels from the waist down to the hem, inside the cloth, are skirt.
    skirt: bool = False
    hem_y: int = 0
    # Idle fist, center origin, fraction of 128. The bone under that pixel holds the weapon.
    main_fist: tuple[float, float] = (0.0, 0.0)
    off_fist: tuple[float, float] = (0.0, 0.0)


FAMILIES: dict[str, FamilyCut] = {
    "warrior": FamilyCut(
        name="warrior",
        head_y=40,
        head_chin_y=48,
        chin_x0=36,
        chin_x1=92,
        arm_y=66,
        upper_y=76,
        fore_y=86,
        pauldron_x_l=36,
        pauldron_x_r=92,
        leg_y=94,
        leg_split_x=64,
        thigh_y=107,
        shin_y=118,
        main_fist=(0.238, 0.035),
        off_fist=(-0.246, 0.035),
    ),
    "rogue": FamilyCut(
        name="rogue",
        head_y=38,
        head_chin_y=48,
        chin_x0=40,
        chin_x1=88,
        arm_y=64,
        upper_y=74,
        fore_y=84,
        pauldron_x_l=40,
        pauldron_x_r=88,
        leg_y=92,
        leg_split_x=64,
        thigh_y=106,
        shin_y=116,
        main_fist=(0.212, -0.004),
        off_fist=(-0.221, -0.006),
    ),
    # Robe hem sits above the shoes. Legs only exist below the hem.
    "mage": FamilyCut(
        name="mage",
        head_y=36,
        head_chin_y=46,
        chin_x0=42,
        chin_x1=86,
        arm_y=62,
        upper_y=74,
        fore_y=86,
        pauldron_x_l=34,
        pauldron_x_r=94,
        leg_y=108,
        leg_split_x=64,
        thigh_y=116,
        shin_y=122,
        skirt=True,
        hem_y=108,
        main_fist=(0.212, 0.024),
        off_fist=(-0.224, 0.071),
    ),
    "healer": FamilyCut(
        name="healer",
        head_y=36,
        head_chin_y=46,
        chin_x0=42,
        chin_x1=86,
        arm_y=62,
        upper_y=74,
        fore_y=86,
        pauldron_x_l=34,
        pauldron_x_r=94,
        leg_y=108,
        leg_split_x=64,
        thigh_y=116,
        shin_y=122,
        skirt=True,
        hem_y=108,
        main_fist=(0.214, 0.030),
        off_fist=(-0.225, 0.029),
    ),
}

DRAW_PLATE = [
    "thigh_l",
    "thigh_r",
    "shin_l",
    "shin_r",
    "foot_l",
    "foot_r",
    "torso",
    "pauldron_l",
    "pauldron_r",
    "upper_l",
    "upper_r",
    "fore_l",
    "fore_r",
    "hand_l",
    "hand_r",
    "head",
]

DRAW_ROBE = [
    "skirt",
    "thigh_l",
    "thigh_r",
    "shin_l",
    "shin_r",
    "foot_l",
    "foot_r",
    "torso",
    "pauldron_l",
    "pauldron_r",
    "upper_l",
    "upper_r",
    "fore_l",
    "fore_r",
    "hand_l",
    "hand_r",
    "head",
]

# Child, and the step that points back at the parent joint.
LIMB_PARENT = {
    "head": ("torso", (0, 1)),
    "pauldron_l": ("torso", (1, 0)),
    "pauldron_r": ("torso", (-1, 0)),
    "upper_l": ("pauldron_l", (0, -1)),
    "upper_r": ("pauldron_r", (0, -1)),
    "fore_l": ("upper_l", (0, -1)),
    "fore_r": ("upper_r", (0, -1)),
    "hand_l": ("fore_l", (0, -1)),
    "hand_r": ("fore_r", (0, -1)),
    "thigh_l": ("root", (0, -1)),
    "thigh_r": ("root", (0, -1)),
    "shin_l": ("thigh_l", (0, -1)),
    "shin_r": ("thigh_r", (0, -1)),
    "foot_l": ("shin_l", (0, -1)),
    "foot_r": ("shin_r", (0, -1)),
    "skirt": ("root", (0, -1)),
}

RACES = [
    "human",
    "dwarf",
    "nightelf",
    "gnome",
    "draenei",
    "worgen",
    "orc",
    "forsaken",
    "tauren",
    "troll",
    "bloodelf",
    "goblin",
]
SEXES = ("m", "f")
