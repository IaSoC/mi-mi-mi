---
feature: deck-restyle-mimo
status: delivered
updated: 2026-09-27
branch: master
commits: # uncommitted deliverable (docs/compose/ untracked); base ca0549f; 无新 commit，区间不适用
---

> Workspace override: 沿用既有交付目录 `docs/compose/deck/`（与 presentation-mi-mi-mi.html 相同的用户选择），不建 worktree，直接在 master 工作区修改。

# Deck 三向改版：MiMo 官方配色 · 从容动画 · 包袱补全

## Report

**What was built** — 对 `docs/compose/deck/`（16:10 HTML 演示）完成三个阶段交付。① 三向改版：配色切 MiMo 官方 V2.6 token（`#F9F6F3` 纸白 / `#1D0601` 墨 / `#FF6700` 橙，p14/15/16 暖近黑剧场页），补回五个包袱，动画改 1s 级 expo-out + 0.16–0.22s stagger。② Amendment 1：P17 市占率四数字 + 插入骁龙 X 机型页，21→22 页。③ Amendment 2：**P17 四框拆为四张内联 SVG 折线图页**（p17 渗透率 TrendForce 1.2%/3.2%/11.5%、p18 Arm PC 份额 2020–2025 逐点标机构、p19 单点 90% + 无历史数据注记、p20 五年 50% 目标路径），删原四卡页并全量重编号至 **25 页 / 259s**；机型页扩为 4 列 **7 卡**（追加 Surface Laptop Ultra / NVIDIA RTX Spark · N1X，标注未发售）。所有数据点均带机构与来源，缺失年份断线不插值，单点序列明示不成线。

**Verification** — `validate_deck.py` PASS（25 页 / 259s / 26 处 " / 25" / 新旧 needle / 资产存在性与相对路径 / 离线无外链）；`validate_dom.py` PASS（sections、data-dur、data-sub=25）；`node --check deck.js` PASS；CSS 括号 390/390。视觉验证：四张图表页与机型页 headless reduced-motion 截图 + System.Drawing 像素/ASCII 分析（Read 工具本会话持续串位，图像结论全部以像素与字符降采样为准）：各页橙色像素 bbox 与 SVG 坐标换算一致；p18「Counterpoint 2027E」与虚线分离；p20 目标标签移至虚线右侧（几何不相交）；p21 确认 4+3 七卡布局。独立审查 verdict **pass**（无 critical/major；3 项 minor——p17 预测点机构小字、p19 年份刻度位置、「未发售」字样——已全部修复并复跑门禁）。

**Journey log** — 1. 包袱找回：用户指认「包袱丢了」后用 history `get` 取回原 prompt 逐条比对；Grill 一次问齐三个决策轴。2. 批量改 CSS/HTML 禁用 PowerShell `-replace`（曾引入字面 `` `n `` 与 UTF-8 乱码），用 Python 脚本/edit 工具；重编号脚本曾因改注释丢 `-->` 让 HTMLParser 吞掉半个文件（`fix-deck-comments.py` 一次性修复），renumber 已改为锚定 `class="corner">` 防误伤正文。3. 本会话 Read 读图系统性串位（读 A 返回 B，队列回放旧图）——一切图像结论以像素统计 / ASCII 降采样复核；headless 截图必须 `--force-prefers-reduced-motion`，且 Edge 写文件在进程返回后才落盘（要轮询等待）。4. 联网调研：IAB 不可用、WebSearch 插件时有时无，主路径为 Edge headless（`websearch_edge.ps1`，**必须带正常 Edg UA 否则 Bing 结果被污染**）+ 子代理 WebFetch（百度/360 可用，DDG/Brave 被墙）；产品图取自 Bing Images `murl` / 百度 `objurl` / 官网 og:image，Bing 图片查询需加正常 UA。5. 折线图数据契约：稀疏序列（90% 单点）按用户拍板「单点 + 明示无历史」呈现，多机构序列逐点标机构不混线，目标线与预测线均虚线并在图例声明口径——「没有的数值不编造」贯穿全程。

## [S1] Problem

现有 `docs/compose/deck/index.html`（21 页）存在三个用户可见问题：

1. **动画生硬且急躁**：入场 0.55–0.85s、stagger 0.085–0.14s、位移偏大，观感匆忙。
2. **第一个 prompt 里的包袱丢失**：《整理对话与文档为HTML版本》首个 prompt（history `prt_g001a0ddae3edc002kVuU3mwph`）中的若干戏剧性笑点在多次改版中弱化或移除。
3. **配色与 MiMo 官方不一致**：现为深色发布会风（`#0B0D10` / `#FF6B35`），官方 V2.6 发布页（https://mimo.xiaomi.com/mimo-v2-6/styles.css）为暖纸白浅色体系。

