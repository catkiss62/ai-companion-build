# QQ 导出音高对齐 v0.42.166+410

日期：2026-11-03。基线：e4f4d7e8f5c840d14cc8850009935bde2d2b7b4c / +409。schema67 不变。

## 范围

QQ 继续由正文模型选择 daily/gentle/lively/cute，解析失败回落日常；不改成跟随 App 的手动语气设置。
QQ 与 App 原本共用 Genie 运行时和参考音频特征，并未跳过参考音频。
本轮仅补齐音高：读取现有 tts_pitch_semitones，复用普通形态“保存值减 1 半音”的策略；默认设置 0 对应音高比 0.9438743127。
QQ 不跟随 App 临时小豆丁形态，不写回设置，不更改 App AudioTrack 音高。

## 实现与边界

所有分段先按既有逻辑合成为 PCM16 WAV 并拼接，再在原生导出身份保护下统一调整。
使用固定版本 androidx.media3:media3-common:1.8.0 的 SonicAudioProcessor，只做离线 PCM 处理，speed=1，保持采样率和声道；不通过改 WAV 采样率冒充降调。
新增 tuneVoiceExport 仅供已取得导出身份的后台调用；处理前、分块处理和返回前均检查当前归属。App 语音抢占、超时、用户取消时，不上传原音频作为伪成功兜底。
不创建播放器或麦克风，不改变参考音频/推理过程，不新增模型请求。
原有音频大小/时长限制、语音发送回执、未知发送结果不重试、失败回落文字继续保留。

## 验证设计

- Dart：默认与滑块边界、模型语气保持、使用变调文件、处理期抢占/取消、缺失或坏输出拒绝。
- 原有 QQ 运行测试：真实读取保存的音调配置并传给导出服务；三语音/归档/回执回归。
- JVM/Robolectric：正弦基频变化、时长与采样率保持、双声道、升降调、零偏移原样通过、短静音、坏 WAV 与取消。
- 现有完整 CI 的源门、正式 Kotlin 单元测试、Flutter 全量与存档恢复检查继续执行。
- 真机听感仍需同句对比；自动基频/时长验证不能宣称已证明所有语气的主观音质一致。

验证状态：完整 CI、专项、Android 15 与原生 PCM 测试已通过，原签名 APK 已生成并核对产物。用户真机听感待同句对比。

## 后续方案

[DSH 安卓互通与渐进插件化方案](DSH_INTEROP_PLUGIN_ROADMAP_2026-11-03.md)为后续讨论与调研记录；本次不实现诊断互通、插件安装服务或新的网络监听。

## 最终验证与安装包

- 运行源码：30fac7b4a1aa3c5002090048d2ec2e8ef4c74cc0，tree fd80b0c4b0c2eddd833b674b2713663448c2234d。
- [完整 CI 41576740750](https://github.com/catkiss62/ai-companion-build/actions/runs/41576740750) success，正式打包 job 125724525634。
- [独立专项 41576740765](https://github.com/catkiss62/ai-companion-build/actions/runs/41576740765) success；QQ 新旧语音与音调组合 26 项通过，其中新增 Dart 8 项。
- 全量 Flutter **3352** 项、独立存档/作品恢复 **171** 项、源码门 **161** 项均通过；组间有重叠，不相加。Dart 分析 0 error、1063 项既有非 fatal 提示。
- Android 15 模拟器 **61** 项通过，job 125722264076；正式 App Kotlin 单元测试步骤通过。
- 独立原生导出测试 **9** 项（PCM 音高 7、原有归属 2），0 failure、0 error、0 skip。job 125722264086；[JUnit 结果制品](https://github.com/catkiss62/ai-companion-build/actions/runs/41576740750/artifacts/13203574286)，ZIP 摘要 172b1c73b34153fdb3e4015a34335f919f40d5059c59f71f114c6c490b36b0b2。
- 原生测试直接编译生产处理器与原始测试文件；仅同步所需两个测试文件，避免 Kotlin 发现共享目录中的无关测试。无需私有模型即可先验证实际 Media3 处理。
- 同步 App 自报版本，并在 17 处既有发布检查中仅追加 +410 允许值；原有功能断言保留。

原签名 APK：

- 包名 com.aicompanion.localfirst；实际版本 0.42.166+410；schema67。
- 大小 **740650302 bytes**。
- SHA-256：`6cc226ceab205c8dcda43dac5834b9134a28d2ffc321cbb31fc26fd8b2266923`。
- 签名 SHA-256：`305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`，与原身份一致。
- [下载 APK 制品](https://github.com/catkiss62/ai-companion-build/actions/runs/41576740750/artifacts/13205700894)。制品为 ZIP，解压后安装 APK；ZIP 733456967 bytes，摘要 a2f4d453fa7f5dc89fbb888435e077b7e20d83560aa52de6f2e579a9e11eb651，不与 APK 摘要混用。
- Draft 432254690（未发布）/ APK asset 704339417 的字节数与原始 APK 摘要一致；ci-monitor-v0345 分支 .ci/v042166-monitor.txt 为 success，运行源码与原始 APK 摘要匹配。

构建前曾发现自报版本未同步与旧白名单缺 +410，已修复；独立测试工程首次误收无关 Kotlin 测试，已改为同步原始目标文件。失败或取消的旧运行不计为最终验证成功。
后续仅文档收口，不重新构建或改变上述 APK 的运行代码。DSH 候选仅作源码/公开发布资料初筛，未安装验收。
