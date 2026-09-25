# AI Companion · 当前总账

更新时间：2026-09-25（UTC；+262 CI 与 APK 完成）

> 本文件是唯一的当前接班入口，继续采用“总账 v2”。顶部是快速接班索引；标记后的正式记录按版本持续追加，不设总容量上限。
>
> 判断优先级：用户最新明确决定 > 当前 GitHub 源码与 Actions > 同时刻脱敏真机诊断/备份 > 本文件 > 冻结归档与 Git 历史。`DESIGNED`、`IMPLEMENTED`、`CI PASSED`、`APK READY`、`TRUE DEVICE PASSED`、`PENDING` 必须严格区分。

## 1. 接班协议

1. 新窗口先读本文件顶部至 `END QUICK HANDOFF INDEX`，再读取当前任务对应的正式记录、`app/docs/DOCUMENTATION_MAP.md`、当前分支/版本、最近提交和直接涉及的源码/测试；旧问题按索引定点查正文、归档或 Git 历史。
2. 每次正式修改前在“当前任务”登记目标、证据、保护边界与验证；完成后回填实现、提交、CI/APK、真机状态和下一步。
3. 容量约束只用于保持顶部快速索引简洁；标记后的正式内容没有字节上限，不因文件增长强制删减或滚动。自然阶段边界、操作性能明显下降或需要不可变证据快照时才建立只读归档。
4. 已有冻结归档：
   - `app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md`：1,587,679 bytes；SHA-256 `602c712f0fb06e70c054c2d54fe0e280f312923864040a3a177ee8e7da67ed70`。
   - `app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.84+228.md`：98,372 bytes；SHA-256 `47d053d842a73e3ff8107dabe867bd503e8a7e77daaecc2afb1867068faa952c`。它是压缩前当前总账的逐字节快照，包含 +219～+228 的完整诊断、设计、实现与 Actions 证据。

## 2. 永久产品与工程边界

- **主体性优先**：事实与安全 Gate 约束虚假完成、越权、凭据泄漏和不可逆损坏，但不把她训练成处处等待批准的被动工具。
- **模型/API 双通道**：内部判断、维护、工具规划与 Outcome 核验走 DeepSeek；双模型模式只在收齐整轮上下文和真实工具结果后调用一次独立的 OpenAI-compatible 第二通道形成可见回复。第二通道地址和模型可由用户配置，默认仍是原玩游 Gemini 地址与模型；非 Gemini 模型不得收到 Gemini 专属 `google.thinking_config`。MCP 网络请求不是模型调用。
- **Jev 决策层（修改模型路由前必看）**：已有 OpenRouter `typesafe/jev-1.13` 的可选短判断入口，默认关闭；普通聊天互动/主动玩笑与沉浸房间模式/事件各用一次批量 Choice 判断。发现封闭选项、短状态、可度量误判成本的语义判断时，要主动告诉用户 Jev 候选位置；确定性逻辑仍由代码处理，复杂计划、工具执行/真实结果核验和自然回复仍由 DeepSeek/最终通道负责。**Jev 的任何新增决策都必须保留真实 DeepSeek 兜底**：关闭、无 Key、低信心、无效结果、网络/额度/超时均回到原 DeepSeek 判断，取消不重复调用；不得静默猜结果或将 Jev 结果当工具已执行事实。先比较同一批样本的准确率、延迟、实际费用和增加的请求次数，再启用新路由。详见末尾 +260 Jev 专节及 +252 现有接入。
- **真实工具事实**：只有成功的真实 Outcome 能支持“已进入、已落子、已发送、已保存、已完成”。失败、blocked、no_result、超时或零调用不能由对白补写。
- **唯一循环所有权（未来功能开工前必查）**：每个会连续推进的能力必须只有一个 continuation owner，并在设计时写清 `execution_id`、唯一触发源、一次唤醒最多规划轮数/工具调用数/真实 mutation 数、终止条件、Stop、崩溃/主后台切换后的恢复规则。用户回合、后台 cadence、工具 Outcome、UI 轮询和平台 callback 可以提供事件，但不得各自继续同一 execution；`next_call / continuation / resume_after` 是权威事实，不是再启动一条循环的许可。Cedar 曾经让前台 Agent 循环、后台游戏循环和 Outcome 续接同时推进，造成重复调用、Token 暴涨、终局丢失与 Stop 不彻底；此事故模式是永久踩雷样本。
- **循环能力首版诊断（随功能一起交付）**：任何新的 MCP、工作区、视频、提醒、Live2D 长任务或其他可续接能力，第一版就必须以脱敏方式记录 `feature / execution_id / trigger_source / continuation_owner / phase / planning_rounds / tool_calls / committed_mutations / continuation_requested / terminal / preempt / late_write / usage_lane`。诊断不得保存 Prompt、Thought 私密正文、密钥、房间凭据或用户文件内容；没有这组证据，不允许靠继续加 retry/delay 猜修循环。
- **Cortico 低风险参考（未来功能设计索引）**：参考项目为 `https://github.com/Pal-AI-Lab/Cortico`。只吸收两个边界思想：一是外部环境通过“可观察事实 + 可执行工具”接入，World/事件事实不直接等于聊天、记忆或成功声明；二是把 `preempt / flush / debounce / piggyback` 当作按功能选择的投递语义词汇。当前项目不移植 Cortico 的中央 Event Stream、World 容器、完整队列/状态机或记忆连续性取舍，不推倒现有自主逻辑。新增能力逐项建立小型隔离适配层即可：输入只形成验证过的观察，执行只经现有 Agent/Outcome 真值链，是否进入对话、短期桥或长期记忆仍由本项目现有策略决定。
- **Cedar 信任优先**：实时 catalog、玩家指南、合法动作、`next_actor / next_call / revision / legal_actions / resume_after`、防沉迷和终局以服务端为权威；APK 不以本地猜测覆盖。
- **Cedar 盲玩隔离**：运行时只使用 Cedar 玩家接口、当前聊天、正常存档与玩家可见 Outcome；`playerSafeGuide` 不得泄露仓库、源码、隐藏状态、题库答案、攻略、剧透或外部网页。游玩链不暴露 `public_web.search`。
- **自然语义 Agent**：允许“陪我下五子棋”等自然表达触发模型自主发现；普通“看看”不是联网授权。Cedar 的账号级 `allow_self_reset` 服从网站设置。用户已决定暂不增加 Agent 确认弹窗，直到未来加入修改/破坏性能力再设计确认。
- **媒体 Agent**：她能发送的媒体必须同时具备自读能力、可执行工具、真实附件 Outcome、来源 provenance 与发送后第一人称历史；只在 UI 或 Prompt 声称不算完成。
- **隐私与发布**：Token、绑定码、私密房间正文、用户附件、诊断、备份、模型权重和参考音频不得进入公开 Git/Prompt/公开诊断。用户持续授权推送明确开发分支并运行常规 Actions/Draft APK；不含合并 `main`、正式 Release、删除分支/用户数据、改变仓库权限。
- **冻结范围**：桌宠当前无确证问题；Live2D 等待新模型测试，不在当前批次恢复。+249 的 Decoder 零新语义防护继续保留；+250 将日常持续会话计时移为手动 TTS 专项对照，并实现双形态气焰值。普通回复表情包已真机重新出现，未发现概率数值漏洞时不强改。

## 3. 当前基线

