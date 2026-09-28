from pathlib import Path

path = Path(__file__).resolve().parent / "index.html"
html = path.read_text(encoding="utf-8")


def replace_between(src: str, start_marker: str, end_marker: str, new_block: str) -> str:
    a = src.find(start_marker)
    if a < 0:
        raise SystemExit(f"start not found: {start_marker[:60]}")
    b = src.find(end_marker, a)
    if b < 0:
        raise SystemExit(f"end not found: {end_marker[:60]}")
    return src[:a] + new_block + src[b:]


p3 = r'''<section class="slide" data-dur="10" data-sub="为什么是 Mi-Mi-Mi？更快的启动、响应与更低开销——以下均由 CDP 与启动基准实测。">
        <header class="slide-head reveal">
          <p class="eyebrow reveal">WHY MI-MI-MI?</p>
          <h2 class="reveal d1">为什么是 Mi-Mi-Mi？</h2>
        </header>
        <div class="kpi-strip">
          <article class="block kpi reveal">
            <p class="block-kicker">COLD START</p>
            <p class="block-stat">2.65×</p>
            <p class="block-title">更快的启动</p>
            <p class="block-line">T1 list-ready · 10-run</p>
          </article>
          <article class="block kpi reveal">
            <p class="block-kicker">IPC</p>
            <p class="block-stat">3.3×</p>
            <p class="block-title">更快的响应</p>
            <p class="block-line">engFetch · 会话就绪</p>
          </article>
          <article class="block kpi reveal">
            <p class="block-kicker">RUNTIME</p>
            <p class="block-stat">Native</p>
            <p class="block-title">更低运行开销</p>
            <p class="block-line">ARM64 · fewer cycles</p>
          </article>
          <article class="block kpi reveal">
            <p class="block-kicker">POWER</p>
            <p class="block-stat">Fewer</p>
            <p class="block-title">理论上更省电</p>
            <p class="block-line">unnecessary instructions</p>
          </article>
        </div>
        <p class="footnote reveal">证据链：功能分段 · 10 次冷启动 · CDP 里程碑 + engine 日志。下三页展开。</p>
        <div class="corner br reveal rv-fade">03 / 18</div>
      </section>

      '''

p4 = r'''<section class="slide" data-dur="14" data-sub="完整观测一次启动：F1–F6 功能分段。最大单点是 engFetch 一次 HTTP。">
        <header class="slide-head reveal">
          <p class="eyebrow reveal">WHY · ONE STARTUP</p>
          <h2 class="reveal d1">一次完整启动，功能逐段计时</h2>
        </header>
        <div class="milestone-track">
          <div class="track-line reveal"></div>
          <div class="milestone-grid">
            <article class="block ms reveal">
              <span class="ms-id">F1</span>
              <p class="block-title">窗体</p>
              <p class="block-stat sm">6.5s / 7.9s</p>
              <p class="block-line">MainWindowTitle</p>
            </article>
            <article class="block ms reveal">
              <span class="ms-id">F2</span>
              <p class="block-title">启动 Logo</p>
              <p class="block-stat sm">9.8s / 19.2s</p>
              <p class="block-line">Win→Logo +3.3 vs +11.2</p>
            </article>
            <article class="block ms reveal">
              <span class="ms-id">F3</span>
              <p class="block-title">侧栏骨架</p>
              <p class="block-stat sm">10.6s / 26.0s</p>
              <p class="block-line">Logo→侧栏 +0.8 vs +6.8</p>
            </article>
            <article class="block ms reveal">
              <span class="ms-id">F4</span>
              <p class="block-title">主界面可交互</p>
              <p class="block-stat sm">10.7s / 26.0s</p>
              <p class="block-line">FCP 4.7s vs 15.7s</p>
            </article>
            <article class="block ms hot reveal">
              <span class="ms-id">F5</span>
              <p class="block-title">会话数据</p>
              <p class="block-stat sm">13.1s / 30.7s</p>
              <p class="block-line"><strong>engFetch 3.07s vs 10.95s</strong></p>
            </article>
            <article class="block ms reveal">
              <span class="ms-id">F6</span>
              <p class="block-title">项目列表</p>
              <p class="block-stat sm">13.3s / 31.2s</p>
              <p class="block-line">子行 ≥3 稳定</p>
            </article>
          </div>
        </div>
        <p class="footnote reveal">来源：bench-functional summary.md · ARM64-20260926-225827 / x64-20260926-225842 · 冷启动 · 18 会话档案。</p>
        <div class="corner br reveal rv-fade">04 / 18</div>
      </section>

      '''

