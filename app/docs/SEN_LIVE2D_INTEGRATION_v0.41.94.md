# Sen Live2D 接入契约（v0.41.94）

## 来源与冻结边界

- Sen 来源：用户自有仓库 `catkiss62/Sen-Live2D-Companion-Android`，提交 `336b93af1d96e1dd85799faf3df966600c1224a7`。
- Cubism Java Framework：该仓库锁定的官方子模块提交 `c2d420012d004b8e61d4c589bd5c34513122f0ea`；Framework 源码与 Sen 已验证补丁按原目录直接编译进同一 Android app。
- Cubism Core AAR SHA-256：`3f05da57ab855e803000e6353888dd561c47758598c6c0200dcd0109312705f8`。许可与可再分发清单位于 `docs/licenses/live2d/`。
- 公开仓库不含 Sen 模型。模型 ZIP 只能由用户通过系统文件选择器导入 app-private 目录。

`SenPerformanceEngine`、`SenLive2DModel`、`SenRenderer`、外观预设与 Framework 是动作/物理真值。本项目不重新调动作曲线；宿主新增内容只负责 PlatformView、生命周期、导入、情绪映射、TTS 波形和聊天 UI。

## 单一所有权与生命周期

聊天页是唯一 Cubism owner：

1. `chat_portrait_mode=sen_live2d` 时实例化一个 `SenLive2DPlatformView`，静态立绘不实例化；
2. 切回静态立绘或页面销毁时，按 `onHostPause → release` 在 GL 线程释放贴图、模型、Shader 与 Framework；
3. Activity `onResume/onStop` 只转发生命周期，不创建第二实例；
4. 系统悬浮宠继续使用 PNG/鲸鱼，本阶段不运行 Cubism；
5. 自动待机唯一 owner 是 Sen 的 `SenPerformanceEngine`，Flutter 没有计时器或第二套自主动作循环。

脱敏诊断使用 `feature=sen_live2d_stage`、随机 `execution_id`、`continuation_owner=sen_view_lifecycle`，记录 created/ready/error/released；不记录模型路径、ZIP 文件名、聊天正文或模型参数。

## 交互与外观

- 自动待机和触摸视线跟随默认开启。
- 摸头完整保留 Sen 参数：模型归一化头区 `0.4927/0.0482/0.7095/0.1088`、至少 120ms、行程至少 `max(34dp, 7.5% 视图宽度)`，离开头区允许 0.08 margin；触发后 10% 使用 `head_pat_confused`。
- 左侧栏提供 `maid / white_shirt / bunny / undressed` 四个按钮和确定性的眼镜开关。衣装层与情绪/动作层分离。
- 用户消息成功写入聊天后只触发本地 `small_nod` 注意/倾听，不分析正文、不增加模型请求；既有 DeepSeek 情绪包随后覆盖为权威语义反应。

## 情绪、效果与声音

现有 `normal + 19` 映射到 Sen 21 情绪：同名直接使用，`nervous → tense`、`crying → sad`、`embarrassed → ashamed`。`romantic_shy` 只在明确选择“脱”的外观时作为视觉演出，不写入消息 emotion、记忆、人格或欲望。

现有 LingChat 情绪短音效继续由原链路一次触发；特效图仍由现有 `ChatEmotionVisual` 选择。Live2D 特效位置每 66ms 从 Sen 已校准的 `ArtMesh151` 动态呆毛根重心点读取，经过当帧 MVP 投影到 Flutter 舞台；锚点不可用时才回退到模型头部上方，不使用静态立绘的固定坐标。

## TTS 口型

`WavAudioPlayer` 在每段 PCM 入队时只保存 256-frame RMS 包络；独立轻量 monitor 每 33ms 读取 `AudioTrack.playbackHeadPosition` 对应的包络并传给 Sen，停止、取消和释放时强制归零。写入进度、生成进度或 Dart 打字进度都不能冒充实际发声进度。

## 导入与回滚

- 上限 8,000 个 ZIP entry、解压后 1.5GB；所有输出先做 canonical-path Zip Slip 检查。
- 在 `staging` 完成解压、model3 识别、JSON 解析与 expression 注册后，才将 `current` 改名为 `backup` 并启用新目录。
- 新模型第一次原生 renderer `onReady` 后才删除 `backup`；若加载报错，恢复旧目录和旧 metadata 并自动重载。进程在确认前终止时，下一次加载仍能确认或回滚。
- 任何导入/渲染失败都不得阻塞聊天、TTS、静态立绘切回或悬浮宠。

## 真机验收

1. 导入用户 Sen ZIP，确认首次加载、杀进程恢复和坏 ZIP/坏 model 回滚；
2. 连续切换静态/Live2D，确认只有一个 GL 实例且聊天面板层级、触摸和返回正常；
3. 验证自主待机、视线、摸头及 10% 彩蛋，四外观与眼镜不互相清空；
4. 用 20 个正式情绪样本确认动作、原特效、原短音效一致，特效随头部移动；
5. 用户发送消息时出现短注意反应，最终回复情绪覆盖；TTS 口型随实际声音且停止后闭嘴；
6. 检查内存、前后台、旋转/重建和连续半小时运行；未经真机不得标记 `TRUE DEVICE PASSED`。