| 项目 | 当前事实 |
|---|---|
| 仓库 | `catkiss62/ai-companion-build`；Flutter/Android 工程位于 `app/` |
| 功能基线 | `agent/v04184-agent-loop-autonomy-closure`，`v0.41.84+228 / schema 61 / Snapshot protocol 6` |
| 功能状态 | `CI PASSED / APK READY / TRUE DEVICE PENDING` |
| +228 远端 | head `29e87d016c8bd81f52f89f95191bd1a1a01a5b57`；tree `c4a112a56d8b634cf3a1a66636979a0833538b7d`；Actions `35440359036`；Artifact `10583263879`；APK SHA-256 `159e283173e49da2924d25b37ba7647893cdafdcc31b63f0e31b7c64e086849b` |
| 仓库维护基线 | `maintenance/repository-governance-20260919`；远端文档 head `123e272196e8ae93f3518157917d76f6af4f1784`；完整构建 head `fa99f32012fa1a0716b746d36b958a8e777ef9b8`；Actions `35446649873` 全绿；文档-only run `35447342921` 正确跳过 APK |
| 当前功能分支 | `agent/v04217-breakthrough-wheel-smooth`，基于 +261 全绿 APK；候选版本 `v0.42.18+262` |
| 当前任务状态 | `+262 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；主动聊天双模型单次 Gemini 正文及 DeepSeek 兜底、满气焰持续判断、轮盘五格虚拟卷轴；Actions `36173105843` 全绿，详见末尾 +262 |
| +250 当前任务 | 本体／小豆丁形态共用成年角色、记忆与能力；同一形态状态驱动角色提示与静态立绘，虚拟弹额头／安抚改变气焰值后继续自然衰减，心形液面与锁定入口；常驻世界书定点柔化并仅迁移未编辑原文；两档 TTS 共用冻结的真实回复与分段，无声生成并复制专项脱敏报告 |
| +250 最终构建 | 功能 head `b5cd2d1070fb237bc72ab66b1867a75da9bbe6e8`；tree `4e0dbbd531aea408ab0face6d46a323f441c7eeb`；Actions `35943607609` 全绿；Artifact `10785922926`；APK SHA-256 `f148f2eb303017ad5f6f689628f230979c24ba16831fdc0181e58bc5e1d73a`；未发布 Draft Release `v0.42.6-dual-form-tts-comparison-test` |
| +249 当前任务 | `loopIndex=0` 时明确判定“零个新语义 token”，在 VITS 前拒绝本段；最后两次会话记录生成时 profile、冷/热状态、各阶段耗时、RTF、播放首帧、队列余量、迟到段、失败/停止与脱敏文本哈希 |
| +249 保护边界 | 不播放参考 prompt、不添加固定语音/固定台词/System TTS 兜底；失败段独立跳过，其他段继续；仅同一文本、音色、语言且分别为 `legacy_fixed_8` / `auto_affinity_v084` 才计算性能对比；schema 61 / Snapshot protocol 6 不变 |
| +249 远端 | head `fb7f77f85d882f99530ab829df9a82eaa604e559`；tree `28e4fbafb5adb2bfaa58aa9ab6e1b1256f0c4b99`；Actions `35900627244` 全绿；Artifact `10770090214`；APK SHA-256 `546dd718d447b0987bf47aaba08089fefb0badffbc076ba38e695fb3e05263c5`；未发布 Draft Release `untagged-3a02088d4968fd7ab603` |
| +248 远端 | 远端 head `33647c7bff15084d6fd3cbc7b817e9b0b216f75c`，tree `80f49d8e93bcfe2a03737a6b8610fbd94d10c255`；Actions `35878106718` 全绿；APK SHA-256 `04a588d2d4628ccaacd1b0b9aaf3759430b46ba33ad69715cb388098c178f0be`；未发布 Draft Release `untagged-2b371d8cd86b365121b0` |
| +248 当前任务 | TTS 默认关闭的“自动核亲和加速”开关；四个声学会话与 Chinese RoBERTa 同用 `AUTO_AFFINITY`。生成中展开全部工具活动，完成后以脱敏卡片绑定回复，中止后绑定中断标记 |
| +248 保护边界 | 保留现有分段首段预填充、串行生成与连续 AudioTrack；不移植测试档、动态分块、FTZ/DAZ、输入映射复用或 memory-pattern 实验；工具卡不保存/展示参数、搜索词、URL、结果正文、Prompt 或隐藏推理；schema 61 / Snapshot protocol 6 不变 |
| +247 当前任务 | `nativeToolDefinitionsFor` 在路由结果的可变边界先建立防御性 `Set` 副本；覆盖纯图片与原生表情包 `content=''`、`promptContent` 非空且 Cedar 已配置的回归，不改千问视觉、`sticker_index`、模型策略或最终回复内容 |
| +247 保护边界 | 只修共同崩溃点与回归门；不把表情包接入识图，不改变 Cedar 阶段选择、工具权限、schema 61、Snapshot protocol 6、人格、欲望、TTS 或 Live2D；不合并 `main`，不发布正式 Release |
| +247 远端 | 功能 head `8fabae5016a7d457b58a581a7a2b609bc0ab69c8`；tree `fc7ca8d84dadabf33dc1f151895f52c42b62ce72`；Actions `35855141996` 全绿；Artifact `10747841131`；APK SHA-256 `6a5d04b79fba46139b16bb185f955fb87431e1b30c4f75f89a09788054b89bab`；未发布 Draft Release `untagged-376e1bf8ac7aac97af25` |
| +246 当前任务 | 识别中的图片允许立即删除，迟到的千问结果不得复活消息或报错；`403 Free quota exhausted` 明确归类为额度耗尽；`please` 不再误命中 `lease`；普通备份冻结不再显示“她正在换设备”。表情包仍使用本地 `sticker_index`，不新增视觉调用或固定回复兜底 |
| +246 保护边界 | 不修改 Sen/Live2D、人格、欲望、Cedar、TTS、schema 61 或 Snapshot protocol 6；不合并 `main`，不发布正式 Release |
| +246 远端 | 功能 head `167a504f4974ef11566b8ac974ab9e7281f00fc0`；tree `2f8c733bb1c80f078bb5b71f88e7b2a3287e8448`；Actions `35843632708` 全绿；Artifact `10742996195`；APK SHA-256 `d4c609c0836427155b9f73a6cf629c45f6cff4d88f801be5b4def828839546c2`；未发布 Draft Release `untagged-d99196e0bf0a288629ac` |
| +245 当前任务 | 21:00～次日 09:00 所有主动来源共享最多一次成功投递；“我会玩游戏”不再误授权 Cedar，前台真实游玩与后台共用局次/疲劳/满足账本；千问视觉新增真实连接测试与鉴权分类；TTS 只保留参考音频不可逆声学签名，高置信回声直接拒绝播放且没有固定音频/台词兜底 |
| +245 保护边界 | 不修改独立 Sen 仓库或已回退 Live2D；不增加对话模型调用；表情包继续使用本地索引语义进入当前 user prompt；schema 61 / Snapshot protocol 6 不变；不合并 `main`，不发布正式 Release |
| +245 远端 | head `09a50bdf14cfc1f5850c4c055fcbeade1b9dedb2`；tree `0985f0961691bdce7e6d521d59a12137ea5a82ad`；Actions `35809712355` 全绿；Artifact `10729507323`；APK SHA-256 `4c6f92b38bb3affa12aa52ae18d2d36276400d706b3a570e154d75e453d08059`；未发布 Draft Release `394245028` |
| +244 远端 | head `c16955ad0a8eeb3945d95c8b42372859d6ab09b8`；Actions `35642646319` 全绿；Artifact `10659441135`；APK SHA-256 `e58122e12f1cc412ff29eccbf0575bb0ae73ba6b524419ea774ad2f5a3dc5684`；未发布 Draft Release `393217151` |
| +244 当前任务 | 以 +237 的共享文件为机械基线回退 Live2D，同时保留 +241/+242 自然回复修复；删除 Sen 服装、预设、动作、情绪、PlatformView、Cubism AAR/Framework/shader 与 TTS/视线/摸头接线；聊天快捷面板永久提供带确认的旧模型包清理按钮，只能删除 App 私有 `filesDir/sen-live2d` |
| +243 当前任务 | 启动只加载服装而不批量启用全部原生预设；只显示三套服装、脱与眼镜；20 种聊天情绪接入，脱/NSFW 使用 `romantic_shy`；原生待机、摸头/彩蛋和当前 PCM TTS 口型保留；人物与特效共用位置/缩放；Flutter 全局触点驱动视线；输入法只挪动聊天面板，不改变 Live2D 原生表面尺寸 |
| +242 当前任务 | 不允许任何本地固定台词以她的身份替代模型回复；用户轮不能被校验器吞成空回复，主动轮可不发送；Sen `main@336b93a` 只读，AI 内的 16 个 Sen 主运行时文件逐字节一致，唯一 Framework 差异只能是 Sen 原始 `cubism-java-no-mipmap.patch` |
| +240 真机结论 | `PlatformViewLink + AndroidViewSurface + initExpensiveAndroidView` 没有修复黑色剪影，反而使整个 Flutter 合成画面变黑；该方向已在 +242 回退。复核 Sen 构建流程后确认 +239 黑色剪影根因是移植时漏掉 `cubism-java-no-mipmap.patch` |
| +240 失败路线 | 仅保留历史证据；当前生产舞台不得出现 `PlatformViewLink`、`AndroidViewSurface`、`initExpensiveAndroidView` 或 `forced_hybrid_composition` |
| +240 远端 | 构建 head `bdae0d3897efe49c251c6d4a2ecfb4a035afa188`；tree `4ef513abf3cbcd20db61357ee5bf4172868474ac`；Actions `35526854350` 全绿；Artifact `10609559197`；APK SHA-256 `bfad10070630724920cb68815d174e8d230740cfa8489761abf9495e12baeea3` |
| +239 真机结论 | shader 缺失已修复：同一模型在 +239 进入 `created → model_load/ready`，未再出现 shader renderer error；但标准 `AndroidView` 合成后显示为黑色剪影，因此整体 Live2D 呈现继续由 +240 验收 |
| +239 远端 | 构建 head `6223c66a09850f950b9646990459133ea8661d32`；tree `f9dd8e3ea303e92bf0862bce03a2384b542fb109`；Actions `35523577868` 全绿；Artifact `10608368899`；APK SHA-256 `897e5163b31fd8950f1e6c97c03f3e20d4d82c7d804aed1a9cf5c6172bee7287` |
| +238 当前任务 | 原样保留 Sen 已真机验证的 21 情绪、自主待机、视线跟随、摸头彩蛋、物理、三套衣服+脱与眼镜；与静态立绘互斥，接入现有情绪效果/音效、用户消息倾听反应和 TTS 波形口型；不改悬浮鲸鱼、人格/欲望真值或模型调用次数 |
| +238 远端 | 构建 head `eba2c185507743f1a50f5758e722f1d8a57b0bbd`；tree `7c0cb89a0de3a03f8d0862c570bffe3615d9fb77`；Actions `35521027339` 全绿；Artifact `10608496160`；APK SHA-256 `1b2376eb57fd8250fb5d8370ef7a1a03fb28e30e0176da059fdc71576e60d67c` |
| +237 当前任务 | 将未完成游戏事项、旧 ASSISTANT 场景与真实 Cedar 游玩状态分开：没有当前成功 Outcome 时只能说“还没玩/想去玩/之前玩过”，不得虚构正在钓、等待咬钩或图鉴刚才没涨；兼容纠正 +236 前已持久化为 attachment 的游戏 thread Thought |
| +237 远端 | 构建 head `0caa9382a472b53f574302064b387b527efae6df`；tree `70cf7225714f0514a7ee385f01cf1e3a499b4acf`；Actions `35509919804` 全绿；Artifact `10605181041`；APK SHA-256 `294b341ddc8354389717566aa83a7ed10bba6891f107f7df34f3bfd76c653cc2` |
| +236 当前任务 | 吸收欲望系统 2.0 的可验证因果账本与竞争诊断，不引入女性向保护欲或第二套欲望真值；把游戏“上瘾”改为可被心境、新兴趣与饱和打断、冷却后可重新点燃的短时投入；过滤 `not_due` 空候选、统一游戏语义域并区分游玩与分享 |
| +236 远端 | 构建 head `8ab3beb8997cb146a8499d00acfdf726e2121a2f`；tree `910c3950d354734adca82c58b5db8559fbbcb861`；Actions `35506384676` 全绿；Artifact `10604605761`；APK SHA-256 `b2aad7f827c64e82e58cd88d71db6690c721941d684abe40c80eee537d52bf22` |
| +235 当前任务 | 保留现有昼夜身体疲劳与连续 `rest_need`，新增有界、短时的正向激活与负面难安静调制；自主主动消息和 Cedar 真实推进在高疲劳时积累睡眠债，经过真实安静窗才回补；用户主动聊天始终正常回应，不新增循环、不改 schema、人格、世界书、最终回复通道或 TTS |
| +235 远端 | 构建 head `8ecbcbcaab339fc4ecd0b9c616db2ceacdc83d16`；tree `ee125bd9967b277975decec70b551ba1c7e7918b`；Actions `35501928714` 全绿；Artifact `10602523875`；APK SHA-256 `1489ba5a886d3323f1b68ca913a8f5d166f68133d7786974c04c514abf10e628` |
| +234 当前任务 | Cedar 五槽事实、已有/turn 0 存档续玩、已知空槽自主开档与破坏性覆盖确认边界；将固定玩游 Gemini 选项改为“`双模型（自定义最终回复）`”，地址/模型可编辑并以旧值预填；不改 schema、人格、疲劳、TTS 或内部 DeepSeek 通道 |
| +234 远端 | 构建 head `16589fc8a88574f5a77f0731f8972e65fe990538`；tree `60060c335ba1b064c950ea97a5274bd5fa06f7b5`；Actions `35498575549` 全绿；Artifact `10601008319`；APK SHA-256 `38aadaa9ffb1f2ac3ddac85fffc9311f4c9c75950692130b7c29eee3fa9210f3` |
| +233 当前任务 | 先修 Cedar Outcome Thought 的事件身份、一次分享与时间锚定；再做愿望单安全主题投影；最后只做语义等价的 DeepSeek 缓存观测/低风险优化。三部分独立提交与验证门，不改人格、疲劳、Cedar 玩法/循环所有权或 Gemini 按次回复链 |
| +233 远端 | 构建 head `2892e67d91652b3d8cdec6a989c8467ed0193764`；tree `36747406e22a5accd35f879d7284a0d3370e5a7c`；Actions `35475970152` 全绿；Artifact `10593264636`；APK SHA-256 `ffe58c0dc10f145ec4ce91489478b3b9327304aab8aa1b39a02f58b13229f6e3` |
| +232 目标 | 游戏厅“最近进展”窄面板复用“游戏活动”同款 Card 颜色；愿望单按安全主题表达并合并同主题活动愿望；登记 Cortico 低风险参考、唯一循环所有权与后续诊断护栏；不改 Agent 循环、疲劳、缓存、TTS、schema、世界书或人格 |
| +232 远端 | 构建 head `3783aa7ccae0d547d4a0a1c18d4f388c398be574`；tree `54da8912e76ce5d59ec142387f1708a972196640`；Actions `35469452065` 全绿；Artifact `10592781832`；APK SHA-256 `ccb0352275d197592b1fd5b9a1ca479f89ec21101f472b234e85f8f7d5968622` |
| +231 远端 | 构建 head `75d9e0a311d5b322f53a742b9016aac16d44c9d9`；tree `2b337e3b4d23a1c4bdc097ee999fc569ddafb7fe`；Actions `35464168272` 全绿；Artifact `10591085711`；APK SHA-256 `1b10c1f49f0d192913c2f15e9f46345160cc2c0ee22acf751eb6755a70a3e565` |
| +230 远端 | 构建 head `6c53a40b5d7413942c12ca84001bb66205c160d1`；tree `9c3674e87f37798964e293b1ffdeaedf4e582c74`；Actions `35458277355`（attempt 2 全绿）；Artifact `10589621373`；APK SHA-256 `de27ec0c0146ef3a879f0bb9d8ae2c06dbfdc3225d8f6694fe8e01c7c5ab8d4a` |
| +229 远端 | 构建 head `0f4ffc6c2b08a310a5f04919a045c98b2e8e63e3`；tree `9e0913202787feca13462c07fdd0941f10d0d4b9`；Actions `35450357850`；Artifact `10587305305`；APK SHA-256 `acbd5c81be69c5c27ae2822ea112fb2b0639a00636b61af7b0f642c02fbcddc6` |
| `main` | 仍为 v0.38.5 旧基线；不得作为 v0.41.x 起点，本批不合并 |

历史兼容与未来扩展索引：`v0.41.82+226` / `agent/v04182-cedar-state-machine-e2e`；`v0.41.83+227` / `agent/v04183-cedar-native-agent-loop`；`v0.41.81+225`；`模型自主发现`；`陪我下五子棋`。全工具调用动作展示已进入 +248；双人格与命运之轮的冻结分析见 6.21，均不得在本批顺手实现。任何新 MCP、工作区、视频理解、Live2D、提醒或长任务先查本文件的 **“唯一循环所有权”**、**“Cortico 低风险参考”** 与 **“循环能力首版诊断”**，不得再复制 Cedar 曾出现的多套循环。

+252 工作分支 agent/v04208-jev-game-result，候选 v0.42.8+252：OpenRouter Jev 两处短判断与 DeepSeek 兜底；保留 +251 气焰语义判断、TTS 和 Gemini 修复；Cedar get_result 不再凭旧结果生成新分享。余额面板延后；详情见 6.25。状态 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。\n\n+253 工作分支 agent/v04209-tts-preflight-heat，候选 v0.42.9+253：快速自检只读取 APK 安装资源；TTS 子进程超时重置绑定并一键顺序无声对照；气焰 0～100 每轮 -10、满值五轮冷却退出，害羞本身不加分。前批 Jev/DeepSeek 兜底不变；详见 6.26。状态 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。

+254 工作分支 agent/v04210-audio-heat，候选 v0.42.10+254：情绪音效改用媒体音量通道，硬件音量键控制媒体；轻微玩笑净降 6 点，互相挑衅需明确升级；Jev 回退诊断按题区分不确定与格式错误。紧急存档事件：+252 06:40 诊断仍有 422 条记忆、1 条会话、旧设备/谱系指纹，+253 08:44 诊断变为 0 条记忆、0 条会话、状态代数 0、新指纹，证明启动了新数据库；本份报告不含闪退栈，不能归因于 TTS 或声称旧库可恢复。06:39 外部 .aibackup 是已知恢复候选，恢复前保留原件且禁止卸载/清数据。状态 IMPLEMENTED LOCALLY / CI PENDING / TRUE DEVICE PENDING；详见 6.27。

+256 工作分支 `agent/v04212-form-pitch-zero`，候选 `v0.42.12+256`：气焰只在 0 自动退出小豆丁，严肃话题仍认真回应；设置音调是小豆丁基准，本体低 1 半音。沿用 +255 已真机恢复的单一试听和发声链，保留锁定与手动安抚。状态 IMPLEMENTATION IN PROGRESS / CI PENDING / APK PENDING / TRUE DEVICE PENDING；详见末尾 +256。

<!-- END QUICK HANDOFF INDEX -->

## 正式记录（无容量上限）

## 4. +228 已完成、只等待真机验收

- Agent 循环重大回归已收口：前台首次成功 mutation 后结束本轮，后台每 cadence 仅一次规划/一次真实推进；普通聊天不再被活跃游戏自动注入整套工具。DeepSeek usage/cache 已按 lane 记录，诊断查看 `modelUsage.byLane`。
- `CedarExecutableCall`、唯一房间 `rooms → full state → replan`、陈旧 session 水合、终局恰好一次 handoff、`recent_game_episode` 有界短期桥接已实现；不新增吞掉 preference/shared_experience 的顶层 game memory kind。
- 单人游戏进入疲劳/昼夜 Gate 与可衰减饱和仲裁；实时共玩承诺不参与竞争。没有伪造各游戏固定概率或硬每日配额。
- 自主网页能力注册、完整来源证据束、普通“看看”误路由、Stop 贯穿 search/extract/压缩/appraiser、FishArchive 有界换候选、自主相册来源已修复。
- 主动联系以真实普通消息后 10 分钟滑动静默窗推迟；不消费 Thought、分享候选或频率额度，不把新话题改写成 followup。
- `screen_on / screen_off / user_present` 已切分 screen session；长熄屏前活动只能作为低置信度短时历史，不能跨会话冒充持续使用。
- “调皮”收窄到真实逗弄/故意曲解/恶作剧/小挑战；音效在第一段可见正文提交时一次触发；刷新回复恢复跟随最新并锚底。
- 用户新版“性格光谱”已作为内置 preset，SHA-256 `fcc1074203b31cdf36466b39b3b6b08b5abd7497855155c31558177242dfe0fb`，仅保守迁移仍等于旧内置 hash 的记录；规则 05 已加入“每一段动作、神态之后都需要配一段对话。”。

真机必须继续验证：一次聊天不出现多次 Cedar mutation；后台每 cadence 至多一步；真人回合仍及时回应；终局只交付一次；普通“看看氧气瓶”不联网；明确网页查询能引用实际页面证据；Stop 无需杀后台；自主网页/相册恢复；熄屏一小时后不说成连续使用；主动新话题在静默 10 分钟后仍送达；刷新锚底；音效与正文同帧。

## 5. 当前任务：v0.41.85+229 Cedar 结构化远程媒体桥

历史实现分支：`agent/v04185-cedar-media-bridge`。

### 已登记证据

- 最新旅行备份中 `cedar_toy.play` 成功，文本 Outcome 内有多个真实 HTTPS `photo_url`，但事件为 `content_kinds=[text]`、`image_data/viewer_url` 为空，最终消息没有 `assistant_mcp_image`。下矿存在同类协议能力。
- `AgentToolRunner._cedarImageAttachments` 和 `CedarToyActivityStore.recordPlay` 只消费 MCP 标准 `type=image` Base64 block；嵌在结构化结果或 JSON 文本中的明确媒体字段只被当文字。
- 这是 APK 的缺失桥接，不是 Cedar 网络失败、模型忘记发图或游戏厅活动窗识别错误。

### 本批目标

1. 只从 Cedar 成功 Outcome 的协议明确媒体字段提取 HTTPS 图片候选，支持结构化 object/list 以及文本 block 中可安全解析的 JSON；不得扫描自然语言中的任意 URL。
2. 复用现有安全公开图片下载边界：HTTPS、重定向、MIME、字节签名、大小与超时保护；每步限制数量并去重。不得为附件触发 `public_web.search`。
3. 下载一次得到的不可变字节同时用于 `MessageAttachment` 与 Cedar activity/history，避免聊天图、活动窗图和模型所见内容不一致。
4. 任一候选失败只保留真实文本/失败分类，不得声称图片已发出；取消后不得迟到写回。标准 MCP Base64 image 行为不得回归。
5. 增加固定回归：旅行 `photo_url`、下矿等价字段、嵌套 JSON、任意正文 URL 拒绝、非 HTTPS 拒绝、重复/超量、下载成功/失败、附件提交、活动记录、Stop/迟到写入。

### 保护边界

- 不改 Cedar 玩法、回合策略、概率、房间身份、revision、棋步或防沉迷；不写死真机 URL/房间/附件文件名。
- 不扩大为通用网页抓图，不改变公共联网授权判断；不把远程 URL 长期当附件，必须先固化受检字节。
- 本批不处理桌宠、TTS、表情概率、`main` 合并、正式发布或历史清理。

### 验证与完成标准

- 修改前后运行当前总账门、+228 与新增 +229 专项门、全部 validator、`git diff --check`、Flutter Analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查。
- Actions 与 APK 完成后才可写 `CI PASSED / APK READY`；真机必须分别看到旅行/下矿成功附件和失败降级，才可写 `TRUE DEVICE PASSED`。

### 本地实现与验证（2026-09-19）

- 新增 `CedarOutcomeMediaBridge`：只解析成功 Outcome 的明确协议媒体字段与完整 JSON 文档；拒绝正文 URL 扫描、HTTP、重复项和超量项，最多固化 3 张远程图片、单次 Outcome 总附件最多 4 张。
- `AgentToolRunner` 在 Cedar execution fence 内完成安全下载、字节签名检查、附件固化、Stop 清理与 activity 引用写入；标准 MCP Base64 图片路径保留。单张远程图片失败只降级为真实文本 Outcome，不伪造“已发送”。
- `CedarGameEvent.imageReference` 与聊天附件共用同一个持久媒体引用；活动窗优先读取该引用，旧 `image_data` 仍兼容。
- 新增 `cedar_outcome_media_v04185_test.dart` 和 `validate_v04185_cedar_outcome_media.py`；验证清单已登记旅行、下矿、失败降级、Stop 和诊断证据。
- 本地已通过：109 项 validator manifest 检查、当前总账门、+228/+229 专项门、相关历史门、Python 语法检查、Workflow YAML 解析与 `git diff --check`。本机没有 Flutter/Dart SDK，完整 Analyze/tests/Android Release 必须由 GitHub Actions 判定；在 Actions 成功前保持 `CI PENDING`。

### Actions 与交付证据（2026-09-19）

- 首轮 Actions `35449949853` 在 Flutter analyze 发现新增测试文件末尾误留重复 `import`，构建按预期阻断；已删除该指令，并把“声明后不得再出现 import”加入 +229 专项门，没有绕过分析器。
- 修复后的 Actions `35450357850` 全绿：109 个源码门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/塔罗载荷、Artifact 与 Draft 上传均成功。
- 构建 head `0f4ffc6c2b08a310a5f04919a045c98b2e8e63e3`；tree `9e0913202787feca13462c07fdd0941f10d0d4b9`；Artifact `10587305305`，ZIP digest `16978dba71bc9b581b47f3e2be4113762819a636015fa7a8e417eaa37c3ec024`，大小 `538,036,212` bytes。
- Draft Release `392107130`；APK asset `574973863`，大小 `544,913,702` bytes，SHA-256 `acbd5c81be69c5c27ae2822ea112fb2b0639a00636b61af7b0f642c02fbcddc6`；稳定测试签名未变。
- 当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。仍需真机分别验证旅行与下矿返回真实图片时：聊天附件出现、活动窗显示同一内容、失败只保留文本、Stop 后不迟到补图。

## 6. 后续待办与观察项

### 6.1 2026-09-20 MCP 真机结果后的前置设计记录（已由 6.2 覆盖）

> 本节保留 +230 开工前的证据与设计推导；其中 `PENDING IMPLEMENTATION / PENDING INTEGRATION` 是当时状态，当前事实以 6.2 的已实现、Actions 与真机回填为准，不得再从本节重复开工。

- **MCP 当前结论**：用户已真机确认双弈五子棋完整打通，正常自然语言也能让 Agent 查看/调用 MCP；可把 MCP 主链视为基本完善。该结论证明双弈共玩与 Agent 执行链，不自动替代旅行/下矿远程图片桥的专项验收。
- **游戏兴趣轨迹冻结**：不增加每游戏固定概率、复杂好感/受挫轨迹或新的顶层“贪玩” Drive。模型可依据实时目录、指南、局面、结果和 Cedar Thought 自然形成临时偏向；花园与猫咪等内容较少的游戏可自然失去吸引力，但不伪造持久偏好。
- **游戏重新竞争方案已接受（DESIGNED / PENDING IMPLEMENTATION）**：单人游戏保留短活动惯性；每累计 3 次真正改变远端状态的成功 Outcome，或活动持续 25 分钟（先到者为准），到达一次 episode checkpoint。checkpoint 后把同一局作为可恢复的 `resume_game` 候选，重新与公开网页发现/分享、普通主动联系、休息和沉默走既有 Desire/Thought 仲裁；其他行为胜出时只暂停、不丢远端存档。实时共玩在合法轮到 companion 时继续履行回合承诺，但服务端防沉迷仍是权威硬边界。不得每一步随机换游戏，也不得把“近似并列采样”扩大成纯随机竞争。
- **相册边界**：相册候选处理当前在 Cedar 推进前运行，并非直接被游戏关闭；但游戏每轮成功后会跳过普通主动联网/聊天，可能让网页图片来源枯竭。恢复统一竞争后先观察来源是否恢复，不单独提高相册保存概率。
- **Cedar 防沉迷一手证据（OFFICIAL UI / PENDING INTEGRATION）**：官网设置实际按“连续游玩轮数”计数，不是按连续分钟计数；页面默认 30 轮提醒、50 轮锁定、锁定 30 分钟后自动重置，也允许网页手动重置，存档不受影响。账号开关 `allow_self_reset` 只代表允许小机自行重置，不代表 APK 应自动重置。
- **现有实现与缺口**：休闲模式本地步进间隔为 2 分钟，快速/观战为 5/10 秒；它与服务端轮数/锁定计数是两层机制，本身不冲突。项目已把平台 `rest / announcements / vote` 交给 Cedar 服务端最终授权，并明确 `rest` 只能用于真实防沉迷提醒/锁定；但尚未把提醒、锁定、剩余时间或重置结果解析成持久状态。现有 `recordPlatformAction` 在 session 仍可继续时会于成功 `rest` 后约 1 秒再次推进，不能直接作为最终防沉迷闭环。
- **防沉迷建议（DESIGNED / 等用户最终选择）**：服务端提醒应强制形成 episode checkpoint；服务端锁定时移除普通 `resume_game` 并把游戏 defer 到权威恢复时间。若网站真实返回 `allow_self_reset=true`，可额外生成带明显继续成本的 `self_reset_and_resume` 候选，与联网、主动联系和休息同场竞争；只有它真实胜出才调用一次 `rest`，随后开启新 episode 并恢复正常 2 分钟休闲节奏，禁止 1 秒续跑。没有真实提醒/锁定证据时不得主动猜测或调用 `rest`。
- **最新同刻备份/诊断证据**：`2026-09-20 00:43` 备份和诊断中没有任何 Cedar `rest` 防沉迷动作或自主重置事件；出现的钓鱼“重开新局”属于游戏存档重开，不能当作防沉迷重置。诊断仍显示曾有 `recentActionCount=24 / saturationPenalty=0.28 / playScore=0.8613 / restScore=0` 的继续游玩判定，支持“活动后只和休息竞争”的结构性根因。
- **TTS 音色小改（DECIDED / PENDING IMPLEMENTATION）**：只把“高兴”从“活泼”改为“可爱”；其余情绪映射不动。
- **TTS 参考语音问题（DIAGNOSTIC FIRST）**：用户已确认现象更像播放/复现 `jiuhu_bento_tools.wav`，不是模型随机串入日语。当前生产调用链没有 `playReferenceAsset` 调用者，临时输出也使用 UUID，不先猜测根修。下一批先扩展脱敏诊断：记录语言、voice key、reference case id、清理前后字符类别计数、有效音素数、首轮立即停止、语义 token 数/哈希、输出 PCM 时长/哈希及 `reference_echo_suspected`；不记录正文。四套参考语音 `jiuhu_bento_tools / jiuhu_dream_days / jiuhu_idle50 / jiuhu_devotion` 统一覆盖。拿到同一时刻诊断后再决定是否修复标点/空音素、立即停止强塞 token 0 或输出回声拦截。

### 6.2 v0.41.86+230 实施登记（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

历史实现分支：`agent/v04186-autonomy-tts-diagnostics`。

本批只实施用户已经确认的三组变更：

1. TTS 自动音色只把 `happy / 高兴` 从 `lively / 活泼` 改为 `cute / 可爱`；其他情绪、固定音色、情绪音效和声学模型不动。
2. TTS 只增强脱敏诊断，不在本批猜测根修或阻断输出：覆盖四套 reference case，记录 voice/reference id、输入与前端规范化后的字符类别计数、有效音素、Decoder 首轮停止、语义 token、输出 PCM 时长/哈希及基于退化推理证据的 `reference_echo_suspected`；仍不得写入正文或参考音频路径。
3. 单人 Cedar 活动增加持久 episode checkpoint：每 3 个成功且真正改变远端状态的 Outcome，或 25 分钟先到者触发。checkpoint 只暂停本地续步，不结束、不换局、不损坏远端存档；`resume_game` 回到现有 Desire/Thought 统一选择，与网页发现/分享、主动联系、休息和沉默竞争。实时共玩承诺保持原优先级。

防沉迷实现边界：只解析服务端明确的结构化提醒/锁定/恢复时间/`allow_self_reset`，以及明确包含“防沉迷”的文本提示；普通游戏冷却或失败不得误判。提醒强制 checkpoint；锁定期间移除普通恢复候选。仅当真实证据同时表明提醒或锁定且 `allow_self_reset=true` 时，才提供带明显分数成本的 `self_reset_and_resume`；胜出后只调用一次平台 `rest`，成功后开启新 episode，并按当前休闲/观看节奏继续，禁止旧有成功后 1 秒续跑。没有证据不得调用 `rest`。

明确冻结：不增加“贪玩” Drive、不建立复杂游戏兴趣/受挫轨迹、不修改每游戏概率、不扩大 Agent 确认弹窗、不处理 TTS 声学根因、桌宠、`main` 合并或正式 Release。

完成门：新增纯策略回归与运行链回归；更新当前总账门、版本与测试清单；运行全部 validator、`git diff --check`、Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查。只有 Actions 全绿后才写 `CI PASSED / APK READY`；TTS 参考音频和单人 episode 仍需真机报告后才能升级为 `TRUE DEVICE PASSED`。

本地实现与验证：

- `happy` 已单独迁到 `cute`；`excited/surprised` 保持 `lively`。四 reference case 的脱敏 checkpoint/运行诊断已加入原始/规范化字符类别、有效音素、Decoder 次数/首轮停止、语义序列、PCM 时长/哈希和回声怀疑标记；没有增加输出拦截或声学猜修。
- 新增 `CedarSoloEpisodePolicy` 与 `CedarAntiAddictionParser`。episode 状态保存在 settings，不改 schema；只计成功的非只读、非平台、非退出远端动作。第三步或 25 分钟触发 checkpoint，`resume_game / self_reset_and_resume` 进入既有 selector；后者必须同时满足真实防沉迷信号与 `allow_self_reset=true`。普通游戏锁定文本有负例保护。
- `rest` 的后台执行增加本地证据门；成功后由原 1 秒改为当前 viewing pace（休闲默认 2 分钟）。恢复同局若本次真实推进失败，会恢复 checkpoint 并延后 8 分钟，不把失败当成已开启新 episode。实时共玩判定和回合优先级未改。
- 新增 Flutter 纯策略测试、Kotlin TTS 证据测试、+230 跨模块源码门，并更新 110 项 validation manifest、工作流、版本和真机清单。本地逐项运行 110 个源码门：107 个通过；另外 2 个只因仓库按治理规则未携带 CI 才恢复的桌宠/LingChat 私有资源包，1 个只因本机无 `kotlinc` 未运行。`git diff --check`、Python 编译、Workflow YAML 与 +230/+229/+228/总账专项门通过。本机无 Flutter/Dart/Gradle 分发，完整编译测试仍由 Actions 判定。

Actions 与交付证据：

- 构建 head `6c53a40b5d7413942c12ca84001bb66205c160d1`；tree `9c3674e87f37798964e293b1ffdeaedf4e582c74`。首轮 Actions 仅在恢复 LingChat 私有视觉资源时遇到远端 `curl (35) Connection reset by peer`，尚未进入编译；不改业务代码，按同一 run 重跑失败任务。
- Actions `35458277355` attempt 2 全绿：110 个源码门、Kotlin 桌宠/悬浮层与新增 TTS 证据测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/塔罗载荷、Artifact 与 Draft 上传均成功。
- Artifact `10589621373`，名称 `AI-Companion-v0.41.86-230-Autonomy-TTS-Diagnostics-APK`，大小 `538,050,951` bytes，ZIP digest `899a04d4819a6751c41b60a3ada9e62607bb2b7f30dc4969ec874adfac0ce25e`；APK SHA-256 `de27ec0c0146ef3a879f0bb9d8ae2c06dbfdc3225d8f6694fe8e01c7c5ab8d4a`；稳定测试签名 SHA-256 未变：`30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-4c16dc23432898cc5020`；本批未合并 `main`、未发布正式 Release。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

真机回填与非阻塞观察（2026-09-20）：

- 用户已确认“高兴”实际使用“可爱”音色，TTS 自动音色映射这一子项升级为 `TRUE DEVICE PASSED`；不代表参考音频疑似复现问题已经根修。
- 单人 episode checkpoint、游戏与联网/主动聊天/休息/沉默重新竞争，以及 Cedar 防沉迷提醒、锁定和自主重置，均转为低优先级“保留等待测试”。夜间不专门诱发游戏；以后上传自然使用形成的存档和同一时刻诊断时顺带核对，不阻塞下一开发任务。
- 旧总账的 Phase 3 状态保持原判：3A 已 `TRUE DEVICE PASSED`，3B 核心链已 `TRUE DEVICE PASSED / OBSERVING`；3C 的消费注入后来已撤出当前运行能力并暂停待重审，因此不把“Phase 3 重要链已通过”误写成“Phase 3 全部能力仍启用且全部通过”。

### 6.3 旧总账去重后的唯一后续任务清单（2026-09-20）

本节已对照当前源码、`DOCUMENTATION_MAP.md`、截至 +218 与 +228 两份冻结总账去重。旧章节中的“下一步 / PLANNED / PENDING”若已被后版完成、撤回或替代，不再自动复活；以后排期只从本节取。

#### A. 可直接进入开发的任务

| 优先级 | 任务 | 当前准确范围 |
|---|---|---|
| P1 | 设置“帮助”与真实能力清单 | `v0.41.87+231 TRUE DEVICE PASSED`：页面直接消费当前 `AgentToolRegistry`，并整理 `【检查系统】`、联网/网页阅读/图片、查手机、Cedar、Stop、备份恢复、TTS、权限隐私、故障排查与明确限制。用户确认入口与内容正常，且 UI 干净美观；其分节层级、图标、留白、克制的卡片色和可折叠说明作为未来全局 UI 美化的参考方向。 |
| P1 | 本地 Genie TTS 推理速度实验 | 当前生产基线是 CPU 8 线程，旧真机已证明 XNNPACK 会出现异常短音频、NNAPI 无收益。先在独立 `Genie-TTS-Android` 测试工程用同设备/同模型拆出前端、语义 Decoder、声码器、WAV 与冷/热启动瓶颈，并比较 4/6/8 线程、`PerformanceHintManager`/线程优先级、大核调度提示、session/张量缓存和分段预生成；只有证据稳定的引擎级方案再移植到伴侣项目做一次集成 A/B。最终必须是默认关闭的“快速推理”开关，关闭即回到当前路径，并具备温度、功耗、峰值内存、音频完整性、音质与自动回退门。普通 App 不承诺 root 级硬件超频，也不直接恢复已否证的 XNNPACK/NNAPI。 |
| P1 | 全工具调用动作展示 | 把目前 Cedar 已有的活动可见性扩展为统一、脱敏的工具运行状态：搜索、读网页、读系统/记忆/查手机、图片保存/发送等显示“正在做什么/成功/失败/已停止”，不展示 Prompt、密钥、私密参数、房间凭据或内部推理；不改变工具权限与 Outcome 真值。 |
| P2 | 通用 MCP Registry 与未来工作区 | Cedar 专用 MCP 已完成，但通用 `mcp.invoke` 仍为不可执行占位。未来按只读优先分批实现 Server 注册、能力目录、权限、审计、超时、取消、凭据隔离和可卸载；需要处理工作任务时再设计独立合理工作区。OAuth、社区工具与 stdio/Harness 不与陪伴数据库直接混用。 |
| P2 | 真实提醒 | `reminder.schedule` 当前仍为不可执行占位。若开工，必须落到 Android 真实调度、可取消/去重/恢复并有真实 Outcome，不能只靠聊天承诺“到时提醒”。 |
| P2 | 记忆/人设/规则修改提案 | `memory.propose_change / personality.propose_change / rules.propose_change` 当前均不可执行。以后只先做可审查 diff 提案；写入、删除或其他可破坏操作必须增加确认、版本与回滚，当前只读 Agent 不增加多余确认。 |
| P3 | 视频理解 | `video_understanding.inspect` 仍为占位。以后独立评估短片抽帧、预算、临时文件隐私、取消和结果持久化；不冒充当前已能看视频。 |
| P3 | Live2D 反应接入 | 模型、动作和素材已在独立 Live2D 仓库完成；伴侣侧以后专门设计“LLM 语义反应 + 本地低延迟关键词/事件反射 + 动作仲裁/冷却/打断”，避免只等完整 LLM 回复才动，也不得让关键词层直接改写人格或对话。完成基础 P1 后再立专项版本。 |
| P3 | DeepSeek 缓存命中优化 | `v0.41.89+233 CI PASSED / APK READY / TRUE DEVICE PENDING`：已补齐细分 `usage_lane`、body-free 段落顺序/长度/哈希观测，并对工具 schema 做语义等价的确定性 key 排序；没有重排提示词、删记忆或冻结实时状态。后续只在真机积累足够样本后按 lane 对比 `recentPromptShapes` 与 hit/miss，再决定是否存在可证明、低风险的第二步 A/B；Gemini `final_reply` 仍不纳入。 |
| P3 | 疲劳与心境的小幅耦合 | 保留昼夜节律主基线，单独评估负面心情导致难入睡、兴奋/聊天愉快/玩嗨短时压住疲劳的有限偏移；必须有幅度上限、短时衰减、睡眠债回补和防止夜间无限续航。排在 +232 真机包之后，优先在北京时间 2026-09-21 下午至晚上、或后续相同自然时段开专项，便于观察从白天到夜间的真实曲线；不在 +232 顺手改公式。 |

#### B. Phase 3C 与 Phase 4 的准确含义和评估门

- **Phase 3C** 已由用户确认属于持续优化方向中的旧阶段编号，关闭独立待办。3A/3B、Thought、Share Seed、统一自主竞争及后续兴趣/分享调整已经承接它真正关心的“长期偏向会影响自主选择”；+210 的具体消费注入又已在 +211 撤回。因此以后不再以“重做 Phase 3C”排期，只在出现新的、可复现的兴趣连续性问题时按当前架构处理。
- **Phase 4** 是人格成长路线的可选末段，不是基础能力缺口：只在高影响歧义、连续反证或用户主动谈及时低频澄清一次；MBTI、契合度、AI 自拟小测试等只作为娱乐与低权重 `test_result / self_report / inference`，不得一次测试直接改写人格事实。开工前要先判断 Cedar 游戏、普通主动聊天和现有学习证据是否已经覆盖娱乐互动需求，以及澄清是否会让她变成问卷机器人。Phase 3C 没有必要恢复时，Phase 4 也可以作为独立可选功能评估，不再机械等待旧阶段编号。
- **情绪引擎扩建**不再是基础待办：最小 `Appraisal → Emotion Episode` 已在 v0.37.5 实现。只有自然证据持续证明缺少混合情绪、恢复轨迹或多事件调度，并且固定回放有量化收益时，才按 `EMOTION_ENGINE_EXPANSION_EVAL_v1.md` 增加一个模块；否则保持现状。

#### C. 保留等待测试（不阻塞开发）

| 项目 | 以后如何顺带确认 |
|---|---|
| +229 Cedar 远程图片桥 | 旅行/下矿自然返回图片时，核对聊天附件与活动窗是同一内容；失败只保留文本，Stop 后不迟到补图。 |
| +230 TTS 参考音频 | “高兴→可爱”已真机通过；仅当参考音频疑似复现时立即导出同一时刻诊断，用四 reference case 的新证据定位，不猜修。 |
| +230 游戏竞争与防沉迷 | 随以后存档/诊断核对 episode checkpoint、统一竞争、同局恢复、提醒/锁定、`allow_self_reset` 和自主重置；夜间不专门诱发。 |
| +228 自主性与屏幕时间线 | 继续自然观察 Token 账单、主动联网/相册、10 分钟静默窗、长熄屏、刷新锚底、表情/音效时序；出现异常才提交同刻证据。 |
| Phase 3A/3B 长尾 | 跨日期兴趣成熟/撤销/新鲜度，以及额度耗尽或能力关闭时的 capability defer 随自然数据观察；核心真机状态不倒退。 |
| Memory 2D 与 D6 媒体备份长尾 | 精确取消/自然主动回忆/工作话题占比，以及删除媒体后的备份、重复迁移、相册引用保护、缓存删除和跨机恢复，有自然样本再回填。 |
| 低概率显示/状态问题 | 表情发送占比、duel“轮到你”、偶发多余 `「`、TTS/桌宠异常均只在明确复现后窄修，不靠概率猜测。 |

#### D. 冻结、可选或需用户重新排期

| 状态 | 项目 | 决定 |
|---|---|---|
| `REMOVED FROM BACKLOG` | MiniMax 在线语音 | 用户确认当前本地小酒狐 Genie TTS 效果更好，MiniMax API、在线/本地双引擎选择、在线音色筛选与 emotion 映射全部从后续任务删除。冻结归档中的 MiniMax 只保留历史证据，不得再次自动排期。 |
| `FROZEN` | 当前屏幕像素观察与自主截图 | 现有 `screen_observation.inspect` 曾在视觉 Provider 前失败；先补系统截图 capability/阶段诊断才可重开。自主截图仍未实现，不因知道 App 名称而声称看见屏幕。 |
| `FROZEN` | HyperOS 文件选择器/系统导航键/悬浮间歇卡死 | 指三类旧真机原生问题：系统文件选择器偶发输入/返回挑战、系统导航键后悬浮层恢复异常、部分 App 切换时桌宠/悬浮层间歇消失或卡死。当前没有持续复现，项目末尾如重开，先取得输入挑战、动画心跳、window generation 与 enter/exit 时间线，不再叠加 retry/delay。 |
| `OPTIONAL` | 主动消息直接带表情、GitHub 灵感库、X/Telegram Provider | 都是新增能力，不是当前概率回归。只有用户再次选择才设计；普通回复表情、通用公开网页和现有媒体链继续保持。 |
| `OPTIONAL` | 手机主存储/平板伴随端、完整换肤、产品化发布 | 独立大型路线，不进入当前陪伴核心维护。平板伴随端先依赖未来视频理解/“陪玩或陪看”能力的正式定义，当前不预判具体方案；`main` 里程碑晋升与正式 Release 仍需用户明确授权。 |
| `MAINTENANCE` | 当前契约文档合并 | 可逐步把人格、Somatic、Inner Drive 重叠文档合并为当前契约；不改变 App、不阻塞功能开发。 |

#### E. 已完成、不得从旧总账重复开工

- Phase 0+1 审查、Phase 2A/2B、Phase 3A、Phase 3B 核心链；Memory 2D 主链、Dynamic Moe D2/D3、最小 Emotion Episode、查手机七日心情/购物车/侧栏、公开网页完整阅读与分享、Agent 自身系统读取、Agent v2、表情和双向图片、Cedar MCP/双弈/终局/连续循环、+228 Agent 循环与自主性收口、+229 远程媒体桥、+230 episode/防沉迷和 TTS 诊断均已有实现或明确状态。
- 角色扮演持续性由用户确认已解决：根因是旧输出模型理解能力与文本表现，切换 Gemini 为文本输出口后不再复现；从冻结任务删除，除非出现新的可复现证据不得重开。
- `PENDING / PLANNED` 只出现在冻结归档的历史段落时，不足以证明今天仍是任务；必须先与本节和当前源码核对。

### 6.4 v0.41.87+231 帮助页与游戏厅活动窗（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

历史实现分支：`agent/v04187-help-cedar-activity-ui`。

本批范围：

1. “全部设置”新增“帮助与真实能力”。普通聊天与自主工具清单直接读取运行时 `AgentToolRegistry` 的 `executable/userTurnAvailable/autonomousAvailable`，避免静态帮助把占位能力写成已可用；同时说明 `【检查系统】`、Stop/刷新、网页/图片/查手机、Cedar、本地 TTS、备份、权限隐私、故障取证和当前明确限制。
2. Cedar 活动窗“最近进展”改为居中 84% 宽度的窄卡片，左右保留外层滚动命中空间；文本仍可选择，最多 12 行的现有边界保持。
3. 活动记录继续显示三行摘要，但增加点击详情；详情可滚动查看完整 summary、动作、时间、图片和该事件 viewer URL，不执行游戏动作、不修改 session。
4. 不改变 Agent 权限/自然语言路由、Cedar 指南/循环/防沉迷/概率、数据库 schema、TTS 运行时、世界书、人格或 `main`。

本轮追加设计记录：Phase 4 继续作为可选人格澄清/娱乐测试，不因 AI 偶尔自然提问而强制开工；需要另查自然问题的用户资料写入证据链。TTS 快速模式先在独立 TTS 工程做引擎基准，再将证实有效的方案以默认关闭开关移植；Live2D 反应接入与疲劳—心境小幅耦合均登记为独立后续任务，不与 +231 混改。

Actions 与交付证据：

- 远端功能提交 `75d9e0a311d5b322f53a742b9016aac16d44c9d9`，tree `2b337e3b4d23a1c4bdc097ee999fc569ddafb7fe`；`main` 未修改。
- Actions `35464168272` 全绿：111 个源码/历史回归门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传均成功。
- Artifact `10591085711`，名称 `AI-Companion-v0.41.87-231-Help-Cedar-Activity-UI-APK`，大小 `538,056,010` bytes，ZIP digest `f64bbe778527f0a6ca3851394f6e398b2322f1cdba53af56d7ffc1050a3e012b`；APK `544,935,646` bytes，SHA-256 `1b10c1f49f0d192913c2f15e9f46345160cc2c0ee22acf751eb6755a70a3e565`。
- Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-83ba209cc91853c32913`；仍是测试 APK，不是正式 Release。真机只需验收帮助页入口/内容、最近进展左右滑动命中区和活动记录详情。

