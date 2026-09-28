#!/usr/bin/env python3
"""Analyze Chromium --trace-startup JSON for the CDP blind window (0-6s)."""
import json
import sys
from collections import defaultdict
from pathlib import Path

# Fallback paths
DEFAULT = [
    r"C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\scripts\bench-output",
]


def load_events(p):
    raw = Path(p).read_text(encoding="utf-8", errors="replace")
    raw = raw.strip()
    if not raw:
        return []
    # Either one JSON object/array, or JSONL (one event per line)
    try:
        data = json.loads(raw)
        if isinstance(data, dict):
            return data.get("traceEvents") or data.get("events") or []
        if isinstance(data, list):
            return data
    except json.JSONDecodeError:
        pass
    events = []
    for line in raw.splitlines():
        line = line.strip()
        if not line or line == ",":
            continue
        if line.startswith(","):
            line = line[1:].strip()
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return events


def analyze(p, window_ms=6000):
    events = load_events(p)
    if not events:
        print(f"{p}: no events")
        return

    # ts is microseconds
    ts_list = [e.get("ts", 0) for e in events if e.get("ts") is not None]
    if not ts_list:
        print(f"{p}: no ts")
        return
    t0 = min(ts_list)
    window_us = window_ms * 1000

    # Complete events (ph=X) with dur
    by_name = defaultdict(lambda: {"count": 0, "dur": 0.0, "max": 0.0})
    v8_scripts = []
    tasks = []
    samples = []

    for e in events:
        ts = e.get("ts")
        if ts is None:
            continue
        rel = ts - t0
        if rel > window_us:
            continue
        ph = e.get("ph")
        name = e.get("name") or ""
        dur = float(e.get("dur") or 0)

        if ph == "X" and dur > 0:
            by_name[name]["count"] += 1
            by_name[name]["dur"] += dur / 1000.0  # to ms
            by_name[name]["max"] = max(by_name[name]["max"], dur / 1000.0)
            if "EvaluateScript" in name or "v8.compile" in name.lower() or name == "V8.Compile":
                args = e.get("args") or {}
                data = args.get("data") or {}
                url = data.get("url") or data.get("fileName") or ""
                v8_scripts.append((dur / 1000.0, rel / 1000.0, name, str(url)[:80]))
            if name in ("RunTask", "ThreadController::RunTask", "TaskQueueManager::ProcessTaskFromWorkQueue"):
                tasks.append((dur / 1000.0, rel / 1000.0, name))

        # CPU profile samples
        if name in ("CpuProfile", "v8-sample", "JitCodeAdded"):
            samples.append((rel / 1000.0, name, (e.get("args") or {})))

        # Profile chunks
        if "cpu_profile" in name.lower() or name == "ProfileChunk":
            samples.append((rel / 1000.0, name, e.get("args") or {}))

    print(f"\n===== {Path(p).parent.name} / {Path(p).name} =====")
    print(f"events={len(events)}  window=0..{window_ms}ms (from first ts)")
    print(f"unique complete names in window: {len(by_name)}")

    print("\n-- TOP COMPLETE EVENTS by total dur (ms) --")
    print(f"{'total_ms':>10}  {'count':>6}  {'max_ms':>8}  name")
    top = sorted(by_name.items(), key=lambda x: -x[1]["dur"])[:30]
    for name, st in top:
        print(f"{st['dur']:10.1f}  {st['count']:6d}  {st['max']:8.1f}  {name[:70]}")

    if v8_scripts:
        print("\n-- SCRIPT EVAL / COMPILE --")
        v8_scripts.sort(reverse=True)
        for dur, rel, name, url in v8_scripts[:20]:
            print(f"  {dur:8.1f}ms  @{rel:7.1f}ms  {name}  {url}")

    if tasks:
        print("\n-- LONGEST RunTask in window --")
        tasks.sort(reverse=True)
        for dur, rel, name in tasks[:15]:
            print(f"  {dur:8.1f}ms  @{rel:7.1f}ms  {name}")

    # Highlight known hot categories
    keys = [
        "V8.Compile", "V8.CompileCode", "EvaluateScript", "FunctionCall",
        "v8.compile", "RunTask", "Resource::sendRequest", "Resource::receiveResponse",
        "ParseHTML", "ParseAuthorStyleSheet", "Layout", "UpdateLayoutTree",
        "Paint", "CompositeLayers", "majorGC", "minorGC", "BlinkGC.AtomicPhase",
        "ThreadController::RunTask", "TimerFire", "EventDispatch",
    ]
    print("\n-- FOCUS --")
    for k in keys:
        hits = [(n, st) for n, st in by_name.items() if k.lower() in n.lower()]
        if hits:
            tot = sum(st["dur"] for _, st in hits)
            print(f"  {k}: total={tot:.1f}ms  names={[n for n,_ in hits][:4]}")


def main():
    paths = sys.argv[1:]
    if not paths:
        root = Path(DEFAULT[0])
        paths = sorted(root.glob("trace-*/startup-trace.json"))[-4:]
        if not paths:
            paths = sorted(root.glob("trace-*/*.json"))[-4:]
    if not paths:
        print("no trace files found")
        return
    for p in paths:
        analyze(str(p))


if __name__ == "__main__":
    main()
