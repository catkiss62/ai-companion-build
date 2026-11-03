# DSH 安卓互通与渐进插件化方案

更新日期：2026-11-03（北京时间）。状态：讨论方案与候选调研，尚未实施互通/插件宿主。
用户确认：值得保留；先完成 QQ 音高修补，再选择安卓 DSH 基线并对齐接口。完整插件化可留至后续较强模型参与架构审查时推进。
QQ 降调 v0.42.166+410 已完成构建与验证，见 [交付记录](QQ_VOICE_PITCH_v042166.md)。诊断互通与插件宿主尚未实施。
本文件不授权重写现有聊天、QQ、记忆或 Live2D，不把候选项目描述为已完成真机验收。

## 1. 目标与当前边界

希望 DSH 能结合 GitHub 中的对应版本源码与手机 App 的实际执行状态排查问题，之后制作扩展并安装到 App，减少需要整包 APK 的功能升级。
维护收益来自稳定接口、明确生命周期、版本兼容与可回退，而非仅把文件改名为“插件”。

当前主工程：catkiss62/ai-companion-build，agent/v042107-review-recovery。
调研运行基线：v0.42.165+409 / schema67，源码分支 HEAD e4f4d7e8f5c840d14cc8850009935bde2d2b7b4c。
当前已有工具注册目录、MCP Streamable-HTTP 客户端、网页作品运行与桥接；尚无供 DSH 使用的通用 App 诊断服务，也没有兼容 Cordis/Node 插件的 App 宿主。
MCP 客户端调用外部工具，不等于已经向外提供 App 自身的诊断接口。
正式安装的 Flutter/Kotlin 核心变更仍需编译、签名和安装；不能通过修改 GitHub 源文件即时改变手机里的 APK。

## 2. 安卓 DSH 初筛

以下结论来自公开 README、发布清单、仓库提交与官方 DSH 文档；未安装这些候选 APK，未进行性能、功耗、安全或全部插件兼容性实测。README 的启动时间、兼容全部生态等宣传不作为本项目验收结论。

| 候选 | 核心方式 | 对本项目的价值 | 初步位置 |
| --- | --- | --- | --- |
| Soodok/Deepseek-Harness-Local-Android | bionic Node 本机运行；官方 DSH 引擎与移动适配、运行时扩展中心 | 无需电脑，适合手机内调试、编写和安装连接插件；有正式发布与运行时管理 | 优先试用候选，未定案 |
| dphmoblie/deepseek-harness-android | PRoot + Ubuntu 24.04 + Node，本机运行 | Linux 工具环境较完整，插件导入/更新/回滚与诊断有文档 | 兼容与备选基线，需验证与伴侣同时运行的资源占用 |
| qsnddayst/dsh-android | Kotlin 壳 + 内嵌 Node/工具链 + WebView | 设备桥与本机通信方案清晰，可作接口实现参考 | 参考实现；发布与日常维护需进一步核对 |
| saya-ch/dsh-mobile | Android 客户端/浏览器连接电脑上的 DSH | 重任务可放电脑，移动端延续会话、插件与工具 | 远程工作流备选；不当作手机本地引擎 |

2026-11-03 检索时固定的代码/发布信息：

- Soodok：main f79ef4fb3224f034d6abb7582d17972704346970；最新非预发布 v1.4.76；另有 v1.5.0 beta，初次验收优先固定正式发布，不追 latest。中英文 README/徽标的上游 DSH 版本文字并不完全一致，以实际运行时自报与发布清单核对。
- dphmoblie：main 9d7f23ee1309d83af2e9ac88648935f11b7eccbb；最新非预发布 v0.3.7，发布运行时记录 DSH 0.2.1-rc.1。
- qsnddayst：master b7c64592483079b451314826802314c8c47c742e；README 说明调试签名与 arm64 验证范围。
- saya-ch：main 42cabbd8b634d73df9f0d9fc26ead1ce3f1f07a2；README 的插件 0.8.1 与 Android App 0.7.1 独立编号，不混为同一个版本。

选择标准：真实工具可用、插件装卸与重启后保持、上游引擎版本可查询、MCP/HTTP 接口可用、前后台切换与故障可诊断、运行时升级可回退。星标数量不代替上述验证。

## 3. 兼容方法

先选一款作验收基线，同时定义独立的 Companion 互通协议和能力发现；不要将主工程绑死到某个第三方 APK 的包名、私有文件目录、UI CSS 或某个 Node 快照。
区分安卓壳版本、内嵌 DSH 引擎版本、连接插件版本、Companion 协议版本。

建议握手返回：App 版本、构建源码 SHA、协议版本、可用诊断/测试能力、实例/连接身份；DSH 侧也报告宿主与连接插件版本。未知能力明确拒绝，不猜测成功。
第一版协议仅为提案，正式实现前再写 schema 与契约测试。

DSH 本机运行时，可以采用 Android 身份可验证的 IPC 加薄适配，或经配对授权的本机 MCP/HTTP 连接。回环地址本身不是权限保护：HTTP 路线仍需连接凭据、有限接口与有效期；不直接开放数据库/任意文件/任意代码执行。
如果宿主实际在电脑，手机的 localhost 不可当成电脑的 localhost；连接方式另行验证，不把常开 VPN、Tailscale 或电脑在线强加给纯手机方案。
DSH 官方支持 stdio 和 Streamable HTTP MCP；优先用公共工具接入点，减少依赖其内部会话对象或私有 UI。

