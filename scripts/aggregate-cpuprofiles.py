#!/usr/bin/env python3
"""Aggregate all embedded cpuProfile blobs from a Perfetto proto trace."""
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


def main():
    paths = sys.argv[1:] or [
        str(p) for p in sorted(Path("scripts/bench-output").glob("trace-*/startup-trace.json"))
    ]
    for p in paths:
        p = Path(p)
        data = p.read_bytes()
        blobs = ex.find_json_objects(data)
        print(f"\n===== {p.parent.name}  blobs={len(blobs)} =====")
        total = defaultdict(int)
        total_samples = 0
        for b in blobs:
            cp = b.get("cpuProfile") or {}
            nodes = cp.get("nodes") or []
            samples = cp.get("samples") or []
            total_samples += len(samples)
            for n in nodes:
                h = n.get("hitCount") or 0
                if h:
                    cf = n.get("callFrame") or {}
                    fn = cf.get("functionName") or "(anon)"
                    url = (cf.get("url") or "").split("/")[-1][:36]
                    total[f"{fn} @{url}"] += h
            by_id = {n.get("id"): n for n in nodes}
            for sid in samples:
                n = by_id.get(sid)
                if not n:
                    continue
                cf = n.get("callFrame") or {}
                fn = cf.get("functionName") or "(anon)"
                url = (cf.get("url") or "").split("/")[-1][:36]
                total[f"{fn} @{url}"] += 1
        print(f"total samples={total_samples}")
        print(f"{'hits':>6}  name")
        for k, v in sorted(total.items(), key=lambda x: -x[1])[:30]:
            print(f"{v:6d}  {k}")


if __name__ == "__main__":
    main()
