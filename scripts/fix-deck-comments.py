"""Repair section comments in index.html that lost their closing '-->'.

A previous renumber run rewrote `<!-- N Name -->` as `<!-- N Name` (terminator
dropped), which made HTMLParser treat the rest of the file as comment text.
This appends the missing terminator on any `<!-- <digit> ...` line lacking it.
"""
import re
from pathlib import Path

HTML = Path(__file__).resolve().parent.parent / "docs" / "compose" / "deck" / "index.html"

text = HTML.read_text(encoding="utf-8")
lines = text.split("\n")
fixed = 0
out = []
for line in lines:
    m = re.match(r"^(\s*<!-- \d+ [^\n]*?)(\s*-->)?\s*$", line)
    if m and "-->" not in line:
        out.append(m.group(1) + " -->")
        fixed += 1
    else:
        out.append(line)
new = "\n".join(out)
print("fixed", fixed)
assert fixed > 0
assert new.count("<!--") == new.count("-->"), (
    new.count("<!--"),
    new.count("-->"),
)
HTML.write_text(new, encoding="utf-8")
print("written")
