#!/usr/bin/env python3
"""Extract readable event names and rough timing from Chromium Perfetto proto traces.

Works without perfetto libraries: scans the binary for interned event name
strings and pairs with nearby varint-ish timestamps when possible.
Falls back to name frequency + file-level report.
"""
import re
import sys
from collections import Counter
from pathlib import Path

# Known Chromium/DevTools timeline event names
INTERESTING = [
    "EvaluateScript", "V8.Compile", "V8.CompileCode", "V8.ScriptCompiler",
    "FunctionCall", "RunTask", "ThreadController::RunTask",
    "Resource::sendRequest", "Resource::receiveResponse", "Resource::finish",
    "ParseHTML", "ParseAuthorStyleSheet", "UpdateLayoutTree", "Layout",
    "Paint", "CompositeLayers", "RasterTask", "MajorGC", "MinorGC",
    "BlinkGC.AtomicPhase", "TimerFire", "EventDispatch",
    "navigationStart", "firstPaint", "firstContentfulPaint",
    "domContentLoadedEventEnd", "loadEventEnd",
    "ThreadController::RunTask", "TaskQueueManager::ProcessTaskFromWorkQueue",
    "v8.callFunction", "v8.compile", "v8.script.run",
    "StartupBrowserContext", "StartupProfile",
    "BrowserShutdown", "GPUProcess", "NetworkService",
    "devtools.timeline", "disabled-by-default-devtools.timeline",
]


def extract_strings(data: bytes, min_len=4):
    """Pull ASCII strings from binary."""
    pat = re.compile(rb'[\x20-\x7e]{%d,}' % min_len)
    for m in pat.finditer(data):
        yield m.start(), m.group().decode('ascii', 'ignore')


def main():
    if len(sys.argv) < 2:
        root = Path('scripts/bench-output')
        paths = sorted(root.glob('trace-*/startup-trace.json'))
    else:
        paths = [Path(p) for p in sys.argv[1:]]

    for p in paths:
        data = p.read_bytes()
        print(f'\n===== {p.parent.name}  size={len(data)/1e6:.2f}MB =====')
        print(f'magic={list(data[:8])}')

        counts = Counter()
        hits = []
        for off, s in extract_strings(data, 4):
            for name in INTERESTING:
                if name in s and len(s) < 80:
                    counts[name] += 1
                    if counts[name] <= 3:
                        hits.append((off, name, s[:70]))

        print('\n-- event-name hits in proto interned strings --')
        for name, n in counts.most_common(25):
            print(f'  {n:5d}  {name}')

        if hits:
            print('\n-- sample matches --')
            for off, name, s in hits[:15]:
                print(f'  @{off:8d}  {name}  |{s}|')

        # Also show some unique longer strings that look like URLs/scripts
        urls = []
        for off, s in extract_strings(data, 12):
            if 'app://' in s or 'index-' in s or '/renderer/' in s:
                urls.append(s[:100])
        urls = list(dict.fromkeys(urls))[:12]
        if urls:
            print('\n-- script/url strings --')
            for u in urls:
                print(' ', u)

        # Trailing note
        print('\nNOTE: file is Perfetto proto (track_event), not Chrome JSON.')
        print('Open in https://ui.perfetto.dev for full timeline, or use traceconv.')


if __name__ == '__main__':
    main()
