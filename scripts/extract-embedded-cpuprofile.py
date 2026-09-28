#!/usr/bin/env python3
"""Extract embedded cpuProfile JSON blobs from Chromium Perfetto proto traces."""
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

PAT = re.compile(rb'\{"source":"Internal","cpuProfile":\{')
END = re.compile(rb'\}\}\}\s*,?\s*')


def find_json_objects(data: bytes):
    out = []
    for m in PAT.finditer(data):
        start = m.start()
        # brace matching
        depth = 0
        i = start
        n = len(data)
        while i < n:
            c = data[i]
            if c == 0x7B:  # {
                depth += 1
            elif c == 0x7D:  # }
                depth -= 1
                if depth == 0:
                    blob = data[start:i + 1]
                    try:
                        out.append(json.loads(blob.decode('utf-8', 'replace')))
                    except Exception:
                        pass
                    break
            i += 1
    return out


def analyze_profile(prof, label, top=20):
    cp = prof.get('cpuProfile') or {}
    nodes = cp.get('nodes') or []
    samples = cp.get('samples') or []
    print(f'\n  nodes={len(nodes)} samples={len(samples)} label={label}')
    if not nodes:
        return
    hit = defaultdict(int)
    by_id = {}
    for n in nodes:
        by_id[n.get('id')] = n
        h = n.get('hitCount') or 0
        if h:
            cf = n.get('callFrame') or {}
            fn = cf.get('functionName') or '(anon)'
            url = (cf.get('url') or '').split('/')[-1][:40]
            key = f'{fn} @{url}:{cf.get("lineNumber","?")}'
            hit[key] += h
    # also count samples
    if samples:
        for sid in samples:
            n = by_id.get(sid)
            if not n:
                continue
            cf = n.get('callFrame') or {}
            fn = cf.get('functionName') or '(anon)'
            url = (cf.get('url') or '').split('/')[-1][:40]
            key = f'{fn} @{url}:{cf.get("lineNumber","?")}'
            hit[key] += 1

    print(f'  {"hits":>6}  name')
    for k, v in sorted(hit.items(), key=lambda x: -x[1])[:top]:
        print(f'  {v:6d}  {k}')


def main():
    paths = sys.argv[1:]
    if not paths:
        paths = sorted(Path('scripts/bench-output').glob('trace-*/startup-trace.json'))
    for p in paths:
        p = Path(p)
        data = p.read_bytes()
        print(f'\n===== {p.parent.name} =====')
        blobs = find_json_objects(data)
        print(f'embedded cpuProfile blobs: {len(blobs)}')
        for i, b in enumerate(blobs[:8]):
            analyze_profile(b, f'blob#{i}')


if __name__ == '__main__':
    main()
