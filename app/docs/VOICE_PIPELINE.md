# Voice Pipeline · current (v0.39.5)

## 普通聊天

```text
DeepSeek SSE
  ├─ reasoning_content -> UI 思考面板 + SQLite
  └─ content delta
        -> TtsSentenceSegmenter
        -> TtsPlaybackQueue
        -> TtsService / TtsTextProcessor
        -> Flutter MethodChannel
        -> NativeTtsBridge
        -> NativeTtsEngine
        -> 新版资源校验（首次初始化/手动强制）
        -> LegacyTtsRuntime
        -> ZH language override / suspend bridge
        -> JNI / libbertvits2.so / MNN / .mnn
        -> byte[] RIFF/WAV
        -> AudioTrack
```

reasoning_content 与正文语音通道物理分离，不会被误读。

## Cancel 语义

Dart 层 generation：阻止未开始的句子继续调用 MethodChannel。

Kotlin 层 speechGeneration：处理“用户在 MNN 正在生成 WAV 时点击停止”的窗口。MNN 调用本身暂不强杀，但生成返回后发现 generation 已过期则直接丢弃 WAV，不启动 AudioTrack。

因此 stop 的目标语义是：

1. 当前已经播放的 AudioTrack 立即停止；
2. 尚未调用 native 的待播句子全部丢弃；
3. 已进入 MNN、尚未返回的旧句子允许完成计算，但结果不得再播放。

## 主动消息策略

- `silent`：只写 SQLite + 通知 + 悬浮未读。
- `when_overlay_opened`：主动消息本身保持安静；用户主动打开悬浮聊天时，最多朗读最新一条尚未朗读的主动消息。
- `immediate`：后台 Active Brain 生成主动消息后直接调用本地 TTS。默认关闭，避免意外出声。

## 后续真机调优项

- 分句阈值是否需要按 Meju 实际推理速度调整。
- 句间停顿是否需要人工增加 60–180ms。
- 游戏/音乐播放时是否需要 AudioFocus duck / mix 策略。
- 蓝牙耳机切换、来电/闹钟中断恢复。
- 更自然的流式预生成（当前 native worker 单线程，稳定优先）。


## Current integrity boundary

首次初始化前会按用户提供的 `完整文件(1).zip` 指纹清单校验 32 项模型/runtime/native 资源；失败即 fail-closed，不进入 JNI/MNN。私有 Dex runtime cache 使用版本化目录，新运行时所需的 5 个拼音字典会在只读缓存 JAR 中注入后再加载。

新版中文前端单次最多接受 300 phones。正常标点分句规则不变；只在极端无句末标点长段落中启用 72 字符安全兜底。队列仍保持分句预生成、严格顺序播放和整队停止语义。
