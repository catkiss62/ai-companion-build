# Internal Validation · v0.7

本文件只记录当前环境能够自动完成的验证，不把未运行的 Flutter/Android 真机测试描述成“通过”。

## 已自动验证

- Dart relative import 路径：通过。
- Dart 字符串/注释排除后的括号结构检查：通过。
- Android XML 解析：通过。
- pubspec / analysis_options YAML 解析：通过。
- SQLite v5 -> v6 新迁移字段/表模拟：通过。
- SQLite v1 -> v6 关键迁移路径模拟：通过。
- 旧 relationship event 升级后标记为历史已内化的迁移逻辑：已检查。
- v0.6 -> v0.7 TTS native/model/runtime 37 个文件 SHA-256：完全一致。
- Reference Library 已纳入 exportAll/importAll，因此进入 Nearby 完整状态包。

## 当前环境未验证

- `flutter analyze`
- `flutter test`
- Gradle APK 构建
- 真机 SQLite upgrade
- 真机 Overlay / Usage / Accessibility / Nearby
- Bert-VITS2/MNN 实际发声

这些继续留到需要真机/完整 Flutter SDK 的测试节点。
