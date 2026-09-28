from pathlib import Path

path = Path(__file__).resolve().parent / "index.html"
html = path.read_text(encoding="utf-8")

start = html.find('<section class="slide punchline"')
if start < 0:
    raise SystemExit("punchline section not found")
end = html.find("</section>", start) + len("</section>")

new_p2 = r'''<section class="slide punchline" data-dur="8" data-sub="MiMo-on-MiMo-on-Timi. 一个词一个词来。">
        <div class="center">
          <p class="eyebrow reveal">SETUP · NOT A PRESS RELEASE</p>
          <h2 class="joke-line">递归栈，自行体会。</h2>

          <div class="word-stage" aria-label="MiMo on MiMo on Timi">
            <div class="word-unit">
              <div class="word-art photo">
                <img src="assets/mimo-logo.png" alt="MiMo" width="88" height="88" />
              </div>
              <p class="word-text">MiMo</p>
              <p class="word-cap">model</p>
            </div>

            <div class="word-op">on</div>

            <div class="word-unit">
              <div class="word-art photo">
                <img src="assets/mimo-icon-win.png" alt="MiMo Desktop" width="88" height="88" />
              </div>
              <p class="word-text">MiMo</p>
              <p class="word-cap">Desktop · agent</p>
            </div>

            <div class="word-op">on</div>

            <div class="word-unit">
              <div class="word-art photo wide">
                <img src="assets/xiaomi-book-s.jpg" alt="Xiaomi Book S" />
              </div>
              <p class="word-text">Timi</p>
              <p class="word-cap">Xiaomi Book S</p>
            </div>
          </div>

          <p class="punch reveal d3">MiMo-on-MiMo-on-Timi.</p>
          <p class="sub reveal d4">A closed-source Electron app, post-market ported to native Windows on ARM — by the app itself.</p>
          <p class="tiny reveal d5">Xiaomi Book S 12.4 · Snapdragon 8cx Gen 2 · Windows 11 ARM64</p>
        </div>
        <div class="corner br reveal rv-fade d6">02 / 25</div>
      </section>'''

html = html[:start] + new_p2 + html[end:]
path.write_text(html, encoding="utf-8")
print("P2 images wired")
print("mimo-logo.png" in html, "mimo-icon-win.png" in html, "xiaomi-book-s.jpg" in html)
