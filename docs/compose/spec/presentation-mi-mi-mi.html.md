---
feature: presentation-mi-mi-mi-html
status: delivered
updated: 2026-09-26
branch: master
commits: # uncommitted deliverable; fill when committing
---

> Workspace override: deliverable lives at `docs/compose/deck/` (user choice). No separate worktree.

# Mi-Mi-Mi 技术前瞻 HTML 演示文稿

## Report

**What was built** — 一份可直接录屏的 2 分钟多页 HTML 演示文稿（16:10 / 1600×1000），入口 `docs/compose/deck/index.html`，配套 `styles.css` + `deck.js`。15 页叙事按「厂商技术前瞻」开场（卖点与实测数字一本正经），中段反转为真实动机（小米笔记本跑小米 Agent 仍走 x64 转译 / 吸管吃圣代），后段回到严肃移植时间线、仓库真实证据、x64 vs ARM64 数据（10 次冷启动实测 T1 2.65× + 三热点分段图），收束于开源宣言与 MiMo-on-MiMo-on-Timi。全程无人声，底部字幕条 + 进度条 + 键盘/自动播放，无 CDN/网络依赖。

**Verification** — `validate_deck.py` PASS（15 页、总时长 121s、叙事关键句、禁外链）；`validate_dom.py` PASS（DOM id 与 JS 契约）；`node --check deck.js` PASS；Edge headless 对多页截图为 1600×1000 且内容互异。独立审查结论：6 项验收均 Met，无 critical。

**Journey log** — 1. 用户要求「虚假的原因」但随后澄清：前半必须像真发布会，真实原因在后段才揭——文案按澄清后的戏剧结构落地。2. 早期展示数字以用户口径为准（2.61× / Still 2.6×），仓库 bench 只作证据页；后续按用户要求把**数据页换成 bench-startup 10 次冷启动实测**（T1 2.65× + Win→Loader / Loader→T0 / engFetch 热点），证据页 engFetch 同步为 2796 vs 9161ms。口号页（卖点 2.6×、Warm Still 2.6×）仍不反写。3. HUD 初版在 stage 外导致录制画幅不完整，已移入 1600×1000 画布。4. 冒烟截图与调试脚本勿与交付物同目录，已清理；`validate_*.py` 保留为验收门禁。5. 工作区按用户指定落在 `docs/compose/deck/`，未建 `.worktrees`。

## [S1] Problem

需要一份可直接录屏成约 2 分钟视频的 HTML 多页演示文稿（16:10），用于今晚 8 点前的技术前瞻风格发布片。素材来自本仓库的 Electron → win32-arm64 移植实验与文档；叙事要求「标题一本正经、内容越来越不对劲」：先像正常厂商技术前瞻，再揭露真实动机（小米笔记本跑小米 Agent 仍走 x64 转译），最后开源并给出闭环彩蛋。全程无人声，仅靠 HTML/PPT 式动画、字幕、终端与数据页推进。

## [S2] Design

### 交付形态

- 入口：`docs/compose/deck/index.html` + 同目录 `styles.css` + `deck.js`
- 纯静态、离线、无构建步骤；浏览器打开即可按页播放
- 画布：16:10（内部逻辑分辨率 1600×1000），整页居中缩放；HUD（进度/字幕/控制）位于画布内
- 交互：
  - ← / → / Space 翻页；Home/End 首末页
  - `#p<n>` hash 直达页；URL 同步当前页
  - 自动播放：`?auto=1` 或键盘 `A` 切换；总时长约 121s
  - 进度条 + 页码角标 + 简易字幕条（每页一句）
- 录制友好：无外部字体/CDN/网络请求；动画用 CSS/JS

### 视觉语言

- 风格锚点：高端厂商技术前瞻 / Keynote 发布会 + 终端实验室质感
- 调色：背景 `#0B0D10`、纸面 `#F4F1EA`、墨色 `#E8EAED` / `#121417`、强调 `#FF6B35`、代码 `#5B8CFF`
- 字体：系统 UI 栈 + Cascadia/Consolas 等宽
- 版式：大标题展示级字号，安全边距约 72–88px；每页 1 个主信息
- 签名时刻：「But why?」停顿页 → 纸面反转「吸管吃圣代」；数据页 2.65× 实测热点图与 Warm「Still 2.6×」

### 叙事页序（2 分钟多页）