真机回填：用户确认本批功能正常；帮助页入口和内容没有问题，排版被确认为干净美观。最近进展窄面板的左右拖动范围与活动记录详情均通过，唯一追加意见是窄面板颜色应与上方“游戏活动”Card 完全相同，该视觉收口进入 +232。

### 6.5 v0.41.88+232 愿望单主题身份、Cedar 同色卡片与扩展护栏（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PARTIAL`。

历史实现分支：`agent/v04188-wishlist-cedar-card-guardrails`。

本批范围与证据：

1. Cedar 活动窗保留“最近进展”居中 84% 宽度与左右外层拖动命中区，但面板从单独猜测的 `surfaceContainerHighest + border` 改为和“游戏活动”完全相同的 Material `Card`；不改文字、12 行边界、活动状态或游戏执行。
2. 愿望单固定句的根因已经定位：旧实现仅按 `drive_key` 返回一句固定正文，且活动愿望只按 `source_thought_id` 去重；同一钓鱼主题产生多个生命周期 Thought 时，会被当成多个不同愿望并重复显示“想认真找点没见过的新鲜东西看看”。
3. +232 以 `drive + canonical safe topic` 作为活动愿望身份，统一 `cedar_game:fishing` 与 `shared.activity.fishing` 等明确同主题别名；同主题的新 Thought 会接续并重绑定原愿望，不增加第二条。正文只从 drive、topic key 与 provenance 分类生成，明确禁止读取或呈现 Thought 私密正文。已完成历史只迁移展示版本，不伪造完成、不强制增加愿望数量；原有 6 小时新增冷却、每日预算、强度/复现/基线与满足条件保持。
4. 将 Cortico 参考地址与“观察事实/执行工具隔离、按功能选择投递语义”写入永久边界；同时将 Cedar 多循环事故提炼为“唯一循环所有权”和首版诊断要求。只增文档护栏，不引入中央 Event Bus、World 容器、完整队列/状态机，也不修改现有 Agent/Cedar 循环。
5. 明确不改：数据库 schema、世界书/用户已修改的性格光谱、人格、Desire/Thought 生成与满足逻辑、Agent 权限/自然语言路由、Cedar 玩法/防沉迷/竞争、TTS、疲劳公式、DeepSeek 缓存实现、`main` 或正式 Release。

真机验收只看三点：进展窄卡颜色是否与“游戏活动”一致；旧固定愿望在一次正常“查手机”刷新后是否迁移；同一钓鱼/旅行主题反复形成 Thought 时活动愿望是否只保留一条且正文能说明主题。不得为了造样本修改真实欲望或游戏偏好。

本地验证：+232 专项门、Workflow YAML、Python 编译与 `git diff --check` 通过；逐项运行 112 个源码/历史门，109 个通过。其余 3 个与本批代码无关：仓库按治理规则不携带 CI 才恢复的 417 文件桌宠源码包与 LingChat 特效包，本机也没有 `kotlinc`；Actions 会在恢复资源和安装工具后执行完整 Flutter analyze、Flutter tests、Kotlin 测试与 arm64 Release 构建。

Actions 与交付证据：

- 远端构建 head `3783aa7ccae0d547d4a0a1c18d4f388c398be574`，tree `54da8912e76ce5d59ec142387f1708a972196640`；`main` 未修改。首次分支创建 run `35469348788` 被随后用于确保 push 事件的同树 CI 提交按 `cancel-in-progress` 正常取消，不是编译失败；权威结果只取新 head。
- Actions `35469452065` 全绿：112 个源码/历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。
- Artifact `10592781832`，名称 `AI-Companion-v0.41.88-232-Wishlist-Cedar-Card-Guardrails-APK`，大小 `538,061,525` bytes，ZIP digest `de6b7f2fd789d3d3e0d195ab7f6a6851fcb834aa783955bd8d33d3462b549aea`；APK SHA-256 `ccb0352275d197592b1fd5b9a1ca479f89ec21101f472b234e85f8f7d5968622`；稳定测试签名 SHA-256 未变：`30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-8043368def99d2e0f7b0`；仍是测试 APK，不是正式 Release。

真机回填与持续观察：

- 游戏厅“最近进展”卡片颜色已确认与“游戏活动”一致，升级为 `TRUE DEVICE PASSED`。
- 旧固定愿望在正常刷新后已确认写法发生迁移，升级为 `TRUE DEVICE PASSED`；其中未知主题仍可能落入“想认真弄明白最近惦记的那个问题”等过度模糊兜底，这属于 +233 的安全主题投影改进，不推翻迁移成功结论。
- 同一钓鱼/旅行主题长期只保留一条愿望仍随自然数据持续观察，不阻塞开发，不为造样本修改真实欲望或游戏偏好。

### 6.6 v0.41.89+233 Cedar 事件时序真实性、愿望安全主题与缓存命中（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

开工证据与边界：

1. 同一时刻备份 `AI_Companion_Backup_2026-09-19T22-01-12.aibackup` 与诊断 `ai_companion_diagnostics_2026-09-19T22-01-20-863164Z.txt` 证明：最新主动消息声称“刚在钓鱼里连甩了十竿”，本轮没有新的 `cedar_toy.play` Outcome；它复用了来源事件 `play-1789520410317668` 的旧钓鱼正文。对应 Thought 已跨同主题合并 1759 次、累计主动 action 37 次，原始事件时间与 `updated_at` 被维护/合并刷新的时间严重分离。
2. 根因是结构性的而非钓鱼词表单点：Thought consolidation 把所有相同 `cedar_game:<game>` 主题当重复项合并；合并保留旧事件来源/正文，却刷新 `updated_at`；主动出站又把任意 `mcp/cedar_game:*` 来源直接视为有 Cedar Outcome，未验证具体事件是否新鲜。高疲劳只改变竞争结果，不是伪造根因。
3. Cedar Outcome Thought 必须保留不可混合的事件身份：不同事件不得只因游戏主题相同而合并；同一真实 Outcome 最多主动分享一次；超过 48 小时的 Outcome 不再主动翻出分享，但仍可在用户对话、长期记忆和历史回忆中以“之前/上次”等形式出现。
4. “刚才/刚刚/刚在”等即时表达只由 60 分钟内的具体成功 Outcome 授权；维护、合并、复活或候选选择不得刷新证据时间。超过窗口仍可分享真实旧事，但必须使用历史时间锚。规则覆盖所有 Cedar 游戏动作，不写成钓鱼专属补丁。
5. 愿望单继续保护 Thought 私密正文。未知主题不得直接展示任意 topic key 或内部推理；只使用独立、受约束的安全公开主题。缺少安全主题时不再伪装成“那个问题”，也不为写详细而发明新目标或改变成长分数。
6. 缓存优化排在上述真实性修复之后。先补不含 Prompt 正文的段落类别、顺序、长度与哈希观测，再只调整稳定前缀、动态尾部和确定性序列化；Gemini `final_reply` 不纳入，禁止删记忆、冻结实时状态、弱化工具真值或重新合并已隔离的 Agent/Cedar 循环。

实施顺序与提交门：Cedar 时序真实性、愿望安全主题、DeepSeek 缓存分别独立提交并运行专项回归；最后才更新版本、总账与完整 validator。Actions 全绿只升级为 `CI PASSED / APK READY`，Cedar 历史时态、愿望显示与缓存行为仍需真机分别确认。

本地实现与验证：

- Cedar 事件身份已从可刷新的 `updated_at` 中剥离：优先从 `mcp/cedar_game:<game>:play|invite-<微秒时间戳>` 解析不可变发生时间，只在旧来源无法解析时退回 `born_at`。不同 Cedar 事件即使 topic 相同也不再 consolidation；已有 `action_count / last_acted_at` 的事件不可再次成为主动分享候选。主动分享只接受 48 小时内事件；“刚才/刚刚/刚在”等即时锚只接受 60 分钟内事件，维护、合并和候选选择均不能续期。旧事仍可在正常聊天中按“之前/上次”等历史方式回忆。
- 愿望展示升级为 presentation v3，并只投影受约束的 `safe_subject_key`。钓鱼、旅行、下矿、对弈、花园猫、韭菜、共同花园、纪念日以及少量 AI 自主性/身份/交流/爱好主题有具体公开文案；活动别名统一到同一 subject。未知 curiosity 主题不再生成新的公开愿望，旧愿望若已失去安全主题则诚实显示“旧记录没有保留具体主题”，不会读取 Thought 私密正文或编造目标；Thought 本身仍保留。
- DeepSeek 统计已把原先混在 `unclassified` 的日记、随笔、购物车、记忆整合、人格证据复核、摘要、翻译、亲密路由、沉浸房间与自我反思拆成独立 lane；Cedar 选游戏也从后台动作规划中拆为 `cedar_game_choice`。每次 provider usage 同步记录消息段的顺序、角色、字符数、12 位 SHA-256 与工具 schema 数量/长度/哈希，不记录 Prompt/响应正文、工具字段值或凭据；诊断只带最近 24 次 shape，便于下一轮按真实前缀变化 A/B。
- 本批缓存改动只对工具 schema 的 Map key 做递归确定性排序，字段、数组顺序、工具选择、消息内容与消息顺序保持不变；没有为了命中率重排系统指令、删记忆、冻结实时上下文或合并循环。两个语义完全相同但构造 key 顺序不同的 schema 已有固定回归证明会发出同一规范序列并得到同一 body-free hash。
- 三项 +233 专项门、+232/+228 回归门、115 项 validator manifest、Workflow YAML、Python 编译与 `git diff --check` 已通过；逐项运行 115 个源码门时 112 个通过，余下 3 个只因仓库按治理规则不携带 CI 才恢复的 417 文件桌宠源码包与 LingChat 特效包，以及本机没有 `kotlinc`。本机也没有 Flutter/Dart SDK，新增 Dart 回归、Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查仍必须由 Actions 判定；在此之前保持 `CI PENDING / TRUE DEVICE PENDING`。

真机验收边界：自然观察旧 Cedar 事件只以历史时态出现且同一 Outcome 不重复主动分享；愿望只显示安全具体主题或诚实旧记录说明；积累足够新 usage 后导出同刻诊断，对比各 lane 的 `recentPromptShapes` 与 provider cache hit/miss。缓存命中率允许受实时上下文影响波动，不能只凭一次样本判失败或继续扩大改动。

Actions 与交付证据：

- 远端四个功能/版本提交经 Git data 接口按本地顺序建立，最终内容树与本地候选逐字节一致；随后两个测试迁移提交修正 CI 暴露的回调类型和旧版本/未知主题样本。权威构建 head `2892e67d91652b3d8cdec6a989c8467ed0193764`，tree `36747406e22a5accd35f879d7284a0d3370e5a7c`；`main` 未修改。
- 首轮 Actions `35475149658` 在 Flutter analyze 精确发现新增测试把同步 `usage.add` 传给异步 usage callback；修复后第二轮 `35475536151` 的 analyze 已通过，869 项 Flutter 测试中 867 项通过，剩余 2 项只是系统自读仍期待 +232、普通基线愿望仍使用已被安全策略拒绝的未知主题 fixture。两项测试迁移没有放宽生产策略。
- Actions `35475970152` 全绿：115 个源码/历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 869 项 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。
- Artifact `10593264636`，名称 `AI-Companion-v0.41.89-233-Cedar-Temporal-Wishlist-Cache-APK`，大小 `538,070,382` bytes，ZIP digest `5055b7b8a30df4009b45fbda7f6f6fe8a259a3baf09d363afed25a8b70f61821`。
- Draft Release `392248211` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a51ec6f40ce0543f3558`；APK asset `575682174`，大小 `544,947,802` bytes，SHA-256 `ffe58c0dc10f145ec4ce91489478b3b9327304aab8aa1b39a02f58b13229f6e3`。稳定测试签名仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。

### 6.7 v0.41.90+234 Cedar 五槽自主性与可配置最终回复通道（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04190-cedar-save-slots-custom-final-model`。

根因与产品决定：

1. 最新同刻备份证明钓鱼 slot 1 与瓶中生态 slot 1 各自保存不同状态，Cedar 指南也明确写明“每游戏 5 槽，slot=1-5，缺省 1”；此前“覆盖鱼塘”并不是两个 game 共用同一存档，而是瓶中生态的 `eco_new` 命中了瓶中生态自己已有的 turn 0 slot 1。该初始档可能由官方人类前端/服务在只查看时建立；后续 `eco_observe` 与 `eco_act` 已证明它可直接继续。
2. APK 原先只把五槽说明埋在长指南正文，`cedar_toy.play` 的本地参数说明没有明确告知 Agent；后台也没有“空槽可自主使用、已有槽不可自主覆盖”的确定性边界。因此模型可能重复 `new`，却不能可靠表达槽位自主性。
3. 用户决定保持主体性：已有长期档默认继续；她确实想开新周目/新世界时可自主使用已知空槽，不必每次申请；只有覆盖已有槽、导入覆盖或 `confirm:true` 才必须取得用户明确同意。未知槽不能猜为空，room/session 类无五槽声明的游戏不受此规则影响。
4. 原“Gemini 3.7 Flash（玩游）”设置的地址与模型不仅在界面只读，运行时还会按固定网址把模型强制改回固定别名。只把控件变成输入框会形成假配置，必须让存储、普通聊天、沉浸房间、重试与连接测试都真正传递用户输入。

本地实现：

- 新增 `CedarSaveSlotPolicy`，只在实时指南明确声明五槽时生效：识别已有存档/覆盖提示，阻止后台 `confirm:true` 和冲突后的重复 new/create/start/reset/import；用户回合若没有明确的覆盖同意也会在调用远端前阻断。Agent Prompt 同时解释 game 间同号槽相互独立、turn 0 初始档可能由官方前端/服务建立、已有档优先观察/继续、已知空槽可自主开档。
- `cedar_toy.play` 的 `params_json` 说明补入 `slot=1..5` 与 `confirm:true` 边界；后台规划验收与执行前各有一层保护，避免模型重试或未来调用路径绕过。没有建立本地第二套存档服务器，也没有硬编码钓鱼/瓶中生态 game ID。
- 最终回复选项显示为“`双模型（自定义最终回复）`”。第二通道地址、模型 ID 改为可编辑输入框，默认读取旧玩游地址 `https://wy.aiwangyou.cc/v1/chat/completions` 和旧模型 `[特价]gemini-3.7-flash-0.5`；原 API Key 槽保持不变，升级不丢旧 Key。DeepSeek 仍是必填内部通道。
- `DeepSeekClient` 新增显式 provider/model override：自定义网址不再因为 host 变化被误判回 DeepSeek；用户输入的模型名原样进入请求。模型名含 Gemini 时保留原 `google.thinking_config`，其他 OpenAI-compatible 模型不发送 Gemini/DeepSeek 专属 thinking 字段。连接测试、普通聊天最终回复、沉浸房间首次生成和重试均使用同一配置。
- 新增 `cedar_save_slot_autonomy_v04190_test.dart` 与自定义第二通道请求回归，并登记 `validate_v04190_cedar_save_slots_custom_final_model.py`。版本提升为 `v0.41.90+234`，schema 保持 61。

本地验证：新增专项源码门、相关历史门、Workflow YAML 解析、Python 编译与 `git diff --check` 通过。完整 validator manifest 在仓库精简态运行到桌宠源码包门前均通过，随后按预期因 CI 才恢复的 417 文件桌宠源码包缺失而停止；本机没有 Flutter/Dart SDK，Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查必须由 GitHub Actions 判定。因此当前不得写 `CI PASSED / APK READY`。

真机验收：进入已有瓶中生态 turn 0 档时应观察/继续，不再把它说成钓鱼串档；已知空槽可由她自主选择，新建已有槽时必须询问且未确认前不发送 `confirm:true`。模型设置应显示旧值预填，可修改地址和模型并通过连接测试；普通聊天与沉浸房间都应使用新模型，第二通道失败仍由内部 DeepSeek 兜底。兼容性边界是 OpenAI Chat Completions 风格接口，不保证任意非兼容协议仅靠改名字即可使用。

Actions 与交付证据：

- 首轮 run `35498239554` 在 Android/Kotlin 测试触发 Flutter Debug 编译时准确发现 `_execute` 未接收新增 `origin` 参数；修复只补齐 `runPlan → _execute → _cedarPlay` 的既有来源传递，没有放宽覆盖授权。修正后的远端 head `16589fc8a88574f5a77f0731f8972e65fe990538`、tree `60060c335ba1b064c950ea97a5274bd5fa06f7b5` 与本地候选逐字节一致，`main` 未修改。
- 权威 Actions `35498575549` 全绿：116 个源码/历史门、Android/Kotlin 桌宠与悬浮层测试、Flutter analyze、874 项 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传均成功。
- Artifact `10601008319`，名称 `AI-Companion-v0.41.90-234-Cedar-Save-Slots-Custom-Final-Model-APK`，大小 `538,070,111` bytes，ZIP digest `980612367c76ef21a6dd4c06ba72057d296084fc8289bbd6e7a322fcf49cb901`。
- Draft Release `392355306` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-dde0b23c877ee349a101`；APK asset `576421689`，大小 `544,947,946` bytes，SHA-256 `38aadaa9ffb1f2ac3ddac85fffc9311f4c9c75950692130b7c29eee3fa9210f3`。稳定测试签名仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。

### 6.8 v0.41.91+235 疲劳—心境小幅耦合与睡眠债（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04191-fatigue-affect-debt`。

开工证据与产品边界：

