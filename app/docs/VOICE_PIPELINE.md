# Voice Pipeline · v0.25

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
        -> 黄金资源校验（首次初始化/手动强制）
        -> LegacyTtsRuntime
        -> JNI / libbertvits2.so / MNN / .mnn
        -> WAV
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


## v0.25 integrity boundary

首次初始化前会按 MejuTTS v2.7 黄金指纹校验 37 项模型/runtime/native 资源；失败即 fail-closed，不进入 JNI/MNN。私有 Dex runtime cache 也必须匹配黄金 SHA-256 才允许加载。
