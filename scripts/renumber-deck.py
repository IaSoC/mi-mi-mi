"""Renumber deck page corners / comments sequentially to a target total.

Usage: python scripts/renumber-deck.py [--total 25] [--dry]
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HTML = ROOT / "docs" / "compose" / "deck" / "index.html"

total = 25
if "--total" in sys.argv:
    total = int(sys.argv[sys.argv.index("--total") + 1])
dry = "--dry" in sys.argv

text = HTML.read_text(encoding="utf-8")

# 1) page corners: sequential "NN / X" occurrences -> "NN / total"
counter = {"n": 0}


def corner_sub(m):
    counter["n"] += 1
    return f'{counter["n"]:02d} / {total}'


def corner_repl(m):
    counter["n"] += 1
    return f'{m.group(1)}{counter["n"]:02d} / {total}'


text2 = re.sub(r'(class="corner[^"]*">)\d{2} / \d+', corner_repl, text)
corners = counter["n"]

# 2) HUD indicator (optional; keyboard-only deck has none)
text2, ind = re.subn(
    r'(<span id="page-ind">)\d+ / \d+(</span>)',
    rf"\g<1>1 / {total}\g<2>",
    text2,
)

# 3) section comments: <!-- N Name -->
cc = {"n": 0}


def comment_sub(m):
    cc["n"] += 1
    return f"<!-- {cc['n']} {m.group(1)} -->"


text2 = re.sub(r"<!-- \d+ ([^>]*?) -->", comment_sub, text2)

print(f"corners={corners} page-ind={ind} comments={cc['n']}")
assert corners == total, f"corners {corners} != {total}"
assert ind in (0, 1), ind
assert cc["n"] == total, f"comments {cc['n']} != {total}"

# no stale foreign totals in corners (e.g. " / 21" when total is 25)
stale = re.findall(rf"\d{{2}} / (?!{total}\b)\d+", text2)
assert not stale, f"stale corners: {stale[:5]}"

if dry:
    print("DRY: not writing")
else:
    HTML.write_text(text2, encoding="utf-8")
    print("written", HTML)
