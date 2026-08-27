# 新版妹居本地 TTS 运行时 · v0.39.5

## 来源与边界

- 用户提供：`完整文件(1).zip`
- 源包 SHA-256：`b72ebc8544de88ee368946d2ac824ea1641377ddbe6e2da378d4112c379a9671`
- 当前打包清单：`TTS_RUNTIME_MANIFEST_v0.39.5.json`
- 资源总数：27 个 asset + 5 个 arm64 native library = 32 项
- CI 负载来源：公开试听仓库 `catkiss62/meju-tts-parity-test-android` 的固定
  `runtime-payload-v1` Release（ZIP SHA-256
  `a826452fdf4ef8d86c7d995382ebdf092b3e341357182201a85ab204f06db24c`）及
  固定提交 `ebc128fff5e788a3e7516690ebd7f8bc82a46e2b` 中的 5 个拼音字典

旧版 9 个拆分 runtime JAR、旧目录模型和 `libMNN_Vulkan.so` 已从当前运行路径移除。当前版本使用新版 2 个 runtime JAR、5 个独立拼音字典、`zh/` 模型/预处理目录及 5 个 native library。为避免两个公开仓库重复保存 135 MB 二进制，AI Companion 源码分支不再跟踪这批实体；Actions 在校验/编译前按固定提交、Release 标签和 ZIP 哈希恢复，最终 APK 中仍须通过 32 项逐文件大小与 SHA-256 校验。旧版文档与 manifest 只作为 Git 历史证据，不再参与当前校验。

## 当前调用链

`Flutter Uint8List -> MethodChannel -> NativeTtsEngine -> LegacyTtsRuntime -> LocalTTSEngine(ZH) -> JNI/MNN -> byte[] RIFF/WAV -> AudioTrack`

运行时步骤：

1. 校验 32 项打包资源的大小与 SHA-256；
2. 将 runtime JAR 复制到版本化只读缓存，并把 5 个拼音字典注入 `runtime_01.jar`；
3. 通过隔离的 DexClassLoader 创建 `LocalTTSEngine`；
4. 明确设置 `TtsLanguage.ZH`，再调用 suspend `initialize()`；
5. suspend `generateTTS(text)` 直接取得 `ByteArray` WAV；
6. 校验 RIFF/WAVE 头后交给 `AudioTrack`。

Base64 只保留为兼容异常返回值的解码兜底，不再是 Flutter/Kotlin 热路径的数据格式。

## 分句、并行与停止契约

- 正常分句仍只使用 A2 句末标点：`。！？；.!?;`。
- 分句 N 播放时可预生成 N+1，但播放必须严格按原顺序。
- 新版 ZH 前端限制为 300 phones；只有连续超过 72 字符且没有更早句末标点时才启用安全切分，优先逗号、顿号、冒号或空格。
- 点击正在合成的省略号或停止按钮会失效整条队列：停止当前 AudioTrack，清空未生成/已生成未播放项，正在推理的旧结果返回后也不得播放。
- 情绪音仍只在整条回复开头触发一次，可与第一句 TTS 并行准备；`<emotion>` 标记继续从可见正文和朗读正文中移除。

## 验收边界

静态验证与 CI 负责证明资源完整、方法签名、调用类型、队列契约、Flutter 测试和 APK 内文件哈希。真机仍需验证初始化、中文发音、速度、停止响应、长回复连续播放及耳机/来电等 Android 音频行为。
