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

## +446 活泼参考音频

> **维护告示：旧资源包中的jiuhu_idle50仅为历史基线，不是当前活泼参考。除用户明确要求回退外，不得移除+446替换步骤，不得只更新WAV而沿用旧文本或六组特征。旧包仍提供模型及其他音色，不能直接删除。**

仅替换 `jiuhu_idle50` 的参考音频/文本/六组离线特征，日常、温柔、可爱及声学权重保持不变。制作记录和CI状态见唯一总账「小酒狐活泼参考替换」。原参考来自固定v0.7.6草稿资源，新补丁以认证加密文件保存，构建前由同一私有APK解锁；不把录音和权重提交到公开源码。

入口：[应用补丁](../../tools/apply_jiuhu_lively_overlay.py)、[补丁测试](../../tools/test_jiuhu_lively_overlay.py)、[四候选端到端推理验证](../../tools/verify_jiuhu_voice_bundle.py)。后者移植自Genie-TTS-Android提交96a6296的verify_voice_bundle.py，只限制CPU线程数，使用原包目标文本/模型/自回归/VITS路径验证。

保持原manifest.version，文件SHA变化触发原生AssetIntegrityPolicy就地替换六组特征；重建echo guard，三个其他音色资源与模型不重复复制。APK升级重启进程后从assets读取新manifest；原生同尺寸旧marker回归保证新ge不会被旧缓存吞掉。不要只换WAV，不要复用旧音素/ssl/ge，不要改播放调速来掩盖参考差异。

回退：保留固定Genie v0.7.6草稿资源，移除构建中的补丁应用与补丁验证步骤，再提高App版本号构建覆盖安装；无需卸载或清理用户存档。旧+445仍可作为源码/听感对照。
