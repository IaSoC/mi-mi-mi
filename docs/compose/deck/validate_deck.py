from pathlib import Path
import re

root = Path(__file__).resolve().parent
html = (root / "index.html").read_text(encoding="utf-8")
css = (root / "styles.css").read_text(encoding="utf-8")
js = (root / "deck.js").read_text(encoding="utf-8")

assert "styles.css" in html and "deck.js" in html
assert "http://" not in html
# offline deck: https only allowed for the project GitHub repo link on P28
for u in re.findall(r'https://[^"\s>]+', html):
    assert u == "https://github.com/IaSoC/mi-mi-mi", u
assert "cdn" not in html.lower() and "fonts.googleapis" not in html
assert "github.com/IaSoC/mi-mi-mi" in html

slides = html.count('<section class="slide')
print("slides", slides)
durs = [int(x) for x in re.findall(r'data-dur="(\d+)"', html)]
print("durations", durs, "total_s", sum(durs))
assert slides == 29, slides
assert 110 <= sum(durs) <= 300  # user will finalize duration later

for needle in [
    "Mi-Mi-Mi",
    "win32-arm64",
    "But why?",
    "sundae",
    "2.65",
    "WoA",
    "To Dear Xiaomi",
    "Still 2.6",
    "engFetch",
    "Age · localStorage",
    "2685ms",
    "kpi-strip",
    "dual-track",
    "lane arm",
    "lane x64",
    "waterfall",
    "hot-layout",
    'class="block',
    "欢迎模仿开发",
    "MiMo-on-MiMo-on-Timi",
    "Prism",
    "loadEngineSessions",
    "arch=arm64",
    "吸管吃圣代",
    # restored gags from the original brief
    "我无法理解",
    "小米的",
    "Windows</em> 客户端",
    "为什么还要转译",
    "💀",
    "这甚至已经超出彩蛋的范畴",
    "精神状态驱动的工程项目",
    "We believe native ARM64",
    # P17 market-share data (amendment 2026-09-27)
    "WoA AI 笔记本渗透率",
    "Arm 架构 PC 出货占比",
    "原生 Arm 应用覆盖",
    # P18 device page
    "device-grid",
    "device-card",
    "主航道上的机器",
    "Snapdragon X Elite",
    "assets/",
    # line-chart pages (p17-p19) + developer toolchain timeline (p20)
    "line-chart",
    "1.4%",
    "Counterpoint 2027E",
    "total user minutes",
    "亿欧智库",
    "单点不足以连线",
    "Developer infrastructure",
    "windows-11-arm",
    "windows-11-vs2026-arm",
    "Arm64 Visual Studio",
    "可寻址基数",
    "移植回报",
    # P23-P26 port technique inserts
    "路径不变",
    "内容换芯",
    "0xAA64",
    "app.asar.unpacked",
    "单目标 compose",
    "43/45",
    "PE = ARM64",
    "同长替换",
    "SURGICAL PATCH",
    "PATH DISGUISE",
    "ASAR BYPASS",
]:
    assert needle in html, needle

# local assets only: every referenced file exists, no remote refs
asset_srcs = re.findall(r'src="([^"]+)"', html)
assert asset_srcs, "expected local images"
for src in asset_srcs:
    assert not src.startswith(("http://", "https://", "//")), src
    assert (root / src).is_file(), src
print("assets", len(asset_srcs), "OK")

# page corners + hud all say /25
assert html.count(" / 29") == 30, html.count(" / 29")  # 29 corners + page-ind

# palette: MiMo official tokens present, legacy dark palette gone
for token in ["#f9f6f3", "#1d0601", "#ff6700", "#f3eee8", "#e8e2db", "#ff9a57", "#d6cec4"]:
    assert token in css, token
for legacy in ["#0b0d10", "#ff6b35", "#e8eaed", "#f4f1ea", "#5b8cff", "#050607", "#0a1020"]:
    assert legacy not in css, "css:" + legacy
    assert legacy not in html, "html:" + legacy
assert ".slide.theater" in css

print("narrative beats OK")
print("css_bytes", len(css), "js_bytes", len(js))

# JS syntax-ish checks
assert "function show" in js or "function show(" in js or "show(" in js
assert "setAuto" in js and "keydown" in js
assert "--w:" in css or "--w:" in html or "var(--w" in css
print("controls OK")
print("PASS")
