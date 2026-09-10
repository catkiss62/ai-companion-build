# Genie v0.6.4 原样移植、崩溃隔离与按需外语 · v0.41.55

状态：`v0.41.55+198 TRUE DEVICE PARTIAL / v0.41.55+199 IMPLEMENTED · CI PENDING`。当前目标：`0.41.55+199 / schema 57 / Snapshot protocol 5`。

## 唯一源基线

- 唯一允许的 Genie 源提交为 `catkiss62/Genie-TTS-Android@5380a536f83aeaec540a9aaa7982149969c73e26`，版本 `0.6.4`。
- 只移植该提交已由用户真机验证的 CPU 8 线程、三语独立前端、自然标点固定分段、首段最多 1 秒 **PCM 写入预填充**、播放上一段时串行生成下一段，以及静音/振动阻止播放。预填充不是额外等待 1 秒墙钟时间。
- 明确排除该提交之后为测试新增的真流式板块、DeepSeek API 真流式联调、动态 token 流闭合及所有尚未真机验收的流式优化。
- 不从 Genie 远端最新 HEAD 取代码。验证器必须同时固定源提交和排除真流式标识，防止后续误升级。

## 原样核心与单一所有者

- `ChineseFrontend`、`EnglishFrontend`、`NativeJapaneseFrontend`、`GenieBenchmarkEngine` 及其模型/张量执行顺序以 v0.6.4 为金标准；伴侣专用导入、诊断、热词和桥接不得继续侵入核心执行类。
- TTS 运行在未加载 Flutter、悬浮窗和后台大脑的私有 `:genie_tts` Android 进程；该进程只有一个引擎、一个串行生成所有者和一个当前语言前端。
- 主进程通过窄 IPC 请求状态、初始化、生成和取消。大体积 WAV 不直接跨 Binder；子进程写入应用私有临时文件，主进程读取后立即删除。一次朗读只建立一个主进程 AudioTrack，第一段写入预填充后开播，后续已生成 WAV 只解析并连续追加 PCM；不得逐段重建 AudioTrack或插入固定 200ms 空白。
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
- `中 / 日 / EN` 只决定当前按需目标语和下一次 TTS 前端，不是播放按钮。切换时停止旧语音并持久化选择，但不朗读当前消息；用户点消息喇叭或下一条自动朗读才会出声。
- 若某条消息已有目标语言缓存，点喇叭后直接朗读；若没有，点喇叭才进入“生成日语/英语”状态，以该消息已经提交的中文 action/dialogue 段做一次关闭思考的自然改写。
- 按需改写只允许看到中文段、kind、情绪标签及必要的称呼字面值；不重新读取对话历史、世界书、Memory、Thought、工具箱或 Agent Outcome，也不重新推演原回复。
- 返回段数、顺序必须与中文完全一致；最终 kind 永远按中文源段落位置恢复，不信任模型可能本地化的 JSON enum（例如 `dialogue → 会話`）。不得改变事实、动作归属、问题、承诺或“操作是否发生”。验证失败不保存、不播放，中文保持不变。
- 成功变体写入现有 `message_language_variants`，以 message id＋language 唯一缓存。以后再次切换不调用 LLM；删除消息和 Snapshot 继续沿用 schema 57 的原子语义。
- 新回复若当前已选日语或英语，可在中文权威正文提交后立即生成当前一个目标语；外语完成前不把中文交给外语 TTS。中文模式没有第二次 API 调用。

## 完成与验收

1. 原样源哈希、排除真流式、单一子进程所有者、IPC 临时文件和 Binder death 均有静态/Kotlin 测试。
2. 默认普通回复不含 `<multilingual_reply>`，中文上下文和既有记忆行为不变。
3. 旧中文消息首次切日/英各只生成一次，缓存后离线切换；失败保持中文且不播放。
4. CI、Flutter analyze/tests、Kotlin、arm64 Release、固定签名和私有资源验证通过后才标 `CI PASSED / APK READY`。
5. 真机先连续播放中文短句，再验英文、日语、停止/切换、旧消息按需外语、长段固定分段、静音/后台和主 App 在 TTS 子进程异常时仍存活。

## +196 真机反馈与 +197 窄修

- +196 已由用户真机确认中文、英文出声；诊断包含连续 `audio_playback/audio_complete`，因此不是模拟通过。日语未出声，现有脱敏报告没有足够事件定位在投影、前端或推理哪一层，+197 保留失败可见性并先修复已知的投影 kind 误翻容错。
- ChatController 的 TTS phase、外语缓存等通知过去都会进入 ChatPage 的通用 `_scrollToLatest()`；+197 只允许真实 stream 内容变化、助手提交或 generation 结束改变滚动位置。
- 普通聊天、沉浸房间和悬浮聊天统一允许点击合成中的 `…` 取消；`playing` 仍显示 `■` 并停止。
- 对照固定 Genie `5380a53` 后确认：声学/前端核心七文件逐字一致，固定分段也一致；旧伴侣播放层的逐段 AudioTrack 与人为 200ms gap 不一致。+197 把播放层恢复为单 AudioTrack 连续 PCM 队列，同时保持生成 worker 单串行、后段立即排队和子进程隔离。
- GPU/NNAPI 不进入 +197。固定 Genie 项目已在目标 Xiaomi 设备测过 CPU、XNNPACK、NNAPI：CPU 8 线程最稳，XNNPACK 出现异常短音频，NNAPI 无收益；若以后重测，必须作为独立实验包按模型逐项 benchmark 与自动回退，不能直接做成默认开关。

