# Build / 真机准备

当前版本、源码提交、实际 CI 与 APK 交付状态以仓库根目录 `AI_Companion_当前总账.md` 为准。修改中或单组测试通过不表示已生成 APK。

## 工具链与本地运行

1. 使用工作流固定的 Flutter 3.44.9、Java 17 与 Android SDK；原生 NDK 为 27.2.12479018。先运行 `python tools/check_android_build_env.py` 和 `flutter doctor -v` 核对环境。
2. 在 `app/` 执行 `flutter pub get`。按 `.github/workflows/build-apk.yml` 的固定版本及摘要恢复所需资源；完整 Genie 模型载荷来自已有私有 Draft，不能用任意替代资源冒充已验证载荷。
3. 运行 `python3 tools/run_validation_suite.py`、工作流中的桥接/原生检查、`flutter analyze --no-fatal-infos --no-fatal-warnings` 与 `flutter test`。清单只读检查 `--check-only` 不等于执行全部源码门。
4. 连接 ARM64 Android 真机，用 `flutter run` 开发；完整 APK 使用工作流中的 `flutter build apk --release --target-platform android-arm64`。仅在恢复了固定 JNI 载荷时沿工作流设置跳过重复原生编译。
5. 按 `TEST_CHECKLIST.md` 和当前版本定向场景做真机检查；记录实际通过范围。CI 的受控模型和模拟器回归不能替代长期后台、音频观感等真机验证。

## 测试 APK 签名与交付

CI 只恢复原有私测签名。签名 Draft、资产、密码或固定证书核验失败时停止，不自动生成替代身份。最终 APK 必须通过 `apksigner`，证书与既有交付一致，并实际核对包内包名、versionName 和 versionCode。

本地未提供私有签名环境变量时，Gradle 保留 debug 签名以便开发；它不能作为同签名覆盖安装包交付。用户测试 APK 只上传未发布 Draft，附源码 SHA、CI、APK SHA-256 和证书指纹；既有公开 Release 不允许被此测试工作流覆盖。

## 数据与离线载荷

- API Key 和 endpoint 存在设备 secure storage，各设备单独配置，不将凭据写入 SQLite 或仓库。
- Nearby 传输已经退休；当前迁移使用已实现的加密手动存档流程。备份协议与 schema 以实际源码及总账为准，升级版本不能自行跳过兼容验证。
- APK 仅包含 `arm64-v8a` 原生载荷。初次初始化会将模型复制到应用私有目录，安装空间会大于 APK 本体。
- 固定载荷的字节与资源完整性在打包后再次核验。初始化失败应保留设置页最深层错误用于定位 class/resource/native linker/model path，不随意更换已验证推理引擎。
