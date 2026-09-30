# Mi Mi Mi

*An experiment on the portability of a “platform-independent” development framework, where everything goes wrong with Windows on ARM.*

**«MiMo-on-MiMo-on-Timi.»**

Mi Mi Mi 是一项实验：在只有 post-market 安装包的前提下，把闭源 Electron 应用 **Xiaomi MiMo Desktop** 从 x86-64 迁移到 Windows on ARM 上的原生 ARM64。

实验在 **Xiaomi Book S 12.4**（Snapdragon 8cx Gen 2，Windows on ARM）上进行：用 **Xiaomi MiMo** 辅助迁移 **Xiaomi MiMo Desktop**——被迁移的应用，恰好就是托管这次迁移的应用。

## 实验问题

> **一个真实 Electron 应用里，到底有多少东西是架构相关的？**

更具体地：

> **能否只用安装后的产物，把闭源 Electron 应用从 x86-64 迁到 ARM64？**

关键区分不是「能不能在 ARM64 上跑」——它已经能跑了（经 Prism）。而是：

> **核心执行路径能否不再依赖 x64 兼容层？**

原路径：`ARM64 CPU → Windows on ARM → Prism → x64 Electron → MiMo Desktop`  
目标路径：`ARM64 CPU → Windows on ARM → ARM64 Electron → MiMo Desktop`

## 四态判别（速查）

| 状态 | 含义 |
|------|------|
| **ARM64** | 已确认 ARM64 |
| **x64** | 已确认 x64 |
| **Independent** | 无 CPU 架构相关二进制依赖 |
| **Unknown** | 证据不足 |

**「能跑」≠「全 ARM64 原生」。** 文件存在也不证明应用加载它。明细见 [docs/STATUS.md](docs/STATUS.md)。

## 从哪里开始

| 我想… | 去读 |
|-------|------|
| 构建 / 安装 ARM64 版（使用者） | [docs/BUILD.md](docs/BUILD.md) · [docs/release/DROP-IN.md](docs/release/DROP-IN.md) |
| 从零重铸骨架（维护者） | [portkit/README.md](portkit/README.md)（作者路径） |
| 当前证据状态与研究清单 | [docs/STATUS.md](docs/STATUS.md) |
| 移植过程的完整设计与结论 | [docs/compose/spec/electron-arm64-port.md](docs/compose/spec/electron-arm64-port.md) |
| 演示文稿 | [docs/compose/deck/](docs/compose/deck/) |
| 致小米的一封信 | [docs/letter-xiaomi.md](docs/letter-xiaomi.md) |
| AI 代理工作约定 | [AGENTS.md](AGENTS.md) |

**操作正典是 `docs/BUILD.md`。** 消费者路径 = drop-in（官方 payload + 骨架 + asar 补丁）；`portkit/` 仅用于作者重建。

## 实验约束

本实验故意从「已安装的应用」出发，而非官方源码仓库。**不假设**拥有：

- 官方源码
- 官方构建系统
- 内部 CI
- 原生 ARM64 构建配置
- 厂商开发环境

因此它更接近 **post-market 可移植性调查**，而非常规的源码级移植。

## 结论应如何理解

最有趣的结论未必是「迁移成功」。

若应用**改动极少即可运行**，说明架构相关边界比想象中更小。  
若**失败**，失败点本身指出抽象在哪里断裂。

成功与失败都是有用的结果。

## Disclaimer

**Mi Mi Mi 是独立研究项目。**

本仓库不包含 Xiaomi MiMo Desktop、小米专有源码、签名证书、私钥、服务凭证或其他属于 Xiaomi 的专有资源。用户须通过合法渠道获取所需软件，并遵守相应许可与服务条款。

项目作者无权代表小米公司签名可执行文件。

本项目按 **AS IS** 提供，不附带任何明示或默示担保。它不是小米官方项目，也不意味着小米、Timi Personal Computing Co., Ltd.、Microsoft、Qualcomm 或 Electron 的背书、支持或参与。

*MIT © 2026 IaSoC — See `portkit/LICENSE` for build tooling licensing.*