## +197 同批默认规则与沉浸格式修复

- 用户备份中的显示分组 05/06/07 实际对应五个稳定规则 key：`04_intimacy_core`、`05_intimacy_rendering`、`06_intimacy_reference`、`immersive_07_global`、`immersive_07_nsfw_source`。五段正文除另行要求删除的年龄边界措辞外保持逐字符一致，并以 SHA-256 锁定；数据库只迁移命中已知旧默认或本次备份哈希的行，其他手改不覆盖。
- “造梗能力”使用备份正文，仅删除同一年龄措辞清理覆盖的一处身份错位示例，激活概率为 50；新安装直接 seed，旧安装仅更新仍等于已知打包默认的条目。
- 当前会注入聊天 LLM 的默认规则、普通/主动提示、沉浸提示、亲密路由、记忆/人格学习和参考资料前言不再加入成年/未成年年龄门。历史常量仅保留用于精确识别旧默认，不是当前 Prompt 来源。
- 沉浸房间弯引号来自代码末端锁与房间默认规则，优先级高于用户提示词。当前 final lock、截断续写锁、全局规则和新建房间默认全部统一为对白 `「」`；旧房间仅在规则仍精确等于历史默认时自动迁移。

## +197 日语真机证据与 +198 窄修

- +197 的新脱敏真机报告中，中文和英文均有完整 `audio_playback/audio_complete`；日语在进入 `initialize_frontend_ja`、`prepare_frontend_ja` 或 `infer_ja` 前即以 `not_initialized / operation_failed` 失败。调用边界将失败点锁定在 `NativeJapaneseFrontend` 构造时的 JNI 库装载，而非日语文本、分段、OpenJTalk 词典或声学推理。
- +198 不再只复用已验证 APK 的 `libopenjtalk_native.so` 而在伴侣项目重编 `libgenie_frontend.so`；CI 从同一份 Genie v0.6.4 APK 同时提取两库，Release 跳过本地 JNI 重编，并在最终 APK 内按字节数与 SHA-256 反查。
- 语言选择移至顶栏 `NSFW` 左侧，可见文字只为“语言 中 日 EN”；点击不触发朗读。聊天面板底部的语音语言说明已删除，但外语消息本身的中文对照仍保留。
- 语速从会改变音高的 PCM 线性重采样改为 `AudioTrack.PlaybackParams`，固定 `pitch=1.0`、仅调整 `speed`。TTS 音量上限提高到 200%，超过 100% 的部分使用 AudioTrack 会话级 `LoudnessEnhancer`，最高约 +6.02 dB；音源已很响时可能触发系统限幅。
- 服务状态增加不含错误原文的 `diagnosticCode`，下次失败可区分真实异常类型。最终 Actions run 817 已通过源码回归、Kotlin/AIDL、Flutter analyze、`709/709` tests、Release APK、固定签名与双 JNI 库成品 SHA 校验；日语恢复与音高/增益体感仍须真机确认。

## +198 真机证据与 +199 依赖闭包窄修

- +198 新报告给出 `frontend_switch_failed / UnsatisfiedLinkError / ja`，证明日语仍在 JNI 装载期失败；随后出现的 `NullPointerException` 是前端未建立后的次生错误，不是首个根因。
- 对 run 817 成品 APK 做独立 ZIP/ELF 检查后确认：`libgenie_frontend.so` 的 JNI 导出与 Kotlin 包名一致，OpenJTalk 六个 C 符号也都能解析；但 `libopenjtalk_native.so` 的 `DT_NEEDED` 明确包含 `libc++_shared.so`，+198 APK 却没有携带该库。
- +199 从同一份真机验证过的 Genie v0.6.4 APK 原样提取 `libc++_shared.so`，与两份日语 JNI 库一同复制、记录大小/SHA 并打包。最终 APK 验证除逐文件字节一致外，还读取 OpenJTalk 与 bridge 的 ELF 依赖表，任何非 Android 系统依赖未出现在 arm64 APK 时直接失败。
- 本窄修不改日语文本、词典、JNI 方法、声学推理、分段/队列、播放参数、UI、Prompt、规则或数据库。CI 通过只能证明依赖闭包和构建完成；首次与第二次日语真正出声仍由真机验收。
