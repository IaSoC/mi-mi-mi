import json, sys
from collections import defaultdict
from pathlib import Path

def analyze(p):
    p = Path(p)
    data = json.loads(p.read_text(encoding='utf-8'))
    nodes = {n['id']: n for n in data['nodes']}
    samples = data.get('samples') or []
    deltas = data.get('timeDeltas') or []

    # self-time: count hits per node
    hit = defaultdict(int)
    for nid in samples:
        hit[nid] += 1

    # approximate wall us
    if deltas and len(deltas) == len(samples):
        total_us = sum(deltas)
        us_per_hit = total_us / max(len(samples), 1)
    else:
        total_us = data.get('endTime', 0) - data.get('startTime', 0)
        us_per_hit = total_us / max(len(samples), 1)

    # aggregate by (fn, url)
    self_by = defaultdict(int)
    for nid, n in hit.items():
        node = nodes.get(nid)
        if not node:
            continue
        cf = node.get('callFrame') or {}
        fn = cf.get('functionName') or '(anonymous)'
        url = cf.get('url') or ''
        if len(url) > 80:
            url = '...' + url[-77:]
        key = f"{fn} @ {url or '<native>'}"
        self_by[key] += n

    # total time (inclusive) via parent links
    parent = {}
    children = defaultdict(list)
    for n in data['nodes']:
        for c in n.get('children') or []:
            parent[c] = n['id']
            children[n['id']].append(c)

    # DFS inclusive hit counts
    incl = defaultdict(int)
    # post-order
    def walk(nid):
        s = hit.get(nid, 0)
        for c in children.get(nid, []):
            s += walk(c)
        incl[nid] = s
        return s
    roots = [n['id'] for n in data['nodes'] if n['id'] not in parent]
    for r in roots:
        walk(r)

    incl_by = defaultdict(int)
    for nid, n in nodes.items():
        cf = n.get('callFrame') or {}
        fn = cf.get('functionName') or '(anonymous)'
        url = cf.get('url') or ''
        if len(url) > 80:
            url = '...' + url[-77:]
        key = f"{fn} @ {url or '<native>'}"
        incl_by[key] += incl.get(nid, 0)

    print(f"\n===== {p.name}  ({p.parent.name}) =====")
    print(f"samples={len(samples)}  nodes={len(data['nodes'])}  window_us≈{total_us:.0f}  (~{total_us/1e6:.2f}s)")
    print(f"us_per_sample≈{us_per_hit:.0f}")

    print("\n-- TOP SELF TIME (own CPU) --")
    print(f"{'self_ms':>10}  {'%':>6}  name")
    top = sorted(self_by.items(), key=lambda x: -x[1])[:25]
    for k, v in top:
        ms = v * us_per_hit / 1000
        pct = 100.0 * v / max(sum(self_by.values()), 1)
        print(f"{ms:10.0f}  {pct:5.1f}%  {k}")

    print("\n-- TOP INCLUSIVE TIME (with children) --")
    top_i = sorted(incl_by.items(), key=lambda x: -x[1])[:25]
    for k, v in top_i:
        ms = v * us_per_hit / 1000
        pct = 100.0 * v / max(max(incl_by.values()), 1)
        print(f"{ms:10.0f}  {pct:5.1f}%  {k}")

    # aggregate by script file
    print("\n-- SELF BY SCRIPT FILE --")
    by_url = defaultdict(int)
    for nid, n in hit.items():
        node = nodes.get(nid)
        if not node:
            continue
        cf = node.get('callFrame') or {}
        url = cf.get('url') or '<native>'
        if len(url) > 100:
            url = '...' + url[-97:]
        by_url[url] += n
    for k, v in sorted(by_url.items(), key=lambda x: -x[1])[:15]:
        ms = v * us_per_hit / 1000
        pct = 100.0 * v / max(sum(by_url.values()), 1)
        print(f"{ms:10.0f}  {pct:5.1f}%  {k}")

if __name__ == '__main__':
    paths = sys.argv[1:]
    if not paths:
        paths = [
            r'C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\scripts\bench-output\cpuprof-ARM64-20260927-001929\startup.cpuprofile',
            r'C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\scripts\bench-output\cpuprof-x64-20260927-001940\startup.cpuprofile',
        ]
    for p in paths:
        analyze(p)
