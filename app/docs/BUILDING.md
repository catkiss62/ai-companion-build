# Build / 真机准备

当前交付环境没有 Flutter SDK、Android SDK 或 ADB，所以本包没有声称“已编译通过”。先运行 `python tools/check_android_build_env.py` 可查看缺失工具。源代码按 Flutter 3.44.x / Dart 3.12.x 编写，Android 原生层按 Kotlin + Google Play services Nearby Connections 设计。

## 在标准开发机上的顺序

1. 安装当前 Flutter stable 与 Android SDK。
2. 在项目根目录执行 `flutter pub get`。
3. 如果 Gradle wrapper 文件缺失，用同版本 Flutter 新建一个临时 Android 项目，把标准 `android/gradlew`、`android/gradlew.bat`、`android/gradle/wrapper/gradle-wrapper.jar` 复制进本项目；不要覆盖本项目的 `AndroidManifest.xml`、Kotlin 源码和 Gradle 配置。
4. 执行 `flutter doctor -v`。
5. 连接一台 Android 真机，执行 `flutter run`。
6. 按 `TEST_CHECKLIST.md` 完成权限和功能闭环。

## 注意

- `release` 当前临时使用 debug signing，仅用于原型。正式分发前必须换成私有 release keystore。
- API Key 存在 Android secure storage，不写入 SQLite，也不会通过 Nearby 状态包迁移。手机和平板各配置一次即可。
- API endpoint 同样存在 secure storage；如果两台设备使用同一反代/官方地址，各配置一次。
- Nearby 状态 ZIP 目前依赖 Nearby 链路加密，并额外做 SHA-256 完整性验证；“手动文件导出”的独立 AES-GCM 加密安排在后续。


## v0.4 Native TTS

- 本版已经包含来源 APK 的 TTS native/model/runtime 实体。
- 当前仅打包 `arm64-v8a`，请优先使用真实 ARM64 Android 手机/平板测试。
- 第一次“初始化模型”会把约百 MB 的模型从 assets 复制到应用私有目录，因此安装空间会明显大于 APK 本体。
- 如果初始化失败，请保留设置页显示的最深层异常；优先排查 class/resource/native linker/model path，而不要修改 Companion Core。
- compatibility runtime 通过 app 私有 code cache 动态加载；源码已将 runtime 文件在加载前设置只读。