1. Cover — Mi-Mi-Mi / win32-arm64 新探索
2. Tagline — MiMo-on-MiMo-on-Timi.
5. Why Mi-Mi-Mi 总览 — 2.65× / 3.3× IPC / Native / Fewer + 证据链脚注
6. Why · 一次完整启动 — F1–F7 功能分段（bench-functional 标本）
7. Why · 三个独立大头 — A 壳 +7.9s / B bundle +6.0s / C 会话 DB +5.0s
8. Why · 三条下钻路径 — ProcMon / CPU Profile / listGlobal 已定位
4. The Experiment — Book S → Win11 ARM64 → MiMo Desktop → Electron/x64 → 💀
5. But why? — 停顿
6. Another reason — 逐句揭露 Xiaomi laptop / Xiaomi Agent / x64 emulation
7. 吸管吃圣代 — 全片唯一情绪爆点（纸面）
8. So we tried something else — Prism ❌ vs win32-arm64 Native
9. Migration timeline — 逆向 → 运行时 → 审计 → 依赖 → 构建 → 验证
10. Evidence — 真实 Prompt（会话《研究我工作在哪台计算机上》）/ boot log arch 对照 / loadEngineSessions / native 路径
11. x64 vs ARM64 — 10-run 实测分段条（T1 / Win→Loader / Loader→T0 / engFetch）+ 热点徽章 + 2.65×
12. Warm start — Still 2.6×.
13. Open — Build framework / prompts / records / workflow
14. 欢迎模仿开发.gif
15. End card — Because we couldn't accept the straw.

### 真实数据契约（来自仓库）

- 平台：Xiaomi Book S 12.4 · Snapdragon 8cx Gen 2 · Windows on ARM
- 目标产物：`output/Xiaomi MiMo ARM64/Xiaomi MiMo.exe`
- 原生依赖：`resources/native/skia.win32-arm64-msvc.node`
- 运行时：`resources/runtimes/win32-arm64/node/node.exe`
- Boot 日志对照：同 `version=26.923.232338`，`arch=x64` vs `arch=arm64`
- Bench 对照（`bench-startup.ps1 -Runs 10` 冷启动均值）：`engFetch` 2796ms（ARM64）vs 9161ms（x64）；T1 list-ready 9680 vs 25656ms（2.65×）；热点 Win→Loader +7.1s（4.5×）、Loader→T0 +4.4s（4.7×）、engFetch +6.4s（3.3×）
- 真实 Prompt 摘录：`docs/compose/deck/migration-prompts.md`（来自会话 `ses_ffe5f298357dfffeN82Wln2VmT`《研究我工作在哪台计算机上》）
- 展示数字（与 deck 一致）：卖点总览 2.65× / engFetch 3.3×；一次完整启动 F1–F6 标本（ARM64 run #10）；热点 +7.1s / +4.4s / +6.4s；数据页 **2.65× faster · T1 list-ready**（10-run）；Warm **Still 2.6×**（口号页不反写）；*10 runs, cold start, same profile.*
- 扩展 CDP 功能观测（待单次标定）：`scripts/bench-functional.ps1` + `cdp-probe.mjs` 已支持 F1–F7 / sidebar-chrome / interactive / Performance FP·FCP·DCL·load；需关闭全部 MiMo 后跑一次，把 F3/F5 换成实测。

## [S3] Out of Scope

- 不生成真正 MP4/配音/字幕烧录文件
- 不做 PPTX 版本
- 不重跑完整 benchmark
- 不修改移植产物、构建脚本或 README 主文档
- 不引入外部 CDN、网络字体、追踪脚本

## Tasks

- [x] T1: Workspace 准备 — 路径 `docs/compose/deck/`（covers: S2）
- [x] T2: 撰写并落盘 feature spec — 本文件（covers: S1; S2）
- [x] T3: 实现 `index.html` + `styles.css` + `deck.js` 15 页 16:10 — 可打开、翻页、hash、自动播放约 121s（covers: S2）
- [x] T4: 填入真实仓库证据与数据页 — 与仓库可核对（covers: S2）
- [x] T5: 验证与视觉走查 — validate 脚本 + headless 截图（covers: S2）
- [x] T6: 代码审查（独立 subagent）— 无 critical，验收 Met（covers: S1; S2）
- [x] T7: Finalize feature document — status=delivered（covers: S1; S2）
