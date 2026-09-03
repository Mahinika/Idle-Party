"""Quick A56 adb playtest: GEAR doll screenshot + dungeon compare."""
import re
import subprocess
import time
from pathlib import Path

ADB = ["adb", "-s", "emulator-5554"]
OUT = Path(__file__).resolve().parent


def adb(*args: str) -> None:
    subprocess.run([*ADB, *args], check=False, capture_output=True)


def dump_ui() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    adb("pull", "/sdcard/ui.xml", str(OUT / "ui_dump.xml"))
    return (OUT / "ui_dump.xml").read_text(encoding="utf-8")


def find_center(xml: str, *needles: str) -> tuple[int, int] | None:
    for m in re.finditer(
        r'content-desc="([^"]+)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        xml,
    ):
        d = m.group(1).replace("&#10;", " ").upper()
        if all(n.upper() in d for n in needles):
            x1, y1, x2, y2 = map(int, m.groups()[1:])
            return (x1 + x2) // 2, (y1 + y2) // 2
    return None


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def screenshot(name: str) -> Path:
    path = OUT / name
    adb("shell", "screencap", "-p", "/sdcard/screen.png")
    adb("pull", "/sdcard/screen.png", str(path))
    return path


def list_labels(xml: str) -> None:
    for m in re.finditer(
        r'content-desc="([^"]+)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        xml,
    ):
        d = m.group(1).replace("&#10;", " | ")[:90]
        x1, y1, x2, y2 = map(int, m.groups()[1:])
        print(f"  {d} @ {(x1+x2)//2},{(y1+y2)//2}")


def main() -> None:
    xml = dump_ui()
    if find_center(xml, "CLOSE") and find_center(xml, "GEAR"):
        print("On GEAR menu — screenshot doll")
        screenshot("playtest_gear_fresh.png")
        c = find_center(xml, "CLOSE")
        assert c
        tap(*c)
        time.sleep(2)

    xml = dump_ui()
    for label in ("CONTINUE",):
        pt = find_center(xml, label)
        if pt:
            print(f"Tap {label} {pt}")
            tap(*pt)
            time.sleep(8)
            break

    xml = dump_ui()
    print("Hub labels:")
    list_labels(xml)
    enter = (
        find_center(xml, "ENTER")
        or find_center(xml, "SUNKEN")
        or find_center(xml, "TIDEHOLD")
    )
    if enter:
        print(f"Enter dungeon {enter}")
        tap(*enter)
        time.sleep(12)
    else:
        # Hub big zone card — tap center lower area
        print("Fallback enter tap")
        tap(540, 1200)
        time.sleep(12)

    screenshot("playtest_dungeon_fresh.png")
    print("Saved dungeon screenshot")


if __name__ == "__main__":
    main()
