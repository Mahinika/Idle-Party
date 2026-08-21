"""Move static members out of a giant Dart class into a sibling class.

`GameLogic` grew past 7000 lines because gear, loot, offline, pets and ascend all
lived on one class. This lifts a named set of members into a new file and leaves
one-line delegates behind, so existing callers keep working while new code can
talk to the smaller class directly.

Line-based on purpose: the repo is `dart format`ed, so every member of a class
starts at indent two with `static ` (or its doc comment does).

Usage: py -3 tool/split_static_class.py <spec.json>
"""

from __future__ import annotations

import io
import json
import re
import sys

MEMBER = re.compile(r"^  static ")
DOC = re.compile(r"^  ///|^  //(?!\s*—)")


def _strip_literals(line: str) -> str:
    out, i, n = [], 0, len(line)
    while i < n:
        ch = line[i]
        if ch == "/" and i + 1 < n and line[i + 1] == "/":
            break
        if ch in "'\"":
            quote = ch
            i += 1
            while i < n:
                if line[i] == "\\":
                    i += 2
                    continue
                if line[i] == quote:
                    break
                i += 1
            i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def scan_members(lines: list[str], class_line: int) -> dict[str, tuple[int, int]]:
    spans: dict[str, tuple[int, int]] = {}
    i = class_line + 1
    n = len(lines)
    doc_start: int | None = None
    while i < n:
        line = lines[i]
        if line.startswith("}"):
            break
        if DOC.match(line):
            if doc_start is None:
                doc_start = i
            i += 1
            continue
        if MEMBER.match(line):
            start = doc_start if doc_start is not None else i
            end = _member_end(lines, i)
            name = _name_of("\n".join(lines[i:end]))
            spans[name] = (start, end)
            doc_start = None
            i = end
            continue
        if line.strip():
            doc_start = None
        i += 1
    return spans


def _member_end(lines: list[str], i: int) -> int:
    depth = 0
    j = i
    while j < len(lines):
        code = _strip_literals(lines[j])
        depth += code.count("(") + code.count("[") + code.count("{")
        depth -= code.count(")") + code.count("]") + code.count("}")
        stripped = code.rstrip()
        if depth <= 0 and (stripped.endswith(";") or stripped.endswith("}")):
            return j + 1
        j += 1
    raise AssertionError(f"unterminated member at line {i + 1}: {lines[i]}")


def _name_of(text: str) -> str:
    """Member name, skipping record return types like `static ({int a}) foo()`."""
    code = "\n".join(_strip_literals(ln) for ln in text.split("\n"))
    code = code[code.index("static ") + len("static ") :]
    m = re.match(r"\s*(get|set)\s+([A-Za-z_][A-Za-z0-9_]*)", code)
    if m:
        return m.group(2)
    depth = 0
    for k, ch in enumerate(code):
        if ch in "[{":
            depth += 1
        elif ch in "]}":
            depth -= 1
        elif ch == ")":
            depth -= 1
        elif ch == "(":
            prev = code[:k].rstrip()
            if depth == 0 and prev and (prev[-1].isalnum() or prev[-1] == "_"):
                return re.findall(r"[A-Za-z_][A-Za-z0-9_]*", prev)[-1]
            depth += 1
        elif depth == 0 and ch in "=;":
            prev = code[:k].rstrip()
            return re.findall(r"[A-Za-z_][A-Za-z0-9_]*", prev)[-1]
    raise AssertionError(text[:120])


def split_top(text: str) -> list[str]:
    parts, depth, cur, i, n = [], 0, [], 0, len(text)
    while i < n:
        ch = text[i]
        if ch in "([{<":
            depth += 1
        elif ch in ")]}>":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
        i += 1
    tail = "".join(cur).strip()
    if tail:
        parts.append(tail)
    return parts


def _arg_name(param: str) -> str:
    p = param.split("=")[0].strip()
    ids = re.findall(r"[A-Za-z_][A-Za-z0-9_]*", p)
    return ids[-1] if ids else ""