## [S2] Design

### 决策（2026-09-27 用户拍板）

- 包袱：**五个全补**。
- 配色：**浅色纸面为主 + 少数深色剧场页**。
- 动画：**从容电影感**（入场 0.9–1.2s、expo-out、stagger 0.16–0.22s、位移收敛）。

### 配色契约（对齐官方 V2.6 页 `:root`）

| token | 值 | 用途 |
|---|---|---|
| `--bg` | `#F9F6F3` | 默认页底 |
| `--bg-block` | `#F3EEE8` | 卡片/代码块底 |
| `--ink` | `#1D0601` | 主文字 |
| `--ink-body` | `rgba(29,6,1,0.70)` | 正文（官方 #1D0601B2） |
| `--ink-dim` | `#888888` | 次级文字 |
| `--border` | `#E8E2DB` | 描边/分隔 |
| `--accent` | `#FF6700` | 强调（官方橙） |
| `--accent-soft` | `#FF9A57` | 次强调（官方 Flash 橙） |
| `--neutral-bar` | `#D6CEC4` | 图表中性条 |

- **默认页**：浅色纸面。原 `.slide.paper`（p16 圣代、p21 尾页）改用 `--bg-block` 层次感 + 橙色 rule，不再是唯一浅色页。
- **深色剧场页**（保留 3 页，`theme-dark` 局部类）：p14 But why? / p15 Another reason / p16 吸管吃圣代。深色页底改为暖近黑 `#17110D`（与纸白同色相族，非纯冷黑），文字 `#F4EFE9`，强调仍 `#FF6700`。
- **图表映射**：x64 条 = `--neutral-bar` 系（慢、非焦点），ARM64 条 = `--accent`（快、焦点），hot 徽章 = `--accent`，数据页大数字 = `--ink` + 橙色单位。
- 图例、KPI、终端窗、进度条、字幕条全部换 token，不允许遗留 `#ff6b35` / `#0b0d10` 等旧值（深色剧场页除外的暖近黑）。

### 包袱补全契约（5 项）

1. **p15 中文揭露序列**：reason-lines 改为逐句 —
   「我无法理解。」→「小米的笔记本。」→「小米的 Agent。」→「小米的 Windows 客户端。」→「**为什么还要转译？**」
   （保留英文 eyebrow；每句独占一拍，最后一句视觉最重。）
2. **p8 Experiment 链条 💀**：flow-stack 末端节点恢复为 `💀`（节点文案 `Electron / x64 → 💀` 结构对齐原 prompt）；原「启动 · IPC · 布局 全线加税」下沉为该节点的副文案或侧卡文案，不删除信息。
3. **MiMo 自举闭环**：p19 Open 页 footnote（或 p20 gif 页副文案）加入原话结构：
   「用 MiMo 把 MiMo 从 x64 移植到 ARM64，又用 MiMo 生成介绍它的视频——这甚至已经不是彩蛋了。」
4. **「精神状态驱动」结语**：p21 尾页在 slogan 与 punch 之间加入一行：
   「表面上是一项严肃的 portability research，实际上是一次精神状态驱动的工程项目。」