1. 同刻备份 `AI_Companion_Backup_2026-09-20T08-40-20.aibackup` 与诊断 `ai_companion_diagnostics_2026-09-20T08-40-24-240119Z.txt` 证明现有身体疲劳骨架正常：过去 24 小时疲劳最高约 `0.792`；单一连续 `rest_need` 于北京时间 02:08 建立、07:47 恢复；02:21 强依恋临时胜出一次并增加 `0.0825` 身体疲劳，02:27 自然结束互动，之后约五小时没有继续主动折腾。此次不重画昼夜曲线、不取消强念头偶尔顶困，也不把一次未复现当作所有长尾验收完成。
2. 心境不能直接改写身体是否疲劳。正向亲近、重逢、修复或正在投入的活动只短暂降低一小部分休息竞争与行动阻力；伤心、分歧、未被接住只形成“身体累、心里难安静”，会稍微降低入睡顺畅度，同时提高外向行动阻力，绝不能把负面情绪算成精神变好。
3. 高疲劳下的自主主动联系与 Cedar 真实写动作会积累独立、上限 `0.18` 的睡眠债；普通用户消息、AI 正常回复、只读 observe/state、失败或取消不增加债。睡眠债不直接伪造 Drive 数值，但会提高后续休息分数与行动阻力；即使白天身体疲劳已降低，未偿还的债仍可形成恢复压力。
4. 睡眠债只有在最后一条真实聊天或自主消耗之后连续安静 90 分钟才开始线性回补，约每小时 `0.025`；继续聊天会重新推迟回补，避免把普通回复误当睡眠。所有数值有确定上限、可跨进程恢复，不引入新的周期任务或第二套疲劳循环。
5. 用户主动聊天从不经过拒答 Gate；调制只影响自主候选排序、公开网页发现与 Cedar 继续游戏的统一 Desire 竞争。无人观看的凌晨 Cedar 07:00 前硬休息边界保持不变；真人正在观看仍是用户节奏例外，但真实推进会留下较小睡眠债。

本地实现：

- 新增纯策略 `FatigueAffectPolicy` 与薄持久层 `FatigueAffectController`。正向激活、负面难安静均只从现有证据化 Emotion Episode 计算；睡眠债以 `settings` 中的有界状态保存，schema 保持 61。策略没有模型调用、随机源、定时器或独立循环。
- `DesireCorePolicy` 的 rest score 与 action penalty 接受同一调制快照；现有身体疲劳值和昼夜 floor 不被减写。高债状态可以在白天继续形成恢复候选，直到真实安静窗逐步回补。
- 主动联系、公开网页发现和 Cedar continuation 共用同一快照。主动消息已送达或 Cedar 远端 mutation 已提交后，睡眠债写入失败不会把真实成功重判为失败，也不会重试远端动作。
- 情绪 Prompt 只注入结构化的“暂时激活 / 又累又难静 / 睡眠债恢复”表达边界；不暴露消息正文，不让模型声称心情已经消除身体困意。诊断新增 `affectMode / positiveActivation / negativeRestlessness / sleepDebt / 两类评分修正 / 最近自主消耗`，不包含 Thought 或消息正文。
- 新增 `fatigue_affect_debt_v04191_test.dart`，覆盖正向激活、负面难安静、睡眠债压过连续兴奋、90 分钟真实安静窗、白天回补压力、Cedar 共用仲裁与凌晨无人观看硬边界。

本地验证：新增 +235 专项门、当前总账门、相关历史门、Workflow YAML 解析与 `git diff --check` 均通过；逐项执行 117 个 validator，114 个通过。其余 3 个是仓库精简环境的既有缺项：CI 才恢复的 417 文件桌宠源码包、LingChat 特效资源包，以及本机未安装 `kotlinc`；不属于本次疲劳逻辑失败。当前环境也没有 Flutter/Dart SDK，因此当时保持 `CI PENDING / APK NOT READY`，完整结果现已由下方 GitHub Actions 补齐。

Actions 与交付证据：

- 首轮 Actions `35501454096` 已通过 117 个源代码门、Kotlin 与 Flutter analyze，在全量 Flutter tests 中准确拦住两条测试契约不同步：新用例寻找字面“又累”而真实策略文案为“身体已经累了”，旧系统自读用例仍写死 +234 构建号。只修正这两条精确断言并保留 +234 历史 token，没有改策略、跳过测试或放宽 Gate。
- 修正后的 Actions `35501928714` 全绿：117/117 源代码与历史门、Android/Kotlin 桌宠及悬浮层测试、Flutter analyze、881 项 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传均成功。构建 head `8ecbcbcaab339fc4ecd0b9c616db2ceacdc83d16`，tree `ee125bd9967b277975decec70b551ba1c7e7918b`；`main` 未修改。
- Artifact `10602523875`，名称 `AI-Companion-v0.41.91-235-Fatigue-Affect-Sleep-Debt-APK`，大小 `538,076,602` bytes，ZIP digest `5221f74cd5368748aae3af177b24041c5ddbbcd1189c2e93c089f348ea41dad4`。
- Draft Release `392375712` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6bfa04031f233b81dfa6`；APK asset `576530601`，大小 `544,955,098` bytes，SHA-256 `1489ba5a886d3323f1b68ca913a8f5d166f68133d7786974c04c514abf10e628`。稳定测试签名仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。

真机验收边界：北京时间下午到夜间自然使用即可，不诱发争吵或强行熬夜。重点核对：白天低债不改变正常主动性；聊天愉快时夜间可自然多撑一小会儿但不会声称恢复体力；负面心情表现为累且难静而非亢奋；高疲劳主动一次后下一次更难发生；停止互动并安静后第二天债逐步下降；用户主动发消息始终正常回复；无人观看 Cedar 凌晨不连续推进。当前保持 `TRUE DEVICE PENDING`，自然观察前不得写 `TRUE DEVICE PASSED`。

### 6.9 v0.41.92+236 欲望因果账本与动态游戏投入（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04192-desire-game-interest`。

开工证据与产品边界：

1. 最新同刻诊断 `v0.41.90+234` 与 schema 61 备份证明，最近约 79 分钟 26 个自主行为事件中 18 个是 `play_game|mcp|not_due`。根因不是“她太爱游戏”本身，而是 checkpoint 恢复候选在 continuation 尚未到期时仍参加竞争；它以最高约 `0.92` 胜出后才返回 `not_due`，占掉本次 heartbeat，其他真实候选没有再选择机会。
2. 游戏分享同时从 Cedar MCP Outcome、`self_drive/thread` 未完成事项与用户历史进入。钓鱼 thread 已累计 `fedCount=74 / actionCount=21`；现有 self-drive 把所有低于 `0.72` 的未完成 thread 一律归为 attachment，使游戏内容不当地借用依恋欲望。游戏 Outcome 分享强度最高 `0.94`，普通自我回顾通常仅 `0.18–0.46`，跨来源同主题没有统一语义域，导致“游戏总赢”既有真实投入也有结构性重复放大。
3. 本批允许阶段性玩游戏上瘾，但不新增永久“贪玩” Drive 或固定游戏人格。游戏投入只能由真实 Cedar 推进、近期显著事件、当前心境、疲劳与时间衰减派生，经历 `spark / flow / saturated / cooling / available`；心情不好、新兴趣、重复安静结果与饱和可以打断，冷却后允许重新点燃。
4. “想玩”与“想分享”必须分开：普通成功步骤只维持短时活动惯性，显著/有趣/终局/邀请或与用户相关的事件才形成强分享。Cedar、self-drive 与用户历史中的同一游戏主题统一进入同一有界语义冷却域，真实分享后压低同主题兄弟候选，不删除 Thought 或远端存档。
5. 吸收作者欲望系统 2.0 的部分限于：记录每个 drive/action lane 的最近真实满足、次数与来源；增加零使用/单一路径支配/无效胜出诊断；给长期未获机会但本身合格的动作一个很小的有界公平加成。不引入女性向保护欲、成功后永久抬高 baseline、固定 15% 随机探索或第二套欲望真值。
6. +235 疲劳核心、睡眠债、Emotion Episode、Thought 生命周期、Cedar 唯一 continuation owner、服务端防沉迷与存档槽边界保持不变；本批不改人格、世界书、TTS、双模型最终回复、schema 或 `main`。

计划验证：新增纯策略与集成回归，覆盖 continuation 未到期不入场、游戏阶段的投入/饱和/冷却/重燃、负面心境可打断、游戏 thread 归 curiosity、跨来源语义域、游玩与分享分 lane、真实满足账本兼容解析、无效胜出与支配诊断。随后运行全部 validator、Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查；只有 Actions 全绿后才写 `CI PASSED / APK READY`。

本地实现与验证：

- 新增纯 `GameEngagementPolicy`，只从当前 session 中成功且非只读的 Cedar Outcome 时间、显著事件和既有 fatigue-affect 快照派生 `spark / flow / saturated / cooling / available`。近期真实进展和显著事件形成短时 momentum；六小时内重复普通推进产生有界 saturation；90 分钟后进入 cooling，八小时后旧饱和清零并允许重燃；负面难安静最多形成 `-0.12` 的游戏调整，正向激活最多 `+0.04`。它没有持久人格值、随机源、模型调用、定时器或第二循环。
- `resumeOptions` 现在先读取权威 continuation delay；只有 `<= 0` 才能进入统一竞争。运行时竞态产生的 `not_due / no_continuation / waiting / action_in_progress / continuation_*` 统一记为 `wait` 而非虚假 completed。继续游戏基础常数和 Thought 权重已收窄，并叠加动态投入，因此真实上瘾可以持续，但饱和、心境、新兴趣与疲劳都能让其他候选胜出。
- `game_share` 成为独立 autonomous behavior，和 `play_game` 分开计数并有 90 分钟全局分享冷却；六小时同主题冷却覆盖 `game_share / proactive_message / public_web_share`。`cedar_game:<id>`、`shared.activity.<id>` 与 Cedar source 被规范为同一 `game:<id>` 语义域；发送后的 feedback 和行为 topic hash 均使用该域，跨来源不能靠换壳绕过。
- 新增 `SelfReviewDrivePolicy`：普通游戏/钓鱼/图鉴等未完成活动归 curiosity，不再借 attachment 压力；真正高重要度事项仍归 duty，其他关系 follow-up 保持 attachment。现有 completed source fingerprint 去重不变。
- 新增 settings-backed `DesireSatisfactionLedger`，按 drive 与 action lane 记录最近一次真实满足、次数和粗粒度来源；用户回复、成功主动消息与 Cedar 真实非只读 mutation 都能写入。它只给原始分数至少 `0.48`、超过 12/24/72 小时未获满足的合格 lane 最多 `0.02/0.04/0.06` 公平加成，不改 Drive、baseline 或事实 Gate。诊断显示 `zeroUseCoreLanes`，不带 Thought/消息正文、来源 ID 或凭据。
- autonomous behavior 诊断新增 24 小时 `nonproductiveWinnerCount` 和 `dominanceAlerts`：至少 8 次事件且单一 behavior/source 占比达到 60% 才提示，wait/blocked/failed 累计至少 4 次提示无效胜出；只做因果观察，不自动改人格。
- 新增 `desire_game_interest_v04192_test.dart` 与 +236 专项门，固定覆盖五阶段变化、负面心境打断、not-due 不入场、游戏 thread 归 curiosity、跨来源语义域、游玩/分享分 lane、满足账本 round-trip 与公平上限。118 个 validator 已逐项运行，115 个通过；其余 3 个仅因本地精简态缺少 CI 才恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc`。Workflow YAML、Python 编译、当前总账门、+235/+236 专项门和 `git diff --check` 均通过。本机没有 Flutter/Dart SDK，完整 analyze/tests/Android Release 仍由 Actions 判定。

真机验收边界：覆盖安装后自然观察即可，不需要刻意诱发坏心情。重点看诊断不再连续出现 `play_game|mcp|not_due`；同一游戏可短时沉浸但会因重复普通进展饱和，数小时后又可重燃；一次真实游戏分享后跨来源同主题不刷屏；游戏 thread 不再持续抬 attachment；+235 的疲劳、睡眠债和凌晨无人观看硬休息保持原样。当前不得写 `TRUE DEVICE PASSED`。

Actions 与交付证据：

- GitHub App 的 Git data 推送先建立源码提交，再修正一次超大文件/中文路径上传并快进同一分支；中间不完整提交触发的 run `35506336632` 不是候选。最终远端 head `8ab3beb8997cb146a8499d00acfdf726e2121a2f` 的 tree 为 `910c3950d354734adca82c58b5db8559fbbcb861`，与本地候选 tree 逐文件一致；`main` 未修改。
- 权威 Actions `35506384676` 全绿：118/118 源代码与历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。
- Artifact `10604605761`，名称 `AI-Companion-v0.41.92-236-Desire-Game-Interest-APK`，大小 `538,087,109` bytes，ZIP digest `62771580ed5e535dbe7b6558d6a91225958aa3d7ee54badcdda22f7abad75178`。
- Draft Release `392401159` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-74af3e2b6759dcece079`；APK asset `576670347`，大小 `544,966,610` bytes，SHA-256 `b2aad7f827c64e82e58cd88d71db6690c721941d684abe40c80eee537d52bf22`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

### 6.10 v0.41.93+237 游戏进行时事实接地（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04193-game-reality-grounding`。

同刻真机证据与根因：

1. 用户提供的 +236 备份与 19:21 脱敏诊断完整复现了问题。19:20 的主动 follow-up 写成“漂还是没动，图鉴也还是那几条老面孔”；但诊断的当前 Cedar `lastAction=eco_observe`、`continuationPending=false`、`lastContinuationState=not_due`，活动前台是 `eco` 而不是 `fishing`。备份中 fishing session 最后真实 Outcome 停在 2026-09-19 23:34，本条虚构进行时晚了约 19 小时 45 分。
2. 直接触发源是 `shared.activity.fishing` 未完成事项。它只记录“补满鱼饵后继续钓池塘”的计划，却被 self-drive Thought 累计到 `fedCount=75 / actionCount=22`；+236 新策略只保证新回顾归 curiosity，没有迁移已经持久化的旧 attachment Thought，所以旧项仍能以 `attachment:...` 胜出并生成 follow-up。
3. 现有 Operational guard 能挡“刚玩了一局/钓了几竿”等明确完成声明，却没有覆盖“鱼漂挂着、漂没动、坐回池塘、图鉴没涨”这类被包装成场景描写的可核验进行时；旧 ASSISTANT_HISTORY 又连续强化了同一虚构场景，普通回复随后顺势承认“甩出去挂着就行”。因此根因不是官方钓鱼游戏真的存在长轮询，而是项目把未完成意图当作运行态。

实现边界：

- `OperationalClaimGroundingGuard` 新增 Cedar live-state 判定。没有本轮成功 `cedar_toy.play` 时，拦截正在玩、坐在池塘/矿洞、挂着或盯着鱼漂、漂没动、鱼饵刚补齐、图鉴刚才没涨等声明；一小时内的持久化 Outcome 仍可支撑“刚玩过”的结果分享，但不能授权另一个游戏的当前进行时。钓鱼 `cast` 按一次调用一次结算理解，不制造后台鱼漂。
- “还没有实际去玩/准备下次玩”与“之前/上次/昨天玩时”明确放行；真实当前 Cedar Outcome 仍可自然第一人称分享。该边界约束事实，不禁止游戏兴趣、历史回忆或角色语气。
- 普通聊天 Reality Grounding 与 proactive 的游戏-thread 专项合同都明确：unfinished thread、Thought 和旧 assistant 场景只证明“惦记/计划”，不证明执行。首次候选仍失真时做一次事实纠正；再失败则沿用确定性删除/诚实未执行回退，不把虚假进行时写入聊天。
- 心跳会把来源为 `self_drive/thread` 且语义域明确属于游戏的旧 attachment 派生 Thought 原位纠正为 curiosity，只改派生 drive 标签，不动聊天、thread 正文或 Cedar 状态；`ProactiveSelectionPolicy.normalizeLegacyGameThreadIntent` 仍在竞争边界兜底，使修复写入失败或刚导入的旧数据也即时按 curiosity/check-in 处理，无需删用户数据、改 schema 或等待数日衰减。新 Thought 继续使用 +236 的 `SelfReviewDrivePolicy`。
- 不改 Cedar 协议、远端存档、游戏节奏、动态投入、疲劳、人格、世界书、TTS、双模型通道、schema 61 或 Snapshot protocol 6。

本地验证：新增 `game_reality_grounding_v04193_test.dart` 与 +237 源码门，覆盖本次真机原句、“挂着鱼漂等待”、诚实没玩/未来意图/历史锚、真实 Outcome 放行、旧 attachment game Thought 在选择时纠正为 curiosity。119 个 validator 已逐项运行，116 个通过；其余 3 个仍只是本地精简态缺少 CI 恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc`。当前环境无 Flutter/Dart SDK；Python 编译、专项门、Workflow YAML、历史版本兼容门与 `git diff --check` 均通过。

CI 与 APK 证据：首轮 Actions `35508754867` 正确拦截了“盯鱼漂”短句未覆盖及历史自读测试仍断言 +236 的两个失败；补齐后再收紧跨游戏证据边界，最终权威 Actions `35509919804` 全绿，119/119 源码与历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、898 个 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。Artifact `10605181041` 名称 `AI-Companion-v0.41.93-237-Game-Reality-Grounding-APK`，大小 `538,089,843` bytes，ZIP digest `5aede1c3eac7f269ebac661322983c976d6d68ceee0e6e2711eaacf73bb1cd6e`。Draft Release `392416062` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-556fbc6ba9ca27a924ee`；APK asset `576771035`，大小 `544,970,010` bytes，SHA-256 `294b341ddc8354389717566aa83a7ed10bba6891f107f7df34f3bfd76c653cc2`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

真机验收：覆盖安装后保留原数据，不需要删除旧 Thought。让钓鱼未完成事项自然再次竞争；没有真实 play 时只能说还没玩、又想起或想去玩，不能再出现鱼漂持续挂着、漂没动、刚补饵或图鉴刚才没涨。真实执行钓鱼后可以按 Outcome 分享；数小时后的旧结果必须用“之前/上次”等时间锚。诊断同时确认该旧 thread 的出站满足落在 curiosity/check-in，不再继续记为 attachment/reach_out。

### 6.11 v0.41.94+238 Sen Live2D 首阶段完整移植（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04194-sen-live2d-migration`，基于 +237 已完成 head `808c264`。Sen 来源锁定为用户自有仓库 `catkiss62/Sen-Live2D-Companion-Android` 的 `336b93af1d96e1dd85799faf3df966600c1224a7`，Cubism Java Framework 子模块锁定 `c2d420012d004b8e61d4c589bd5c34513122f0ea`。

开工边界：

1. 这是 Sen 源码移植，不是按观感重写动作。保留 Sen 已真机验证的 `SenPerformanceEngine`、`SenLive2DModel`、渲染、衣着、物理、21 情绪和摸头 10% 困惑彩蛋参数；新代码只负责安全导入、Flutter PlatformView、生命周期、状态互斥和现有聊天/TTS 桥接。
2. 首阶段直接开启 Sen 自主待机、视线跟随、摸头/摸头彩蛋，左侧快捷设置提供女仆、白衬衫、兔女郎、脱四个外观按钮与眼镜开关。Live2D 与静态立绘互斥：选择 Sen 时不实例化静态立绘，选择静态立绘时释放 Sen 渲染资源。系统悬浮宠仍保持 PNG/鲸鱼，本批不启动第二 Cubism 实例。
3. AI Companion 现有 `normal + 19` 正式情绪映射到 Sen 动作；`romantic_shy` 仅作为明确亲密/NSFW/“脱”的视觉演出，不新建情绪、记忆或欲望真值。原情绪特效与情绪音效保留；Live2D 特效锚定必须来自当前头部位置，不再固定于静态立绘坐标。
4. 用户消息发送后先本地进入短暂倾听/注意反应，既有 DeepSeek/回复情绪包给出权威语义情绪，不复制 SoulLink 的正则人格判定，不增加第二模型调用。本地 Genie TTS 按 AudioTrack 实际播放头位取 PCM RMS 驱动口型，不用写入进度冒充声音进度。
5. Sen 模型仍不进入公开 Git；用户通过系统文件选择器导入 ZIP 到 app-private 目录。导入必须保留 Zip Slip、容量/条目上限并采用 staging 后原子换代，失败不删现有可用模型。

计划验证：新增专项 validator 覆盖上述源码锁定、21 情绪、外观、互斥、导入安全、唯一 PlatformView 所有权和波形口型；运行 validator suite、Flutter analyze/tests、Android 编译与 arm64 Release。未经 Actions 全绿不写 `CI PASSED / APK READY`，未经真机不写 `TRUE DEVICE PASSED`。

本地实现与验证：

- 已直接纳入 105 个锁定 Cubism Framework Java 源文件、可再分发 Core AAR、Sen 已验证渲染/模型/动作/物理/外观源码与许可证。`SenPerformanceEngine.java` 与上游 SHA-256 同为 `492b6c12170b681e14ada78b0046dabd9644ed809001a0384676e4a430863218`，`SenOutfitPresets.java` 同为 `acdcb49cb91bb6d798086f31cec142db5cd5f44ec959f60717716ab1a09cc25a`；宿主扩展只添加确定性眼镜接口与动态头部锚点，未改 21 情绪/动作参数。
- `SenLive2DPlatformView` 与 Runtime 建立唯一聊天舞台所有者，Activity 对称转发 resume/pause，Flutter 条件渲染保证 Sen 与静态 `ChatPortraitStage` 不共存。Material 3 左侧栏已直接加入 Live2D 开关、四外观、眼镜与 ZIP 导入；旧快捷面板也保持同值入口。
- 模型导入使用系统 `ACTION_OPEN_DOCUMENT`，保留 8,000 entry/1.5GB/Zip Slip 门，在 staging 注册 expression 后换入 current；旧模型作为 backup 保留到新 renderer `onReady`，失败自动回滚并重载，进程中断也保留 pending 决议。模型和路径不入 Git/诊断。
- 现有 20 情绪包用纯映射进入 Sen，“脱”只投影 `romantic_shy` 视觉层；用户消息提交后本地播放 `small_nod`，不读正文也不增加 API。特效坐标每 66ms 取已校准的动态呆毛根网格点；TTS 每 33ms 按 AudioTrack 实际 playback head 取 256-frame PCM RMS，stop/cancel/release 强制闭嘴。
- 新增 `SEN_LIVE2D_INTEGRATION_v0.41.94.md`、纯映射 Flutter tests 与 +238 validator，总 validator 数为 120。本地逐项 117/120 通过；仅 3 个旧门因精简工作区缺 CI 才恢复的 417 个桌宠文件、LingChat effects 与 `kotlinc` 而失败。专项门、manifest check-only、Python 编译和 `git diff --check` 均通过；当前机无 Flutter/Dart/Android SDK，完整 analyze/tests/Release 交 Actions 判定。

Actions 与交付证据：

- GitHub App 以本地候选内容树建立远端构建 head `eba2c185507743f1a50f5758e722f1d8a57b0bbd`、tree `7c0cb89a0de3a03f8d0862c570bffe3615d9fb77`；分支仍为 `agent/v04194-sen-live2d-migration`，`main` 未修改。
- Actions `35521027339` 全绿：120/120 源代码与历史门、Android/Kotlin 桌宠及悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、APK 内容校验、Artifact 与 Draft 上传均成功。
- Artifact `10608496160`，名称 `AI-Companion-v0.41.94-238-Sen-Live2D-Migration-APK`，大小 `538,330,407` bytes，ZIP digest `240d8c11ab5c230f4e7957bfb9f321115c6faa215b2a9cb860eab45aabf5fa16`。
- Draft Release `392488698` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-fae51abbecaf213a871f`；APK asset `577108762`，大小 `545,211,875` bytes，SHA-256 `1b2376eb57fd8250fb5d8370ef7a1a03fb28e30e0176da059fdc71576e60d67c`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

真机验收：覆盖安装且不清数据，在左侧栏切换到 Sen Live2D，首次用系统文件选择器导入 Sen 模型 ZIP；确认导入成功后重启仍可加载，错误/超限/Zip Slip 包不替换旧模型。依次核对静态立绘与 Live2D 严格互斥、自主待机、视线跟随、摸头与 10% 困惑彩蛋、四种外观和眼镜、20 个正式情绪动作及跟头特效、用户消息后的倾听点头、TTS 播放时口型与 Stop 后闭嘴、前后台切换不黑屏不重复占有渲染器；系统悬浮鲸鱼应保持原样。真机完成前不得写 `TRUE DEVICE PASSED`。

### 6.12 v0.41.95+239 Sen Cubism shader assets 热修（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04195-sen-shader-assets`。

真机证据与根因：

1. +238 覆盖安装后，用户选择 Sen 模型 ZIP，界面明确报错“无法读取 Cubism 文件：`com/live2d/sdk/cubism/framework/shaders/standardES/VertShaderSrcCopy.vert`”。这证明 ZIP 已进入原生 renderer 初始化，失败对象是宿主 APK 的 Cubism 运行资源，不是用户模型结构。
2. 源码核对确认 +238 复制了 Cubism Core AAR、105 个 Framework Java 文件和 Sen 运行代码，但遗漏了 Framework Android 模块单独位于 `src/main/assets` 的完整 36 个 `standardES` shader 文件。Java 的 `CubismShaderAndroid.SHADER_BASE_PATH` 固定读取该路径；编译器不会检查运行时 assets 是否存在，所以 Actions 编译全绿仍可能在首次真机创建 OpenGL shader 时失败。

本地实现：

