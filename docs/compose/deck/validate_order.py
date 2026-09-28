"""Validate in-slide animation ORDER for the Mi-Mi-Mi deck.

Models the delays the browser actually applies after the order fix:

  candidates (.reveal/.block/.wf-row/.wf-total/.track-line)
      -> inline animation-delay written by deck.js prepStagger:
         index-in-document * 0.24s, unless the HTML carries an explicit
         inline animation-delay (escape hatch, e.g. p4 footnote);
         inline style beats every stylesheet stagger rule (.dN classes,
         one-shot shorthands, block calc()s).
  helpers (.bar/.big-num/.wf-bar, lanes, legend, grid-bg)
      -> their CSS rules (calc from the parent candidate's --i, or fixed).

Contract: effective delays are non-decreasing in document order on every
slide, and the last delay still leaves room before data-dur expires.
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent
html_text = (root / "index.html").read_text(encoding="utf-8")
js_text = (root / "deck.js").read_text(encoding="utf-8")

CANDIDATE = ("reveal", "block", "wf-row", "wf-total", "track-line")
STEP = 0.24
ANIM_TAIL = 1.5   # longest entrance animation, for the data-dur headroom check


def parse_slides(text: str) -> list[str]:
    parts = re.split(r'(?=<section class="slide)', text)
    return [p for p in parts if p.startswith('<section class="slide')]


def tokens(section: str):
    """Yield (kind, tag, classes, style, text) in document order."""
    for m in re.finditer(r"<(/?)([a-zA-Z0-9]+)([^>]*)(/?)>|([^<]+)", section):
        if m.group(5) is not None:
            yield ("text", "", set(), "", m.group(5))
            continue
        closing, tag, raw, selfclose = m.group(1), m.group(2), m.group(3) or "", m.group(4)
        if tag in ("br", "img", "meta", "link", "input") or selfclose:
            continue
        cm = re.search(r'class="([^"]*)"', raw)
        sm = re.search(r'style="([^"]*)"', raw)
        cls = set(cm.group(1).split()) if cm else set()
        style = sm.group(1) if sm else ""
        yield ("close" if closing else "open", tag, cls, style, None)


def helper_delay(cls: set[str], stack: list[tuple[set[str], int]], parent_ci: int) -> float | None:
    """Fixed / calc delays for non-candidate animated helpers; None = not one."""
    if "grid-bg" in cls:
        return 0.0
    if "lane-bar" in cls:
        for anc, _ in reversed(stack):
            if "lane" in anc:
                return 0.5 if "arm" in anc else 1.65
        return None
    if "lane" in cls:
        return 0.2 if "arm" in cls else 1.35
    if "dual-legend" in cls:
        return 2.4
    if parent_ci < 0:
        return None
    if "bar" in cls and "x64" in cls:
        return round(parent_ci * STEP + 0.05, 3)
    if "bar" in cls and "arm" in cls:
        return round(parent_ci * STEP + 0.15, 3)
    if "big-num" in cls:
        return round(parent_ci * STEP + 0.15, 3)
    if "wf-bar" in cls:
        return round(parent_ci * STEP + 0.18, 3)
    return None


def analyze(section: str) -> list[dict]:
    """Animated elements in document order with their effective delay."""
    entries: list[dict] = []
    cand_stack: list[dict] = []
    tag_stack: list[tuple[set[str], int]] = []  # (classes, nearest candidate index or -1)
    depth = 0
    cand_i = 0
    in_svg = 0

    for kind, tag, cls, style, text in tokens(section):
        if kind == "text":
            if cand_stack:
                cand_stack[-1]["text"] += text
            continue
        if tag == "svg":
            in_svg += -1 if kind == "close" else 1
            continue
        if in_svg:
            continue
        if kind == "close":
            depth -= 1
            if tag_stack:
                _, ci = tag_stack.pop()
                if ci >= 0 and cand_stack and cand_stack[-1]["idx"] == ci:
                    cand_stack.pop()
            continue

        parent_ci = next((ci for _, ci in reversed(tag_stack) if ci >= 0), -1)
        is_cand = bool(cls & set(CANDIDATE))
        if is_cand:
            e = {"tag": tag, "cls": cls, "style": style, "idx": cand_i,
                 "text": "", "kind": "cand"}
            entries.append(e)
            cand_stack.append(e)
            tag_stack.append((cls, cand_i))
            cand_i += 1
            continue

        h = helper_delay(cls, tag_stack, parent_ci)
        if h is not None:
            entries.append({"tag": tag, "cls": cls, "style": "", "idx": parent_ci,
                            "text": "", "kind": "helper", "delay": h})
        tag_stack.append((cls, -1))
        depth += 1

    for e in entries:
        if e["kind"] == "cand":
            m = re.search(r"animation-delay:\s*([0-9.]+)s", e["style"])
            e["delay"] = float(m.group(1)) if m else round(e["idx"] * STEP, 3)
        e["text"] = " ".join(e["text"].split())[:38]
    return entries


def label(e: dict) -> str:
    cls = ".".join(sorted(e["cls"])[:4])
    return f"{e['tag']}.{cls} «{e['text']}»" if e["text"] else f"{e['tag']}.{cls}"


def main() -> int:
    assert "animationDelay" in js_text, "deck.js must write inline animation-delay"
    sections = parse_slides(html_text)
    assert len(sections) == 29, len(sections)

    failed = 0
    for n, sec in enumerate(sections, 1):
        dur = float(re.search(r'data-dur="(\d+)"', sec).group(1))
        entries = analyze(sec)
        if not entries:
            continue
        delays = [e["delay"] for e in entries]

        problems = []
        for a, b in zip(range(len(entries) - 1), range(1, len(entries))):
            if delays[b] + 1e-9 < delays[a]:
                problems.append(
                    f"  out of order: {delays[a]:.2f}s {label(entries[a])}"
                    f" -> {delays[b]:.2f}s {label(entries[b])}"
                )
        if max(delays) + ANIM_TAIL > dur:
            problems.append(
                f"  last delay {max(delays):.2f}s + {ANIM_TAIL}s animation"
                f" exceeds data-dur={dur}s"
            )
        mark = "!!" if problems else "  "
        print(f"{mark} p{n:>2} n={len(entries):>2} last={max(delays):.2f}s dur={dur:.0f}s")
        for p in problems:
            print(p)
        failed += bool(problems)

    print(f"\nslides failing order contract: {failed}/{len(sections)}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