5. **反讽句**：p3 Why 页在 KPI strip 与 footnote 之间加入：
   「We believe native ARM64 can provide a better experience.」（厂商腔引用样式，为后文反转埋线。）

### 动画契约

- 入场时长：`0.55–0.85s` → **`0.9–1.2s`**；缓动统一 `cubic-bezier(0.16, 1, 0.3, 1)`（expo-out）。
- stagger：`0.085–0.14s` → **`0.16–0.22s`**（`.d1–.d8` 与 `--i` 步进同步放宽）。
- 位移收敛：translate 起始距离减到约 60%（生硬感主要来自大位移+短时长）。
- 页内节拍（reveal-lines、timeline、bars、blocks）按同一节奏体系重排；数据条 grow 1.2s。
- `data-dur` 按新节奏校验：每页入场序列播完后仍留 ≥2s 阅读停顿；**总片长不压缩**（现状 21 页合计约 223s，改版后维持约 220–245s 区间）。
  - 注：Grill 选项文案中的「135–150s」基于旧 15 页 spec（121s），已过时；21 页不可能压进 150s 而不显急躁，故以「不压缩、不赶拍」为准。
- 键盘/翻页/hash/自动播放/`window.__deck` 行为不变。

### 交付物

- 修改 `docs/compose/deck/index.html`、`styles.css`（必要时 `deck.js` 的 stagger 步进）。
- `validate_deck.py` / `validate_dom.py` 断言随新文案与新 token 同步更新。

### Amendment（2026-09-27）：P17 市占率数据 + WoA 机型新页

起点：用户要求「P17（WoA 现状页）加市占率类数据；再加一页 WoA 型号/图片」。本节为增补契约，其余章节不变。

**1. P17 数据契约（改 `index.html` p17，页码仍标 17/22）**

- 结构：保留 eyebrow `WINDOWS ON ARM · 现状` 与 h2 `WoA：能跑 ≠ 原生`；h2 下加一行 `.sub` 说明（x64 能跑但官方要 Arm-native，Copilot+ / Snapdragon X 是主航道）；**原 4 卡 `benefit-grid` 整体替换为 `kpi-strip` 4 列大数字**（避免纵向溢出）。
- 四个大数字（口径不可改写，必须带机构与年份）：

| kicker | stat | title | line |
|---|---|---|---|
| TRENDFORCE · 2025 | `1.2%` | WoA AI 笔记本渗透率 | 占整体笔记本出货 · 2029 预估 11.5% |
| ABI RESEARCH · 2025 | `13%` | Arm 架构 PC 出货占比 | 占整体 PC 出货（含苹果 Mac） |
| MICROSOFT · 2025-09 | `90%` | 原生 Arm 应用覆盖 | 占用户使用时长 |
| ARM + QUALCOMM | `50%` | 五年目标 | Windows PC 中 Arm 占一半（CEO 公开口径） |

- footnote 更新为来源清单：TrendForce（2026-06 报告，2025 值）· ABI Research（2025-01，Tom's Hardware 引述）· Microsoft Windows Blogs（2025-09）· Canalys 2024Q3 骁龙 X 出货 72 万台（占整体 PC 0.8%）。
- `data-dur` 14 → 16；不引入新图片。

**2. 新页契约：p18「骁龙 X 机型页」（插入在 p17 与原 p18 之间）**

- 头部：eyebrow `SNAPDRAGON X · 机型`，h2 主航道机型（文案实现时定，需点出「商务到创作全线覆盖」）；`data-dur="14"`；`data-sub` 描述首批骁龙 X 机型阵容。
- 主体：**6 张机型卡的网格**（新增 `.device-grid` / `.device-card` CSS，风格对齐 `.card`：白卡、`--radius`、1px 描边），每卡 = 本地图 + 产品全名 + SoC 型号 + 1 行可查证规格。
- 机型清单（调研已核对来源，规格以来源页为准）：Surface Pro 11（X1E-80-100）· ThinkPad T14s Gen 6（X Elite）· Yoga Slim 7x Gen 9（X1E-78-100）· ASUS Vivobook S 15 S5507（X Elite）· Samsung Galaxy Book4 Edge 14（X1E-80-100）· HP OmniBook X 14 / EliteBook Ultra G1q（X1E-78-100）。
- 图片：全部**下载到 `docs/compose/deck/assets/` 本地相对引用**（离线硬约束），落盘后用 Pillow 校验可解码、宽度 ≥600px、无水印；某机型找不到合格真图 → 该卡降级为纯文字/色块卡，**不得用 AI 生成图冒充真实机型产品图**。
- footnote：注明机型/规格来源为各厂商产品页与发布信息。

