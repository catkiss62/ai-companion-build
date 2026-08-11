# v0.6 Internal Validation

执行环境仍没有 Flutter / Dart / Android SDK，因此本轮没有声称执行 `flutter analyze`、`flutter test` 或 Gradle APK 构建。

已实际执行的内部检查：

- Dart 源文件：45
- Kotlin 源文件：15
- Dart 测试文件：9
- 本地相对 import 路径检查：通过
- Dart/Kotlin 词法级括号结构检查：通过
- Android XML 解析：通过
- `pubspec.yaml` 解析与 `0.6.0+6` 版本检查：通过
- SQLite schema v4 -> v5 TTS 设置迁移模拟：通过；不会覆盖已有 `tts_enabled`
- v0.5 -> v0.6 `jniLibs` / TTS model/assets 共 37 个文件逐文件 SHA-256：完全一致
- `NativeTtsEngine.kt` 使用最小 Android/runtime stub 进行 `kotlinc` 语法+类型编译：通过
- TtsSentenceSegmenter 关键测试向量的等价行为镜像：通过
  - 中文跨 delta 成句
  - fenced code 排除
  - fence 被拆跨 delta
  - 超长无强标点 soft split
- ZIP 在打包后另行执行完整性测试。

仍需未来 Flutter/Android 完整工具链或真机验证：

- Dart analyzer / Flutter widget tests 的真实执行
- MethodChannel 多 FlutterEngine 的 Android runtime 行为
- JNI/MNN 真机初始化与语音输出
- AudioTrack stop/pause/resume 实际时序
- 悬浮窗内语音控制体验