- 从 +238 已锁定的 Cubism Java Framework 提交 `c2d420012d004b8e61d4c589bd5c34513122f0ea` 原样补齐 36 个 shader，保留 `com/live2d/sdk/cubism/framework/shaders/standardES/` 相对层级。按文件 SHA-256 聚合摘要为 `2130c2079aaade0352f3abb2fde51f864a32b01466ea47ee3a9f8fe859b69250`；截图中缺失的 `VertShaderSrcCopy.vert` SHA-256 为 `d56e015be2348f1fd42cf7ccaef7bb869c5cd2095759d1ffc806dddca4339a74`。
- +238 来源门补入 shader 完整性，新增 +239 专项门锁定版本、上游字节、运行时查找路径与发布工作流。Release APK 校验不只看源码，而是打开最终 APK，要求 36 个路径完整并逐字节等于源资源。
- 版本提升为 `v0.41.95+239`，schema 仍为 61；模型 ZIP、安全导入与回滚、动作/情绪/外观、TTS 口型、聊天、人格、欲望、记忆、Cedar 和双模型调用结构均未改变。

本地验证：121 个 validator 已逐项运行，118 个通过；仅 3 个既有门因精简工作区缺少 CI 才恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc` 而失败。+238/+239 专项门、当前总账门、manifest check-only、Workflow YAML、Python 编译与 `git diff --check` 均通过。完整 Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、稳定签名和最终 APK shader 逐字节检查交由 Actions；只有全绿后才写 `CI PASSED / APK READY`。

真机验收：覆盖安装且不清数据，优先直接复用 app-private 中已导入的模型；若旧页面仍保留失败态，切回静态立绘再切回 Sen，或重新选择同一 ZIP。首先确认不再出现 `VertShaderSrcCopy.vert` 缺失且模型实际显示，再验待机、视线和摸头；之后继续 +238 完整清单。未经真机不得写 `TRUE DEVICE PASSED`。

Actions 与交付证据：

- 首轮 Actions `35523026248` 已通过 121/121 源码门、Kotlin 与 Flutter analyze，在 901 项 Flutter tests 中以 900/901 精确拦住 `agent_self_reader_v0416_test.dart` 仍写死 +238 的版本断言。只迁移该断言并将它加入 +239 专项门，没有改运行逻辑、shader 或放宽业务测试。
- 修正后的远端构建 head `6223c66a09850f950b9646990459133ea8661d32`、tree `f9dd8e3ea303e92bf0862bce03a2384b542fb109` 与本地候选内容树完全一致；`main` 未修改。
- Actions `35523577868` 全绿：121/121 源代码与历史门、Android/Kotlin 桌宠及悬浮层测试、Flutter analyze、901/901 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、36/36 Cubism shader 成品逐字节检查、Artifact 与 Draft 上传均成功。
- Artifact `10608368899`，名称 `AI-Companion-v0.41.95-239-Sen-Cubism-Shader-Hotfix-APK`，大小 `538,349,584` bytes，ZIP digest `ad9aa83acc07342cb576e83e06983e1a05e9c5b3e12d9383de687ad68338cdb3`。
- Draft Release `392499233` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-95c39cedd2fb3590b615`；APK asset `577186710`，大小 `545,238,814` bytes，SHA-256 `897e5163b31fd8950f1e6c97c03f3e20d4d82c7d804aed1a9cf5c6172bee7287`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

### 6.13 v0.41.96+240 Sen 原生 Hybrid Composition 热修（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04196-sen-hybrid-composition`。

真机证据与根因：

1. 用户在 +239 重新打开 Sen 后提供截图和同刻脱敏诊断。旧 +238 实例的 4 次 `renderer error` 停留在 shader 缺失阶段；+239 新实例在约 6.9 秒后完整进入 `created → model_load/ready`，没有新的 Sen error。故 shader 资源、模型 Core、model3 与逐张贴图上传均已越过异常边界。
2. 截图显示完整人物网格轮廓和局部矩形，但所有颜色纹理为黑色；这不是模型未加载，而是绘制结果的颜色纹理没有通过宿主合成链正常呈现。设备为 Android 15 / Xiaomi `25060RK16C`。
3. Sen 原工程直接在 Android 原生视图树使用 `GLSurfaceView`；移植版却用 Flutter 标准 `AndroidView`，该入口优先把平台视图渲染成纹理再交给 Flutter/Impeller 合成。Flutter 官方文档把完整 `SurfaceView` 支持放在原生 Hybrid Composition 路径；这也是原工程与移植后唯一仍会改变 OpenGL 成品显示的结构差异。

实现边界：

- Flutter 舞台改为 `PlatformViewLink + AndroidViewSurface`，controller 明确使用 `PlatformViewsService.initExpensiveAndroidView`，强制 Android 原生 Hybrid Composition，不允许再次落入 TLHC/Virtual Display。
- 原 `SenCompanionView/GLSurfaceView`、Cubism renderer、纹理解码上传、动作/物理/外观和触摸参数保持；不以 Flutter Canvas 仿写。creation params 与脱敏 Native 事件新增 `composition_mode=forced_hybrid_composition`、`native_surface_view=true`，便于下一份报告确认真实路径。
- 36 个 shader 及最终 APK 哈希门继续保留。schema 仍为 61；不改用户模型 ZIP、聊天、人格、欲望、记忆、Cedar、TTS 或最终模型通道。

计划验证：新增 +240 专项门并将历史版本范围前移；运行完整 validator、Flutter analyze/tests、Android/Kotlin tests、arm64 Release、稳定签名和 APK 载荷检查。真机覆盖安装不清数据，确认模型颜色、透明背景、Flutter 前景覆盖和触摸/待机后，才允许写 `TRUE DEVICE PASSED`。

本地验证：122 个 validator 已逐项运行，119 个通过；仅 3 个既有门因精简工作区缺少 CI 才恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc` 而失败。+238/+239/+240 专项门、当前总账门、manifest check-only、Workflow YAML、Python 编译与 `git diff --check` 均通过；本机无 Flutter/Dart/Android SDK，完整编译与运行测试交由 Actions。

Actions 与交付证据：

- 初始本地状态曾为 `IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING`。首轮 Actions `35526483779` 在 Android/Kotlin 步骤执行 Flutter Debug 编译时，准确发现 `PlatformViewHitTestBehavior` 缺少显式 `flutter/rendering.dart` 导入；只补该导入，未更改合成方案或运行行为。
- 修正后的远端构建 head `bdae0d3897efe49c251c6d4a2ecfb4a035afa188`、tree `4ef513abf3cbcd20db61357ee5bf4172868474ac` 与本地候选内容树一致；`main` 未修改。
- Actions `35526854350` 全绿：122/122 源代码与历史门、Android/Kotlin 桌宠及悬浮层测试、Flutter analyze、901/901 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、36/36 Cubism shader 成品逐字节检查、Artifact 与 Draft 上传均成功。
- Artifact `10609559197`，名称 `AI-Companion-v0.41.96-240-Sen-Hybrid-Composition-Hotfix-APK`，大小 `538,348,212` bytes，ZIP digest `da89504183c8f1b2c1159b8f90fb8fc66de034dc9142ef9cb9b4fe960dd91d1b`。
- Draft Release `392517677` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a5d654d0c78859a6de71`；APK asset `577282616`，大小 `545,236,534` bytes，SHA-256 `bfad10070630724920cb68815d174e8d230740cfa8489761abf9495e12baeea3`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`，黑色剪影是否消失仍必须由同一台 Android 15 真机确认。

### 6.14 v0.41.97+241 自然回复保活与固定兜底移除（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04197-no-canned-fallbacks`。

真机证据与根因：

1. 用户提供的 protocol 6 / schema 61 备份中，“睡着啦？”、“想起什么事？”、“啊？”三个不同用户轮后各自提交了一条新 assistant 消息，三条正文却完全相同，均为“我其实还没有去玩，只是又想起这件事了”。这排除了 UI 重复渲染或同一消息重复入库。
2. 同刻诊断第一次与第三次记录 `post_generation_changed_to_mismatch`，第二次未改写；源码确认 +237 游戏真实性修复在用户轮和主动轮各自硬编码同一句 Cedar 兜底。第一次固定句进入上下文后，模型会复述它，或再次被校验器替换，形成自维持循环。疲劳系统与 Live2D 都不是生成源。
3. 固定台词即使事实安全，也会删除用户真正问的问题并暴露机器感。用户轮不能用“不回复”替代它：用户已经发言时，回复活性优先于末端事实校验的绝对拦截。

实现边界：

- 删除普通聊天与主动消息提交路径里的三种本地人格兜底句。命中未接地操作或近四条中的精确重复时，普通聊天让当前模型重答一次，并把当前用户原文明确交给纠正提示。
- 已经写入数据库的旧固定句继续保留在聊天界面、备份和诊断中作为真实历史证据，但通过三个精确内容签名从后续普通/主动模型历史中排除，不再污染新生成；正常的“还没玩”、钓鱼回忆或不同措辞不会被过滤。
- 新增精确重复检测和用户回复保活选择：优先纠正后的非重复候选；若纠正反而重复，则回到原始非重复候选；如果两份都不完美，仍提交一份真实模型输出并记录 `grounded_reply_retry_degraded_pass`，绝不提交固定台词或空正文。
- 主动消息没有待回复用户，仍允许在一次纠正后 `WAIT`；若只剩无法接地的句子或精确重复，则不发送，而不是伪装成她说一句固定的“事实更正”。
- 审计四个 assistant 写入边界：普通聊天、主动聊天、沉浸房间、截断草稿确认。沉浸房间与截断确认写入的是模型流/用户明确确认的草稿；Gemini 失败切 DeepSeek 是模型提供方切换；界面错误提示不进入聊天、记忆或 TTS，均不属于人格固定回复。
- Live2D 本轮暂停，不把尚未在 Sen 原生工程真机验证的 `TextureView/SurfaceTexture` 载体混入 +241。

计划验证：专项静态门锁定“生产运行路径不得再出现三条已知固定人格句”、用户轮非空保活、主动轮阻止策略、版本与工作流；完整 Actions 运行 validator、Flutter analyze/tests、Android/Kotlin tests、arm64 Release、签名与 APK 载荷校验。真机覆盖安装后连续复测“睡着啦？→ 想起什么事？→ 啊？”以及未实际游玩的钓鱼话题，确认每轮均自然回应且不再复读固定句。

本地验证：123 个 validator 已逐项运行，120 个通过；仅 3 个既有门因精简工作区缺少 CI 才恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc` 而失败。+241 专项门、+237 游戏真实性门、回复/表情提交顺序门、Cedar 时间真实性门、当前总账门、Workflow YAML、Python 编译与 `git diff --check` 均通过；完整 Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、稳定签名与 APK 载荷检查交由 Actions。

### 6.15 v0.41.98+242 Sen 完整移植与固定兜底收口（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04198-sen-texture-direct-port`。

纠正记录与根因：

1. Sen 已在 `main@336b93a / v0.5.23` 完成并验收，只能作为只读移植源。曾误在 Sen 创建 `agent/v0524-texture-host` 并编写 TextureView/EGL 测试载体，这是越界操作：本地错误分支已删除，错误 APK/ZIP 已移出交付目录；远端误分支因当前 Git 凭据不能删除，已强制回退到与 `main@336b93a` 完全相同，不再包含错误代码。Sen `main` 从未改变、从未合并、从未发布该实验。
2. +239 的真实现象是 Cubism 已 `ready`、人物网格完整但贴图全黑。重新逐项对照 Sen 构建流程后发现，AI 当时复制了 105 个 Framework Java 文件、Core AAR与36个shader，却漏掉 Sen Actions 每次构建前应用的 `patches/cubism-java-no-mipmap.patch`。
3. Sen 的纹理管理器只上传 level 0，不生成 mipmap；未打补丁的官方 `CubismShaderAndroid.setUpTexture()` 每帧又强制 `GL_LINEAR_MIPMAP_LINEAR`，导致纹理不完整并采样成黑色。+240 因此误把贴图问题当成 Flutter 合成问题，强制 Hybrid Composition 后让整个画面变黑。

本地实现：

- 回退 +240：聊天舞台恢复标准 `AndroidView`，删除 `PlatformViewLink / AndroidViewSurface / initExpensiveAndroidView / forced_hybrid_composition` 生产接线与对应诊断字段。
- 以 Sen `main@336b93a` 机械同步最终接入边界中的16个主运行时Java文件，使它们逐字节一致；不迁入测试壳专用 `MainActivity` 和系统TTS演示类。原先为动态特效锚点与确定性眼镜新增的核心改写已移出：特效回到Flutter固定舞台锚点，眼镜由薄桥接调用Sen已有`applyExpression("glasses")`并跟踪目标状态。
- 原样保存 Sen 的 `cubism-java-no-mipmap.patch`，SHA-256 `227d57f649dc29d83066811be84fdb2e7a0969eac8f36a0e1de7dae96b7ffad7`；在 AI 内直接把同一补丁结果应用到 `CubismShaderAndroid`，唯一允许的 Framework 差异为 `GL_CLAMP_TO_EDGE + GL_LINEAR`。
- 新增 +242 来源门：锁定 Sen 16 文件聚合摘要、补丁后 Framework 105 文件聚合摘要、补丁本体、Core AAR、profile、标准 AndroidView 与失败 Hybrid 路线缺席。专项文档为 `app/docs/SEN_LIVE2D_DIRECT_PORT_v0.41.98.md`。
- 固定回复收口保持：普通聊天与主动联系的本地人格固定句均已删除；Gemini最终呈现每轮至多一次，必要修正走DeepSeek；修正不可用时保留真实模型输出，用户轮不为空，主动轮可不发送。

本地验证：124个validator逐项运行，121个通过；仅桌宠417文件、LingChat effects与`kotlinc`三个既有门因精简工作区缺少CI恢复资源/工具而失败，失败集合与前版一致。+242直接移植门、+241回复保活、+240失败路线回退、+239 shader资源、+238迁移、+237游戏真实性、总账门和`git diff --check`均通过。完整Flutter analyze/tests、Android/Kotlin tests、arm64 Release、稳定签名及APK载荷检查交由Actions。

远端与交付证据：功能 head `84d6a2c869d1c3ca8d802080b0e2826296448df4`、tree `ca8cc6dfa382175123aa33a105ff95b8e935573f`，与本地功能树逐字节一致；`main`未修改。Actions `35532252873`一次全绿，124/124源码门、Kotlin/Android、Flutter analyze/tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact与Draft上传均成功。Artifact `10611821532`，大小`538,351,786` bytes，ZIP digest `888fd377c39098b0a6cb277426586022a675f712e07f3885048fdc8ac896a988`；APK SHA-256 `096d95bfbae99c4dadabfcece89389c824e858bbfa1341430e869686b443f776`。Draft Release为未发布地址`https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-37e74d5b24cf0d2decf5`。当前只等待同一台真机验证，不得提前标记`TRUE DEVICE PASSED`。

保护边界：

- 不修改 Sen 仓库、581项外观、21情绪/动作、四套服装、原生物理、呆毛、兔耳、尾巴、摸头和TTS 90%口型；模型继续只从用户本机ZIP导入。
- 不修改 Cedar 循环、人格、欲望、记忆、TTS声学模型、悬浮桌宠、`main`或正式Release。
- CI/APK通过后仍是 `TRUE DEVICE PENDING`；真机必须确认彩色纹理、透明背景、聊天层级、触摸/摸头、待机、服装/眼镜、TTS口型以及反复进入/退出。

### 6.16 v0.41.99+243 Sen 正式产品接入收口（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04199-sen-product-integration`。

根因与实现：

1. AI 薄桥错误调用带 `startupExpressions` 的重载，把 ZIP 中全部表达、预设和道具在启动时启用；现改为 Sen 稳定工程同款 `loadModel(info.modelFile, true, outfit)`。产品只公开女仆、白衬衫、兔女郎、脱与眼镜。
2. 原生程序动作作为一次性表现保留在隐藏桥接层；原生预设/道具作为装扮式持续状态保留且不展示。未来接入必须同时定义开始与结束/取消时机，例如“载入中”在思考开始启用，在成功、失败、取消或结束时关闭。
3. 19 个非中性聊天情绪加 `normal` 共 20 种接到 Sen；脱或 NSFW 使用额外 `romantic_shy`。既有 Flutter 情绪动画和音效不变。
4. 位置/大小使用单指移动和双指缩放，人物通过 Sen 原生 `setStageTransform` 变换，外部特效共享同一 scale/offset；摸头仍走 `screenToModelNormalized`，所以跟随人物。标准 `AndroidView` 与无 mipmap 补丁保持。
5. `ChatPage` 的 Flutter 全局触点驱动既有视线接口，覆盖聊天框、按钮和其他 Flutter 页面；输入法属于独立系统窗口，无法可靠读取键盘触点，不伪造。根 Scaffold 不自动压缩舞台，只按 `viewInsets` 移动聊天面板，避免人物变形。
6. 自主待机、摸头和 10% 困惑彩蛋保留；现有 `WavAudioPlayer` 继续以实际 PCM RMS 驱动口型，不迁入 Sen 系统 TTS 测试。

验证：125 个 validator 中 122 个通过；仅 417 文件桌宠源码、LingChat effects 与 `kotlinc` 三个既有门因精简工作区缺少 CI 恢复资源/工具而失败。+243/+242/+241 专项门、+240 回退门、总账门、Workflow YAML、Python 编译和 `git diff --check` 通过；完整 Flutter/Kotlin/Release 交由 Actions。Sen 仓库保持独立且未修改。真机覆盖服装/眼镜、20 情绪、NSFW/脱羞涩、位置缩放、特效/摸头跟随、待机、TTS 口型、全页视线和输入法不变形。

远端与交付证据：功能树经 GitHub Contents API 写入后与本地候选 tree `679452c4feef0af657b41aeb9aa3b8466b141f07` 一致；用于触发 Actions 的无运行时改动 head 为 `6a93c2a5067ea9b9b1c42789fc2cc961b397404f`，`main` 未修改。Actions `35539446162` 全绿：125/125 源码门、Kotlin/Android、Flutter analyze/tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗/Cubism 载荷、Artifact 与 Draft 上传均成功。Artifact `10613803835`，大小 `538,358,387` bytes；APK SHA-256 `3cca55f7a48aea699558b2bf5d3f29025205244640d83a6006a79b4bc78cde1f`。Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-31bd7a4c04576a53e034`。当前只等待真机验收，不得提前标记 `TRUE DEVICE PASSED`。

### 6.17 v0.42.0+244 Live2D 干净回退与旧模型清理（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04200-live2d-clean-rollback`。

用户决定与实现边界：

1. 当前 Sen Live2D 将由新模型重新替换，准确回退优先于保留旧接口或界面骨架。三套服装、脱、眼镜、20+1 情绪、原生预设/程序动作、自主待机、视线、摸头、TTS 口型与位置缩放均不作为半成品保留。
2. 以 +237 的共享 UI/Android 文件为机械回退基线，完整删除 Cubism Core AAR、105 个 Framework Java 文件、36 个 shader、Sen 16 个主运行时文件、profile、补丁、PlatformView、Flutter stage/presentation、专项测试与旧生产 validator。`app.dart` 的 IME 特判、`WavAudioPlayer` 的 Sen RMS 接线、MainActivity 的 Sen 生命周期、Manifest/Gradle 依赖一并恢复到接入前状态。
3. +241/+242 的自然回复修复不属于 Live2D：`durable_generation_runner`、`proactive_engine`、`prompt_history_policy`、`recent_reply_repetition_guard` 及其测试/validator 原样保留，禁止固定人格兜底与用户轮空回复的合同不得回退。
4. 旧 APK 已把模型解压到 `filesDir/sen-live2d/{current,staging,backup}`，覆盖安装不会自动删除。新增独立 `Live2DModelStorageBridge`，只接受 `status` 与 `clearImportedModels`；清理前验证 canonical 目标必须是 `filesDir` 的直接子目录 `sen-live2d`，删除后只清空 `sen_live2d` SharedPreferences。聊天两套快捷面板均永久显示“清除 Live2D 模型包”，实际有数据时必须二次确认；静态立绘、聊天、附件、备份与桌宠目录不受影响。
5. 新 Live2D 后续按新模型重新设计，不复活旧 Sen 动作/预设目录。清理桥可以继续独立保留，也可以由未来新 Live2D 设置页复用。

保护边界：不修改独立 Sen 仓库；不修改人格、欲望、记忆、Cedar、TTS 声学模型、悬浮桌宠、schema 61、Snapshot protocol 6、`main` 或正式 Release。

本地验证：+244 专项门、+241 自然回复保活门、当前总账门、Workflow YAML 解析、Python 编译与 `git diff --check` 通过；并逐文件确认五个自然回复核心文件与 +242 head `84d6a2c` 完全一致，五个共享 Android/UI 文件与 +237 head `0caa938` 完全一致。首轮 Actions `35641760278` 在第 16/121 个旧门 `validate_v04143_phase3b_question_autonomy.py` 停止，根因只是六个历史 validator 的当前版本正则止于 `0.41.99+243`；已统一追加 `0.42.0+244`，不改变任何运行时。第二轮 Actions `35642646319` 全绿：完整源码/历史回归门、Flutter packages/analyze/tests、Android/Kotlin tests、release APK 编译、稳定签名、既有资源完整性与 APK 内无 Live2D/Cubism 残留检查均通过。Workflow Artifact `10659441135`，未发布 Draft Release `393217151`，APK SHA-256 `e58122e12f1cc412ff29eccbf0575bb0ae73ba6b524419ea774ad2f5a3dc5684`。真机仍需覆盖安装验证旧模型占用可见且能清除、重启后不恢复、静态立绘/聊天/TTS/输入法无回归。

### 6.18 v0.42.1+245 自主节律、媒体诊断与 TTS 回声防护（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04201-autonomy-media-hardening`。

真机证据与根因：

1. 疲劳本身在 07:49 已从 `rest_need` 恢复，但同一夜间窗口 07:49、08:29 又连续投递；旧 `ProactiveDawnGatePolicy` 只有分数惩罚，没有硬次数上限，且网页/游戏分享可走分开的频率统计。
2. 近期 Cedar 真实成功均来自用户回合；前台 `AgentToolRunner` 只写活动 session，没有像后台引擎一样写 `play_game` 满足账本、疲劳支出和 solo episode。与此同时“我会拿来……玩玩游戏”因宽泛正则被标成 `explicit_request` 并实际调用 Cedar。
3. 备份中的视觉提供商近期错误为 401/403 authorization。普通用户图片依赖千问视觉，因此会失败；App 原生表情包不走视觉 API，已通过 `sticker_index → ChatMessage.promptContent → PromptHistoryPolicy.userTurnHistory` 证明当前语义会进入最终用户轮。
4. 用户明确听到末句变成 `jiuhu_bento_tools.wav`。生产 APK 已删除参考 WAV，且生产播放器只接收推理生成字节，因此不是代码直接播放文件，而是声学条件泄漏/参考回声。旧诊断虽然计算 `referenceEchoSuspected`，导出白名单却丢掉关键字段，且只识别单 token 退化。

实现：

- 新增跨来源的夜间联系硬上限：21:00 至次日 09:00 只允许一条成功主动投递；只统计 `decision=sent`，失败、等待、blocked 不占额度，09:00 自动结束窗口。原 dawn 连续分数调制继续保留。
- 新增 `CedarPlayOutcomeBookkeeper`，前台 Agent 与后台自主推进共享同一套 solo episode、反沉迷、疲劳支出和 `play_game` 满足账本。用户明确触发的真实 solo mutation 可从已到期的旧 checkpoint 开始新 episode；同一前台回合后续动作继续累计，不会每步重置；共玩/多人仍只在有双方许可时推进。
- Cedar 语义边界区分“用户描述自己准备玩”与“让她玩/一起玩”。前者不暴露 Cedar 写工具，即使模型试图选工具也过不了本地 allowlist；后者保持自然入口。
- 千问视觉设置增加使用内置测试像素的真实连接测试，覆盖地址、Key、模型与 JSON 响应；401/403、缺 Key、限流、超时、网络和无效响应以系统 UI 明确分类，不把固定句写成伴侣回复。用户图片保留后可重试；表情包不增加视觉调用，并新增当前 user turn 的 prompt 回归测试。
- CI 在删除四份参考 WAV 前提取 64 段归一化能量包络与过零率，APK 只保留不可逆小型签名和参考文本 SHA-256。推理音频与对应签名在时长、包络和过零率上同时高度相似且输入并非参考原句时，生成段直接失败并禁止进入播放器；不播放参考文件、系统 TTS、固定音频或固定台词。补齐 reference case、字符类别、有效 phone、decoder 次数、PCM 时长/hash 与回声判据的脱敏诊断白名单。

验证计划：运行 +245 专项门、全部历史 validator（CI 恢复资源/Kotlin 编译器相关既有例外单列）、Flutter analyze/tests、Android/Kotlin tests、arm64 Release、参考 WAV 缺席与签名存在检查。Actions 只构筑独立分支测试 APK 与未发布 Draft，不合并 `main`、不发布正式 Release。真机需覆盖验证：夜间第二条主动消息被挡、用户第一人称游戏描述不触发、明确让她独玩后可自主续步、视觉设置准确报告当前 Key、图片识别恢复、表情包理解正常，以及任意句子不再播放参考台词。

