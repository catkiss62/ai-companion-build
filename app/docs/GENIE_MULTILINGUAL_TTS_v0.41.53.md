# Genie 多语普通聊天与本地 TTS · v0.41.53

状态：本地实现完成、静态合同通过；私有 Genie 本体、完整 CI/APK 与真机待完成。基线：AI Companion v0.41.52；Genie-TTS Android v0.6.4。

## 产品状态

- `show_foreign=false`：新回复沿用原中文协议，当前播放语言强制 `zh`。
- `show_foreign=true`：新回复在一次模型回合内生成同一情绪、意图和语义分段的 `zh/ja/en` 自然表达。
- `zh/ja/en` 是显示与语音的唯一语言状态。点击语言先停止旧播放，再切换显示并从头播放该语言。
- 聊天页只保留一条全局 `中/日/EN` 联动控件；旧消息的扬声器按当前全局语言重播，不在每个气泡里重复放三颗语言按钮。
- 日文/英文主视图显示小号中文对照；TTS 不读对照。
- 关闭外语不删除已有版本；旧中文消息不回填翻译。缺版本的语言按钮禁用。

## 数据与生成协议

原 `messages.content` 和 `segments_json` 继续保存中文并作为上下文、Memory、关系、日记、检索、Grounding 和 Agent 承接的唯一真源。日英写入以 message id 和语言为键的独立版本表；备份/恢复必须原子保留。

三语模式使用机器可解析的对齐段协议：一轮只有一个 `<emotion>`，随后每个 `action/dialogue` 段携带 `zh/ja/en`。标签只存在于 Provider 原始正文和 durable checkpoint，最终提交前解析并丢弃。模型可按语言习惯自然改写，但不得改变事实、Agent 操作声称、动作归属、称呼或情绪。

解析失败时优先保护用户回合：中文完整则提交中文并只保存有效外语；中文不完整才走现有生成修复/失败机制。不得用本地翻译器补缺，不得把错误语言交给另一个前端。

## 显示

中文继续使用现有动作白色斜体、对白用户选择色和 `ChatSegment` 动画。外语沿用相同 action/dialogue 类型但使用独立的弱化边框/语言角标；日英主文下方显示对应中文段的小号弱色对照。原始协议标签和包装字符永不显示。

普通聊天和悬浮聊天读取同一 `ChatMessage` 投影；沉浸房间后置。

## 音色与情绪

设置项为 `auto`、`daily`、`gentle`、`lively`、`cute`。固定模式整条回复锁定一个音色。自动模式只消费现有 `TtsEmotionCue`：

- daily：normal、serious、confident、angry、disgust、confused；
- gentle：calm、worried、crying、afraid、nervous、shy、embarrassed、affection；
- lively：happy、excited、surprised；
- cute：playful、helpless、flustered。

低可信 fallback 回到 daily。不恢复 19emo ONNX，不增加第二情绪分类器。

## 队列、分段与生命周期

保留 Dart `TtsPlaybackQueue` 的顺序、抢占、Stop、generation-ahead 和 owner 语义。Genie Provider 使用单一串行推理 worker；Dart 可提前提交，但原生会话禁止并发。

先按 `ChatSegment` 分动作/对白，再在每段内按语言切声学子段：

| 语言 | 目标 | 硬上限 |
|---|---:|---:|
| 中文 | 42 字符 | 54 字符 |
| 日文 | 42 字符 | 54 字符 |
| 英文 | 88 字符 | 110 字符 |

优先完整句号/问号/叹号，再用逗号、顿号、冒号和空格，最后才硬切；不得拆 surrogate pair。实时文本还要在热词/用户发音替换后再执行一次硬上限检查，防止谐音膨胀后超限。播放上一段时生成下一段，首段保持固定一秒预填充基线。

声学 ONNX 会话共用；语言前端容量为一。切换语言时停止 AudioTrack、令旧生成结果失效、释放旧前端，再按需加载中文 RoBERTa、英文 CMUdict 或日语 OpenJTalk。禁止启动时同时加载三套前端。

本批保留现有 Dart 队列：每次只把一个已受 54/110 字符上限约束的句级 WAV 经 MethodChannel 交给独立 AudioTrack worker，避免建立第二套播放队列；是否进一步改成 Kotlin 句柄队列，由真机峰值 PSS 决定。静音/振动必须阻止播放；AudioTrack 使用 `USAGE_MEDIA + CONTENT_TYPE_SPEECH`。

## 资源

- APK 内：Genie 四会话 TTS 本体、四个正式参考特征、CMUdict、OpenJTalk 压缩资源与 JNI；不含备选音色。
- 用户导入：约 352 MB INT8 Chinese RoBERTa，大小和 SHA 必须核对后原子保存。
- APK 排除：旧妹居 27 个资源、5 个 MNN/JNI 库及 19emo ONNX。
- 公开仓库排除：私人原始权重、数据集、参考录音、转换后私有模型负载和用户 RoBERTa 文件。

## 中文热词

`token` 与 `DeepSeek` 使用大小写不敏感的固定音素/谐音覆盖，只改变发音。目标分别为“拖肯（肯弱读）”与“地铺 C 咳（铺、咳轻短）”。需要固定测试混合大小写、标点和连续技术词。

## 验收

自动化覆盖 schema/备份、协议解析、中文权威隔离、缺语言降级、UI 联动、四音色映射、双层分段、串行 worker、前端容量一、Stop/切换、静音和旧资源排除。真机覆盖三语短句、超长单段、500/1000 字回复、切换从头播放、后台恢复、来电/静音与峰值 PSS。
