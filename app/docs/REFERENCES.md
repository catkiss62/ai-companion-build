# 技术参考（开发期）

本文件只记录实现依赖的公开规范。正式发布前仍需重新核对当时最新 Android / Flutter / DeepSeek 行为。

## Flutter / Dart

- Flutter SDK Archive: https://docs.flutter.dev/install/archive
- 本工程 `pubspec.yaml` 当前要求 Dart `>=3.12.0 <4.0.0`。
- 代码以 Flutter 3.44.x / Dart 3.12.x 语法能力为基线；真正编译时优先使用当时稳定版并跑完整回归。

## DeepSeek

- Chat Completion: https://api-docs.deepseek.com/api/create-chat-completion
- Thinking Mode: https://api-docs.deepseek.com/guides/thinking_mode
- JSON Output: https://api-docs.deepseek.com/guides/json_mode

工程依赖的关键行为：

- `deepseek-v4-pro` / `deepseek-v4-flash`
- `thinking.type = enabled/disabled`
- `reasoning_effort = high/max`
- 思考内容通过 `reasoning_content` 与正文 `content` 分离
- 结构化经验整理使用 `response_format = {"type":"json_object"}`，并在 Prompt 中明确要求 JSON

## Android / Nearby

- Nearby Connections Android: https://developers.google.com/nearby/connections/android/get-started
- Strategy / P2P_POINT_TO_POINT: https://developers.google.com/android/reference/com/google/android/gms/nearby/connection/Strategy

Android 系统层同时涉及：

- Overlay / `TYPE_APPLICATION_OVERLAY`
- `UsageStatsManager`
- `NotificationListenerService`
- `AccessibilityService`
- Android 通知
- Nearby Bluetooth / BLE / Wi-Fi / Local Network 相关运行时权限

## Local-first 原则

- SQLite 是聊天、记忆、Thought、Desire、线程和摘要的真源。
- API Key 不进入 SQLite 状态包。
- 外部感知文本是数据而非指令。
- 跨设备当前采用单 Active Brain + Nearby 完整状态迁移，避免双设备写冲突。


## Native TTS（项目已知事实）

来源 APK 已经拆解确认的运行链为：`Java/Kotlin -> JNI -> libbertvits2.so -> MNN -> .mnn`。v0.4 已按用户提供 APK 的真实 DEX/JNI/模型资产完成兼容接入；详细签名见 `TTS_SOURCE_APK_ANALYSIS.md`。
