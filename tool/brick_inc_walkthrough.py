"""Systematic Brick Inc screenshot walkthrough (no purchases)."""

from __future__ import annotations

import subprocess
import time
from pathlib import Path

SERIAL = "emulator-5554"
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "competitor_research" / "brick_inc_idle_breaker" / "screens"
LOG = ROOT / "docs" / "competitor_research" / "brick_inc_idle_breaker" / "SESSION_LOG.md"


def adb(*args: str) -> None:
    subprocess.check_call(["adb", "-s", SERIAL, *args])


def tap(x: int, y: int, wait: float = 1.8) -> None:
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(wait)


def swipe(x1: int, y1: int, x2: int, y2: int, wait: float = 1.2) -> None:
    adb("shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), "350")
    time.sleep(wait)


def back(wait: float = 1.2) -> None:
    adb("shell", "input", "keyevent", "4")
    time.sleep(wait)


def shot(name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with path.open("wb") as f:
        subprocess.check_call(
            ["adb", "-s", SERIAL, "exec-out", "screencap", "-p"], stdout=f
        )
    print(name)


def log(note: str) -> None:
    line = f"- Walkthrough — {note}\n"
    if LOG.exists():
        LOG.write_text(LOG.read_text(encoding="utf-8") + line, encoding="utf-8")


def close_overlays() -> None:
    """Red X on shop / close buttons (bottom-left)."""
    tap(130, 2280, 0.8)
    tap(130, 2280, 0.8)
    back(0.6)


def nav_battle() -> None:
    tap(540, 2180, 1.5)


def nav_cards() -> None:
    tap(108, 2180, 1.5)


def nav_hex() -> None:
    tap(324, 2180, 1.5)


def nav_portal() -> None:
    tap(756, 2180, 1.5)


def nav_shop_tab() -> None:
    tap(972, 2180, 1.5)


STEPS: list[tuple[str, str, callable]] = []


def main() -> None:
    close_overlays()
    nav_battle()

    # --- Battle ---
    shot("15_battle_home.png")
    log("15 battle home")
    swipe(540, 1900, 540, 1100)
    shot("16_battle_upgrades_scrolled.png")
    log("16 battle upgrade scroll")
    swipe(540, 1100, 540, 1900)

    # --- Cards ---
    nav_cards()
    shot("17_cards_card_tab.png")
    log("17 cards tab")
    tap(780, 2050, 1.5)  # Mythic Card sub-tab
    shot("18_cards_mythic_tab.png")
    log("18 mythic card tab")

    # --- Meta hub + each tile ---
    nav_hex()
    shot("19_meta_hub.png")
    log("19 meta hub")
    tiles = [
        ("20_meta_epic.png", 270, 620, "Epic"),
        ("21_meta_system_admin.png", 540, 620, "System Admin"),
        ("22_meta_soul.png", 810, 620, "Soul"),
        ("23_meta_science.png", 270, 880, "Science Foundation"),
        ("24_meta_dimension.png", 540, 880, "Dimension"),
        ("25_meta_art.png", 810, 880, "Art Society"),
    ]
    for fname, x, y, label in tiles:
        nav_hex()
        tap(x, y, 2.2)
        shot(fname)
        log(f"{fname} {label}")
        back(0.8)
        back(0.8)

    # --- Challenge hub ---
    nav_portal()
    shot("26_challenge_hub.png")
    log("26 challenge hub")
    tap(720, 1980, 1.5)  # New World sub-tab
    shot("27_challenge_new_world_tab.png")
    log("27 new world tab")
    tap(360, 1980, 1.5)  # back to Challenge
    tap(540, 420, 1.8)  # Leaderboard button
    shot("28_leaderboard.png")
    log("28 leaderboard")
    back()
    nav_portal()
    tap(540, 520, 1.8)  # Preset
    shot("29_preset.png")
    log("29 preset")
    back()

    # --- Shop overlay (tabs only, no buy buttons) ---
    close_overlays()
    nav_shop_tab()
    shot("30_shop_summons.png")
    log("30 shop summons tab")
    tap(280, 1980, 1.5)  # Special Offer tab (view only)
    shot("31_shop_special_offer.png")
    log("31 special offer tab (no taps on SKUs)")
    swipe(540, 1600, 540, 800)  # scroll offers
    shot("32_shop_special_offer_scroll.png")
    log("32 special offer scrolled")
    tap(540, 2220, 1.2)  # Prism Shop bar area — careful
    shot("33_prism_shop.png")
    log("33 prism shop entry")
    close_overlays()

    # --- Left rail ---
    nav_battle()
    tap(80, 650, 2.0)
    shot("34_rail_booster.png")
    log("34 booster overlay")
    close_overlays()
    nav_battle()
    tap(80, 780, 2.0)
    shot("35_rail_piggy_bank.png")
    log("35 piggy bank")
    close_overlays()
    nav_battle()
    tap(80, 910, 2.0)
    shot("36_rail_growth_center.png")
    log("36 growth center")
    close_overlays()

    # --- Right rail ---
    nav_battle()
    tap(1000, 650, 2.0)
    shot("37_rail_mission.png")
    log("37 mission")
    close_overlays()
    nav_battle()
    tap(1000, 780, 2.0)
    shot("38_rail_event.png")
    log("38 event")
    close_overlays()
    nav_battle()
    tap(1000, 920, 2.0)
    shot("39_rail_gift_lower.png")
    log("39 gift icon lower")
    close_overlays()

    # --- Top bar ---
    nav_battle()
    tap(1020, 170, 2.0)
    shot("40_hamburger_menu.png")
    log("40 hamburger menu")
    back()
    tap(930, 170, 1.5)  # x2 speed
    shot("41_x2_speed_panel.png")
    log("41 x2 speed")
    back()
    tap(620, 230, 1.5)  # power magnifier area
    shot("42_power_detail.png")
    log("42 power detail popup")
    back()

    nav_battle()
    shot("99_battle_return_end.png")
    log("99 end on battle")
    print("Done:", OUT)


if __name__ == "__main__":
    main()
