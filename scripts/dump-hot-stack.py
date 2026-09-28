import json, sys
from collections import defaultdict
from pathlib import Path

def load(p):
    data = json.loads(Path(p).read_text(encoding='utf-8'))
    nodes = {n['id']: n for n in data['nodes']}
    samples = data.get('samples') or []
    deltas = data.get('timeDeltas') or []
    hit = defaultdict(int)
    for nid in samples:
        hit[nid] += 1
    total_us = sum(deltas) if deltas and len(deltas) == len(samples) else (data.get('endTime', 0) - data.get('startTime', 0))
    us = total_us / max(len(samples), 1)
    parent = {}
    children = defaultdict(list)
    for n in data['nodes']:
        for c in n.get('children') or []:
            parent[c] = n['id']
            children[n['id']].append(c)
    return data, nodes, hit, us, parent, children

def frame(n):
    cf = n.get('callFrame') or {}
    fn = cf.get('functionName') or '(anonymous)'
    url = (cf.get('url') or '').split('/')[-1]
    line = cf.get('lineNumber')
    col = cf.get('columnNumber')
    return f"{fn} @{url}:{line}:{col}"

def stack_up(nodes, parent, nid, limit=8):
    out = []
    cur = nid
    seen = set()
    while cur is not None and cur not in seen and len(out) < limit:
        seen.add(cur)
        out.append(frame(nodes[cur]))
        cur = parent.get(cur)
    return out

def dump_hot(p, names):
    data, nodes, hit, us, parent, children = load(p)
    print(f"\n########## {Path(p).parent.name} ##########")
    print(f"window={sum(hit.values())*us/1e6:.2f}s  us/sample={us:.0f}")

    # find nodes whose function name matches
    for want in names:
        matches = []
        for nid, n in nodes.items():
            cf = n.get('callFrame') or {}
            fn = cf.get('functionName') or ''
            if fn == want:
                matches.append(nid)
        if not matches:
            print(f"\n-- {want}: not found --")
            continue
        print(f"\n-- {want}: {len(matches)} frame(s) --")
        for nid in matches:
            n = nodes[nid]
            self_h = hit.get(nid, 0)
            # inclusive
            def walk(i):
                s = hit.get(i, 0)
                for c in children.get(i, []):
                    s += walk(c)
                return s
            incl = walk(nid)
            print(f"  self={self_h*us/1000:.0f}ms  incl={incl*us/1000:.0f}ms  {frame(n)}")
            up = stack_up(nodes, parent, nid)
            for i, s in enumerate(up):
                print(f"    {'  '*i}^ {s}")
            # top children by self
            ch = []
            for c in children.get(nid, []):
                ch.append((hit.get(c, 0), c))
            ch.sort(reverse=True)
            for h, c in ch[:8]:
                if h:
                    print(f"    child self={h*us/1000:.0f}ms  {frame(nodes[c])}")

if __name__ == '__main__':
    names = sys.argv[1].split(',') if len(sys.argv) > 1 else ['Age', 'oQ', 'clusters', 'mY', 't.flush', 't._postJson']
    paths = sys.argv[2:] or [
        r'C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\scripts\bench-output\cpuprof-x64-20260927-001940\startup.cpuprofile',
        r'C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\scripts\bench-output\cpuprof-ARM64-20260927-001929\startup.cpuprofile',
    ]
    for p in paths:
        dump_hot(p, names)