本地验证：Workflow YAML 解析、变更后 Python validator 编译、+245 专项门、+244 Live2D 回退保护门、+241 自然回复保活门、+235 疲劳负债门、当前总账门与 `git diff --check` 通过。全量历史静态门实际通过 118 项；另 4 项只因本地 sparse 工作树缺少 CI 恢复的大肥鱼参考图、417 件桌宠源包、LingChat 资源，以及本机无 `kotlinc` 而未执行，不是源码断言失败。本机同时无 Flutter/Dart SDK；完整 analyze/test/Kotlin/release APK 交由 Actions 实编译。

Actions 与交付证据：正确源码树 `0985f0961691bdce7e6d521d59a12137ea5a82ad` 在 run `35809712355` 全绿，已通过总账协调、变更范围判定、全部源码/历史回归门、Flutter analyze/tests、Kotlin tests、arm64 Release APK 构筑、签名验证、四音色回声签名覆盖与 APK 内参考 WAV 缺席检查。Workflow Artifact `10729507323`，未发布 Draft Release `394245028`，APK SHA-256 `4c6f92b38bb3affa12aa52ae18d2d36276400d706b3a570e154d75e453d08059`。没有合并 `main`，没有发布正式 Release。

### 6.19 v0.42.2+246 图片事务与备份冻结真值修复（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04201-autonomy-media-hardening`。

真机证据与根因：

1. 最新相册图片已经完成本地 prepare/commit，真正首错是千问视觉 `403 Free quota exhausted`；账号处于免费额度耗尽或“仅使用免费额度”限制，并非图片选择、保存或 Key 为空。
2. 删除失败是确定的本地逻辑错误：`deleteAttachmentMessage` 在全局 `analyzingImage=true` 时直接返回 `false`，因此用户在八秒视觉请求尚未结束时必然看到“没有删除这条图片消息”。
3. 诊断中的 `errorCategory=lease` 是分类器对 `please add funds` 的错误子串匹配；真实 provider health 与附件记录均为 403 quota/authorization，不存在聊天租约或设备所有权丢失。
4. 备份导出使用 `transfer_lock` 暂停写入，但首页只看布尔锁并统一显示“她正在换到另一台设备”。备份完成后的导出状态证明 `active_brain=true`、`transfer_lock=false`、所有本机租约已释放，没有真实换机。
5. 近期表情包已经由 `sticker_index` 成功建立 user turn 与 generation job，不调用千问；该轮在约 8.8 秒后被用户 Stop，数据库按既有语义撤回了未完成 user turn，因此外观上像“没有发送”。本轮不加入视觉或固定回复兜底。

实现：

- 图片分析记录当前 message id；删除该条时立即提交消息/附件/媒体引用删除并刷新 UI，不再被全局分析标志拒绝。无法取消的在途 HTTP 请求使用本地 discard fence，迟到的成功或失败均不得重建回复、覆盖错误栏或记成真实视觉失败；并在当前请求释放后继续处理可能排队的图片。
- ProviderHealth 增加 `quota_exhausted`，在通用 401/403 鉴权前识别 `free quota / free tier only / add funds / 余额不足`；UI 明确提示充值或关闭“仅使用免费额度”，同时说明原图仍保留。附件遥测只按完整单词 `lease` 匹配，`please` 保持 API 错误。
- 根据 `transfer_lock_owner` 中的 `backup_export / backup_restore` 目的区分写冻结：首页、关系页和聊天阻塞提示分别说明“保存/恢复本机备份”，只有真实接管继续显示换设备。
- 版本提升为 `v0.42.2+246`，新增专项静态门及 quota、遥测、备份冻结展示单测；不修改 Sen/Live2D、人格、欲望、Cedar、TTS、schema 或备份协议。

验证计划：先运行全量静态门与 `git diff --check`；Flutter/Dart SDK 不在本地镜像时，由授权的 GitHub Actions 执行 Flutter analyze/tests、Kotlin tests、arm64 Release APK、稳定签名与现有资源门。真机需分别验证：识别中删除立即消失且不返魂、额度耗尽显示准确、补足额度后图片可正常进入回复、表情包不调用视觉且正常回复、备份期间不再显示换设备。自动化通过不等于真机通过。

本地验证：Workflow YAML、Python 编译、+246 专项门、+245 自主媒体门、+244 Live2D 回退保护门、+241 自然回复保活门、当前总账门和 `git diff --check` 通过。全量 123 项静态门中实际通过 120 项；其余三项只因稀疏工作树缺少 CI 恢复的 417 件桌宠源包、LingChat 特效目录及本机没有 `kotlinc`，不是源码断言失败。本机没有 Flutter/Dart SDK，完整 analyze/tests 与 APK 编译交由 Actions。

Actions 与交付证据：首轮 run `35842639649` 已通过源码/历史门、Kotlin 与 Flutter analyze，Flutter 913 项中 912 项通过；唯一失败只是旧测试仍断言 `build=v0.42.1+245`，生产输出已正确为 `v0.42.2+246`。窄修测试后，功能 head `167a504f4974ef11566b8ac974ab9e7281f00fc0` / tree `2f8c733bb1c80f078bb5b71f88e7b2a3287e8448` 在第二轮 run `35843632708` 全绿：123 项静态门、Kotlin tests、Flutter analyze、913 项 Flutter tests、arm64 Release、稳定签名和完整 TTS/桌宠/LingChat/塔罗资源门全部通过。Artifact `10742996195`，APK SHA-256 `d4c609c0836427155b9f73a6cf629c45f6cff4d88f801be5b4def828839546c2`，未发布 Draft Release `untagged-d99196e0bf0a288629ac`。没有合并 `main`，没有发布正式 Release；真机仍待验收。

### 6.20 v0.42.3+247 纯媒体空文本回合路由崩溃修复（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04203-media-empty-turn-hotfix`。

真机证据与根因：

1. 最新纯图片已完成本地 prepare/commit，且补足额度后千问视觉成功返回；原生表情包历史附件也由本地 `sticker_index` 完成语义，不调用千问。两者都建立了 generation job，却只到 `chat_intimacy_route`，没有进入 `final_reply`。
2. 同刻持久化恢复错误为 `Unsupported operation: Cannot change an unmodifiable set`。纯图片和纯表情包的 `ChatMessage.content` 都合法为空，真实语义位于 `promptContent`；`DurableGenerationRunner` 用空 `content` 请求工具定义，同时仍传入 Cedar 阶段工具集合。
3. `AgentToolPlanner._routeToolIds('')` 返回 `const <String>{}`，`nativeToolDefinitionsFor` 随后对它执行 `removeAll/addAll`，因此在任何模型回复前同步抛错；后台恢复会重走同一路径并再次失败。用户 Stop 只是终止卡住的 job，不是根因。

本批目标与保护边界：

- 在 `nativeToolDefinitionsFor` 的可变边界建立路由集合的防御性副本，未来即使路由函数返回不可变集合也不能再崩溃；不改变空文本本身的工具识别语义。
- 回归必须覆盖纯图片与原生表情包两类 `content='' / promptContent 非空` 消息，并证明 Cedar 阶段工具仍能安全注入；普通空文本且没有 Cedar 阶段时仍返回空工具列表。
- 不修改千问、视觉重试、表情包索引、模型调用策略、Cedar 阶段选择、人物表达或固定回复；schema 61 与 Snapshot protocol 6 不变。
- 完成后运行专项静态门、相关 Flutter tests、全量静态门与 CI 完整 analyze/tests/arm64 Release；只产出独立分支测试 APK 与未发布 Draft，不合并 `main`、不发布正式 Release。真机最终需分别发送一条无附言图片和一个原生表情包，确认都收到正常回复且诊断无新的 `last_generation_recovery_error`。

实现：`nativeToolDefinitionsFor` 现在以 `<String>{..._routeToolIds(text)}` 在 Cedar `removeAll/addAll` 前取得可变集合所有权；没有 Cedar 阶段的普通空文本仍返回空 schema。新增同一测试中的纯图片与原生表情包 fixture，均断言 `content` 为空、`promptContent` 非空，并验证 Cedar gateway 安全注入且不抛异常。版本提升为 `v0.42.3+247`，新增专项静态门与独立分支 CI/Draft APK 身份；未修改视觉、`sticker_index`、模型策略或 Cedar 权限。

本地验证：+247 专项门、验证清单结构（124 项）、Workflow YAML、Python validator 编译与 `git diff --check` 通过。本地稀疏工作树未检出部分 Android/诊断/欲望目录，且镜像没有 Flutter/Dart SDK，因此完整历史门、Flutter analyze/tests、Kotlin tests 与 Release APK 交由 Actions 实编译；这部分仍是 `CI PENDING`，不提前宣称通过。

Actions 首轮 run `35854318795` 在第 16/124 项源码门前停止：生产修复与新增专项门未报错，失败仅因七个历史 validator 的版本正则最高只接受 `v0.42.2+246`。随后统一追加 `v0.42.3+247` 兼容项，不放宽任何功能断言；本地确认七处版本门、Python 编译、+247 专项门、验证清单结构与差异检查通过后进入第二轮完整构建。

Actions 与交付证据：第二轮远端功能 head `8fabae5016a7d457b58a581a7a2b609bc0ab69c8` / tree `fc7ca8d84dadabf33dc1f151895f52c42b62ce72` 在 run `35855141996` 全绿：124 项源码/历史回归门、Kotlin tests、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗资源门、Artifact 与未发布 Draft 上传均成功。Artifact `10747841131`，APK SHA-256 `6a5d04b79fba46139b16bb185f955fb87431e1b30c4f75f89a09788054b89bab`，未发布 Draft Release `untagged-376e1bf8ac7aac97af25`。没有合并 `main`，没有发布正式 Release；真实图片与原生表情包回复仍待真机验收。

### 6.21 v0.42.4+248 TTS 自动核亲和与全工具活动展示（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04204-tts-affinity-tool-activity`。

用户决定与本批范围：

1. 本批只制作两项：从 `catkiss62/Genie-TTS-Android` 最终验证分支/提交 `agent/v084-native-vs-affinity-diagnostic@a5a8425f221575eaca542ac9ae4bbf5e5b799153` 正确移植 TTS 自动核亲和，并完成所有用户回合 Agent 工具的展开/持久活动展示。双人格与命运之轮只登记设计分析；新 Live2D 继续等待独立测试项目，不接入。
2. TTS 开关默认关闭。关闭时保持伴侣原生产配置：四个声学会话固定 CPU 8 线程，Chinese RoBERTa 使用当前 CPU 数；开启时五个会话必须逐项同用 `VerifiedRuntimeConfig.AUTO_AFFINITY`：CPU EP、intra-op 原样 `0`、inter-op `1`、`SEQUENTIAL`、`ALL_OPT`、intra/inter spinning 均为 `1`，VITS 默认 memory pattern 不关闭。不得把 `0` 改成 `max(1, ...)`。
3. 明确不移植独立测试仓库里的原生 8 线程对照档、比较/报告 UI、动态分块、FTZ/DAZ、Decoder 输入映射复用、memory-pattern 实验、XNNPACK/NNAPI 实验或 sustained-performance 实验。现有 Decoder 循环、固定一秒首段预填充、串行句段生成、连续单一 `AudioTrack.MODE_STREAM`、Stop fencing 与下一段预生成队列保持不变。
4. 配置切换由主进程先 Stop；AIDL 配置调用在 `:genie_tts` 隔离进程既有 `Genie-TTS-worker` 上排队，等待当前不可强杀的 ONNX 调用自然返回后关闭四个声学会话及 Chinese RoBERTa，再按新档懒加载。迟到结果由既有 generation token 丢弃，不增加并发 session owner。
5. 工具调用生成中使用默认展开列表，按真实回调显示“正在做什么/成功/没有结果/失败/未获准/已停止”；终态从已有 `agent_tool_outcomes` 与 `generation_jobs` 关联到助手消息或中断标记，折叠卡片可查看工具名、状态、结果数量、耗时、时间与来源设备。数据库仍只保留 90 天/最多 200 条有界元数据；参数、查询词、URL、网页正文、工具结果正文、Prompt、推理正文、密钥与房间凭据从未进入该接口。
6. schema 保持 61，Snapshot protocol 保持 6。没有把工具活动写进 `messages`，因此不会进入 Prompt、记忆提取、总结、关系学习或她的第一人称自我叙事；可见思考与工具事实仍是两条独立展示链。

已实现代码合同：

- `BenchmarkModels.kt` 新增最小生产配置类型与唯一 `AUTO_AFFINITY`；`GenieBenchmarkEngine` 的单一 session factory 对四个声学模型应用精确设置；`ChineseFrontend.configure` 对 RoBERTa 应用同一配置；`GenieTtsRuntime` 负责默认档/加速档映射与安全卸载。
- AIDL、隔离客户端、原生引擎、MethodChannel、Dart provider/service 与语音设置页已贯通；状态和脱敏 checkpoint 暴露 `runtimeProfile`，便于真机报告证明实际使用的档位。设置键为 `tts_auto_affinity_enabled`，默认 `0`。
- `AgentToolStatus` 新增 `stopped`；用户 Stop 时记录真实终态。聊天控制器保留本轮多项活动，历史通过生成任务 ID 投影，不做 schema 迁移；聊天页提供生成中展开面板和终态可展开卡片。
- 新增 Kotlin 配置合同测试、Dart 状态/工具投影测试与 +248 静态门。完整 Kotlin/Flutter/Release 编译仍需 GitHub Actions；本地 Gradle wrapper 因当前执行环境无法访问 `services.gradle.org` 尚未完成编译，不能提前标为 CI 通过。

本地验证：+248 专项门、+247 空媒体回归门、+244 Live2D 干净回退门、当前总账门、Workflow YAML、Python 编译与 `git diff --check` 通过。完整 `validation_suite.txt` 共 125 项，121 项通过；其余四项只因本地工作树没有由 CI 恢复的大肥鱼参考图、417 件桌宠源包、LingChat 资源及本机没有 `kotlinc`，不是源码断言失败。Gradle wrapper 尝试下载固定 Gradle 8.12 时被当前环境网络策略阻止，Flutter/Dart SDK 也不在本机，因此当时将 Kotlin 编译、Flutter analyze/tests 与 Release APK 交由 Actions 实编译，结果见下条。

Actions 与交付证据：远端功能 head `33647c7bff15084d6fd3cbc7b817e9b0b216f75c` / tree `80f49d8e93bcfe2a03737a6b8610fbd94d10c255` 在 run `35878106718` 全绿；APK SHA-256 `04a588d2d4628ccaacd1b0b9aaf3759430b46ba33ad69715cb388098c178f0be`，未发布 Draft Release `untagged-2b371d8cd86b365121b0`。该构建证明自动核亲和与工具活动代码可编译、全套门通过，但不代表之后由 +247 备份确证的 Decoder 零语义参考泄漏已经修复；该共享旧逻辑进入 +249 根修。

真机验收：先保持开关关闭做一条短句；开启后做一条短句真实播放与一段长文本连续播放，确认音色、Stop、分段衔接及 AudioTrack 队列正常，并在诊断中确认 `runtimeProfile=auto_affinity_v084`。随后各触发一次成功、无结果/失败和执行中 Stop 的工具调用，确认生成中逐项显示、回复后可展开、重启后仍存在，且卡片不出现参数、搜索词、URL 或结果正文。独立测试报告曾推算部分后续段可能短暂迟到，所以即便总 RTF 小于 1 也不得以此验收删除缓冲。

#### 后续冻结分析：双人格

1. 排序固定在 +248 真机收口之后再单独讨论，不在本批建立人格状态、气焰/害羞数值或立绘切换。用户指出当前人设或既有记忆可能已经偏激进；若直接让“雌小鬼”语气推动气焰值，会产生正反馈并快速顶满，因此后续第一步不是做触发动画，而是审计当前内置人设、用户编辑的人设、人格学习候选、长期记忆/总结与可能已有的激进表述，区分“基础语气偏强”与“状态变化”。
2. 推荐首版采用用户可见的手动双人格切换，两个形态共享同一 AI/记忆主体，但使用独立、显式的当前形态状态；进入沉浸房间时把入口形态钉住，房间内不因普通一句话自行跳变。自动量表应等审计和手动版稳定后再设计，不能仅按毒舌关键词自增，也不能从模型回复反向无限喂高自己。
3. 若后续使用气焰/害羞量表，必须定义可解释的外部事件输入、双向衰减、滞回阈值、每日/每回合上限、手动复位及存档迁移；不能把现有长期记忆整库改写成雌小鬼人格，也不能让形态状态污染事实记忆。旧存档初始值应为中性/未选择，而不是根据历史文本猜测。
4. “嘭”烟雾只作为形态切换的可替换表现层：先用静态烟雾图 + 短缩放/渐隐验证遮挡和节奏，效果不好可无数据迁移地关闭。新小小鱼立绘仍以测试项目验收为前置，不复活已回退的 Sen Live2D 链。

#### 后续冻结分析：命运之轮

1. 用户已决定首版采用“直接本地移植 + 手动同步上游”，不做自托管网页、WebView 或通用 MCP 依赖。后续开工时先冻结上游 commit、许可证/署名、tag 数据格式与 RNG 行为；每次同步由人工比较并记录上游 commit、数据/逻辑差异与本项目适配，不自动拉取远端内容。
2. 本地实现应只有一个结构化轮盘 Outcome（选中的安全分类/tag、来源版本、随机事件 ID），由现有真实工具/Outcome 真值链消费；不把原项目 UI、Node 服务或任意脚本执行面整体搬进 APK。NSFW 内容继续服从当前成人场景入口、用户设置与沉浸边界。
3. 产品入口推荐先做“房间外抽取 → 带结构化结果进入沉浸房间”，因为结果、重抽与进入边界最清楚；稳定后再复用同一 Outcome 增加房间内娱乐入口，不能维护两套随机结果。作者所说的“MCP 操作”只表示外部 AI 可通过其暴露的工具协议代替玩家点击；本项目既已选择本地移植，首版无需为此增加 MCP 服务器或第二套循环 owner。
4. 后续仍需逐文件审计上游许可证、资源版权、tag 内容与移动端适配后才能实现；当前只冻结架构结论，不宣称已经完成移植。

### 6.22 v0.42.5+249 TTS 零语义根修与最后两次会话诊断（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04205-tts-semantic-guard-session-metrics`。

#### 真机证据与根因

1. 用户提供的 +247 备份 `AI_Companion_Backup_2026-09-23T15-19-22.aibackup` 与同刻诊断显示，最后两轮不同回复都混入了参考录音；倒数第二轮为 `daily / jiuhu_bento_tools`，最后一轮为 `cute / jiuhu_devotion`，因此不是某一个参考文件或某一句回复的偶发问题。
2. 倒数第二轮 14 段中的 2/5/6/7 段都出现 `decoderIterations=1`、`semanticCount=122`、固定 semantic hash `4eb0e366`、音频 4,880 ms；最后一轮 12 段中的 2/4 段出现 `decoderIterations=1`、`semanticCount=87`、固定 hash `cc653afb`、音频 3,480 ms。坏段 6 有 21 个字符、41 个有效 phone，排除“只因标点空段”的解释。另有一个独立 `NullPointerException` 失败，不与参考回声混为同一根因。
3. `GenieBenchmarkEngine` 原逻辑在 stage Decoder 第一次调用就 stop 时令 `loopIndex=0`，随后却执行 `requested = yValues.size`，把整个 `y` 张量当作新生成语义。该张量含参考 prompt 前缀，因此 VITS 重建对应音色参考录音。正常事件满足 `decoderIterations = semanticCount + 1`；上述 1/122 与 1/87 正是相反证据。
4. 旧二级门只拒绝 `decoderIterations<=1 && semanticCount<=1`，所以被错误报告成 122/87 的 prompt 前缀绕过；声学门又要求近乎同波形，而重新经过 VITS 的参考语义不必与原 WAV 逐采样相同，daily 相似度约 0.28～0.30、cute 又受时长门影响，故同样漏判。APK 没有直接播放参考 WAV 的生产调用，根因是参考语义重建，不是文件播放器。
5. 同一抽取逻辑也存在于独立 Genie TTS 测试仓库最终提交 `a5a8425f221575eaca542ac9ae4bbf5e5b799153`，固定测试句没有触发首轮 stop；+247→+248 的生产差异只改 ORT 配置，不改语义抽取。因此这是两个项目共享的潜伏引擎 bug，不是 AUTO_AFFINITY 迁移造成的回归。

#### 本批实现合同

1. 新增纯函数 `GeneratedSemanticTokens.select`。`loopIndex=0` 明确抛出 `NoGeneratedSemanticTokensException`；`decoderResult` 无论成功/拒绝都关闭，且 VITS tensor 只可能由真实新生成的尾部 token 构造。没有固定音频、固定台词、系统 TTS 或参考语义兜底；该失败段返回空，既有 A2 队列继续播放其他成功段。
2. `GenieTtsRuntime` 在拒绝时写入 `semanticCount=0 / immediateStop=true / referenceEchoReason=decoder_no_generated_semantics`；旧声学防线保留，并收紧为只要 `decoderIterations<=1` 却生成长音频就拒绝，不再信任可能已污染的 semanticCount。
3. Scheduler 通过 `beginTtsSession / finishTtsSession` 显式标出一次完整朗读。原生端按 generation 聚合成功、失败、拒绝、无音频和 Stop；最后两次尝试单独持久化，清除 Native 历史时同步清除。诊断只保存字符数、SHA-256、语言/音色、profile、计数与耗时，不保存回复正文、Prompt、PCM/WAV、参考路径或音频。
4. 每段记录生成时实际 `runtimeProfile` 与完整配置说明、冷/热模型状态、frontend/model load/fixture/encoder/首步 decoder/自回归/vocoder/总推理/端到端、semantic/decoder 数、音频时长、RTF、生成调用耗时、入队等待和实际播放倍速；会话聚合首段 ready、AudioTrack 开播、总 RTF、估算最小缓冲、迟到段、完成/部分/失败/停止状态。
5. `NativePreflightProbe.ttsSessionDiagnostics` 导出最后两次完整快照。只有文本分段哈希相同、语言与音色工作负载相同，且两次分别为 `legacy_fixed_8` 与 `auto_affinity_v084` 时，才给出 AUTO_AFFINITY 总推理降幅；不同回复或不同音色明确标记不可比较。播放倍速与推理速度分开记录，自动核亲和不改变 AudioTrack 的 1.0x（温柔音色既有 1.2x 仍单独显示）。
6. schema 61、Snapshot protocol 6、模型文件、四音色映射、文本分段、串行推理、首段一秒 PCM 预填充、连续 `AudioTrack.MODE_STREAM`、Stop fencing 与配置开关默认值均不变。

#### 回归与验收

- Kotlin 门覆盖四种可选音色形状的首轮 stop 均拒绝、正常尾部抽取不修改源数组、失败段诊断、同工作负载双档比较与不同回复禁止比较；Dart A2 测试同时锁定成功/无音频会话都必须完整关闭。
- 真机依次对同一条回复在关闭加速与开启加速下手动播放一次，随后立即导出诊断；`sessions` 必须恰好保留这两次并显示 `comparison.comparable=true`。再用多段长文本验证迟到段、最小缓冲、Stop 与后续段继续播放。
- 四音色各覆盖一次包含多段的回复，诊断中不得再出现 `decoderIterations=1` 同时 `semanticCount=122/87` 且产出长音频；遇到首轮 stop 应看到 `rejected_no_generated_semantics`，该段无声但其他成功段照常播放。
- 本地最终验证：`git diff --check`、Python validator 编译、Workflow YAML、当前总账门、+249 专项门与 +248～+244/+203～+200 重点历史门通过。完整 `validation_suite.txt` 共 126 项，122 项通过；余下 4 项仅因本地工作树不含 CI 恢复的大肥鱼参考图、桌宠源包、LingChat NOTICE 及本机无 `kotlinc`，不是源码断言失败。
- 本地环境无 Flutter/Dart SDK；Gradle wrapper 尝试运行 `testDebugUnitTest` 时，Gradle 8.12 下载被当前网络策略拦截。该本地限制已由下述 Actions 完整 Kotlin tests、Flutter analyze/tests 与 arm64 Release 实编译结果补齐。

#### Actions 与交付证据

- 首轮 run `35898976733` 在历史 `validate_preflight_kotlin_v27.py` 失败：该门只编译 `NativePreflightProbe.kt` 与临时桩，未声明新增 `TtsSessionDiagnosticStore`。已补齐只读桩并由 +249 专项门锁定，不改生产运行时。
- 第二轮 run `35899547271` 已通过 126/126 源码门、Kotlin 编译/测试与 Flutter analyze；915 个 Flutter 测试中 914 个通过，唯一失败是 `agent_self_reader_v0416_test.dart` 仍断言上版 `v0.42.4+248`。已更新为 `v0.42.5+249` 并纳入 +249 门。
- 最终远端 head `fb7f77f85d882f99530ab829df9a82eaa604e559` / tree `28e4fbafb5adb2bfaa58aa9ab6e1b1256f0c4b99` 在 run `35900627244` 全绿：126/126 源码/历史回归门、Android/Kotlin tests、Flutter analyze、915/915 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与未发布 Draft 上传均成功。
- Artifact `10770090214`，名称 `AI-Companion-v0.42.5-249-TTS-Semantic-Guard-Session-Metrics-APK`，大小 `538,139,766` bytes，ZIP digest `0b1ca2a49a24047cbd7c659f66fa048f2a7d7f24f6394937a2a4859a177dbd51`。APK SHA-256 `546dd718d447b0987bf47aaba08089fefb0badffbc076ba38e695fb3e05263c5`，未发布 Draft Release `untagged-3a02088d4968fd7ab603`。没有合并 `main`，没有发布正式 Release；参考语音根修与同回复双档诊断仍待真机验收。

