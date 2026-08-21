import json, base64, sys
from pathlib import Path

def save(cdp_json_path, out_png):
    p = Path(cdp_json_path)
    j = json.loads(p.read_text(encoding="utf-8"))
    def find(o):
        if isinstance(o, dict):
            if "data" in o and isinstance(o["data"], str) and len(o["data"]) > 1000:
                return o["data"]
            for v in o.values():
                r = find(v)
                if r:
                    return r
        return None
    data = find(j)
    if not data:
        raise SystemExit("no data in " + str(p))
    out = Path(out_png)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(base64.b64decode(data))
    print(out, out.stat().st_size)

if __name__ == "__main__":
    save(sys.argv[1], sys.argv[2])
