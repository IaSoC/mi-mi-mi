#!/usr/bin/env python3
"""Reorder deck slides and insert WoA + To Xiaomi slides after But why."""
from pathlib import Path
import re

p = Path(r"C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\docs\compose\deck\index.html")
html = p.read_text(encoding="utf-8")

parts = re.split(r'(\n\s*<!--\s*\d+\s+[^>]+-->\n)', html)
head = parts[0]
blocks = {}
i = 1
while i < len(parts):
    comment = parts[i]
    body = parts[i + 1] if i + 1 < len(parts) else ""
    name = re.search(r'<!--\s*\d+\s+([^>]+)-->', comment)
    key = name.group(1).strip() if name else f"blk{len(blocks)}"
    blocks[key] = {"comment": comment, "body": body}
    i += 2

WOA = '''
      <!-- 16 WoA status -->
      <section class="slide" data-dur="14" data-sub="Windows on ARM 正进入专业计算：ThinkPad T14s Gen 6 等机型已量产，专业本形态正在扩大。">
        <header class="slide-head">
          <p class="eyebrow">WINDOWS ON ARM</p>
          <h2>WoA 正在进入专业计算</h2>
        </header>
        <div class="benefit-grid">
          <article class="card reveal">
            <h3>专业本已上路</h3>
            <p class="stat">T14s</p>
            <p class="muted">ThinkPad T14s Gen 6 等<br />商务本采用 ARM64 SoC</p>
          </article>
          <article class="card reveal d1">
            <h3>形态在扩大</h3>
            <p class="stat">WoA</p>
            <p class="muted">Copilot+ PC 持续扩张<br />Surface / OEM 多线跟进</p>
          </article>
          <article class="card reveal d2">
            <h3>问题已变了</h3>
            <p class="stat">≠ 能跑</p>
            <p class="muted">x64 转译「能跑」<br />专业应用要「原生核路径」</p>
          </article>
          <article class="card reveal d3">
            <h3>MiMo 的位置</h3>
            <p class="stat">缺环</p>
            <p class="muted">号称专业全能桌面 AI<br />WoA 原生应是故事一部分</p>
          </article>
        </div>
        <p class="footnote reveal d4">口径引自 README《To Dear Xiaomi Corporation》与仓库 Why Windows on ARM。若需 2026 最新机型/兼容矩阵，请提供可核对来源后补入。</p>
        <div class="corner br">16 / 18</div>
      </section>
'''

LETTER = '''
      <!-- 17 To Xiaomi -->
      <section class="slide" data-dur="16" data-sub="To Dear Xiaomi Corporation：不是你要求我做，只是我想知道这有多难。现在轮到你们了。">
        <header class="slide-head">
          <p class="eyebrow">TO XIAOMI CORPORATION</p>
          <h2>I did it. Now it\\'s your turn.</h2>
        </header>
        <ul class="timeline">
          <li class="reveal">
            <span class="tl-i">01</span>
            <span class="tl-t">你们自己的广告</span>
            <span class="tl-d">「面向专业人士的全能 AI 桌面应用」<br />办公 / 设计 / 编程 / 多模态创作</span>
          </li>
          <li class="reveal d1">
            <span class="tl-i">02</span>
            <span class="tl-t">专业人士用什么本？</span>
            <span class="tl-d">ThinkPad——越来越多是 ARM64<br />WoA 已进入专业计算</span>
          </li>
          <li class="reveal d2">
            <span class="tl-i">03</span>
            <span class="tl-t">我恰好有一台 Book S</span>
            <span class="tl-d">ARM64 Electron + 架构依赖处理<br />后市场二进制嫁接，原生跑通</span>
          </li>
          <li class="reveal d3">
            <span class="tl-i">04</span>
            <span class="tl-t">不是被要求的</span>
            <span class="tl-d">没有源码，没有官方环境<br />只是想知道：「到底有多难？」</span>
          </li>
        </ul>
        <p class="footnote reveal d4">Now it\\'s your turn. — README《To Dear Xiaomi Corporation》</p>
        <div class="corner br">17 / 18</div>
      </section>
'''

order = [
    "Cover",
    "Tagline",
    "Why",
    "Why one startup",
    "Why hotspots",
    "Hot functions",
    "Hot fn roles",
    "The Experiment (expanded)",
    "Tried something else",
    "Migration timeline",
    "Process evidence",
    "Data",
    "Warm",
    "But why",
    "Another reason",
    "Sundae",
    # insert WOA + LETTER after Sundae
    "Open",
    "gif",
    "End",
]

# Verify all keys exist
missing = [k for k in order if k not in blocks]
if missing:
    raise SystemExit(f"missing keys: {missing}")

out = [head]
idx = 0
total_placeholder = "18"
for key in order:
    idx += 1
    b = blocks[key]
    # renumber comment
    comment = re.sub(r'<!--\s*\d+\s+', f'<!-- {idx} ', b["comment"])
    # renumber corner in body
    body = re.sub(
        r'(class="corner[^"]*">\s*)\d+\s*/\s*\d+',
        lambda m: f"{m.group(1)}{idx:02d} / {total_placeholder}",
        b["body"],
        count=1,
    )
    out.append(comment)
    out.append(body)
    if key == "Sundae":
        # insert new slides with following numbers
        for extra in (WOA, LETTER):
            idx += 1
            extra = re.sub(r'<!--\s*\d+\s+', f'<!-- {idx} ', extra, count=1)
            extra = re.sub(
                r'(class="corner[^"]*">\s*)\d+\s*/\s*\d+',
                lambda m: f"{m.group(1)}{idx:02d} / {total_placeholder}",
                extra,
                count=1,
            )
            out.append(extra)

new = "".join(out)
# fix total if needed
final_count = new.count('<section class="slide')
print("slide count", final_count)
new = new.replace("/ 18", f"/ {final_count:02d}").replace(f"16 / {final_count:02d}", f"16 / {final_count:02d}")
# page-ind (keyboard-only deck has none; regex is a no-op then)
new = re.sub(r'id="page-ind">\s*\d+\s*/\s*\d+', f'id="page-ind">1 / {final_count:02d}', new)
# data-dur total ok
p.write_text(new, encoding="utf-8")
print("corners", re.findall(r'corner[^>]*>\s*(\d+ / \d+)', new))
print("subs", re.findall(r'data-sub="([^"]{0,40})', new))
