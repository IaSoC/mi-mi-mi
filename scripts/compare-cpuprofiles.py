#!/usr/bin/env python3
"""Compare aggregated embedded CPU samples across two Perfetto traces."""
import json
import sys
from collections import defaultdict
from pathlib import Path

import importlib.util
spec = importlib.util.spec_from_file_location(
    "ex", Path(__file__).parent / "extract-embedded-cpuprofile.py"
)
ex = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ex)


def aggregate(p):
    data = Path(p).read_bytes()
    blobs = ex.find_json_objects(data)
    total = defaultdict(int)
    samples = 0
    detail = defaultdict(list)  # key -> list of (fn, url, line, col)
    for b in blobs:
        cp = b.get("cpuProfile") or {}
        nodes = cp.get("nodes") or []
        smp = cp.get("samples") or []
        samples += len(smp)
        by_id = {n.get("id"): n for n in nodes}
        def add(n, w=1):
            if not n:
                return
            cf = n.get("callFrame") or {}
            fn = cf.get("functionName") or "(anon)"
            url = (cf.get("url") or "").split("/")[-1][:40]
            key = f"{fn} @{url}"
            total[key] += w
            if len(detail[key]) < 5:
                detail[key].append(
                    f"{cf.get('lineNumber','?')}:{cf.get('columnNumber','?')}"
                )
        for n in nodes:
            add(n, n.get("hitCount") or 0)
        for sid in smp:
            add(by_id.get(sid), 1)
    return total, samples, detail, len(blobs)


def main():
    if len(sys.argv) < 3:
        print("usage: compare-cpuprofiles.py a.json b.json")
        return
    ta, sa, da, ba = aggregate(sys.argv[1])
    tb, sb, db, bb = aggregate(sys.argv[2])
    na = Path(sys.argv[1]).parent.name
    nb = Path(sys.argv[2]).parent.name
    print(f"\n{na}: blobs={ba} samples={sa}")
    print(f"{nb}: blobs={bb} samples={sb}")

    keys = set(ta) | set(tb)
    rows = []
    for k in keys:
        a, b = ta.get(k, 0), tb.get(k, 0)
        rows.append((k, a, b, b - a, (b + 1) / (a + 1)))
    rows.sort(key=lambda x: -abs(x[3]))

    print(f"\n{'delta':>6}  {na[-6:]:>6}  {nb[-6:]:>6}  {'x':>6}  name")
    for k, a, b, d, r in rows[:40]:
        print(f"{d:+6d}  {a:6d}  {b:6d}  {r:6.2f}  {k}")

    print("\n-- detail for biggest x64-only / x64-heavy --")
    for k, a, b, d, r in rows[:12]:
        if d > 20:
            print(f"  {k}  {nb[-6:]}={b} loc={db.get(k)}")


if __name__ == "__main__":
    main()