## 4. 分阶段实施

### A. 只读诊断互通

先实现安装版本/源码定位、按请求 ID 的执行阶段与错误、相关设置和运行状态查询；范围按问题领取，避免每次搬整份存档。
优先覆盖 QQ 接话与发送、模型通道失败、TTS 实际参考档位/音高、Live2D 实际参数和动作来源。
数据必须有采集时间、运行实例与过期说明；“没有采集到”不可写成“没有错误”。
App 正常运行不依赖 DSH 是否打开；诊断连接可显式停止。

验收：DSH 能将同一轮问题的源码版本、当前设置与执行记录对应起来；断线/切后台/进程重启不串请求，不持续重读全库。凭据与私人日志原文不写入公开仓库。

### B. 有界测试入口

在 A 稳定后开放预览动作、生成同句测试语音、读取测试结果等明确命令。测试请求与正常聊天具有各自身份和取消规则，复用现有优先级/工作栅栏。
写入设置或插件安装另设明确能力；不把“能读取诊断”自动升级成任意写库权限。
验收以实际参数变化、生成文件或播放结果为据，不仅返回“成功”文字。

### C. 一个可安装扩展试点

适合的试点：Live2D 动作/表情参数包，或一个新的外部工具适配。
沿用模型独立身份，菜菜与 DeepSeek 参数、存档、摸头区域等继续隔离。
App 包内包含所需原生能力；DSH 制作的是 App 明确支持的扩展格式，通过接口安装。先不承诺直接运行任意 npm/Cordis 插件。
扩展至少声明 ID、版本、内容摘要、最低协议/能力要求、配置 schema、命名空间和生命周期。启用/禁用/升级时处理定时器、监听、在途任务和重复执行。
保留旧版本，验证新版本后再激活；失败可回退。存档包含扩展清单、配置与状态，恢复时提示缺失/不兼容，不能静默改变人格或模型设置。

### D. 根据试点再扩大

可优先扩展世界书/提示词模块、参数组合、外部工具、互动小页面。
原生 TTS 引擎、Live2D 渲染错误、后台服务、数据库核心和底层存档变更，仍走正式 APK 迭代。
完整兼容 DSH 生态需处理 Cordis 服务、Node/原生依赖、UI 插槽与移动资源成本，视为独立大工程，当前不承诺实施。

## 5. 必要验证与资源成本

- 在 Redmi K80 Ultra / HyperOS / Android 15 / arm64 实机验证，尤其与 Live2D、Genie-TTS、QQ 后台共存的内存、发热与响应。
- 相同最小连接插件在选定主候选与另一候选上跑同一套握手、查询、超时、取消、重连契约测试；检测能力差异，避免仅按产品名判断兼容。
- 插件重复安装、同 ID 升级、禁用、回退、App 升级、导出导入与缺失依赖都有明确结果；不绕过现有任务归属/源数据失效栅栏。
- 发布信息后续可收敛到统一版本来源，减少分散的版本白名单维护；保留实际功能回归门，作为独立维护事项，不夹带到插件化改造。
- 每阶段单独验收；不要同时重构人格、记忆、QQ、双模型 Live2D 和主聊天调度。
- 较强模型可用于方案、跨模块审查和回归设计，但质量依赖固定基线、可执行契约及真机证据；不以订阅套餐或某个思考档位替代验证。

## 6. 已保留的视觉项目

参考：[SAOS-3624/dsh-see-now](https://github.com/SAOS-3624/dsh-see-now)，调研版本 0.0.7 / 06c4594381fe0ef59dbce0fb2c705c6621cc29b3。
价值：本地画面变化检测、筛帧、多帧拼图及模型调用节流。后置摄像头聊天与平板共同观影均仍待决定。
第一通道用于识图，第二/第三通道带上下文生成聊天；识图仍有输入、观察摘要和可能思考输出成本。
宣传“4 分钟 5 分钱”未获完整账单复核；默认至少约 15 秒唤醒，不等于一两秒端到端回应；影片对白需另接字幕/转写。
手持摄像头全幅晃动会增加变化分，需按实际场景调整采样。安卓视频采集黑屏问题与 token 优化独立处理。

## 7. 资料入口

- [官方 DSH](https://github.com/deepseek-ai/deepseek-harness)
- [官方 MCP 接入](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/mcp.zh.md)
- [Soodok 本机版](https://github.com/Soodok/Deepseek-Harness-Local-Android) / [正式版 v1.4.76](https://github.com/Soodok/Deepseek-Harness-Local-Android/releases/tag/v1.4.76)
- [dphmoblie 本机版](https://github.com/dphmoblie/deepseek-harness-android) / [正式版 v0.3.7](https://github.com/dphmoblie/deepseek-harness-android/releases/tag/v0.3.7)
- [qsnddayst 实现参考](https://github.com/qsnddayst/dsh-android)
- [saya-ch 远程版](https://github.com/saya-ch/dsh-mobile)
- [Android 应用间数据与身份边界](https://developer.android.com/privacy-and-security/security-tips)
- [Flutter 正式版与开发热重载边界](https://docs.flutter.dev/testing/build-modes)
