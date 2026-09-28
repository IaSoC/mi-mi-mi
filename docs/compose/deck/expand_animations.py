"""Expand in-slide element animations across the Mi-Mi-Mi deck.

Reads index.html (UTF-8), assigns stagger indices, adds motion variants
where useful, and writes the file back.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parent
html_path = root / "index.html"
html = html_path.read_text(encoding="utf-8")

# 1) Slide heads animate
html = html.replace(
    '<header class="slide-head">',
    '<header class="slide-head reveal">',
)

# 2) Flow arrows cascade with nodes
html = html.replace(
    '<div class="flow-arrow">',
    '<div class="flow-arrow reveal rv-fade">',
)

# 3) Path columns + vs
html = html.replace(
    '<div class="path-vs">',
    '<div class="path-vs reveal rv-pop d1">',
)
html = html.replace(
    '<div class="path-box">',
    '<div class="path-box reveal rv-l">',
)
html = html.replace(
    '<div class="path-box bad">',
    '<div class="path-box bad reveal rv-l">',
)
html = html.replace(
    '<div class="path-box good">',
    '<div class="path-box good reveal rv-l">',
)

# 4) Terminals: wipe-in
html = html.replace(
    '<div class="term reveal">',
    '<div class="term reveal rv-wipe">',
)
html = html.replace(
    '<div class="term reveal d2">',
    '<div class="term reveal rv-wipe d2">',
)

# 5) Cards pop a bit more
html = html.replace(
    '<article class="card reveal">',
    '<article class="card reveal rv-pop">',
)
html = html.replace(
    '<article class="card reveal d1">',
    '<article class="card reveal rv-pop d1">',
)
html = html.replace(
    '<article class="card reveal d2">',
    '<article class="card reveal rv-pop d2">',
)
html = html.replace(
    '<article class="card reveal d3">',
    '<article class="card reveal rv-pop d3">',
)

# 6) Result card from right
html = html.replace(
    '<aside class="result-card reveal d4">',
    '<aside class="result-card reveal rv-r d4">',
)

# 7) GIF card bounce
html = html.replace(
    '<div class="gif-card reveal">',
    '<div class="gif-card reveal rv-pop">',
)

# 8) Reason lines slide from left with stagger already via d*
for n, cls in enumerate(["d1", "d2", "d3", "d4", "d5"], start=1):
    html = html.replace(
        f'<p class="reason reveal {cls}">',
        f'<p class="reason reveal rv-l {cls}">',
    )
    html = html.replace(
        f'<p class="reason big reveal {cls}">',
        f'<p class="reason big reveal rv-l {cls}">',
    )

# 9) Rules expand
html = html.replace(
    '<div class="rule reveal d1">',
    '<div class="rule reveal rv-line d1">',
)
html = html.replace(
    '<div class="rule dark reveal d3">',
    '<div class="rule dark reveal rv-line d3">',
)

# 10) Punch / mega use blur-up
html = html.replace(
    '<p class="punch reveal d2">',
    '<p class="punch reveal rv-blur d2">',
)
html = html.replace(
    '<p class="punch dark reveal d2">',
    '<p class="punch dark reveal rv-blur d2">',
)
html = html.replace(
    '<p class="punch dark reveal d4">',
    '<p class="punch dark reveal rv-blur d4">',
)
html = html.replace(
    '<h1 class="mega-soft reveal">',
    '<h1 class="mega-soft reveal rv-blur">',
)
html = html.replace(
    '<h1 class="mega reveal d1">',
    '<h1 class="mega reveal rv-z d1">',
)
html = html.replace(
    '<h1 class="mega dark reveal d1">',
    '<h1 class="mega dark reveal rv-z d1">',
)

# 11) Quote / display
html = html.replace(
    '<p class="quote-line reveal">',
    '<p class="quote-line reveal rv-z">',
)
html = html.replace(
    '<h2 class="display dark reveal d1">',
    '<h2 class="display dark reveal rv-z d1">',
)

# 12) Open list items from right-ish
html = html.replace(
    '<li class="reveal">',
    '<li class="reveal rv-l">',
)
html = html.replace(
    '<li class="reveal d1">',
    '<li class="reveal rv-l d1">',
)
html = html.replace(
    '<li class="reveal d2">',
    '<li class="reveal rv-l d2">',
)
html = html.replace(
    '<li class="reveal d3">',
    '<li class="reveal rv-l d3">',
)
html = html.replace(
    '<li class="reveal d4">',
    '<li class="reveal rv-l d4">',
)
html = html.replace(
    '<li class="reveal d5">',
    '<li class="reveal rv-l d5">',
)

# 13) Bar rows wipe
html = html.replace(
    '<div class="bar-row reveal">',
    '<div class="bar-row reveal rv-l">',
)
html = html.replace(
    '<div class="bar-row reveal d1">',
    '<div class="bar-row reveal rv-l d1">',
)
html = html.replace(
    '<div class="bar-row reveal d2">',
    '<div class="bar-row reveal rv-l d2">',
)
html = html.replace(
    '<div class="bar-row reveal d3">',
    '<div class="bar-row reveal rv-l d3">',
)

# 14) Benefit grid / timeline / evidence already use reveal — ensure header children
html = html.replace(
    '<p class="eyebrow">WHY MI-MI-MI?</p>',
    '<p class="eyebrow reveal">WHY MI-MI-MI?</p>',
)
html = html.replace(
    '<p class="eyebrow">WHY 路 ONE STARTUP</p>',
    '<p class="eyebrow reveal">WHY 路 ONE STARTUP</p>',
)
# fix common eyebrow patterns without reveal
html = re.sub(
    r'<p class="eyebrow">([^<]+)</p>',
    r'<p class="eyebrow reveal">\1</p>',
    html,
)
html = re.sub(
    r'<p class="eyebrow dark">([^<]+)</p>',
    r'<p class="eyebrow dark reveal">\1</p>',
    html,
)

# 15) Title inside headers without reveal
html = re.sub(
    r'(<header class="slide-head reveal">\s*<p class="eyebrow reveal">[^<]*</p>\s*)<h2>',
    r'\1<h2 class="reveal d1">',
    html,
)

# 16) Corner badges slight fade
html = re.sub(
    r'<div class="corner ([^"]+)">',
    r'<div class="corner \1 reveal rv-fade d5">',
    html,
)

html_path.write_text(html, encoding="utf-8")
print("patched", html_path)
print("reveal count", html.count("class=") and html.count("reveal"))
print("rv-pop", html.count("rv-pop"))
print("rv-l", html.count("rv-l"))
print("rv-wipe", html.count("rv-wipe"))
print("rv-z", html.count("rv-z"))
print("rv-blur", html.count("rv-blur"))
print("rv-line", html.count("rv-line"))
