from pathlib import Path

path = Path(__file__).resolve().parent / "index.html"
html = path.read_text(encoding="utf-8")

old_start = html.find('<section class="slide" data-dur="5" data-sub="MiMo-on-MiMo-on-Timi')
if old_start < 0:
    raise SystemExit("P2 start not found")
old_end = html.find("</section>", old_start) + len("</section>")

new_p2 = r'''<section class="slide punchline" data-dur="8" data-sub="MiMo-on-MiMo-on-Timi. 一个词一个词来。">
        <div class="center">
          <p class="eyebrow reveal">SETUP · NOT A PRESS RELEASE</p>
          <h2 class="joke-line">递归栈，自行体会。</h2>

          <div class="word-stage" aria-label="MiMo on MiMo on Timi">
            <!-- word 1 -->
            <div class="word-unit">
              <div class="word-art" aria-hidden="true">
                <svg viewBox="0 0 96 96" width="88" height="88">
                  <rect x="10" y="18" width="76" height="58" rx="14" fill="#1a2230" stroke="#FF6B35" stroke-width="2.5"/>
                  <circle cx="36" cy="46" r="6" fill="#FF6B35"/>
                  <circle cx="60" cy="46" r="6" fill="#FF6B35"/>
                  <path d="M34 62c6 6 22 6 28 0" stroke="#E8EAED" stroke-width="2.5" fill="none" stroke-linecap="round"/>
                  <rect x="42" y="8" width="12" height="12" rx="3" fill="#5B8CFF"/>
                </svg>
              </div>
              <p class="word-text">MiMo</p>
              <p class="word-cap">model</p>
            </div>

            <div class="word-op">on</div>

            <!-- word 2 -->
            <div class="word-unit">
              <div class="word-art" aria-hidden="true">
                <svg viewBox="0 0 96 96" width="88" height="88">
                  <rect x="18" y="22" width="60" height="50" rx="12" fill="#243044" stroke="#5B8CFF" stroke-width="2.5"/>
                  <circle cx="48" cy="14" r="5" fill="#5B8CFF"/>
                  <rect x="46" y="8" width="4" height="8" fill="#5B8CFF"/>
                  <rect x="32" y="38" width="32" height="6" rx="3" fill="#E8EAED"/>
                  <rect x="32" y="50" width="20" height="6" rx="3" fill="#FF6B35"/>
                  <circle cx="72" cy="70" r="7" fill="#3ECF8E"/>
                </svg>
              </div>
              <p class="word-text">MiMo</p>
              <p class="word-cap">agent</p>
            </div>

            <div class="word-op">on</div>

            <!-- word 3 -->
            <div class="word-unit">
              <div class="word-art" aria-hidden="true">
                <svg viewBox="0 0 96 96" width="88" height="88">
                  <rect x="16" y="24" width="64" height="42" rx="6" fill="#1c2430" stroke="#E8EAED" stroke-width="2.5"/>
                  <rect x="22" y="30" width="52" height="30" rx="3" fill="#2a3548"/>
                  <rect x="8" y="68" width="80" height="8" rx="3" fill="#FF6B35"/>
                  <circle cx="48" cy="45" r="5" fill="#FF6B35"/>
                </svg>
              </div>
              <p class="word-text">Timi</p>
              <p class="word-cap">laptop</p>
            </div>
          </div>

          <p class="punch reveal d3">MiMo-on-MiMo-on-Timi.</p>
          <p class="sub reveal d4">A closed-source Electron app, post-market ported to native Windows on ARM — by the app itself.</p>
          <p class="tiny reveal d5">Xiaomi Book S 12.4 · Snapdragon 8cx Gen 2 · Windows 11 ARM64</p>
        </div>
        <div class="corner br reveal rv-fade d6">02 / 25</div>
      </section>'''

html = html[:old_start] + new_p2 + html[old_end:]
path.write_text(html, encoding="utf-8")
print("P2 replaced")
print("word-unit" in html, html.count("word-unit"))
