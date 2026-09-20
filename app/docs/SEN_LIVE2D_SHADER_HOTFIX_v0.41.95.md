# Sen Live2D Cubism shader assets 热修（v0.41.95）

## 真机故障与根因

v0.41.94+238 首次导入 Sen 模型后，原生 renderer 报错：

`无法读取 Cubism 文件: com/live2d/sdk/cubism/framework/shaders/standardES/VertShaderSrcCopy.vert`

模型 ZIP 已经完成解压并进入 renderer 初始化；失败对象不是用户模型，而是宿主 APK。首阶段移植复制了 Cubism Core AAR、105 个 Framework Java 文件和 Sen 源码，却漏掉 Framework Android 模块独立保存于 `src/main/assets` 的 shader 资源。`CubismShaderAndroid` 固定从上述 assets 路径读取这些文件，因此编译和静态测试可以成功，首次真实创建 OpenGL shader 才会失败。

## 修复

- 从已锁定的 Cubism Java Framework 提交 `c2d420012d004b8e61d4c589bd5c34513122f0ea` 原样复制完整 36 个 `standardES` shader 文件到宿主 Android assets 的相同相对路径。
- 36 文件的按文件 SHA-256 聚合摘要锁定为 `2130c2079aaade0352f3abb2fde51f864a32b01466ea47ee3a9f8fe859b69250`；截图中缺失的 `VertShaderSrcCopy.vert` SHA-256 为 `d56e015be2348f1fd42cf7ccaef7bb869c5cd2095759d1ffc806dddca4339a74`。
- 源码 validator 同时校验文件数、目录层级与聚合摘要，避免漏文件或换行重写。
- Release APK 校验直接打开成品 ZIP，要求 `assets/com/live2d/sdk/cubism/framework/shaders/standardES/` 下恰好存在同一 36 文件，并逐字节等于源码资源；仅“源码目录存在”不再算通过。

本批不改变模型 ZIP 格式、安全导入、动作参数、情绪映射、外观、口型、人格、欲望、记忆、Cedar 或模型调用链。

## 真机验收

覆盖安装且不清数据。旧版已导入并保存在 app-private 的 Sen 模型应直接复用；如果界面仍停留在失败态，可切回静态立绘再切回 Sen，或重新选择同一 ZIP。验收至少确认：不再出现 `VertShaderSrcCopy.vert` 缺失、renderer 进入 ready、模型实际显示并能执行待机/视线/摸头。随后继续执行 v0.41.94 的完整 Live2D 清单。未经真机不得标记 `TRUE DEVICE PASSED`。
