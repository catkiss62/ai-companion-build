# Sen Live2D 原生 Hybrid Composition 失败路线（v0.41.96）

> 当前状态：`TRUE DEVICE FAILED / ROLLED BACK IN v0.41.98+242`。该方案使整个 Flutter
> 合成画面变黑，现仅作为失败证据保留，不得恢复到生产舞台。后续审计确认 +239 黑色剪影的
> 根因是完整移植时漏掉 Sen 构建必需的 `cubism-java-no-mipmap.patch`，并非必须强制 Hybrid
> Composition。

## 真机证据

v0.41.95+239 覆盖安装后，诊断先记录旧实例的 shader `renderer error`，随后新实例完整进入 `created → model_load/ready`。这证明 36 个 Cubism shader 已可读取、模型 Core 已创建、贴图上传流程没有抛错。真机截图同时显示完整的人形网格轮廓和局部矩形，但模型颜色全部变黑。

故障设备为 Android 15 / Xiaomi `25060RK16C`。问题发生在 renderer `ready` 之后，不再属于模型 ZIP、缺 shader 或导入回滚。

## 根因与修复

Sen 原项目把 `GLSurfaceView` 直接放在 Android 原生视图层。首次移植却使用 Flutter 标准 `AndroidView`；该入口优先采用 Texture Layer Hybrid Composition，把平台视图先渲染为纹理，再由 Flutter/Impeller 合成。Flutter 官方平台视图文档明确区分：纹理层是标准 `AndroidView` 的默认路径，而完整 `SurfaceView` 支持应使用 Android 原生视图层的 Hybrid Composition。

本批改为：

- `PlatformViewLink + AndroidViewSurface` 承载 Sen 舞台；
- controller 使用 `PlatformViewsService.initExpensiveAndroidView`，明确强制原生 Hybrid Composition，不允许再次退回 TLHC/Virtual Display；
- 保留原 `SenCompanionView/GLSurfaceView`、Cubism renderer、贴图上传、动作和触摸实现，不以 Flutter Canvas 重写；
- creation params 与脱敏 Native 诊断记录 `composition_mode=forced_hybrid_composition`、`native_surface_view=true`，不记录模型路径或用户内容；
- 继续保留 36 个锁定 shader 与最终 APK 逐字节校验。

Hybrid Composition 的代价是平台视图合成开销可能高于纹理层，但本项目的 Live2D 是单一、固定位置的聊天舞台；Android 15 真机优先保证 `GLSurfaceView` 原生显示正确。聊天、人格、欲望、记忆、Cedar、TTS、模型 ZIP 与 schema 61 均不改变。

参考：Flutter 官方 [Android Platform Views](https://docs.flutter.dev/platform-integration/android/platform-views) 与 [`initExpensiveAndroidView`](https://api.flutter.dev/flutter/services/PlatformViewsService/initExpensiveAndroidView.html)。

## 构建结果

修正一个缺少显式 `flutter/rendering.dart` 导入的编译问题后，Actions `35526854350` 全绿：122/122 源码门、Android/Kotlin 测试、Flutter analyze、901/901 Flutter tests、arm64 Release、签名和成品资源检查全部通过。候选 APK SHA-256 为 `bfad10070630724920cb68815d174e8d230740cfa8489761abf9495e12baeea3`；CI 只证明构建与既有回归成立，不替代同一设备的显示验收。

## 真机验收

覆盖安装且不清数据；当前 app-private Sen 模型无需重新导入。切回静态立绘再切到 Sen 后确认：

1. 模型不再是黑色剪影，原皮肤、头发、眼睛和服装纹理正常；
2. Flutter 背景仍透出，聊天面板和头部情绪特效仍能覆盖在模型上；
3. 触摸视线、摸头、自主待机至少各触发一次；
4. 新诊断的 Sen `created/ready` 事件带 `composition_mode=forced_hybrid_composition`，且没有新的 renderer error。

未经真机确认不得标记 `TRUE DEVICE PASSED`。
