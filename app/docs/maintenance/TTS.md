# 语音与原生播放

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [tts_service.dart](../../lib/core/tts/tts_service.dart) | Dart 调度 |
| [tts_voice_profile.dart](../../lib/core/tts/tts_voice_profile.dart) | 语音风格/选择 |
| [tts_text_processor.dart](../../lib/core/tts/tts_text_processor.dart) | 正文处理 |
| [NativeTtsEngine.kt](../../android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt) | 原生入口 |
| [GenieTtsIsolatedService.kt](../../android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsIsolatedService.kt) | 独立进程推理 |

## 状态与边界

当前链路使用 Genie 独立进程推理，旧 Meju/MNN 文档是历史。语种、参考音频、语音风格、推理参数和播放速度不是同一设置。预加载需结合进程是否存活，不能承诺进程被杀后仍无须加载。

## 小改动如何落点

修改前查 Dart→原生桥→隔离进程→播放回执。语言切换应与文本同步；播放期间 JEV 嘴部控制和声学口型分工要检查。历史加速候选不能直接重启当优化。

## 回归入口

- [tts_policy_test.dart](../../test/tts_policy_test.dart)
- [tts_text_processor_test.dart](../../test/tts_text_processor_test.dart)
- [tts_playback_tuning_test.dart](../../test/tts_playback_tuning_test.dart)
- [tts_structured_stream_parser_test.dart](../../test/tts_structured_stream_parser_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：冷/热启动、切语种、停止播放、进程被杀后恢复、最后两轮播放速度诊断。