**3. 页码与规模契约**

- 总页数 21 → **22**：p18 及之后所有角标 `NN / 21` 改 `NN / 22` 并顺移重编号，`#page-ind` 初始值改 `1 / 22`（`deck.js` 为动态计算，不改）。
- `data-dur` 总长仍守 **110–260s**（当前 223s + 16 + 14 − 14(原 p17 14→16 计 +2) ≈ 237s，需以脚本实测为准）。
- 门禁断言同步：`validate_deck.py` `slides == 22` 且新增 needle（`1.2%`、`13%`、`90%`、`device-grid` 等实现后回填）；`validate_dom.py` `sections/data-dur/data-sub == 22`。

**4. 调研来源（本次联网核实，供 footnote 引用）**

- TrendForce：WoA AI 笔记本渗透率 2025=1.2%、2026=3.2%、2029=11.5%（占整体笔记本出货）；Arm 架构笔记本整体 2029 达 34.2%。转载源 chinaaet.com/article/3000178038、163.com/dy/article/KUJKTT750519QIKK.html。
- ABI Research：2025 年 Arm PC 约占整体 PC 出货 13%（Tom's Hardware 2025-01-05）。
- Canalys（2024Q3）：骁龙 X 系列笔记本出货 72 万台 = 整体 PC 0.8%、Windows PC <1.5%（凤凰网/芯智讯 i.ifeng.com/c/8fwa8QRzZdn）。
- Microsoft（2025-09 Windows Blogs 引述）：原生版 Arm 应用已覆盖用户使用时长 90%。

**5. Amendment 任务**

- [x] T8: P17 市占率数据 — acceptance: p17 呈现 4 个契约大数字与新 footnote，`validate_deck.py` 新 needle 全过（covers: 本节 §1; depends: T1）
- [x] T9: p18 机型新页 + assets 图片 — acceptance: 新增 6 机型卡，图片全部本地 `assets/` 且解码校验通过（可解码、主体宽度达标；实际用 System.Drawing 完成——MIMO_PYTHON 无 Pillow），离线无外链（covers: 本节 §2; depends: T1）
- [x] T10: 页码 21→22 重编号 + validate 断言 — acceptance: 全部角标与 `#page-ind` 为 /22，三个 validate 断言改 22 后全绿（covers: 本节 §3; depends: T8; T9）
- [x] T11: 门禁 + headless 截图 — acceptance: `validate_deck.py` + `validate_dom.py` + `node --check deck.js` 全 PASS，p17/p18 reduced-motion 截图与像素采样正常（covers: 本节 §1–§3; depends: T10）
- [x] T12: 独立审查 — acceptance: subagent 对照本 Amendment 验收，无 critical（covers: 本节; depends: T11）
- [x] T13: Finalize — status=delivered、Report 更新、commits 区间（covers: 本节; depends: T12）

### Amendment 2（2026-09-27）：P17 四框拆为四张折线图页

起点：用户要求把 p17 的四个大数字框「拆成四张折线图」独立成页，数值时间跨度想从骁龙 8cx 时代到 2025 年，**没有的数值不得编造**。已拍板：拆成 4 个新页（deck 22→25 页）；框3 只有单点则单点呈现并明示无历史数据；框4 基线同时用媒体估算与 Canalys。

**1. 数据契约（每个点必须有来源，缺失年份断线，禁止插值）**

