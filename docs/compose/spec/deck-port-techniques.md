---
feature: deck-port-techniques
status: delivered
updated: 2026-09-27
branch: master
commits: ca0549f..uncommitted
---

# Deck 插页：改造特点 × 单目标 Compose

## Report

**What was built** — 在 `docs/compose/deck/index.html` 的 P22 与开源页之间插入 4 页技术插页，总页数 25 → 29。首版为 P11 式双 `.term` 代码墙；**改版后四页异构图示**（用户要求不要求同构）：N1/N2 用 `.path-compare` 路径对照，N3 用 `.stage-rail` 七阶段 + `.kpi-strip.cols-3`（T1–T10 / 43/45 / 2.65×，素材来自会话「研究我工作在哪台计算机上」），N4 用 `.open-list` 2×2 卡片（WNe 同长、绑定写死、wheel 换芯、载荷不动）。页码重编号至 `/29`；三门禁断言同步。

**Verification** — `validate_deck.py` PASS（slides 29 / total_s 300 / assets 11 OK）；`validate_dom.py` PASS（sections 29）；`validate_order.py` PASS（0/29 failing）；CSS 括号 422/422；`node --check deck.js` PASS。改版后 Edge headless 截图 p23–p26 + System.Drawing 色样：path-compare 绿框/墨字、stage-chip 橙描边、open-list 卡片均落盘。首版独立审查 verdict **pass**（六阶段→七阶段、2.6×→2.65× 已修）。

**Journey log** — 1. 用户点名 N1（「保留 asar 寻找的绝对路径，更换里面的 pe」），并把原拟「只换壳」换成「单目标 compose 能力」；素材用 `talk_to_session` 向会话「研究我工作在哪台计算机上」要结构化摘要，比 FTS memory 更完整。2. `renumber-deck.py` 的 stale-corner 正则会把正文里的 `43 / 45` 误判为页码——写成 `43/45`（无空格）绕开，勿改脚本正则伤及注释。3. 审查 major 是计数口径：compose 契约是 **七阶段**（含 Workspace），文案写「六阶段」会被台下数出来；加速比上台用实测 **2.65×**（T1 list-ready），2.6× 留给 Warm 口号。4. 总时长贴死门禁上限 300s（新页 9+9+11+9），再长就得从旧页抠秒；旧基线 259s 已漂到 262s，以 `validate_deck` 实测为准。5. 项目惯例在此仓库是 **master 原地改 deck**（既有 spec 均 `branch: master`，deck 未入库），未开 worktree。

## [S1] Problem

PPT 在 P22 与 P23 开源页之间缺少「怎么做到的」：改造手法与 Agent 单目标 compose 能力都未上台。观众听得到结论，看不到手术台。

## [S2] Design

在 P22 与 P23 之间插入 **4 页技术插页**，总页数 25 → 29。**四页不要求同构**（用户拍板），用图示替代连排深色 term 代码墙。

### 插页清单（按放映顺序）

| 新页 | 特点 | 版式 | 证据锚点 |
|------|------|------|----------|
| N1 | 路径不变，内容换芯 | `.path-compare` 左右对照 | asar/JS 仍找 `*-x64`；PE Machine 0xAA64 |
| N2 | 绝对路径穿透 asar | `.path-compare` 相对 vs 绝对 | canvas js-binding 补丁 |
| N3 | 单目标 compose 能力 | `.stage-rail` + `.kpi-strip.cols-3` | T1–T10 全勾；43/45 ARM64；2.65× |
| N4 | 同长替换 · 写死路径 | `.open-list` 2×2 卡片 | WNe / onnxruntime / wheel / payload |

N1 为用户点名（「保留 asar 寻找的绝对路径，更换里面的 PE」）。N3 替换原拟「只换壳」：用户指定展示 **Agent 对单目标的 compose 能力**，素材来自会话「研究我工作在哪台计算机上」的 Grill→Finalize 全流程。

### 版式契约

- 每页：`header.slide-head`（eyebrow + h2）+ 主体 + `p.footnote` + `div.corner.br`
- N3：`.stage-rail`（Grill→Finalize 七 chip）+ 三 KPI 块 + `.belief` 金句
- `data-dur`：N1=9、N2=9、N3=11、N4=9（合计 38s）；总时长 **300s**（门禁上限）
- `data-sub`：每页一句旁白，中文，说清对照关系
- 动画：`.reveal` / `.rv-l` / `.rv-pop` / `.dN`，顺序契约由 `validate_order` 守门
- 页码：`scripts/renumber-deck.py --total 29` 全量重编号（角标 + page-ind + 注释）
- 门禁：`validate_deck.py` slides/needles、`validate_dom.py` sections/data-dur/data-sub 同步 29
- 新增 CSS：`.stage-rail` / `.stage-chip` / `.stage-sep` / `.kpi-strip.cols-3`

### N3 文案锚（来自会话「研究我工作在哪台计算机上」）

- 单目标：Post-Market 下 Xiaomi MiMo Desktop (Electron 41.7.2) x64 → 原生 ARM64，纯二进制嫁接
- 阶段：Grill → Workspace → Spec → Implement → Verify → Review → Finalize（七阶段）
- 证据：`docs/compose/spec/electron-arm64-port.md` T1–T10 全勾；43/45 PE ARM64 (95.6%)；bench-startup 冷启动 2.65×（T1 list-ready）；瓶颈 = 模拟层 V8 非渲染；portkit 四步可复现
- Slide 短句：`Post-Market binary grafting: x64 → ARM64, no source, no vendor toolchain.`

## [S3] Out of Scope

- 不改 P22 / P23 原有文案与布局
- 不引入新图片资产
- 不重排 P1–P22 既有叙事
- 不把 Journey Log / 完整 spec 搬上台

## Tasks

- [x] T1: 写入 4 页插页 HTML（P22 与 P23 之间）— acceptance: 4 个 `section.slide` 含上述标题与双 term 对照（covers: S2）
- [x] T2: 页码 25→29 重编号 — acceptance: 角标 29 处 `NN / 29`、page-ind `1 / 29`、注释 1–29（covers: S2; depends: T1）
- [x] T3: 同步三门禁并跑通 — acceptance: validate_deck / validate_dom / validate_order 全 PASS，总时长 ≤300s（covers: S2; depends: T2）
