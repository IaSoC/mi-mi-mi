# Migration prompts — session «研究我工作在哪台计算机上»

Source: MiMo Desktop conversation `ses_ffe5f298357dfffeN82Wln2VmT` (2026-09-25).
Quoted user prompts only; wording preserved.

## Brief

> 不知道你能否接住我的笑话的包袱。总之先研究一下你工作在哪台计算机上。

> /compose-next 没问题，你接住了。所以接下来的问题就很真实了。我先不告诉你我对这个实验的名字，但是你注意到了吗，现在的 Xiaomi Mimo.exe （）位于： C:\Users\xiaomi\AppData\Local\Programs\Xiaomi MiMo ） 工作在体系结构 x64 上。而它是一个 Electron。所以我在探索 Electron 的可移植性边界。目标是在 Post-Market 状态下（没有源代码和构建环境）让 MiMo Desktop 运行在 ARM64 原生二进制上。

## Toolchain

> 我手动安装了 Git。如果后续有基础软件链，请明示，由我来手动安装。

> 刚刚网络比较弱。先看一下这个页面帮我构建一下传入 winget 的指令。https://learn.microsoft.com/en-us/cpp/overview/acquire-msvc?view=msvc-170#install-msvc-by-using-winget

## The self-hosting moment

> 你在关掉出错的移植的时候把你自己也关掉了。

> /compose-next 我现在用 ARM64 版本启动了，正确识别了现有的用户配置。那么我们接下来的测试过程应该怎么进行？

> 你忘记了我现在就在用适配的 ARM64 版本 MiMo Desktop，于是都匹配上了。🤣

## Measurement discipline

> 我在想可以这样做，写一个测量脚本，然后我在完全关闭现有的 MiMo 实例的情况下用两个版本的脚本启动同一个用户档案。

> 有两个问题。第一，x86_64 版本的完整启动时间好像明显更长，就是显示出项目的时间，这个能否被计算？第二个是脚本有问题。

> 依然不太对，虽然它最终显示了数字，但在我观测到的几次测试中，实际上主页根本没有渲染出来。

> 这次 x64 版本的数字完全测错了，它仍然在灰色屏幕就被杀掉了，并告诉我 Arm 比 x64 还慢。

> 我已经运行过了，但是 x64 模式依然计时有误，我仍然看到它还未加载完毕就被杀了。接下来我倾向编写一个各启动一次的测试脚本，收集信息直到人手关闭 MiMo，并引入启动过程的 Mimo 本体完整日志导出。

> 我们这次就可以基于新四点写了。窗体出现，MiMo 打光标，落地页渲染，和项目列表出现。

> 我觉得咱们别瞎猜了，直接改测试脚本吧，我们应该能匹配到。

> 总时间是我手动关闭的，因此那个不算。我又试了一下 x64 版本，人眼看到的窗体打开到 MiMo 标志大约需要 4.75s，你自己研究一下这到底是哪个时间点。

> 还有个问题，我看了一下，任务列表的加载应该不是 200ms，而是 Arm 2.5s，x64 4.5s 这个级别。特点是从‘暂无任务’显示出可选的任务。

> 就用 Engineer Sessions 吧。

## Packaging & license

> 再继续测试前，我希望能专门做一个文件夹打包我们目前的构建环境，并带有一个从官方二进制提取的指导。

> 所以 Elevate.exe 是什么？

> 好的，就写入 MIT。然后所有方写 IaSoC，版权年份 2026。

> 然后我希望你把这个 readme 格式化之后放到合适的位置。Mi Mi Mi … «MiMo-on-MiMo-on-Timi.» …
