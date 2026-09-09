# Genie v0.6.4 原样移植、崩溃隔离与按需外语 · v0.41.55

状态：`DESIGN LOCKED / IMPLEMENTATION IN PROGRESS`。目标版本：`0.41.55+194 / schema 57 / Snapshot protocol 5`。

## 唯一源基线

- 唯一允许的 Genie 源提交为 `catkiss62/Genie-TTS-Android@5380a536f83aeaec540a9aaa7982149969c73e26`，版本 `0.6.4`。
- 只移植该提交已由用户真机验证的 CPU 8 线程、三语独立前端、自然标点固定分段、首段固定 1 秒预填充、播放上一段时串行生成下一段，以及静音/振动阻止播放。
- 明确排除该提交之后为测试新增的真流式板块、DeepSeek API 真流式联调、动态 token 流闭合及所有尚未真机验收的流式优化。
- 不从 Genie 远端最新 HEAD 取代码。验证器必须同时固定源提交和排除真流式标识，防止后续误升级。

## 原样核心与单一所有者

- `ChineseFrontend`、`EnglishFrontend`、`NativeJapaneseFrontend`、`GenieBenchmarkEngine` 及其模型/张量执行顺序以 v0.6.4 为金标准；伴侣专用导入、诊断、热词和桥接不得继续侵入核心执行类。
- TTS 运行在未加载 Flutter、悬浮窗和后台大脑的私有 `:genie_tts` Android 进程；该进程只有一个引擎、一个串行生成所有者和一个当前语言前端。
- 主进程通过窄 IPC 请求状态、初始化、生成和取消。大体积 WAV 不直接跨 Binder；子进程写入应用私有临时文件，主进程读取后立即删除，再复用现有 Dart 固定分段播放队列。
- 子进程 native abort 时，主 App 必须存活；Binder death 转换为真实 TTS 失败并允许下一次重建服务，不能让 UI 永久转圈或声称已播放。
- Manifest 显式使用 `android:extractNativeLibs="true"`，与正常工作的 v0.6.4 APK 对齐。日语 JNI 初始化失败必须返回并持久记录具体异常，不能只留下 `initialize_frontend_ja` 后静默失败。

## 诊断不是独立测试包

- 修复包同时记录 RoBERTa session create/run、encoder、first decoder、stage decoder、vocoder、WAV 和 AudioTrack 的 begin/end。
- 危险阶段记录子进程 PID、PSS/RSS 分桶、当前语言、模型是否已加载和输入长度；不记录聊天正文、模型路径、私人资源或张量内容。
- 诊断与崩溃隔离随正式修复交付，不制作只有日志、没有行为改善的纯检测 APK。

## 中文权威与按需外语

- 每轮普通聊天恢复现有中文最终正文协议；不再默认注入要求一次输出 `zh/ja/en` 的三语 JSON。
- 中文 `messages.content/segments_json` 继续是历史、Memory、日记、关系、检索、Grounding 与 Agent 的唯一权威内容。
- “显示外语”只控制气泡投影；关闭时界面保持中文对照，但仍可用 `中 / 日 / EN` 选择朗读语言。
- `中 / 日 / EN` 同时决定当前按需目标语和 TTS 前端。选日语只准备日语，选英语只准备英语；绝不为了一个目标语言同时生成另一个外语。
- 若某条消息已有目标语言缓存，立即切换正文并从头播放；若没有，按钮进入“生成日语/英语”状态，以该消息已经提交的中文 action/dialogue 段做一次关闭思考的自然改写。
- 按需改写只允许看到中文段、kind、情绪标签及必要的称呼字面值；不重新读取对话历史、世界书、Memory、Thought、工具箱或 Agent Outcome，也不重新推演原回复。
- 返回段数、顺序和 kind 必须与中文完全一致；不得改变事实事实、动作归属、问题、承诺或“操作是否发生”。验证失败不保存、不播放，中文保持不变。
- 成功变体写入现有 `message_language_variants`，以 message id＋language 唯一缓存。以后再次切换不调用 LLM；删除消息和 Snapshot 继续沿用 schema 57 的原子语义。
- 新回复若当前已选日语或英语，可在中文权威正文提交后立即生成当前一个目标语；外语完成前不把中文交给外语 TTS。中文模式没有第二次 API 调用。

## 完成与验收

1. 原样源哈希、排除真流式、单一子进程所有者、IPC 临时文件和 Binder death 均有静态/Kotlin 测试。
2. 默认普通回复不含 `<multilingual_reply>`，中文上下文和既有记忆行为不变。
3. 旧中文消息首次切日/英各只生成一次，缓存后离线切换；失败保持中文且不播放。
4. CI、Flutter analyze/tests、Kotlin、arm64 Release、固定签名和私有资源验证通过后才标 `CI PASSED / APK READY`。
5. 真机先连续播放中文短句，再验英文、日语、停止/切换、旧消息按需外语、长段固定分段、静音/后台和主 App 在 TTS 子进程异常时仍存活。
