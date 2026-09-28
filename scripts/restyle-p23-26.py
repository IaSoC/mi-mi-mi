from pathlib import Path

html_path = Path(r"C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\docs\compose\deck\index.html")
text = html_path.read_text(encoding="utf-8")
start = text.index("      <!-- 23 Trick path PE -->")
end = text.index("      <!-- 27 Open -->")

new = r'''      <!-- 23 Trick path PE -->
      <section class="slide" data-dur="9" data-sub="特点一：保留 asar 解析的绝对路径，只更换路径里面的 PE。解析器看字符串，装载器看机器码。">
        <header class="slide-head reveal">
          <p class="eyebrow reveal">TRICK 01 · PATH DISGUISE</p>
          <h2 class="reveal d1">路径不变，内容换芯</h2>
        </header>
        <div class="path-compare">
          <div class="path-col reveal">
            <p class="path-label">Resolver asks for</p>
            <div class="path-box reveal rv-l">canvas-x64.node</div>
            <div class="flow-arrow reveal rv-fade">↓</div>
            <div class="path-box reveal rv-l">…/win32/x64/</div>
            <div class="flow-arrow reveal rv-fade">↓</div>
            <div class="path-box reveal rv-l">process.arch → "x64"</div>
          </div>
          <div class="path-vs reveal rv-pop d1">→</div>
          <div class="path-col reveal d2">
            <p class="path-label accent">Loader actually reads</p>
            <div class="path-box good reveal rv-l">PE 0xAA64 · ARM64</div>
            <div class="flow-arrow reveal rv-fade">↓</div>
            <div class="path-box good reveal rv-l">same path, new PE</div>
            <div class="flow-arrow reveal rv-fade">↓</div>
            <div class="path-box good reveal rv-l">asar header unchanged</div>
          </div>
        </div>
        <p class="footnote reveal d4">解析层只认路径字符串，装载层只看 PE 头。名实分离——保留 asar 寻找的路径，更换里面的二进制。</p>
        <div class="corner br reveal rv-fade d5">23 / 29</div>
      </section>

      <!-- 24 Trick asar bypass -->
      <section class="slide" data-dur="9" data-sub="特点二：相对 require 仍被 asar 虚拟 FS 劫持。改成 resourcesPath 绝对路径，native module 从真实磁盘加载。">
        <header class="slide-head reveal">
          <p class="eyebrow reveal">TRICK 02 · ASAR BYPASS</p>
          <h2 class="reveal d1">绝对路径穿透 asar</h2>
        </header>
        <div class="path-compare">
          <div class="path-col reveal">
            <p class="path-label">Relative require</p>
            <div class="path-box bad reveal rv-l">require('./skia.*.node')</div>
            <div class="flow-arrow reveal rv-fade">↓</div>
            <div class="path-box bad reveal rv-l">asar virtual FS intercepts</div>
            <div class="flow-arrow reveal rv-fade">↓</div>
            <div class="path-box bad reveal rv-l">never hits disk ✗</div>
          </div>
          <div class="path-vs reveal rv-pop d1">vs</div>
          <div class="path-col reveal d2">
            <p class="path-label accent">Absolute path</p>
            <div class="path-box good reveal rv-l">resourcesPath + unpacked</div>
            <div class="flow-arrow reveal rv-fade">↓</div>
            <div class="path-box good reveal rv-l">real filesystem</div>
            <div class="flow-arrow reveal rv-fade">↓</div>
            <div class="path-box good reveal rv-l">ARM64 .node loads ✓</div>
          </div>
        </div>
        <p class="footnote reveal d4">unpacked:true 允许改 JS，但相对 require 仍走 asar fs。把路径钉死到 app.asar.unpacked，才真正落到磁盘。</p>
        <div class="corner br reveal rv-fade d5">24 / 29</div>
      </section>

      <!-- 25 Compose capability -->
      <section class="slide" data-dur="11" data-sub="特点三：不是单点补丁，而是一场单目标 compose。Grill 到 Finalize 七阶段闭环，门禁与基准给出可核查证据。">
        <header class="slide-head reveal">
          <p class="eyebrow reveal">AGENT · COMPOSE</p>
          <h2 class="reveal d1">单目标 compose，一场走完</h2>
        </header>
        <div class="stage-rail">
          <span class="stage-chip accent reveal rv-l">Grill</span>
          <span class="stage-sep reveal rv-fade">→</span>
          <span class="stage-chip reveal rv-l d1">Workspace</span>
          <span class="stage-sep reveal rv-fade d1">→</span>
          <span class="stage-chip reveal rv-l d2">Spec</span>
          <span class="stage-sep reveal rv-fade d2">→</span>
          <span class="stage-chip reveal rv-l d3">Implement</span>
          <span class="stage-sep reveal rv-fade d3">→</span>
          <span class="stage-chip reveal rv-l d4">Verify</span>
          <span class="stage-sep reveal rv-fade d4">→</span>
          <span class="stage-chip reveal rv-l d5">Review</span>
          <span class="stage-sep reveal rv-fade d5">→</span>
          <span class="stage-chip accent reveal rv-l d5">Finalize</span>
        </div>
        <div class="kpi-strip cols-3">
          <article class="block kpi reveal">
            <p class="block-kicker">SPEC</p>
            <p class="block-stat">T1–T10</p>
            <p class="block-title">全部勾选</p>
            <p class="block-line">electron-arm64-port.md</p>
          </article>
          <article class="block kpi reveal d1">
            <p class="block-kicker">PURITY</p>
            <p class="block-stat">43/45</p>
            <p class="block-title">PE = ARM64</p>
            <p class="block-line">95.6% · 架构审计</p>
          </article>
          <article class="block kpi reveal d2">
            <p class="block-kicker">COLD START</p>
            <p class="block-stat">2.65×</p>
            <p class="block-title">更快落地</p>
            <p class="block-line">瓶颈在模拟层 V8，不是渲染</p>
          </article>
        </div>
        <p class="belief reveal d4">Post-Market binary grafting: x64 → ARM64, no source, no vendor toolchain.</p>
        <p class="footnote reveal d5">同一场对话完成迁移、验证、基准与开源整理——MiMo migrating MiMo on Timi.</p>
        <div class="corner br reveal rv-fade d5">25 / 29</div>
      </section>

      <!-- 26 Trick surgical patch -->
      <section class="slide" data-dur="9" data-sub="特点四：同长替换与写死路径。白名单插入不能改文件头长度，绑定路径写死旧名，磁盘真相已是 ARM64。">
        <header class="slide-head reveal">
          <p class="eyebrow reveal">TRICK 03 · SURGICAL PATCH</p>
          <h2 class="reveal d1">同长替换 · 写死路径</h2>
        </header>
        <ul class="open-list">
          <li class="reveal rv-l"><strong>WNe 白名单同长插入</strong><span>"win32-x64" → "win32-arm64"，不改 asar 字节长度</span></li>
          <li class="reveal rv-l d1"><strong>绑定路径写死旧名</strong><span>binding.js 仍写 win32/x64，磁盘 PE 已是 ARM64</span></li>
          <li class="reveal rv-l d2"><strong>Python wheel 换芯</strong><span>pydantic_core / jiter → win_arm64.whl，不重编译</span></li>
          <li class="reveal rv-l d3"><strong>应用载荷不动</strong><span>手术刀只动该动的字节，payload 原样保留</span></li>
        </ul>
        <p class="footnote reveal d4">同长才不撕裂 asar 头；绑定层继续说 x64，磁盘上的真相已是 ARM64。</p>
        <div class="corner br reveal rv-fade d5">26 / 29</div>
      </section>

'''

html_path.write_text(text[:start] + new + text[end:], encoding="utf-8")
print(f"replaced {end-start} chars with {len(new)} chars")