| 页 | 序列 | 实线（实际/已发布值） | 虚线（预测/目标） | 明确缺失 |
|---|---|---|---|---|
| p17 | WoA AI 笔记本渗透率（占整体笔记本） | 2025=1.2%（TrendForce） | 2026=3.2%、2029=11.5%（TrendForce 预测） | 2020–2024 无同口径公开数据；脚注注明 Omdia 2024=80 万台（绝对量，不同口径） |
| p18 | Arm PC 出货占比（含 Mac） | 2020=1.4%、2022=12.8%（亿欧智库）；2023=15%（芯智讯）；2025=13%（ABI Research） | 2027=25%（Counterpoint 预测） | 2021/2024 无同口径点（该年份不落点不连线）；亿欧 2027=26.7% 进脚注 |
| p19 | 原生 Arm 应用覆盖（占使用时长） | **仅 2025-09=90%**（Microsoft，total user minutes） | — | 2021–2024 微软未公布同口径数据（图面明示）；单点不成线，画坐标轴+单点+注记 |
| p20 | 五年 50% 目标 vs 现状 | 2024 初≈<1%（媒体估算，芯智讯转述，标「媒体估算」）；2024Q3=<1.5%（Canalys，骁龙 X 占 Windows PC） | 2029=50%（Arm CEO Rene Haas 2024-06 采访：五年内 Windows PC 中 Arm 超 50%；路透社口径，经 IT之家/财联社转述） | 虚线仅连接两个已声明锚点，标注「目标路径，非机构预测」 |

- 每个数据点在图上带机构小字标注；不同机构口径不得混入同一条实线的同一点上；缺口年份不落点。
- 来源 URL 存于脚注（仅机构/媒体名+日期进正文，离线约束禁止 http 链接进 HTML——与既有 footnote 风格一致）。

**2. 页面契约**

- 删除原 p17（`WoA：能跑 ≠ 原生` 四卡页）；新 p17–p20 为四张折线图页，原 p18–p22（机型页/To Xiaomi/Open/gif/End）顺移为 p21–p25。
- 每页结构：eyebrow（`WINDOWS ON ARM · …` 系列）+ h2 + 一句 `.sub` + **内联 SVG 折线图**（`.line-chart`，viewBox 约 1000×420，含 y 轴 % 刻度、x 轴年份、实线 `--accent` + 实心点、虚线预测 + 空心点、点旁数值与机构小字、图例「实线=已发布值 / 虚线=预测·目标」）+ footnote 来源行。
- 无 CDN/无外链/无网络字体；SVG 全内联；入场动画沿用既有 reveal 体系（不做描边动画，降低风险）。
- `data-dur`：p17=9、p18=10、p19=8、p20=9（删除原 p17 的 16s，总时长 239−16+36=**259s**，仍 ≤260）。
- 页码全量重编号 21→25（角标 `NN / 25`×25 + `#page-ind`=`1 / 25` + 注释 1–25），沿用 `scripts/renumber-deck.py --total 25`。
- 必须保留 validate needle：`WoA` 字样（原 h2 已删，在 p17 标题或 sub 中保留）、`WoA AI 笔记本渗透率`、`Arm 架构 PC 出货占比`、`原生 Arm 应用覆盖`、`Windows PC 中 Arm 占一半`（挪进 p20 文案）等，改 needle 前先改文案保证语义成立。

**3. 断言契约**

- `validate_deck.py`：`slides == 25`；`" / 25"` 计数 26；新增 needle（`line-chart`、`1.4%`、`total user minutes`、`Rene Haas` 等实现时回填）；assets/其余 needle 不变。
- `validate_dom.py`：sections / data-dur / data-sub == 25。
- 总时长断言 110–260 不变（259s）。

**4. Amendment 2 任务**