p5 = r'''<section class="slide" data-dur="14" data-sub="三个独立大头：A 壳冷启 +7.9s、B 主 bundle +6.0s、C 会话 DB +5.0s。">
        <header class="slide-head reveal">
          <p class="eyebrow reveal">WHY · THREE BOTTLENECKS</p>
          <h2 class="reveal d1">三个独立大头，不是同一个调用</h2>
        </header>
        <div class="waterfall">
          <div class="wf-row reveal">
            <div class="wf-label">
              <span class="wf-tag">A</span>
              <div>
                <p class="block-title">壳冷启</p>
                <p class="block-line">spawn · sandbox · GPU · asar</p>
              </div>
            </div>
            <div class="wf-bar-wrap"><div class="wf-bar" style="--wf:79%"></div></div>
            <div class="wf-delta">+7.9s</div>
          </div>
          <div class="wf-row reveal">
            <div class="wf-label">
              <span class="wf-tag">B</span>
              <div>
                <p class="block-title">主 bundle</p>
                <p class="block-line">Age localStorage + APM oQ</p>
              </div>
            </div>
            <div class="wf-bar-wrap"><div class="wf-bar accent" style="--wf:60%"></div></div>
            <div class="wf-delta">+6.0s</div>
          </div>
          <div class="wf-row reveal">
            <div class="wf-label">
              <span class="wf-tag">C</span>
              <div>
                <p class="block-title">会话 DB</p>
                <p class="block-line">listGlobal SQL + 187KB JSON</p>
              </div>
            </div>
            <div class="wf-bar-wrap"><div class="wf-bar" style="--wf:50%"></div></div>
            <div class="wf-delta">+5.0s</div>
          </div>
          <div class="wf-total reveal">
            <div class="block total-block">
              <p class="block-kicker">TOTAL T1 GAP</p>
              <p class="block-stat">+17.8s</p>
              <p class="block-line">13.3s vs 31.2s · 2.3× · 窗体本身只差 1.2×</p>
            </div>
          </div>
        </div>
        <p class="footnote reveal">次级：app:// 静态 SVG 845ms vs 213ms（4×）、wasm 322ms vs 49ms。首绘被 A/B 拖住（FCP 4.7s vs 15.7s）。</p>
        <div class="corner br reveal rv-fade">05 / 18</div>
      </section>

      '''

p6 = r'''<section class="slide" data-dur="14" data-sub="B 段 CPU profile：Age 是 8 次 localStorage.removeItem，oQ 是 APM 遥测序列化。">
        <header class="slide-head reveal">
          <p class="eyebrow reveal">WHY · HOT FUNCTIONS</p>
          <h2 class="reveal d1">B 段热点函数，已钉到源码</h2>
        </header>
        <div class="hot-layout">
          <article class="block hero reveal">
            <p class="block-kicker">HERO · HOT FUNCTION</p>
            <h3 class="block-title">Age · localStorage</h3>
            <p class="block-stat">2685ms</p>
            <ul class="block-list">
              <li>x64 self-time 26%</li>
              <li>8× removeItem 清旧主题键</li>
              <li>ARM64 仅 1ms · <strong>~335ms/次</strong></li>
            </ul>
            <p class="block-foot">同步 localStorage 在 x64 模拟层 = sync IPC</p>
          </article>
          <div class="hot-side">
            <article class="block reveal">
              <p class="block-kicker">APM</p>
              <h3 class="block-title">oQ · 遥测</h3>
              <p class="block-stat sm">1255ms</p>
              <p class="block-line">flush→sendEvents→_postJson</p>
            </article>
            <article class="block reveal">
              <p class="block-kicker">REACT</p>
              <h3 class="block-title">clusters</h3>
              <p class="block-stat sm">185ms</p>
              <p class="block-line">正常 3× · 不是主因</p>
            </article>
            <article class="block reveal">
              <p class="block-kicker">SAMPLE</p>
              <h3 class="block-title">idle 占比</h3>
              <p class="block-stat sm">81%→34%</p>
              <p class="block-line">x64 在烧 CPU</p>
            </article>
          </div>
        </div>
        <p class="footnote reveal">来源：cdp Profiler · cpuprof-ARM64-001929 / x64-001940 · index-C2vAeNdg.js:184。</p>
        <div class="corner br reveal rv-fade">06 / 18</div>
      </section>

      '''


def swap_section(html: str, page_num: int, new_section: str) -> str:
    """Replace the section whose corner says 'NN / 18'."""
    # find the section that contains the page marker
    marker = f">{page_num:02d} / 18<"
    idx = html.find(marker)
    if idx < 0:
        raise SystemExit(f"marker not found for page {page_num}")
    # section start: walk back to last <section class="slide
    start = html.rfind('<section class="slide', 0, idx)
    end = html.find("</section>", idx)
    if start < 0 or end < 0:
        raise SystemExit(f"section bounds not found p{page_num}")
    end += len("</section>")
    # keep a trailing newline + spaces like original if present
    tail = end
    while tail < len(html) and html[tail] in "\r\n ":
        if html[tail] == "\n":
            tail += 1
            break
        tail += 1
    return html[:start] + new_section.rstrip() + "\n\n      " + html[tail:]


html = swap_section(html, 3, p3)
html = swap_section(html, 4, p4)
html = swap_section(html, 5, p5)
html = swap_section(html, 6, p6)

path.write_text(html, encoding="utf-8")
print("P3-P6 rewritten")
print("blocks", html.count('class="block'))
print("kpi-strip", html.count("kpi-strip"))
print("waterfall", html.count("waterfall"))
print("hot-layout", html.count("hot-layout"))
print("milestone-track", html.count("milestone-track"))
