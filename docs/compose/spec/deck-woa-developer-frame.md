---
feature: deck-woa-developer-frame
status: delivered
updated: 2026-09-27
branch: master
commits: ca0549f..uncommitted
---

# Deck P17–P20：出货叙事 → 开发者基建

## Report

**What was built** — 保留 P17–P19 的出货/生态硬数据与整张折线图，仅轻改 eyebrow / `.sub` / `data-sub`，把叙事串成「渗透仍低 → 可寻址装机 → 原生覆盖 90%」；P20 整页从「五年 50% 目标」换成 **Developer infrastructure** 里程碑时间线（4 条一手来源：VS 17.4 原生 ARM64、linux-arm64 CI、`windows-11-arm` 免费公开仓、`windows-11-vs2026-arm` GA）。页数仍 29，总时长仍 300s。动画用 P10 的 `rv-l dN` + P22 的 `ul.timeline` 结构。

**Verification** — `validate_deck.py` PASS（29 页 / 300s / needles 同步）；`validate_dom.py` PASS；`validate_order.py` PASS（0/29）；P20 headless 截图存在。独立审查 verdict **pass**（AC1–AC5 全过；P17–19 SVG 与改前 byte-identical；里程碑日期对照 github.blog 核实）。两处 minor 已修：spec needle 与实现对齐；preview 状态写入 tl-d/footnote。

**Journey log** — 1. IAB/Browser Use 起不来（无 `mimo-browser-use`），按 skill 报给用户后改用项目回退 `scripts/websearch_edge.ps1` + 正常 Edg UA（需 `-ExecutionPolicy Bypass`）。2. 数据契约仍守「没有的数值不编造」：工具链不画假百分比曲线，改用带日期的里程碑。3. needle `Rene Haas` / `Windows PC 中 Arm 占一半` 随 P20 替换删除，勿只改 HTML 忘改 `validate_deck.py`。

## [S1] Problem

P17–P20 当前四页全是消费侧出货渗透/份额/目标线，与「WoA 前期主打 Developers 不是 Consumers」的叙事错位。需要保留出货与生态硬数据，补一页开发者工具链基建，页数不变（仍 29），总时长仍 ≤300s。

## [S2] Design

### 数据筛选结论（已 Grill 拍板）

| 页 | 处置 | 理由 |
|----|------|------|
| P17 | **保留图与数据**，轻改标题/副标题 | TrendForce 渗透率 = 诚实的用户基数（仍很小） |
| P18 | **保留图与数据**，轻改标题/副标题 | Arm PC 出货占比 = 开发者可寻址受众 |
| P19 | **保留图与数据**，轻改标题/副标题 | Microsoft 90% 原生覆盖 = 移植回报 |
| P20 | **整页替换** | 原「五年 50%」偏消费市场目标；改为开发者工具链里程碑时间线 |

叙事弧：用户基数还小（P17）→ 可寻址装机在涨（P18）→ 应用原生已就绪（P19）→ 工具链与 CI 已就绪（P20）→ 所以轮到你们（P21+）。

### 轻改标题（P17–P19，图/SVG/机构点不动）

- P17：eyebrow 仍 `WINDOWS ON ARM · 渗透率`；h2 保留「WoA AI 笔记本渗透率」（validate needle）；`.sub` 补一句开发者视角：出货渗透仍低 = 受众还在早期
- P18：eyebrow 改为 `WINDOWS ON ARM · 可寻址基数`；h2 保留「Arm 架构 PC 出货占比」（needle）；`.sub` 从「占整体 PC 出货」延伸到「开发者可寻址的装机」
- P19：eyebrow 改为 `WINDOWS ON ARM · 移植回报`；h2 保留「原生 Arm 应用覆盖」（needle）；`.sub` 把「用户使用时长」接到「说明原生化已过临界，移植有回报」

禁止改动：四页的 polyline/circle/数值/机构小字/footnote 来源清单；P17/P18/P19 的 `data-dur` 不变。

### P20 新页：开发者工具链里程碑时间线

- `data-dur="9"`（与原 P20 相同，总时长不变 = 300s）
- eyebrow：`WINDOWS ON ARM · 工具链`
- h2：`Developer infrastructure`
- 结构：复用 `.timeline`（同 P10 Migration），**不**用 `.line-chart`
- 里程碑（均有一手来源，已 Edge 回退打开核对）：

| 时间 | 标题 | 内容 | 来源 |
|------|------|------|------|
| 2022-11 | Arm64 Visual Studio 17.4 | 首个完全支持的原生 Arm64 VS，大多数工作流免模拟 | VS Blog 2022-11-08 |
| 2025-04 | `windows-11-arm` 免费 | GitHub Actions Windows on Arm runner 对全部公开仓免费（含 Free tier） | Windows Dev Blog / GitHub Changelog 2025-04-14 |
| 2026-08 | `windows-11-vs2026-arm` GA | Win11 arm64 + VS2026 镜像在 standard/larger hosted runners 正式可用 | GitHub Changelog 2026-08-20 |

- 可加第四条（可选，若排得下）：2025-01 linux arm64 runners 先行（GitHub Changelog 提及）——优先级低于上三条
- footnote：完整 URL/标题来源；注明「断线不补 / 无同口径百分比不编造」
- `data-sub`：说明开发者基建从 IDE 到 CI 已闭环，与前 3 页出货/生态数据衔接

### 门禁同步

- 删除 P20 旧 needles（若语义不再出现）：`Windows PC 中 Arm 占一半`、`Rene Haas`——改前先确认全 deck 是否还有他处引用；若无则从 `validate_deck.py` 移除
- 新增 needles：`Developer infrastructure`、`windows-11-arm`、`windows-11-vs2026-arm`、`Arm64 Visual Studio`、`可寻址基数`、`移植回报`
- `line-chart` needle：P17–P19 仍在，保留
- slides/sections/data-dur/data-sub 仍 29；`" / 29"` 计数仍 30；total_s 仍 300

### 硬约束

- 页数 29 不变；不插入/删除 section
- 「没有的数值不编造」：不为工具链发明百分比曲线
- P17/P18/P19 的机构点与 footnote 一字不改（除上述 `.sub`/eyebrow/h2 允许文案）

## [S3] Out of Scope

- 不改 P16 情绪页、P21 机型页
- 不引入新图片资产
- 不重排其余页码
- 不把完整 URL 列表塞进图面（footnote 够用）

## Tasks

- [x] T1: 轻改 P17/P19/P18 标题与 `.sub` — acceptance: 图与机构点原样，h2 needle 仍命中，sub 服务新叙事（covers: S2）
- [x] T2: 整页替换 P20 为工具链时间线 — acceptance: `.timeline` 四里程碑 + 来源 footnote，`data-dur=9`，旧 50% 图删除（covers: S2; depends: T1）
- [x] T3: 同步 validate needles 并跑三门禁 — acceptance: deck/dom/order 全 PASS，total_s=300，slides=29（covers: S2; depends: T2）