def _param_paren(head: str) -> int:
    """Index of the parameter list `(`, skipping a record return type.

    `({GameState state, int overflowEssence}) stashEquipmentDetailed(...)` has
    two top-level parens; only the one right after the member name counts.
    """
    depth = 0
    for k, ch in enumerate(head):
        if ch in "[{":
            depth += 1
        elif ch in "]}":
            depth -= 1
        elif ch == ")":
            depth -= 1
        elif ch == "(":
            prev = head[:k].rstrip()
            if depth == 0 and prev and (prev[-1].isalnum() or prev[-1] == "_"):
                return k
            depth += 1
    return -1


def delegate_for(text: str, name: str, target: str) -> str | None:
    """`static <signature> => Target.name(args);` for a moved method."""
    code = "\n".join(
        ln for ln in text.split("\n") if not ln.strip().startswith("//")
    )
    at = code.index("  static ")
    head = code[at + len("  static ") :]
    paren = _param_paren(head)
    if paren < 0:
        return None  # field or getter: caller handles
    depth, k = 0, paren
    while k < len(head):
        if head[k] == "(":
            depth += 1
        elif head[k] == ")":
            depth -= 1
            if depth == 0:
                break
        k += 1
    ret_and_name = head[:paren].strip()
    params = head[paren + 1 : k]
    positional, named = [], []
    for raw in split_top(params):
        p = raw.strip()
        if not p:
            continue
        if p.startswith("{"):
            named += [_arg_name(q) for q in split_top(p.strip("{}")) if q.strip()]
        elif p.startswith("["):
            positional += [
                _arg_name(q) for q in split_top(p.strip("[]")) if q.strip()
            ]
        else:
            positional.append(_arg_name(p))
    args = [a for a in positional if a] + [f"{a}: {a}" for a in named if a]
    return (
        f"  static {ret_and_name}({params}) =>\n"
        f"      {target}.{name}({', '.join(args)});\n"
    )


def main() -> None:
    spec = json.load(io.open(sys.argv[1], encoding="utf-8"))
    src_path = spec["source"]
    src = io.open(src_path, encoding="utf-8").read()
    lines = src.split("\n")
    class_line = next(
        i
        for i, ln in enumerate(lines)
        if re.match(r"^(abstract final class|class) " + spec["class"] + r"\b", ln)
    )
    spans = scan_members(lines, class_line)
    missing = [m for m in spec["members"] if m not in spans]
    assert not missing, f"not found: {missing}"

    moved = [(m, "\n".join(lines[spans[m][0] : spans[m][1]])) for m in spec["members"]]

    delegates = []
    for name, text in moved:
        if name.startswith("_") or name in spec.get("no_delegate", []):
            continue
        d = delegate_for(text, name, spec["target_class"])
        delegates.append(d if d else f"  // MANUAL DELEGATE NEEDED: {name}\n")

    drop = sorted((spans[m] for m in spec["members"]), reverse=True)
    for a, b in drop:
        del lines[a:b]

    if delegates:
        # End of *this class*, not of the file: game_logic.dart also declares
        # OfflineProgressResult and an enum after GameLogic.
        end = class_line
        depth = 0
        while end < len(lines):
            code = _strip_literals(lines[end])
            depth += code.count("{") - code.count("}")
            if depth == 0 and end > class_line:
                break
            end += 1
        block = [
            "",
            f"  // —— {spec['bucket']}: moved to {spec['out'].split('/')[-1]} ——",
        ] + "".join(delegates).rstrip("\n").split("\n")
        lines[end:end] = block

    io.open(src_path, "w", encoding="utf-8").write("\n".join(lines))
    body = "\n".join(t.rstrip() + "\n" for _, t in moved)
    io.open(spec["out"], "w", encoding="utf-8").write(
        spec["header"] + "\n" + body + "}\n"
    )
    print(f"moved {len(moved)} members -> {spec['out']}")


if __name__ == "__main__":
    main()