- [x] T14: spec Amendment 2（本节）— acceptance: 数据表与页面契约落盘（covers: 本节）
- [x] T15: 四页 SVG 折线图 + 删原 p17 — acceptance: p17–p20 成立，每点带机构标注，缺年断线，单点页有无数据注记（covers: 本节 §1–§2; depends: T14）
- [x] T16: 25 页重编号 + validate 断言 — acceptance: 角标/注释/page-ind 全 25，三门禁断言同步（covers: 本节 §3; depends: T15）
- [x] T17: 门禁 + headless 截图 — acceptance: 三件套 PASS，四页截图 + 像素采样（covers: 本节; depends: T16）
- [x] T18: 独立审查 — acceptance: 对照本节验收，无 critical（covers: 本节; depends: T17）
- [x] T19: Finalize — status=delivered、Report 增补（covers: 本节; depends: T18）

**5. Amendment 2 追加（同日，用户拍板）：机型页第 7 卡 = RTX Spark**

- 调研（Edge headless 核实）：英伟达与微软 **2026-05-31** 公布 RTX Spark（N1X）平台，定位「新一代 Windows PC 方案」：最高 20 核 Arm CPU（联发科合作）+ Blackwell GPU（最高 6144 核）+ 128GB 统一内存；2026-07-18 曝光 Windows 11 Arm64 原生驱动 616.00（IT之家 ithome.com/0/978/599.htm）；NVIDIA 官方《Windows on Arm Porting Guide》专设 “Windows on ARM on RTX Spark” 章节（docs.nvidia.com/rtx-spark/rtx-spark-porting-guide）；首批机型 2026 秋季上市，Surface Laptop Ultra 首发（15"，Computex 2026-06-01 发布）。
- 落位：机型页（Amendment 1 的 p18，现为 **p21**）新增第 7 卡「Surface Laptop Ultra / NVIDIA RTX Spark · N1X / 20 核 Arm + Blackwell · 128GB · 2026 秋」，标注未发售；`device-grid` 改 `repeat(4, 1fr)`（7 卡 4+3，留一空位）。
- 图片：微软官网 surface-laptop-ultra 页 og:image（ctfassets 官方海报）降采样为 1200px JPEG 存 `assets/surface-laptop-ultra.jpg`（深色渐变海报底，属官方视觉）；已验证为笔记本主体、无烘焙文字。
- footnote / data-sub 同步补 RTX Spark 公布日期与秋季上市口径；页数不变（仍 25）。


## [S3] Out of Scope

- ~~不增删页数（仍为 21 页），不改真实数据数字与证据内容。~~（Amendment 2026-09-27：增一页至 22 页并在 P17 新增市占率数据；Amendment 2：P17 四框拆为四个折线图页，总页数 25；原 16 页既有证据数字不动。）
- 不引入 CDN / 网络字体（官方页的 PT Serif/Ubuntu 不离线引入，字体栈维持系统字体 + 等宽）。
- 不生成 MP4、不重跑 benchmark、不改移植产物与 README。
- 不做全片深色或全片浅色的极端方案。
- 不用 AI 生成图冒充真实机型产品图；机型图找不到合格真图时该卡降级为文字/色块。

## Tasks

- [x] T1: 撰写 feature spec — 本文件（covers: S1; S2）
- [x] T2: 配色改造 — styles.css token 体系换为官方色值，浅色为主 + p14/15/16 深色剧场页；截图确认无旧色残留（covers: S2）
- [x] T3: 包袱补全 — index.html 五处文案/结构落位，validate_deck.py 断言同步（covers: S2; depends: T1）
- [x] T4: 动画节奏 — 时长/缓动/stagger/位移按动画契约调整，data-dur 校验，node --check 通过（covers: S2; depends: T2; T3）
- [x] T5: 验证 — validate_deck.py + validate_dom.py + node --check + headless 多页截图走查（covers: S2; depends: T2; T3; T4）
- [x] T6: 独立审查 — subagent 对照 spec 验收，无 critical（covers: S1; S2; depends: T5）
- [x] T7: Finalize — status=delivered、Report、commits 区间（covers: S1; S2; depends: T6）
