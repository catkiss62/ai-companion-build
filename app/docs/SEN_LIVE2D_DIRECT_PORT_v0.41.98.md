# Sen Live2D 完整移植与黑色剪影根因（v0.41.98）

## 结论

AI Companion 的 +239 已经能创建 Cubism、加载 model3 和全部贴图，但漏掉了 Sen 稳定构建必需的
`patches/cubism-java-no-mipmap.patch`。Sen 的 `NativeTextureManager` 只上传纹理 level 0，不生成
mipmap；未打补丁的官方 `CubismShaderAndroid` 却会在每帧绘制时重新指定
`GL_LINEAR_MIPMAP_LINEAR`。OpenGL 因此把纹理判为不完整并采样成黑色，真机表现正是完整人物网格
轮廓仍在、颜色全部变黑。

+240 把问题误判为 Flutter 合成方式并强制 Hybrid Composition，导致整个 Flutter 画面变黑。该路径
已在本版回退；不再创建新的 TextureView/EGL 实现，也不修改已经验收的 Sen 仓库。

## 直接来源

- Sen 稳定基线：`catkiss62/Sen-Live2D-Companion-Android` `main@336b93af1d96e1dd85799faf3df966600c1224a7`（v0.5.23）。
- Cubism Java Framework：Sen 锁定的 `c2d420012d004b8e61d4c589bd5c34513122f0ea`。
- Sen 主运行时的 16 个 Java 文件在 AI Companion 中保持逐字节一致；测试壳专用的 `MainActivity` 与
  `SenSystemTtsLipSync` 按 Sen 自带接入文档明确不进入最终聊天页。
- Framework 的 105 个 Java 文件保持上游内容，只有 `CubismShaderAndroid` 应用 Sen 仓库原始补丁；
  补丁文件 SHA-256 为 `227d57f649dc29d83066811be84fdb2e7a0969eac8f36a0e1de7dae96b7ffad7`。
- Core AAR、默认 VTS profile 和 36 个 shader assets 继续按既有哈希门锁定；模型 ZIP 仍只在用户本机导入。

## 宿主边界

Flutter 只保留必要外围桥接：模型 ZIP 私有目录导入、生命周期、情绪/动作 ID、服装、眼镜、触摸、
TTS 音量包络与诊断。Sen 的 Renderer、Model、PerformanceEngine、物理、动作曲线和外观参数不在
AI 工程内重写。

眼镜仍调用 Sen 已有的 `applyExpression("glasses")` 开关；桥接层只跟踪目标状态，模型每次重新加载后
至多补一次切换，不向 Sen 核心新增第二套状态接口。情绪特效使用固定舞台锚点，不再为特效位置修改
Sen Renderer/Model。

## 回归门

1. 当前舞台使用标准 `AndroidView`，不得重新出现 `initExpensiveAndroidView`、`AndroidViewSurface` 或
   `forced_hybrid_composition`。
2. `CubismShaderAndroid.setUpTexture()` 必须是 `GL_CLAMP_TO_EDGE + GL_LINEAR`，不得恢复
   `GL_LINEAR_MIPMAP_LINEAR`。
3. Sen 16 文件聚合摘要、Framework 105 文件补丁后聚合摘要、补丁本体、Core AAR、profile 与 shader
   资源均由 `validate_v04198_sen_direct_port.py` 锁定。
4. 构建成功只代表 `CI PASSED / APK READY`；同一台真机确认彩色纹理、透明背景、动作/物理、触摸、
   服装/眼镜、TTS 口型和反复进出页面后，才能标记 `TRUE DEVICE PASSED`。
