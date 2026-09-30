from pathlib import Path
from html.parser import HTMLParser

root = Path(__file__).resolve().parent
html = (root / "index.html").read_text(encoding="utf-8")
js = (root / "deck.js").read_text(encoding="utf-8")


class Collector(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.classes = set()
        self.sections = 0
        self.in_section = False
        self.section_classes = []

    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        if "id" in d:
            self.ids.add(d["id"])
        if tag == "section":
            self.sections += 1
            self.section_classes.append(d.get("class", ""))


c = Collector()
c.feed(html)

required_ids = ["stage", "progress-bar", "hud", "progress"]
missing = [i for i in required_ids if i not in c.ids]
assert not missing, missing
# keyboard-only: no on-page slide controls; no narration bar
for banned in ["page-ind", "btn-prev", "btn-next", "btn-play", "controls", "subtitle"]:
    assert banned not in c.ids, banned
print("ids OK", sorted(c.ids))

assert c.sections == 28
print("sections", c.sections)

# every section that is not paper/end should be dark-ish default
paperish = [x for x in c.section_classes if "paper" in x]
print("paper slides", len(paperish), paperish)

# JS references only these
for name in ["stage", "progress-bar", "keydown"]:
    assert name in js, name
print("js id refs OK")

# data attributes
assert html.count("data-dur=") == 28
assert html.count("data-sub=") == 28
print("PASS runtime contract")
