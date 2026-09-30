"""Facit registry, debt ratchet, and CLI."""
from __future__ import annotations

import argparse
import json
import sys

from facit import armor, body, hands, icons, style, unique
from facit.findings import Finding, apply_debt, wrap
from facit.lock import check_lock
from facit.report import write_contact_sheet, write_failures

# (id, slow). Slow checks are the gold-master rebakes.
SLOW = frozenset({"pose_bodies", "race_bake"})


def collect(
    selected: set[str] | None,
    *,
    relock: bool,
    no_lock: bool,
    skip_slow: bool,
) -> list[Finding]:
    out: list[Finding] = []

    def add(name: str, fn) -> None:
        if selected is not None and name not in selected:
            return
        if skip_slow and name in SLOW:
            return
        out.extend(fn())

    add("files", lambda: wrap("files", body.check_files()))
    add("classifier", lambda: wrap("classifier", body.check_classifier()))
    add("race_bodies", lambda: wrap("race_bodies", body.check_race_bodies()))
    add("body_tint", lambda: wrap("body_tint", body.check_body_tint_masks()))
    add("pose_bodies", lambda: wrap("pose_bodies", body.check_pose_bodies()))
    add("race_bake", lambda: wrap("race_bake", body.check_race_bake()))
    add("draw_order", lambda: wrap("draw_order", body.check_draw_order()))
    add("tiers", lambda: wrap("tiers", armor.check_tiers_and_materials()))
    add("face", lambda: wrap("face", armor.check_face_ownership()))
    add("styles", lambda: wrap("styles", armor.check_styles()))
    add("manifest", lambda: wrap("manifest", armor.check_manifest()))
    add("grips", lambda: wrap("grips", hands.check_hand_items()))
    if not no_lock:
        add("lock", lambda: wrap("lock", check_lock(relock)))
    add("idle", lambda: wrap("idle", body.check_idle_gate()))
    add("style", style.check_style)
    add("material", armor.check_material_surface)
    add("unique", unique.check_unique)
    add("proportion", hands.check_proportions)
    add("icon_parity", icons.check_icon_parity)
    add("hand_anchor", hands.check_hand_anchor)
    add("full_stack", armor.check_full_stack)
    add("readability", armor.check_readability)
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Paper-doll facit gate")
    parser.add_argument("--relock", action="store_true")
    parser.add_argument("--no-lock", action="store_true")
    parser.add_argument("--fast", action="store_true", help="skip pose and race rebakes")
    parser.add_argument("--only", default="", help="comma-separated check ids")
    parser.add_argument("--json", default="", help="write the failure list to this path")
    parser.add_argument("--report", action="store_true")
    parser.add_argument("--write-debt", action="store_true")
    parser.add_argument("--prune-debt", action="store_true")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args(argv)
    if args.selftest:
        from facit.selftest import run as run_selftest

        return run_selftest()

    selected = {p.strip() for p in args.only.split(",") if p.strip()} or None
    findings = collect(
        selected,
        relock=args.relock,
        no_lock=args.no_lock,
        skip_slow=args.fast,
    )
    # --fast still ran the slow checks above. Skip them up front instead.
    failures, _debt = apply_debt(
        findings,
        write=args.write_debt,
        prune=args.prune_debt,
    )
    if args.report:
        sheet = write_contact_sheet()
        write_failures(failures or findings)
        print(f"report {sheet}")
    if args.json:
        payload = [f.as_dict() for f in failures]
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
            fh.write("\n")
    for f in failures:
        where = f" {f.file}" if f.file else ""
        print(f"FAIL {f.check}{where}: {f.key}")
    if failures:
        print(f"{len(failures)} facit check(s) failed")
        return 1
    print("facit ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