### 6.23 v0.42.6+250 双形态与手动 TTS 无声对照（2026-09-23）

- 状态：`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。分支 `agent/v04206-tts-mood-dual-mode`，从 +249 远端已交付源码单独建立；本节不包含用户备份、诊断或聊天明文。
- 双形态：本体／小豆丁形态是同一成年角色，记忆与能力不变；持久化气焰、形态与锁定；每个真实用户轮按消息 ID 仅推进一次，严肃语境退出自动小豆丁形态；点击心形量表可触发一次虚拟轻弹额头/安抚并升/降气焰，事件只注入紧接着的回复。锁定保持立绘形态，但严肃语境降低表达锋芒；界面气焰提示、形态自知与显式 Agent 检查系统读数统一显示“小豆丁形态”。
- 性格：未编辑的常驻性格光谱与成人核心身份文案做精确指纹迁移，保留用户自行编辑条目；激烈耍性子只由当前真实小豆丁形态状态承载，不把属性名常驻注入每轮。旧版 +250 未编辑默认文案按精确内容哈希升级为“小豆丁形态”，用户自行编辑的内容保持原样。
- 用户补充后的形态定义：身体外观缩成 Q 版小豆丁，情绪控制与表达暂时孩子气，更任性、冲动、耍赖和暴躁；得意时逞强挑衅，被看穿或轻巧反击时嘴硬、害羞、慌乱破防。角色仍是同一个成年人，记忆与判断能力不变；严肃话题仍可收住。已同步当前形态提示、常驻世界书、Agent 自读；添加 +250 旧默认正文的精确 SHA-256 `06b01d4e…87f3e` 到迁移白名单，自定义条目不覆盖。此前 Actions 成功的 APK 和正在编译的名称修订版均不作为本轮最终交付，需以本版定义重新构建。
- TTS：语音与情绪页显示当前胜出档和本轮候选档两个无声测试按钮、复制专项报告和样本更新文字入口。固定同一条已提交的真实 API 回复、语种、音色、前处理和分段，在隔离 Genie 子进程测自动核亲和与自动 Decoder＋8 线程 VITS；逐段只保存哈希及耗时，失败或不一致禁算胜者，比较足够明确时才持久化生产档。普通会话不再持续写入详尽成功片段性能历史，原生错误与崩溃线索保留。
- 验证与后续：先完成源码门、Flutter analyze/tests 与 Kotlin/arm64 Release 构建；真机检查心形液面、按钮语义事件后跨轮持续、自动/锁定形态、三语入口共享会话配置，以及同样本双档无声对比是否有效。性能提升没有预设 50% 结论。
- 最终构建证据：功能提交 `b5cd2d1070fb237bc72ab66b1867a75da9bbe6e8`，tree `4e0dbbd531aea408ab0face6d46a323f441c7eeb` 与本地源码一致。Actions `35943607609` 源码门 126 项、Kotlin 单元测试、Flutter analyze/test、arm64 Release APK、签名和包内资源核验全部通过；Artifact `10785922926`，APK SHA-256 `f148f2eb303017ad5f6f689628f230979c24ba16831fdc0181e58bc5e1d73a`，Draft `v0.42.6-dual-form-tts-comparison-test`。仅 CI 通过，双形态语气、立绘与 TTS 对照仍待用户真机验收。此前仅改名称的 run `35941949391` 虽全绿但定义不完整，已由本次构建取代。

### 6.24 v0.42.7+251 气焰语义增长（2026-09-24）

- 状态：`DESIGNED / IMPLEMENTATION IN PROGRESS / CI PENDING / TRUE DEVICE PENDING`。用户在 +250 真机确认：本体性格稳定、小豆丁表现明显且不过分；但自然逗弄没有关键词就不会涨气焰，现有每轮 `-4 + 命中词时 +13` 从零到 76 通常需九轮，和此前“互动推动”的说明不符。此前代码事实必须保留，不把关键词版写成已实现语义理解。
- 目标：复用普通用户轮已有的 DeepSeek 亲密路由调用，一次返回亲密路由和本轮互动强度；只把实际用户参与的玩闹作为正向输入，不由她自己的上一句情绪或提示词自抬气焰。语义强度经过本地限幅，约五轮普通互相较劲可达自动变身阈值；手动按钮立即改变数值与形态，锁定仍只影响自动切换。正常聊天不新增模型调用；失败或字段缺失时不猜加分，保持回复链继续。崩溃/Stop/重新生成按 user turn ID 幂等，严肃语境抑制玩闹；按钮事件只在近期下一次相关回复有效。
- 验证：覆盖无关键词的自然逗弄、关键词出现但语义认真、上下文互相较劲、隔时衰减、同轮重试/手动锁、按钮事件过期与严肃抑制；源码门、Kotlin、Flutter 与 arm64 Release 构建通过后交付 APK，真机验收单独记录。

- 本轮合并 +251 真机反馈：语音与情绪页面在读取 TTS 状态前先展示设置，TTS `status()` 只读，不在打开页面/快速自检时隐式重配模型；快速自检对孤立进程读取设置 3 秒边界，深度自检仍执行完整校验。两个测速按钮明确标为无声对照；根据当前语种和朗读范围从最近的真实回复中选择可朗读样本；若没有对白，明确标记后改用真实回复全文，不再固定拿一条长但只有动作的回复，测速选样不先初始化声学模型。`试听发声` 才是实际有声按钮。用户脱敏报告中的 TTS 状态读取失败，以及历史原生生成 `NullPointerException` 分别记为待真机验证，不把当前样本报错当作后者已解决。
- Gemini：对照 Google 官方 OpenAI 兼容 REST 请求示例，将 `google.thinking_config` 移入实际请求体的 `extra_body`；仅在最终候选经过可选修正后呈现对应模型返回的思考摘要，避免先显示被弃用候选的摘要而最终正文没有摘要时闪退。摘要缺失依旧为空，不造人工思考。非 Gemini 自定义模型不加专用字段；服务商转发是否支持新参数须以真机验收。
- 判断型内部路由继续 `thinking:false`，只复用既有 DeepSeek 亲密路由返回的语义互动强度；五轮自然互相较劲的目标是本地上限映射，非模型随意决定 0～100 分。手动亲密开关继续旁路路由，无额外请求。
- 状态：`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；版本 `v0.42.7+251`，功能 head `13533d1f087850a6889ce34064697ae2629e9cbd`，tree `273be445c45007775272ca03533a35e4354ba571`。Actions `35952517475` 完整成功：126 项源码门、Kotlin、Flutter analyze/tests、arm64 Release、签名与包内资源门通过；Artifact `10789656940`，APK SHA-256 `a72f1a97d911495854af1b91336ab98892e512b46b7af8a97dbda92ab79b4a21`，未发布 Draft `untagged-8a0d0901c585b9b8f490`。CI 证明编译与自动门通过，不代表真机 TTS 原生空指针或第三方转发链路已修复。

- Jev 评估（研究，本版未集成）：`jevtypesafeai.com` 自称独立平台，明确声明未获 TypeSafe AI 背书；官方为 `typesafe.ai`、`docs.typesafe.ai`，官方调用是 `POST https://api.typesafe.ai/v1/systemone`。Jev choice/score/noul 适合短而明确的多项判断；中文调侃与关系上下文仍须用同批脱敏人工标注样本比较准确率、延迟和费用。当前气焰复用已有 DeepSeek 路由，单独迁移会增加网络调用。未接第三方平台、未新建密钥或上传私密对话。出处：https://typesafe.ai/ ，https://docs.typesafe.ai/introduction ，https://jevtypesafeai.com/ 。
- 余额汇总评估（研究，本版未集成）：DeepSeek 官方 `GET https://api.deepseek.com/user/balance` 可用对应官方密钥查询真实余额；玩游、Agnes、千问视觉、Tavily 与 TypeSafe Jev 的额度查询不能套用一个聊天接口，未证实其官方只读接口及当前 Key 权限者须标示控制台入口或明确为本机估算。未来“模型与联网”设置可分提供商手动刷新，显示来源与时间、失败独立呈现；Key 留在现有安全存储，只向自身核实的域名发送。出处：https://api-docs.deepseek.com/api/get-user-balance ，https://docs.typesafe.ai/api 。

### 6.25 v0.42.8+252 Jev 短判断试点与游戏结果复读（2026-09-24）

- 从 +251 已构建远端源码创建独立分支；保留 +251 五轮气焰语义判断、TTS 与 Gemini 修正。Jev 默认关闭，独立加密 OpenRouter Key，只负责普通聊天的一次组合判断（亲密描写深度 + 气焰交互强度）及沉浸房间的一次组合判断（场景深度 + 明确事件）。手动开关与确定性事件优先，Jev 不生成对白或记忆，不改 Gemini 最终回复。其他 DeepSeek 短判断尚未迁移。
- 单一 JevDecisionGateway 使用 OpenRouter Decisions typesafe/jev-1.13，每请求含状态与多条 choice；选择缺失、低 confidence、网络/鉴权/402/超时等返回 null，由原 DeepSeek Flash 不思考判断完整接管；取消不额外发兜底。只有费用/Token/耗时/失败类型的 120 条有界脱敏账本 jev_short_usage_v1，包括 OpenRouter 实际 usage.cost，不含问题或聊天正文。设置页面连接测试消耗少量额度；用户需验证真实误判与实际账单才扩大覆盖。省钱和准确率并非预设结论。
- 用户诊断/备份证明：同一份自测结果被 sins_virtues_answer_batch 与稍后的 sins_virtues_get_result 各自种植分享念头。结果快照读取不再生成新的主动分享 Thought，同时以 quiet 标记活动记录而不成为新的近期主动话题；真实完成新题与独立终局通知仍可分享；历史已入库旧 Thought 不删除。
- 余额面板另批处理：DeepSeek/OpenRouter/千问/Gemini 中转接口及凭据权限不同；此次只记录本功能产生的实际费用。验证顺序：126 个源码门、Flutter analyze/tests、Kotlin、arm64 Release、签名及 Draft，真机验证错 Key、402、停止、两路对照和旧测试结果不重复分享。CI 和真机结果必须分别回填。

- 最终 CI 交付证据：功能 head fa62d0c08aeb0597a874526c8015fecc4544c6f3；Actions 35961379029 全绿，源码门、Kotlin、Flutter analyze/tests、arm64 Release、签名和包内资源门通过；Artifact 10793156007，APK SHA-256 ee7fec22ff304d1c2e20f1da1cb32208f13a69ef4a798d4ab22826f87d725d52；未发布 Draft URL 为 untagged-247641dabd0b4c85691f。此前 e621f28 的 run 35960427181 虽全绿但尚未将读取旧结果的活动记录标为 quiet，已由本轮替代。只证明 CI，不代表 OpenRouter 实时调用、余额不足回退或游戏厅真机自然表达已验收。

## 6.26 v0.42.9+253 TTS 自检与五轮语义气焰（2026-09-24）

- 用户真机截图：TTS 资源未就绪、连接 Genie TTS 子进程超时，测速失败；自检页面与 TTS 页面同样等待状态。脱敏备份气焰已达 100。诊断中另有声学进程成功生成第一片段、第二片段原生 NullPointerException 与子进程退出，不能从这份日志证明空指针的具体代码位置或真机发声已经恢复。
- 快速自检读取主进程 APK manifest 并标注只验证资源，不绑定声学子进程；深度自检仍执行黄金资源校验和初始化。TTS 连接超时/死亡重置旧绑定与等待锁，下一次显式试听或测试能重新绑定，超时写入无正文脱敏诊断。
- 一键顺序无声测速两档，同一次固定回复、同一分段、同一批次才能比较与改变胜出档；失败独立记录代码并仍尝试另一档。试听发声是唯一有声按钮，复制专项报告保留。
- 气焰值继续使用 0～100；每轮 -10（另计自然小时衰减），轻度/互相/强烈主动玩笑分别 +16/+26/+28，认真话题再 -18。仅害羞、脸红、尴尬而未回敬时给 ordinary；满值五轮普通对话降至 50 并退出小豆丁。Jev 与 DeepSeek 的两组分类提示一致。备份与 Jev 脱敏用量只证明当时高位及部分低置信度兜底，不记录选项文本，不能断言具体回合是哪一路判定。
- 验证：源码门、Flutter analyze/tests、Android Kotlin、arm64 Release 和签名交给独立 CI；CI 与真机结论另行回填。声学空指针位置需要新包诊断或真机堆栈才能进一步收口，不用另一种音色/固定台词伪装成功。

- CI 交付：功能 head `5a8263efc925f32d80da6dc8af34aaf55cf97d71`；Actions `35974252470` 全绿，126 项源码门、Android Kotlin、Flutter analyze/tests、arm64 Release、签名及 APK Genie/素材校验通过；Artifact `10797768347`；APK SHA-256 `6f4a3c34f987f41c912e2427b8386ba6d70731e30ebf9537120a830db4cc3640`；未发布 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-7ba9838d3966a80f6d12`。该证据不等于真机发声、旧子进程空指针或语义体感已验收。

## 6.27 v0.42.10+254 语音音量、气焰和新库事故（2026-09-24）

- 用户新诊断 `2026-09-24T08-44-43Z` 属 +253 包；与 +252 的 `2026-09-24T06-40-13Z` 对比，`database` 身份和数据谱系同时改变，`stateGeneration` 由 183 变 0，记忆 422→0，会话 1→0，系统恢复计数和原生诊断也重新从零开始。这证明当前是新库，不能从重启后诊断查明清空动作或当次闪退堆栈；源码中 SQLite 数据库只在应用私有数据库目录打开，本批没有发现 TTS 删除该目录的调用。包内 `allowBackup=false`，系统自动还原不能当作恢复承诺。已知外部 06:39 存档必须保留原件，真机由用户确认后在应用内导入；严禁通过改安装包、清数据或新建空库“修复”旧数据。
- 新建库默认 `tts_enabled=0`、`emotion_sound_enabled=0`；+253 报告中 TTS 只有本地 APK 资源检查，没有声学生成或播放尝试。因此“自动回复没声”至少与丢失设置吻合，无法凭此诊断认定 Genie 播放引擎已损坏。恢复/打开开关后需试听一段普通聊天并导出新的播放专项诊断。
- 情绪 WAV 先前被标记 `USAGE_ASSISTANCE_SONIFICATION`，与 Genie 的 `USAGE_MEDIA` 分属不同音量策略。改为媒体 usage，主界面音量键目标固定到 `STREAM_MUSIC`。游戏内音量继续作为媒体音量之上的独立系数；需要真机检验手机媒体音量从 0 到 50% 再到 100% 时语音和情绪音效是否一致变化。
- 气焰的现行公式是每轮 `-10 + bonus`；旧 `light=+16` 实际每轮净 `+6`，确实会在普通玩笑里持续升温。现将 light 调为 +4、净 -6，ordinary 净 -10，mutual 净 +16、strong 净 +18，serious 净 -28；Jev 和 DeepSeek 双提示把 mutual 收紧为用户主动升级的互相挑战。5 轮 mutual 从 0 升到 80 的既有真值保留。旧 Jev 回退日志混合“低信心/格式无效”；新日志仅记录失败问题类型和状态，不记录对话、答案或概率，DeepSeek 回退不变。
- 回归边界：保留普通聊天、手动试听和一键无声对照三个入口；`app/test/playful_form_heat_test.dart` 增加轻微玩笑连续降温，历史音频验证门要求情绪音效和媒体流一致并有音量键路由。分支验证、CI/APK 和真机结论必须分别标注，不能以模拟测试宣称发声成功。用户对“扩充 Jev Noul/Score”还在讨论，本版没有改调用次数或按概率加热。
- 用户补充的图形参考：不是传统温度计刻度，而是上方独立发光的小爱心 + 细长暗色玻璃管，粉色液面按 0～100 气焰高度升降。`PlayfulHeatGauge` 的本地候选画法已按参考图重绘，仍保留轻弹额头、温柔安抚、形态锁定菜单及无障碍读数；需 APK 真机核对视觉质感。上线前用真实对话的 Jev/DeepSeek 分类观察 ordinary、light、mutual 的比例，再决定是否微调气焰参数；目前 +254 的参数只是待真机校准的候选值。

## 7. 历史验证兼容摘要

下列短语只为既有自动化门继续识别已完成阶段；权威细节在冻结归档，不代表当前任务重做：

- `v0.34.5+70`、`直接选择器 guard`、`冻结悬浮恢复`；`每小时最多 6 次`、`不暂停自主联网`、`电池优化白名单`；`v0.35.1+76`。
- `v0.39.5 新版妹居 TTS 运行时迁移`；`0.41.5+144`、`0.41.6+145`、`schemaVersion=41`；`v0.41.7`、`Memory Phase 1`、`Bad state: No element`。
- `Phase 1`、`误判不可接受`、`Phase 2 继续关闭`、`不合并 main、不发布正式 Release`；`Phase 2A`、`#D4BBFC`、`relationshipAge()`。
- `0.41.19+158 / schema 44 / snapshot protocol 5`、`动作与神态不是随机可选装饰`；`v0.41.20`、`stay_with_user_topic=0`、`CONVERSATION_AGENCY_PHASE2A5_v0.41.20.md`；`分享前重新阅读的核心是恢复上下文`、`恢复当前详细上下文`。
- `v0.41.22`、`schema 44`、`Phase 2B/3/4 继续关闭`。
- `Cedar 玩家协议与后台连续行动收口`、`Unexpected end of input`、`Cedar Agent 完整续接链`、`jsonRetryCount=58`、`CedarAgentActionPlanner`。
- `Cedar 后台换手闭环`、`根因已由同一时刻备份、诊断与源码三方证明`；`停止与备份互锁`、`transfer_lock_owner`；`Cedar 运行时抢占、开关与夜间节律`。
- 历史状态兼容：`IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING`、`CI PENDING / TRUE DEVICE PENDING`。

## v0.42.11+255 · TTS 运行链定点回退与气焰备份刷新（候选；真机未验收）

- 用户提供的 +254 脱敏诊断出现大量 `tts child_connection_timeout / bind_timeout`，一次已记录的 TTS 子进程异常；用户提供的备份内 TTS 与自动朗读均开启，最近错误为 `tts_generate_failed / call(...) must not be null`。这些证据不能单独确定子进程死亡的源代码位置，因此本批按用户要求将音频运行、双档测试与会话计时链退回到 +248 自动核亲和基线。保留后续已修复的 Android 媒体音量控制、Jev/聊天逻辑与气焰降温，不回退全应用数据结构。保留子进程连接超时后的清理和主进程轻量 `localStatus`；拒绝 Binder 空音频路径时提供明确错误。
- 语音页进入只读随包资源状态，不排队启动语音子进程。导入/校验/初始化操作直接展示实际操作返回结果，不再额外排一个 3 秒的状态请求。语音页只留一个真正生成并播放的「试听发声」，移除未验证的双档无声对照按钮与相关实验链。中文 RoBERTa 选择和导入期间显示阶段信息；若子进程本身仍无法启动，真机日志会直接反映超时。
- 真机前自检进入先读取轻量本机概况并显示，原完整诊断继续完成后替换概况；概况禁止导出为完整报告。快速状态不初始化 Genie/ONNX。完整与深度诊断入口保持不变。
- 用户 09:58 备份有 `playful_form_state_v1`，记录气焰 68；数据库恢复不排除该键。聊天页此前仅初始化或收到新轮消息时读取，因此导入后旧界面仍显示原数值。现在切回聊天、应用恢复时重读，并在聊天保持挂载期间每 2 秒核对一次；气焰数值依然是存档里的真实值。玻璃管、顶端爱心和填充随数值从原粉色 `−110°` 色相渐变至原粉色。
- 静态验证：`git diff --check`、Workflow YAML 与总账门通过；历史 125 个源门中 122 个通过。另三个分别需要 CI 恢复 417 个桌宠资源文件、LingChat 特效文件以及本机缺少的 `kotlinc`，不是本次业务断言失败。
- 风险与验收：本地不能运行 Flutter/Gradle 或复现目标手机独立进程崩溃；需要 GitHub Actions 编译、Flutter/Kotlin 测试，并在原手机验证：旧存档导入显示 68；关闭/打开页面均不长时间卡住；导入 RoBERTa 后「试听发声」实际听见、自动朗读也能出声。不能把源代码回退视为已经证明问题解决。
- CI 首轮 run `35986329658` 在 `Verify clean source baseline` 拦下旧版号 literal：Workflow 把构建标签改为 +255，却遗漏 `grep -Fqx 'version: 0.42.10+254'`。修正为 +255 后重新推送；首轮没有进入 Flutter/Kotlin 编译，不能算实编译失败。
- CI 第二轮 run `35986562701` 已通过全部源门、Kotlin 测试、Flutter analyze，Flutter 927 项中 926 项通过；唯一失败是 `agent_self_reader_v0416_test.dart` 固定预期 `build=v0.42.10+254`，实际 +255 正确。已同步测试预期并重新推送；第二轮未进入 Release APK 打包。
- CI 第三轮 run `35987574373` 成功：125 个源码门、Kotlin 测试、Flutter analyze、Flutter 全量测试、Release APK 编译、固定签名与 APK 模型/桌宠/塔罗资源校验均通过。功能源码 head `4c2101f529fbaf4f6fe7b2289aaea48153e65b34`，tree `fe8a3f0e081a66b77681eaf527340e6f664a117b`；Artifact `10803376064`；私有草稿 Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-943842dd3eb416b00021`；APK SHA-256 `170be5edc6a2ee55a2431fc289a14b6acc4551ef74bacec19ee7e1f4e4692487`。`TRUE DEVICE PENDING`：本次完成构建不能证明用户手机独立 TTS 进程已恢复播放。


## v0.42.12+256 · 双向 Jev 气焰、端点切换与双形态音调（候选；2026-09-24）

- 决策：仅气焰到 100 时本体进入小豆丁、到 0 时小豆丁恢复本体。认真求助不触发单独的人设切换，也不在角色提示中额外要求突然变得严肃；本人的内容依旧由原有伴侣设定和对话上下文负责。用户此前确认 +255 的 TTS 播放、气焰均可用，保留该音频核心和唯一「试听发声」。
- 输入端：原有 Jev/OpenRouter 组合短判断继续按当轮用户真实表达选 serious/ordinary/light/mutual/strong；serious/ordinary 均无加分；light +6、mutual +30、strong +42。本体每轮自然 −2，实际净变化依次为 −2/−2/+4/+28/+40；小豆丁每轮自然 −15，实际净变化为 −15/−15/−9/+15/+27。时间空档沿用每小时 −3（最多 12 小时）。普通害羞、友善、口头关怀不自动算玩闹；温和笑话也不会让小豆丁持续涨温。一次明确互相挑衅从 0 需约 4 轮入形；100 起普通交流约 7 轮回到 0。端点夹取 0～100；锁定形态的手动选择仍按原入口执行。
- 自主端：同次预回复 Jev 组合判断新增独立 initiative=open/closed；仅在 open 的回合，用由 turn ID 决定的固定 30% 抽样给主模型一条可忽略的主动轻玩笑提示。抽样自身加分为 0，重试不换抽样结果。回复生成并定稿后，另一笔 Jev Choice 根据用户文本、少量近期上下文和**实际可见回复**判定 none/playful/strong/settle，分别额外 0/+16/+24/−8；复制、温柔、脸红、认真解释不算主动挑衅。仅在回复赢得数据库提交后结算，保存 assistant ID 使重复回放不二次加分。初期不使用随机数直接加热，也不让模型自行报出数值。
- 所有短判断的 Jev 缺 Key/未启用、答案缺失/不确定、网络失败、402、超时与格式异常，均由现有 DeepSeek Flash 不思考模式判断同一组问题或同一最终回复；取消直接停止兜底。两方都失败时用户输入不给正增量，自主端不追加分，回复本身照常提交。Jev 输出为离散选项，不把模型生成的任意数值直接写入存档。诊断沿用只记 lane、耗时、用量与失败类别、不存正文或选项的有界记录。OpenRouter 截图单次约 $0.000070～$0.000081，用户明确优先反馈及时、成本可忽略；新回复后判断会多一次网络等待，需要真机测端到端延时和回退比例，再决定是否合并请求。
- 状态并发：气焰、形态、回合 ID 与手动交互统一在 SQLite 设置键里事务读改写，避免等待 Jev 时覆盖用户按键或相邻回合；原备份键 `playful_form_state_v1` 不变。音调沿用 +256 的每次播放前形态读取：小豆丁用设置选中的原值，本体降 1 半音（设置 0 则 0/−1）；仅使用既有音调调整链，不动子进程、绑定、ONNX、语音队列和无声测速。
- 验证关注：单元测试覆盖正常趋稳、入形仅在 100、Q 形七轮自然归零、真正挑衅快速升温、认真求助仍是当前形态、回复定稿一次性加分、决定性抽样、Jev 成功及余额不足后的 DeepSeek 兜底；历史源码门因硬编码版号 +255 拦截须兼容 +256 后再跑 Flutter analyze/tests、Kotlin、签名与 arm64 APK。构建状态 `CI PASSED / APK READY / TRUE DEVICE PENDING`。功能提交 `f107a48578d761ac4722256a23bfee1adb343c2b`，tree `6d034edc1f7e73472c43bf5dd7bfee8ab3e2c312`；Actions run `36002099038`：125 项源码门、Kotlin 测试、Flutter analyze/tests、Release APK、签名及包内 Genie/桌宠/塔罗资源检查全绿；Artifact `10809520556`；未公开的 Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c851c83a1c515da6746d`，APK SHA-256 `739c86422711e1eedabf15594543abaf300b3c39d77c9a3822ee3a8c9120a289`。真机重点验证两种形态连续聊天、主动玩闹、未填 Jev Key/余额不足、音调和发声；CI 结果不能代表真机已验收。


## v0.42.13+257 · 双房间气焰与可回看的工具调用（2026-09-25，候选）

- 用户提供的 +256 私密备份只有最新状态快照：2026-09-25 01:44（北京时间）气焰 49、小豆丁形态、未锁定，lastTurn/lastAssistantTurn 均已保存；诊断中 Jev chat_playful_self used 5、low_confidence_self 3；chat_intimacy_route used 13、low_confidence_interaction 10、历史合并旧 low_confidence_or_invalid 5。现有诊断没有逐轮分类结果／值变动，备份也没有逐轮气焰流水，**不可由此断言是哪句话让气焰上升或下降**。不向公开仓库提交私密备份或诊断原文。
- 停止问题证实：普通聊天 PromptBuilder 在回复生成前写入用户本轮的气焰变动，用户按 Stop 会删除尚未提交的用户消息、留下仅供 UI 重编辑的中断展示；先前没有归还气焰。沉浸房间同样会撤回未完成用户消息。修复：状态记录本轮结算前热量/形态及上一回合；只有最新未提交回合且未被后续回合/手动形态操作取代时才允许还原；撤回普通或沉浸用户消息和还原气焰放在**同一 SQLite 事务**。已提交回复不能被较晚的 Stop 回滚；备份继续使用既有 `playful_form_state_v1` 键，兼容旧存档。
- 两房间仍保持各自聊天正文、小说现场和事实边界；共享同一个 PlayfulFormStore。沉浸回合单独用一次 Jev Choice 批量选 interaction/initiative，Jev Key 未配、402、网络/格式/低置信度转 DeepSeek Flash 不思考判断；复用普通回合 −2/−15 自然降温、加分枚举、0/100 切换。沉浸 Prompt 加载相同形态提示和轻量自主开玩笑机会，小说视角规则不变；实际可见回复经 Jev→DeepSeek 判断其自身玩闹，最终回复成功提交后才加自主分。沉浸 UI 读取相同气焰、共享玻璃管与手动互动，并以相同 qForm 选静态立绘；TTS 每次播放继续从同一状态读形态，不复制音调设置。草稿重试不重复结算用户回合；用户确认截断回复时按 none 完结临时回合。
- 工具历史：工具的 user-facing displayText 之前只通过运行时 callback 显示，`agent_tool_outcomes` 只保存调用次数／状态／时间，因此对话结束或悬浮窗刷新后丢失可读细节。现在用 200 条有界独立设置记录实际已展示的 displayText（每项至多 800 字），仍保留原有脱敏 Outcome 表；普通聊天从真结果读取并显示灰色高透明工具面板，悬浮窗也随消息加载并可展开查看。只写用户可见短文，不记录 promptData、工具参数、模型思考、密钥或诊断正文。沉浸房间没有 Agent 工具执行链，继续保留其工具权限边界；不能伪造不存在的工具调用，后续若单独授权为房间接入工具，必须先按总账唯一 continuation owner 设计调用/停止/存档。
- TTS 双档性能对照后续单独做，不在本批动已经恢复的发声链。先保持 +255 的自动核亲和运行、单个「试听发声」、轻量状态与原子诊断；未来对照在同一用户真实回复／音色／语言／分段上明确手动启动，串行无声生成两个档位，分别冷启动并记录核、PSS/RTF、每片段计时、子进程绑定/死亡和缺段；只在同批、两档都有效时比较，不在模型未就绪或播放失败时给出胜出档。另存最近两轮**真实播放**（不同形态）速度，用户可直接区分听感与纯推理测速。前次双档测速改动后真机出现子进程连接超时、资源未就绪、原生空指针；+255 回退到此前音频运行链后用户确认可发声。诊断只能证明故障与新增测试链共时，**没有证明**是哪行代码引发原生异常；下次须沿独立最小探针和真机栈定位，不靠恢复已撤的双档按钮猜测。保护固定签名、资源校验、媒体音量流和存档键。
- 预期验证：停止前后气焰、已提交后 Stop 不回滚、手动形态动作不被旧回合覆盖；跨普通／沉浸连续涨跌和 UI 立绘一致；无 Jev Key／402 的 DeepSeek 兜底；工具活动实文在普通和悬浮窗完结、重开后仍能展开；TTS 现有真人发声不回归。当前 `CI PASSED / APK READY / TRUE DEVICE PENDING`：Actions run `36041874888` 完整通过 125 项源码门、Kotlin 测试、Flutter analyze 与全量 tests、Release APK、固定签名、Genie/桌宠/塔罗资源核对；功能 head `84ec9af1dd4df93bb4b36b46d03d2fe794aadfe3`，tree `0226ce2225d28c9aead68855b4bcda69e31d46cc`；Artifact `10827521660`；未公开 Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-d0809bb1e451a9b07625`；APK SHA-256 `be0d5f7a40f8ae5c5dd610e4a80d62fec9c1d4bdf25e5130b5908eda7b8b47bf`。真机仍需逐项核对：停止前后热量、跨房间立绘与数值、Jev 失败后的 DeepSeek、工具实文完结与重开、现有 TTS 真人发声；CI 不视为真机验收。

## v0.42.14+258 · 可回看的规划过程与本地命运之轮（2026-09-25，开工登记）

- 证据：+257 已持久化工具的 user-facing displayText，但截图中的 `THINKING` 是 DeepSeek `reasoning_content` 的实时流，工具运行状态是另一条链。`generateInternal` 会向界面转发规划推理，最终消息却只保存最后一次 `generated.reasoning`；跨规划回合的真实可见推理在提交后丢失。普通聊天已有 ReasoningPanel，悬浮窗有独立渲染。双模型模式会抑制内部规划推理的实时转发。用户明确要求两边可看到并在完成后回看实际呈现的内容，不以“工具活动”短文代替。
- 上游冻结：`https://github.com/29-Cu/Ruota-della-Fortuna`，commit `8d62036de5c3e0cdb18ac082c77a7051b55ce43a`，MIT；独立页面 `index.html` 内嵌 DIMS 与 `src/tags.json` 内容一致，7 维共 502 标签（其中 GORE 62，初始锁定）；独立 `Math.random()` 等概率选中每个启用维度并支持单列重抽。CSS/SVG/Web Audio 实现暗金机器、灯框、卷轴、拉杆与结果卡。用户要求保留这些视觉与动效，以本地 Flutter 重建而非 WebView/服务端/MCP。
- 产品合同：抽取是完全虚拟的幻想装置。用户在轮盘界面确认最终结果后才绑定新沉浸房间；结构化结果与上游版本持久化，给模型的房间提示只列选中标签与虚构规则，允许超现实混搭、分幕展现，不要求现实物理一致，也不把未输入的用户动作、台词、同意或态度写成事实。房间之外的记忆、AI Self 与自主 Agent 不因结果改变；后续房内重抽沿同一 Outcome 扩展，首版不另建循环。
- 保护边界：不增加模型调用或改变 DeepSeek 内部/Gemini 最终回复计费链；存储给用户实际可见的推理，但不得泄露私密 Prompt/密钥或将过程注入模型历史/公开诊断；失败与 Stop 不伪造成完成结果；不改 TTS、Cedar 游戏规则、形态温度、Live2D、`main`、正式 Release 或用户旧房间。保留上游 MIT 声明并审核字体许可。
- 验证门：单/双模型的规划流、工具 Outcome、最终回复三段显示与重开后回看；Stop、崩溃恢复、重复轮次不乱序；轮盘多维启停、均匀取样与单列重抽、默认 GORE 锁、确认前无房间注入、确认后房间隔离、进退场、备份恢复；Flutter analyze/tests、仓库 validator、Android release、固定签名与 APK 真机外观/动画验收。当前仅开工，`CI PENDING / APK PENDING / TRUE DEVICE PENDING`。
- 实现（本地，未完成 CI）：`VisibleReasoningTranscript` 按完成的规划回合和最终回复收集真实 provider reasoning，内部 DeepSeek 规划在单/双模型中均实时展示并 checkpoint，提交后沿现有 `reasoning_content` 在普通聊天与悬浮窗回看。历史提示构造不重放 reasoning；工具 Outcome 仍使用独立的 +257 附件。Gemini 最终仅显示被接受的 reasoning。
- 轮盘（本地，未完成 CI）：复制上游 `src/tags.json` 502 条、LICENSE/NOTICE；纯 Flutter 灯箱、暗金机身、七轮停靠、拉杆、单轮重抽和 GORE 解锁确认；只有确认抽签再填写房间表单后才创建房间。JSON 中保存源 revision 和选中维度/标签于房间 `entry_context`，房间顶部可回看；系统背景将其解释成幻想装置的创作素材，允许超现实搭配，不伪造用户行动或同意。不新增模型调用、独立循环或 schema。原创字体和网页音频未移植，待真机对照视觉精度。
- 本地验证：`git diff --check`、JSON 内容计数（7 维 / 502 标签 / 单一 GORE 锁）通过；125 项校验清单结构通过，前 24 项通过后因稀疏检出缺少仓库原有 `dafeiyu_reference.webp` 而停止，不是功能失败。Flutter SDK 不在本地，需完整检出的 CI 执行 analyze、test、release APK。`CI PENDING / APK PENDING / TRUE DEVICE PENDING`。
- 远端验证（2026-09-25）：功能 tree `6efaa1d699cc73f92b9108f1e220e990db2f17e8`，GitHub head `001c3cf43883032b47ce0224259777c15ce45c27`；Actions `36094383066` 全绿，125 项源码校验、Kotlin 测试、Flutter analyze/test、release APK、固定签名/资源核验全部通过。Artifact `10846946684`（14 天），APK SHA-256 `3fab6379553866a1bc3a4b61a5fde1b0a6dbcd1cfe450d8eb149e0e63d720efa`；signer `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。未发布 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-478e1a10f9514d22b372`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；真实设备尚未校验轮盘像素/手感、普通聊天与悬浮窗跨回合过程显示以及房间续写。

## v0.42.15+259 · 原版命运之轮视觉回归（2026-09-25，开工登记）

- 用户截图证据：网页为完整黑金主题、Rye 装饰字发光招牌、七轮三行窗口同屏、四边动态跑马灯、独立 GORE 翻盖、圆形 SPIN/竖向拉杆、自定义标签和搜索。+258 的 Flutter 仿制版用了紫色横向滚动单行标签轮、扁平滤镜片和小拉杆，关键比例与动效均不一致。先前回答“能够按原样画出”未兑现，用户质疑后明确选择直接复用原页面外观代码。
- 本轮目标：本地离线嵌入原版冻结提交 `8d62036de5c3e0cdb18ac082c77a7051b55ce43a` 的 HTML/CSS/JS；只加入可见的“确认结果并创建沉浸房间”入口和安全数据桥。保留原有灯框、卷轴、停靠动效、拉杆、GORE 翻盖、Add Tag、Search、History，并让页面字体可离线使用。轮盘仍不运行 Agent/模型或外部服务器，房间只读取用户确认的有限字段；从 +258 沿用结构化房间设定，不动聊天 THINKING、TTS、Cedar 或 schema 61。
- 验证路径：原网页代码与打包页面的差异限于离线字体、App 结果桥与作者署名链接；检验桥消息格式、维度/标签匹配、确认前不创建房间、WebView 外部导航隔离及持久化。Flutter analyze/tests、125 项验证、APK 签名和上机视觉/动效仍各自区分；远端结果见下。
- 用户同轮补充：沉浸房间页面底部必须和普通聊天一样展示“她／聊天／更多”三个导航按钮，并让这些按钮能真正回主界面相应标签；输入框左侧增加“推进”按钮，单击只令现有剧情自然推进一个节拍，不生成固定台词、不记录为用户扮演的动作或许可。实现需使用已有沉浸房间请求、Stop 与独立现场账，不开第二续写循环；按钮引发的控制事件需在时间线与模型提示中与用户原话区分，不能更新用户身体互动的气焰值。
- 本地实现：打包 `index.html` 原始机台和 3 款 OFL 字体，WebView 只加载本地页面并将确认后的选中标签通过受限桥传回 Flutter；允许原作者署名链接由 Android 浏览器打开。普通聊天与房间大厅、房间内共用相同底部 NavigationBar，离开活动房间按原有流程暂停。推进作为保存在时间线的房间控制事件送入现有生成链，跳过用户肢体捕获、用户轮人格判断和用户自主行为推断，停止的控制事件不显示为用户消息；下一轮模型历史明确标注该操作不代表用户发言或同意。
- 远端验证（2026-09-25）：功能 tree `18b856e14a573a844bc6a3f1afef1b655997b1f1`；GitHub 功能 head `d580ed694ef9ae75017e1c231d95eb59033d0fd1`；Actions `36105651518` 全绿：源码校验、Kotlin 测试、Flutter analyze/test、release APK、签名、既有资源核验均通过。Artifact `10851237002`（14 天）；APK SHA-256 `a2316fa38b323ec725323186d32df019e0cda914a0649c130cc835f9a4ce4fac`，签名指纹 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。未发布 Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c2d726ee49c01198c248`。状态 `CI PASSED / APK READY / TRUE DEVICE PENDING`；手机端仍需确认原版轮盘的像素与动画、WebView 本地标签存储、导航跳转、推进生成质量。

## v0.42.16+260 · 房间导航、思考分段翻译和轮盘振动（2026-09-25，开工登记）

- 用户决定：沉浸房间底部中间显示“房间”且选中后不用重新导航，左右两端仍能去主界面；去掉人工添加的“【规划 N】”标题，仅展示 DeepSeek 实际返回的过程文本；翻译应分别判定规划和“【最终回复】”的英文比例，仅翻译英文占优的段落。确认在线轮盘已在每轮停靠调用 `navigator.vibrate(18)`，Android manifest 缺失 `VIBRATE` 权限。
- 现有账本与代码证据：+258 之前就有“DeepSeek 工具规划，无工具后再由第二通道回复”，+258 只是把已有规划过程显示出来；只要 Cedar 已配置，旧 `cedarStageToolIds()` 对任何普通聊天均返回 `gatewayToolIds`，为零游玩需求的闲聊附加游戏厅工具，导致备份末轮零工具仍先调用 DeepSeek。修复此确定性门：仅本轮游玩意图、共玩待接续，或本轮确有 Cedar Outcome 时暴露游戏厅工具；其余按现有相关工具路由，不加额外 Jev 网络请求。
- 实施与验证：在新功能分支补齐 Android 振动权限、导航选中行为及文案；只清除新消息上人工规划编号并兼容旧存档文本；规划英文占多时翻译完整思考链，否则最终回复英文占多时只翻译最终回复，保留原文与整个记录的缓存身份。保留原网页动画与逐轮 `buzz(18)`，不凭模拟器/CI 声称已证明真机手感或帧数；完整 CI 构建可供实机核对。schema 61 与备份协议不变；不合并 `main`、不发布正式 Release。
- Jev 专节（2026-09-25 的源码与官方文档核对）：现有 `JevDecisionGateway` 在 OpenRouter Decisions API 发送最小 `state` 和多个独立 Choice，验证答案/信心后使用，否则调用原 DeepSeek Flash；`PlayfulTurnJudge`、`ImmersiveNsfwRouter` 已实装，不复用聊天完成接口。官方 Jev 是结构化决策而非生成文本，Choice／Score／Noul 可在同一请求中并列短问题；官方强调各问题聚焦一个判定，复杂权衡拆问、由代码组合。适合对话意图分类、闭集工具候选/场景路由、主动消息是否适时、情绪或房间事件评分（需验证本项目真值）；不适合继续剧情、生成答复、核验 Cedar 合法动作/真实 Outcome 或单纯读设置/计数。置信度是分布集中程度，不代表具体场景正确率；每项新增任务须有独立标注样本阈值、误判代价、脱敏用量、费用和延迟对照，且 **DeepSeek 为任何 Jev 失败/不确定的必经兜底**。本轮游戏厅误开启是明确布尔条件，直接在代码中修复；若后续希望让 Jev 负责模糊的“是否值得进入 DeepSeek 工具规划”，先在影子对照验证对自然游玩、联网和记忆请求的漏判，再在启用时落地 DeepSeek 兜底，不能用一个低信心的“闲聊”吞掉真实工具意图。官方出处：https://docs.typesafe.ai/introduction 、https://docs.typesafe.ai/api 、https://openrouter.ai/typesafe/jev-1.13/ ；本项目现有路线详情参看上文 §6.25。
- 本地实现：中间导航“房间”和门图标，选中中间项不离开房间；新消息与流式规划不再添加编号；翻译遵循用户两级判定并支持旧存档；仅游戏请求/待续共玩/实际 Cedar Outcome 暴露游戏厅工具，普通闲聊已配置 Cedar 时不触发 DeepSeek 规划；Android manifest 补齐 `VIBRATE` 供网页现有每轮停靠震动调用。新增独立翻译分支与 Cedar 空工具门回归测试。
- 本地验证：总账交接校验、Agent v2、图像可靠性、主观搜索回归和 `git diff --check` 已通过；第一次 Actions `36117923678` 在旧 +219 静态契约校验第 99/125 项失败：它硬编码要求 `cedarStageToolIds()` 直接引用旧的常驻 gateway/engaged 字样，与本轮修复冲突；更新检查为实际 `toolIdsForUserTurn` 行为和回归测试后重跑。Flutter analyze/test 与 Android APK 交由完整远端 CI；原网页视觉、动画帧率、振动强度仍需真机。
- 远端验证（2026-09-25）：功能 tree `3ad68dd178bd6d474bb534038ecf829bd2ef426b`，远端构建 head `156743912284dd896434857ce46f32e8cc6364f5`；Actions `36118441665` 全绿：125 项源码校验、Kotlin 测试、Flutter analyze/test、release APK、签名和资源核验均通过。Artifact `10856307246`（14 天）；APK SHA-256 `607a2d1c84546b0f2364e47f8db1e049f77c1ed8908778fdbc9f01ac5088fb8f`；签名指纹 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。未发布 Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c92a839f0ea079a1b17c`。状态 `CI PASSED / APK READY / TRUE DEVICE PENDING`；手机仍需检查逐轮震动、动画流畅度、翻译分段和真实零工具回合的用量变化。

## v0.42.17+261 · 满气焰触发与命运之轮细节（2026-09-25）

- 双形态：本体自然达到 100 时只蓄势，下一次真实用户消息是一次触发判断机会。Jev 阅读最近 3～5 轮和本轮消息，按最新互动是否让她明显绷不住选“触发／等待”；Jev 不可用、不确定或失败时 DeepSeek Flash 同题兜底，两者均失败不消耗机会。触发时先更新共享状态和角色提示，再生成回复；若否，这轮保持满值，其后正常衰减。严肃求助不能作为触发。弹额头仍直接变身，安抚、锁定与手动按钮不变；小豆丁只有 0 自动还原。普通聊天与沉浸共用状态，Stop 回滚蓄势与形态。
- 视觉：真实切换到小豆丁时立绘跳两下，不加烟雾。命运之轮 WebView 关闭 Android 边缘拉伸和可见滚动条，仍可正常上下滚动；网页默认声音开启，在首次手势音效时创建 Web Audio；跨卷轴重复 tick 限速，跑马灯仅更新实际变动的灯泡，保留原机台外观与逐轮振动。帧率改善需同机对照网页和 APK 验证。
- 验证：状态和 Jev/DeepSeek 兜底专项测试、JS 语法、总账门、Flutter Analyze/Test 与 Android Release 已由 Actions `36138316955` 全绿确认；真机观察普通／沉浸跨房间、Stop、锁定、双跳、声音、拖动边缘及帧数。状态 `CI PASSED / APK READY / TRUE DEVICE PENDING`。
- 构建交付：GitHub 构建提交 `3a9fd3091970ba132e9261575f212f709ee32613`，内容树 `66eb5939a2cc3bd013b508ebc24998587dd71bf6` 与本地提交 `d85d2f5` 完全一致；Artifact `10866132151`（14 天），Draft Release `396618220`，APK asset `588394207`，大小 `546205928` bytes，SHA-256 `2d5ccfc8d3508c093b11c60759cf12c9e46e07e128b1ccbf7ef23c997e21c4a7`。草稿页 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-d10092c51d058bdfdfb3`；未发布正式 Release。

## v0.42.18+262 · 主动聊天最终通道、满气焰持续判断、轮盘虚拟卷轴（2026-09-26）

- 用户澄清：自然升到 100 的当轮不判断；至少短暂保持一轮 100。此后只要本体仍在 100，每条真实用户消息都可让 Jev 判断突破，Jev 不确定或失败时 DeepSeek 兜底；判断“等待”不直接扣到 85。持续互相玩闹把数值维持 100，就应继续判断；一旦普通交流实际降到 100 以下才停止。旧存档若在 100、非小豆丁且 `breakthroughReady=false`，下轮也要恢复判断。突破语义提示暂不放宽，先真机观察。
- 2026-09-26 01:39 用户备份与脱敏诊断证据：最后状态 `heat=100/qForm=false/breakthroughReady=false`；此前约 01:31“晚安”一轮有唯一一次 Jev `playful_breakthrough` 用量，此后数轮打趣没有再次调用，因旧代码把第一次等待当成永久用尽机会。当前数据库状态不外传、私密正文不进公开诊断。
- 主动聊天：仅此回复路径在双模型设置下将现有内在状态、已选来源、真实 Outcome、时间和语境合并后一次交 Gemini 写可见正文；DeepSeek/Jev 仍负责已有内部短判断、维护与工具。Gemini 缺 Key、网络/格式错误或中途截断时用 DeepSeek Flash 自然生成；事实校验需重答时只由 DeepSeek 纠正，不第二次向按次计费的通道请求。保存最终实际生成模型和其真实 reasoning，英语摘要不再丢弃，沿普通聊天的思考链翻译入口按需翻译；没有独立 DeepSeek 规划回合时不伪造规划思考链。单 DeepSeek 设置保持原流。
- 轮盘：真机反馈 APK 明显掉帧、手机浏览器原版较顺畅；本地代码的每卷轴按标签集复制至少八份，七卷轴合计产生很长的运动 DOM/合成层，同时 SVG 灯带逐帧动画滤镜、机台灯频繁切换发光阴影。改为每卷轴固定五个可见/预备 cell，按跨行更新文字，仅对短 strip 做 transform；停止中心仍与抽签结果对应，保留文字/灯箱、拉杆、单列重抽、默认音效和每列停靠振动。移除卷轴运动 blur 与灯带逐帧滤镜脉动，把跑马灯运动更新从 55ms 降为 95ms。此为源码判断，不声称已证明特定 Android WebView 的 GPU 瓶颈或真机帧率收益。
- 验证：`git diff --check` 和打包 JS 语法通过；Node 卷轴运动探针按 1、2、7、50、90 个标签核对五格 DOM 数量和停止中心选中值。仓库 125 项验证在稀疏检出下第 27 项因未检出 417 件桌宠旧素材停止，前 26 项通过；本机无 Flutter SDK，Flutter analyze/test 和 release APK 待完整 CI。schema 61、备份协议、普通/悬浮/沉浸正文、Cedar 游戏房间、TTS、Live2D 不变。状态 `IMPLEMENTED LOCALLY / CI PENDING / APK PENDING / TRUE DEVICE PENDING`。
- 首次完整 Actions `36171693729` 在第 86/125 项遇到旧 +209 静态断言（主动引擎不得读取第二通道 Key），它与本轮明确的新路由相矛盾；前 85 项通过。把该断言改为检查 DeepSeek 内部 Key、双模型开关、Gemini 只尝试一次以及 DeepSeek 兜底，本地单项通过，待完整重跑；不是实际 Flutter 编译错误。
- 最终远端 head `3aa281d25bbc50ba174c2b145d5e08b6423127a2`；Actions `36173105843` 源码回归、Kotlin、Flutter analyze/test、release APK、签名和资源核验全部通过，Draft Release 上传成功。Artifact `10880534317`，APK SHA-256 `7d869d4d678cd82d9dddeb3f1624658c9633a48fbe5e91aeab4f532a384cc083`；Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-454347b060d2df3185c9`。上一轮 Actions `36172168049` 因修正发布名称的新提交而取消，不能当成测试失败。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；待真机观察满气焰连续判断与自然变身、主动正文模型及思考翻译、命运之轮帧率和停靠/振动。
