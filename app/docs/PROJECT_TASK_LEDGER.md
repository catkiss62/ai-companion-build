# AI Companion · Project Task Ledger

> 长期任务总账。每个正式版本更新 `docs/HANDOFF.md` 时必须同步核对本文件；完成、冻结、退役和延期都要显式记录。最新完整接班入口：仓库根目录 `AI_Companion_接班总账_v36_2026-08-17.md`。
>
> 用户明确要求：任务总账是跨窗口对接的最高优先级文件。每次新增任务、改变排期、修改实现或得到新的真机证据，都必须详细更新；不能只靠 PR 描述或聊天上下文。欲望系统与双通道感官设计是“真人感核心备份”，后续自主联网、屏幕感知、媒体理解与桌宠自主行为必须围绕现有 Desire / Thought / Intent / Gate 与 Somatic 双通道接线。

状态：`ACTIVE` 当前主线 · `NEXT` 紧随其后 · `LATER` 后续重要 · `FROZEN` 暂停保留 · `RETIRED` 已移除 · `GUARDRAIL` 不可回归。

## 2026-08-19 最新排期覆盖

### ACTIVE / SOURCE IMPLEMENTED · v0.35.3 NSFW 语境路由与六规则正文换代

- [x] 六份用户规则共 31 个小节逐字进入运行时默认正文；新增每小节 SHA-256 校验，禁止自动润色或改写。稳定 ID、标题、load policy 与数据库围栏继续由代码控制。
- [x] 聊天顶栏新增白/紫长方形 `NSFW` 按钮；自动路由在实际生成前用无思考 DeepSeek 判断 `daily / nsfw / nsfw_reference`，按钮反映实际装载，手动开/关优先覆盖下一轮后恢复自动。
- [x] 移除固定短语 bootstrap 与成人 Session 许可门槛。Session 只负责共同场景连续性；双感官内部体验与外部共同在场事实继续分层。
- [x] 痴女作为 NSFW-biased 特殊风格进入路由判断；无关普通话题不自动色情化，成人暗示与邀请更容易加载完整成人规则。
- [x] 六规则主导入/导出改用系统 JSON 文件选择器，剪贴板作为次级入口；沿用 HyperOS direct-picker overlay guard。
- [x] 删除聊天 Temperature UI、数据库读写、DeepSeek 请求参数、恢复/主动消息接线；思考开关保留。数字化性格系统明确延期到后续独立设计/版本。
- [x] 版本提升至 `v0.35.3+78`，schema 保持 26；新增 `tools/validate_v0353_nsfw_context_router.py` 与 `docs/NSFW_CONTEXT_ROUTER_v1.md`。
- [ ] GitHub Actions、APK、checksum、草稿 Release 与真机 NSFW 路由/文件往返验证尚待本轮完成。

### BUILT BASELINE · v0.35.2 六大规则设定工作台

- [x] 所有设定类 Prompt 收口为用户指定的六框：01 身份核心、02 日常说话规则、03 性格底色、04 记忆规则、05 NSFW 状态机、06 NSFW 渲染；性格试穿和原保护锁定正文在框内完整可见可改。
- [x] `locked` 改为保护常驻：不能关闭，但可以编辑、导入和恢复默认；启动 seeding 不覆盖用户手工正文。权限、停止、隐私、Active Brain、transfer、run token、成人 Session Gate 与数据库事实校验继续由代码保护。
- [x] 六卡片点开式 UI、全屏单一长文本编辑器、中文系统复制/剪切/粘贴/全选与 Android clamping 滚动已实现；用于修复 AlertDialog 嵌套长文本在选区向上拖到顶时反复回弹。
- [x] 新增只包含六大规则正文的 `ai_companion_prompt_pack` 剪贴板导入/导出；导入先解析和确认变化，不携带聊天、实际记忆、Desire、Key、权限或设备信息。
- [x] 每组可“和她讨论”，模型只给修改理由和完整待确认稿；不直接写数据库，必须由用户再次保存。
- [x] 04 记忆规则接入真实经验整合器和 AI Self 反思；主动表达规则并入 02 的主动轮次小节，避免出现可见文本与隐藏同义 Prompt 两套真源。
- [x] 新增模型思考开关与聊天 Temperature `0.0～2.0`，默认思考开启、Temperature `1.0`。DeepSeek 官方思考模式忽略 Temperature，因此只在关闭思考时发送；普通聊天、图片回复、断点恢复和主动开口共用，网页/记忆/设定提案保持独立稳定参数。
- [x] 版本提升到 `v0.35.2+77`，schema 保持 26；新增 `tools/validate_v0352_prompt_workbench.py` 与 Temperature 请求体测试。
- [x] 实现 head `fdee4f49f96d52db02bfd07400735f36095c9930`；Actions run `32173096666` 已通过完整历史/新静态回归、Kotlin 桌宠测试、Flutter analyze、167 条 Flutter tests、release APK、原生库/417 文件载荷、checksum 与私有草稿 Release 上传。
- [x] APK `AI-Companion-v0.35.2-77-Prompt-Workbench-APK.apk`（240.3MB），SHA-256 `2e7602c4cfba34e7f3dc1e64d2eef33b03f93566d1da07d71883b34d700248e2`；草稿 Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-382bc37a74c8121eec70`。Draft PR #23 保持未合并，正式 Release 未发布。
- [ ] 真机验收六框、中文菜单、选区顶端滚动、设定包往返、AI 提案确认，以及关闭思考后不同 Temperature 的 A/B 差异。

### BUILT BASELINE · v0.35.1 性格内在反应与表达 v2

- [x] 根据 v0.35.0 真机样本确认普通性格不是“需要多培养才出现”：预设应该在 1～3 次回复内可辨；培养只负责个人化和稳定。当前 `playful × impish` 三轮仍弱、出现“换性格/正式营业”元表演和万能守候收尾，因此进入本轮修正。
- [x] 四底色与四姿态由一句标签扩展为两段因果：内在先注意/波动，外在再按性格过滤；明确允许思考与台词不一致，且每个组合有不同的泄露、压缩、放缓、反击和关系注意方式。
- [x] 普通试穿每轮按稳定 key 动态重编译，不再使用已启动时缓存的旧 Prompt；模型不再读到“当前试穿、双方知情、切换”等 UI 元信息。特殊风格继续只临时生效，并禁止在对话中说明风格层、期限或状态变化。
- [x] 可见思考固定为第一人称当下反应：默认“我/他”，不写“需要帮助用户/规划回复/维持人设”等任务记录。情绪感叹由事件触发，不把“完了”之类变成固定口癖。
- [x] 外观显著性降噪：默认自称“我”；“小鲸鱼”只作低频回应昵称，“大肥鱼”只作引用/反击；外观仅在当前话题确实相关时进入注意。
- [x] 复用现有持久化 Desire/Thought 生成结构化情绪余波，不保存原始 reasoning、不增加试穿记忆库、不升 schema；状态包继续覆盖原数据。脱敏诊断只新增 policy 与最强余波 drive/state/band。
- [x] 主动联系末层保持当前性格，在最有性格的自然落点结束；不自动追加随时守候、慢慢来或等待回复的保证。
- [x] 版本提升到 `v0.35.1+76`，schema 保持 26；契约文档为 `docs/PERSONALITY_INNER_VOICE_v2.md`，静态校验为 `tools/validate_v0351_personality_inner_voice.py`。
- [x] 最终实现 head `a564cb8a6dbcebd8071384d391b5e7527c9620a1`；Actions run `32160558352` 已通过完整历史/新静态回归、Kotlin 桌宠测试、Flutter analyze、164 条 Flutter tests、release APK、原生库/417 文件载荷、checksum 与私有草稿 Release 上传。
- [x] APK `AI-Companion-v0.35.1-76-Personality-Inner-Voice-APK.apk`（239.8MB），SHA-256 `830332e19f774e6d62989d41fa167a4662342991d8c2de63c41869e5573083f7`；草稿 Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-7bedb31de10cf8a5062f`。PR #23 仍为 Draft，未合并 main、未发布正式 Release。
- [ ] 真机 A/B：同一组“被夸/被晾/被抓到嘴硬/认真求助/随口告别”分别测试四底色与姿态，确认 1～3 轮可辨、思考有情绪但不固定口癖、台词不过度解释内心、主动消息无万能守候尾巴。

## 2026-08-18 最新排期覆盖

### FROZEN · HyperOS 文件选择器返回后悬浮卡住（移至项目末尾）

- [x] 用户确认暂时冻结，不再为该小问题继续消耗当前开发轮次；整个项目主体完成后才重新研究。
- [x] 修正证据表述：另一个同样为私人制作、功能更少、代码更简单、看起来没有做专门恢复优化的桌宠也会复现；这不代表所有桌宠都会出现，只证明该问题并非 AI Companion 独有。
- [x] v0.34.6+71 报告是在真实复现卡死后才导出，但仍显示 `coverSessionId=0`、enter/exit/recovery/detach 全 0、`attached/touchable/visible=true`、`inputSuspect=false`。因此不是“报告里没有发生卡死”，而是卡死完全没有进入现有诊断；当前结构健康检查不能证明真实输入或动画可用。
- [x] Android DocumentsUI 会出于反点击劫持主动隐藏第三方 overlay；HyperOS 在返回后可能没有可靠恢复部分未专门优化的 overlay 输入/动画状态。首次启动另一个桌宠后两个 overlay 曾共同成功一次，后续共同失败，支持系统冷/热窗口或输入通道复用问题，但现有证据不足以证明具体系统根因。
- [x] 保留 v0.34.4 attach settle、v0.34.5 App 自有 direct-picker guard、3 次上限和 700ms settle；不回滚、不增加第四次重试、不继续延长等待。
- [x] v0.34.9 最新报告捕获到健康路径：上传页期间主动 detach，所以桌宠暂时消失；退出后 attempt 1 重挂成功并 settled，attached/touchable/visible=true。该表现符合保护设计，用户明确不要求修改；`possibleRecoveryLoop=true` 只留作观察。
- [ ] 项目末尾重开时必须先增加真实输入挑战、动画帧心跳、window instance/generation 和系统页面 enter/exit 时间线；不能再以 attached/flags 作为成功证明，也不能继续盲调重建时序。

### COMPLETED / TRUE-DEVICE PASSED · v0.34.9 分层公开网页发现

- [x] 第一个真实 Provider 接入既有 heartbeat：只从已存在的 curiosity / reflection / social `DesireIntent` 派生 `discover_interest` 路由，不建立第二套欲望或主动触发器。
- [x] 使用中文 Wikimedia 官方 REST 搜索；查询只来自固定公开主题白名单，Thought、用户消息、关系资料、屏幕/通知内容和 Intent reason 均不离开设备。
- [x] schema 25 新增 `public_web_candidates` 不可信候选池；每次最多 3 条、TTL 14 天、总量 240，保存标题/短摘要/HTTPS URL/来源/指纹与生命周期，但不直接写 Memory、Thought、系统规则或聊天。
- [x] 滚动 24 小时最多 4 次已放行尝试，UTC 六小时窗口哈希去重，HTTP 12 秒超时；锁屏不拦安静联网，Active Brain、transfer、用户生成、device/generation、run token、预算与重复围栏均保留。
- [x] HTTP 返回后在结果提交事务内重新检查用户生成任务；候选、Outcome 和轻量 Desire satisfy 原子提交。失败、无结果、仅重复、stale writer 或并发用户生成均不满足欲望。
- [x] 同一 heartbeat 成功后重新加载 Desire，避免主动联系逻辑读取旧 snapshot；本阶段 Provider 永不直接发消息，未来分享仍经过独立 proactive Gate。
- [x] 脱敏诊断新增 `database.publicWebCandidates` 及公开网页检查，只含计数、lifecycle、粗粒度运行结果/错误和来源元数据；显式不含标题、摘要、URL、查询、interest key 或 Thought 正文。
- [x] 自动化已覆盖阈值/来源、固定主题隐私、六小时去重、预算/TTL/容量、HTML 清理、HTTPS 来源、三条上限和存储边界；本地 v0.34.7 回归及 v0.34.8 静态校验通过。
- [x] GitHub Actions run `32061800320` 全绿：完整历史回归、Kotlin 桌宠测试、Flutter analyze/tests、release APK、原生库/417 文件载荷、checksum 与草稿 Release 上传均通过。
- [x] APK `AI-Companion-v0.34.8-73-Public-Web-Discovery-APK.apk`，239,553,049 bytes，SHA-256 `10957e7417de9686122ed7d7784a41542157f2fca3e8aa7d5af7ab56d264fc4f`；草稿 Release `untagged-fb193eb0c14190803f0a`。
- [x] v0.34.9 增加 Tavily keyless 全网层、可选安全 Key、Wikimedia 回退、额外公开来源加法搜索、Agnes 2.5 Flash 公开片段整理和有界 `WEB_CANDIDATE_DATA` 短期上下文；额外来源永不替代全网搜索。
- [x] Actions run `32095469762` 全绿；APK `AI-Companion-v0.34.9-74-Layered-Web-Discovery-APK.apk`，SHA-256 `7fa1c47f4e87f50a461669098effa0e275bfa39fec336817edb9c1e94b9fe10f`。
- [x] 2026-08-18 真机报告确认 schema 25、4 次 public_web 全部 succeeded、12 条候选全部 reviewed、`provider=tavily+agnes`、Agnes enabled、used=4/remaining=0、最后 gate_duplicate、无错误。搜索、整理、持久化与短期读取主链通过。
- [ ] 下一功能进入“手动一次看当前屏幕”，先完成明确用户触发与敏感页保护，再开放 Desire 驱动的低频屏幕观察。

### GUARDRAIL · 内在驱动系统 + 欲望系统融合备份

- [x] 纠正命名：较早的通用 8 Drive/Thought/Intent/heartbeat 资料是“内在驱动系统”；2026-08-18 的 4 张图是 `claude-twin` 参考工程的具体“欲望系统”接线。
- [x] 两者保留概念分层，但运行时融合成唯一主干；不建立第二套人格、Desire、Thought、Intent、主动联系或 Tool Gate。
- [x] 当前实现映射、真机证据、平台适配差异和不可回归边界统一备份到 `docs/INNER_DRIVE_DESIRE_SYSTEM_BACKUP_v2.md`。
- [x] 结论：8 Drive、baseline、Thought 生命周期、Intent、fatigue/libido/duty gate、satisfy、refractory、Self Drive、主动反馈与自主工具接线完整；dream/gameification、任意网页深读与屏幕视觉属于未照搬或未来消费者，不算第二核心缺失。

### LATER · 和风天气 API（设计前先沟通）

- [ ] 仅登记为后续环境输入，不插入当前主线，不在本轮实现。
- [ ] 开始设计前先向用户索取并核对其参考代码，再决定和风天气 API 版本、定位来源/精度、权限、刷新与缓存、失败回退及脱敏诊断。
- [ ] 天气只能形成有来源、带时间和地点粒度的 Awareness/context；不得直接制造 Desire、长期记忆或固定主动消息。

### 2026-08-18 能力边界澄清与后续接线

- [x] v0.34.8 的 Wikimedia 单层已经由 v0.34.9 升级为 Tavily 全网 + 可选额外公开来源 + Wikimedia 回退；它仍不是任意正文深读、动态浏览器或图片理解器。
- [x] v0.34.9 已把每次最多 3 条候选作为独立 `WEB_CANDIDATE_DATA safety=untrusted_public` 有界注入当前生成上下文；读取只改变 reviewed/view count，不创建 Memory、Thought、消息或 proactive request。
- [ ] 继续补“候选复看/筛选 → 可选分享 Intent”后半段：允许她安静收藏或放弃；只有真的想分享时才走现有 proactive Gate、Grounding、2/2h 与 8/24h 上限。分享必须保留来源，不把网页写进用户 Memory，也不强制每次发现都说。
- [x] `screen_observation` 的 `6 / rolling hour` 是未来普通屏幕视觉的异常保护上限，不是“每显示 6 次识图一次”，也不是固定每 10 分钟执行。当前只有用户在聊天中主动发送图片的视觉理解；“手动看当前屏幕”和自主截图 Provider 均尚未实现。
- [x] 当前手机感知只提供 screen/locked、粗粒度 App/活动类别、忙碌度、使用与 Accessibility 事件计数等本地摘要。她能感觉用户持续操作或切换，但看不到 ChatGPT 中正在输入的文字，不能因为好奇自行截图。
- [x] 公共网页 `4 次 / 滚动 24 小时` 不是为了节省 LLM token：Wikimedia 查询本身不调用模型。数值用于限制后台网络、电量、循环与候选膨胀；当前每次最多 3 条，即最多 12 条/日。首轮长测保留 4 次，先看成功率、重复率和候选质量；有数据后再讨论调到 6 次/日。
- [x] X / Telegram 仍为后置 Provider。Telegram 可负责已知贴纸集、文件与以后经隔离授权的搜索/导入，但不能代替 App 自己的表情包系统；核心应是本地语义表情库（情绪/语境标签、来源/许可、安全、去重、WEBP/TGS/WEBM），Telegram 与 X 只是可选来源。

### PLANNED · MiniMax TTS 双引擎与 UI

- [ ] 新增 MiniMax API key 接入，默认模型锁定 `speech-2.8-turbo`；旧 Meju A2 继续作为本地离线引擎与可选失败回退，不删除、不重做其 native/MNN、断句、generation-ahead 或 FIFO 黄金基线。
- [ ] “异步 + 流式”实现为两条不同链：普通聊天使用 `POST /v1/t2a_v2`、`stream=true` 的 HTTP MP3 流式合成并接入现有 `TtsPlaybackQueue`；超长文本使用 `POST /v1/t2a_async_v2` 创建任务、`GET /v1/query/t2a_async_query_v2` 轮询、成功后按 `file_id` 检索并立即下载。不得把二者误写成一个同时异步又流式的请求。
- [ ] 异步任务必须 durable：SQLite 保存本地 job、MiniMax `task_id/file_id`、模型/音色/参数、状态、attempt/next poll、创建/更新时间、下载临时路径/最终路径/hash/size 与脱敏错误类别；受 Active Brain、device/generation 与 run token fencing，进程死亡/重启后可恢复且创建幂等，不能重复提交计费。
- [ ] 状态兼容 `Processing / Success / Failed / Expired` 及大小写规范化；轮询采用 5s→10s→30s→60s 有界退避，不以官方 10 次/秒上限作为实际轮询频率。成功后立刻下载，使用临时文件 + 校验 + 原子重命名；下载链接按 9 小时有效处理。
- [ ] 官方当前约束按 direct `text` 最长 50,000 字符、`text_file_id` 单文件小于 1,000,000 字符设计；未在当前官方接口页确认“T+7 必定完成”，不得把该说法硬编码成删除/失败期限。
- [ ] 音色范围：中文普通话、女声、儿童/青年、游戏与 RPG / 动漫与动画 / 角色配音；固定置顶顺序为 `Chinese (Mandarin)_Sweet_Lady`、`Chinese (Mandarin)_IntellectualGirl`、`Chinese (Mandarin)_ExplorativeGirl`。官方 voice ID 文档不带用户筛选页中的性别/年龄/场景标签，正式实现前需从 MiniMax 控制台导出或人工冻结完整 ID 清单，避免漏选/错选。
- [ ] 试听：当前官方系统音色列表未提供可直接打包的静态试听下载 URL，不得把第三方音频冒充官方素材。优先核实控制台是否允许下载；若没有，则经用户确认后用其 API key 对统一短句生成本项目试听文件，并核对费用与再分发条款后再决定打包 APK 或按需缓存。
- [ ] TTS 设置 UI 采用顶部“语音引擎：本地 / MiniMax 在线”选择，只展示当前引擎配置；统一音色卡点击进入 bottom sheet，前三音色置顶、其余支持筛选/搜索/试听。共享语速/音量，Provider 专属项折叠；普通聊天使用流式，长文本另设任务队列页，避免两套完整设置同时铺开。
- [ ] MiniMax API key 使用安全存储，永不进入 SQLite 明文、日志、状态包或脱敏诊断。诊断只增加 Provider、模式、任务状态计数、耗时/音频大小桶、轮询/恢复/下载结果、fallback 与错误类别，不输出 key、原文、音频 URL、task/file ID 或语音内容。

### TBD · GitHub 项目灵感发现

- [ ] 增加独立总开关，默认关闭；GitHub 搜索预算与公共网页预算分开。功能只负责发现、评估并告诉用户，不自动复制代码、下载依赖、改 APK 或创建实现任务。
- [ ] 使用独立“项目灵感库”，不写用户 Memory，也不与 14 天 TTL 的公共网页候选混放。按 `owner/repo` 去重，长期保存 URL、极简大纲、语言/平台、许可证、更新时间、可迁移性分级、风险与用户决定；用户要求的“都记下来”至少保留 URL 和大纲。
- [ ] AI 的“可在 APK 中做出来”只能是带置信度的建议，分为：Android/Dart/Kotlin 可直接借鉴、算法/协议可移植、仅概念/UI 可重做、依赖桌面/外部后端不适合、许可证/安全/体积待查。无许可证仓库只允许阅读与记录思路，不能默认复制代码。
- [ ] 推荐初始保护值为每日 2 次 discovery、每日最多 3 个仓库深读；先观察命中质量和 GitHub rate-limit headers 再调。是否启用、具体预算和灵感主动分享频率仍待用户确认。

### GUARDRAIL · v0.34.7 自主行动公共底座

- [x] 新增统一 `DesireIntent → Tool Gate → durable Action → Outcome → satisfy/feedback` 合同；工具不能自行产生人格、欲望、Intent 或主动联系。
- [x] Tool Gate 与主动消息投递 Gate 完全分离；联网成功以后只能先形成候选，不能自动发消息。
- [x] schema 24 新增 `autonomous_action_runs`：绑定 Active Brain generation/device、run token、dedupe、预算、锁屏状态、粗粒度结果与耗时；不保存 query、URL、网页/屏幕正文、账号或 Thought 正文。
- [x] 只有真实 `succeeded + candidate_stored/observation_stored + resultCount>0` 才能在同一 SQLite 事务中轻量 satisfy；失败、取消、无结果、重复、stale writer 和恢复均不能满足欲望。
- [x] 锁屏只阻止 `screen_observation`，不阻止安静 `public_web`；敏感页面、生成占用、transfer lock、Inactive Brain、Provider 缺失、预算耗尽和重复均有确定 Gate 原因。
- [x] 普通屏幕观察滚动窗口锁定为每小时最多 6 次；公开网页/视频 Provider 尚未设计，预算明确显示未配置而不擅自拍数值。主动联系继续沿用独立 2/2h、8/24h 上限。
- [x] 脱敏诊断新增 `database.autonomousActions`：按工具/状态计数、最后 Gate/Outcome、耗时桶、预算、锁屏与去重；显式声明不含 query、URL、内容、账号和内部 reason。
- [x] v0.34.7 只交付底座，phase=`foundation_not_scheduled`，不接入真实 Provider，不虚构已经上网或看屏幕。
- [x] v0.34.8 已把第一个真实公共网页 Provider 接入既有 heartbeat；成功只进有来源候选池。随后做手动一次屏幕识别。

## 2026-08-17 当前主线覆盖说明

> 本节覆盖下方早期 P0/P1 排期，但不删除历史实现与证据。当前产品基线为
> Draft PR #23 的已安装真机基线为 `v0.34.4+69`；本轮开发版本为 `v0.34.5+70`，schema 23 不变。

### ACTIVE · 悬浮恢复、后台存活与 Somatic 正向验收

- [x] 2026-08-17 20:58 脱敏报告确认 v0.34.4 失败样本没有进入 cover 状态机：`accessibilityAuthorized=false`、`coverSessionId=0`、`lastSystemCoverAt=0`、attempt/recovery 均为 0；OEM 备用 `onWindowVisibilityChanged` 也仍报告可见。此报告不能证明 settle 修复失败，但证明选择器检测入口存在缺口。
- [x] v0.34.5 增加“直接选择器 guard”：完整 App 主动打开图片/相机、诊断导出、手动备份保存/打开文件选择器前，直接向既有 cover 状态机发送 enter；返回、取消或启动失败时发送 exit。它不依赖无障碍或 OEM 窗口可见性回调，不建立第二套恢复状态机。
- [x] 保留 v0.34.4 的异步 attach settle 验证，不回滚已确认的同步误判修复；保持最多 3 次恢复，不增加第四次重试、不继续延长等待。
- [x] v0.34.5 首次提交后静态复核发现聊天页误用私有构造器 `AndroidBridge()`，会在 Flutter analyze/compile 阶段失败；已改为既有单例 `AndroidBridge.instance`，并把该断言加入 v0.34.5 validator。此修正不改版本号、不改恢复状态机，仅解除构建阻断。
- [ ] GitHub Actions artifact 存储配额仍为已知限制；APK 与 `.sha256` 继续由 workflow 写入同一私有仓库的草稿 Release，不恢复 artifact 上传、不发布正式 Release。待本次重新构建后回填 run、APK SHA-256 与草稿 Release 链接。
- [x] GitHub 连接可读写 PR/分支，但 Actions runs/logs 接口对连接令牌返回 403；安卓网页端又未显示可接管的 Cloud Browser。workflow 因此新增 `actions: read` 和独立 `report-ci-failure` job：失败或取消时读取已结束 job 的日志尾部，把状态、run URL、head SHA 与错误摘要覆盖上传为草稿 Release 内的 `AI-Companion-v0.34.5-70-CI-Monitor.txt`。成功时同名文件改写为 `status=success` 并附 APK SHA-256；不使用已满配额的 artifact。
- [x] 连接令牌也无法列出私有草稿 Releases，因此 CI monitor 同时镜像到 PR #23 的固定 `<!-- v0345-ci-monitor -->` 评论，并授予 workflow `pull-requests: write`。失败评论带日志尾部，成功评论带 run、head、APK SHA-256 与真实草稿 Release URL；自动修复读取 PR 评论，最终用户交付只发送 APK，无法直传时发送草稿 Release 链接，不把监测任务/CI 文件当成成品。
- [x] 上述 PR 评论读取接口同样返回 404，故在实际启用前改为独立 `ci-monitor-v0345` 分支的 `.ci/v0345-monitor.txt`。workflow 用既有 `contents: write` 覆盖该文件；该分支不建 PR、不合并 main，也不会触发当前 `pull_request` workflow。连接可通过 contents API 读取它。失败内容含日志尾部，成功内容含真实 Release URL 和 APK SHA-256；PR 评论方案已退役。
- [x] 首个可读取的自报告对应 Actions run `32040383825`、失败 job `95418527942`：失败发生在 `Source and regression validation` 的第一个历史校验器 `validate_v0331_desktop_pet_source_parity.py`，其版本白名单仍停在 `0.34.4+69`，没有接受当前 `0.34.5+70`。这不是 App 运行逻辑、direct picker guard 或恢复状态机失败。
- [x] 按“不要逐个报错逐个补丁”的边界扫描 workflow 实际调用的全部校验器；除 v0.34.5 新校验器外，共发现 15 个历史校验器仍引用旧版本/旧 workflow 标题/旧 APK 名称（v0321、v0322、v0331～v0343，v0344 不含旧版本锁）。本轮一次性把这些发布身份契约迁移到 `v0.34.5+70` / `Direct Picker Recovery` / `AI-Companion-v0.34.5-70-Direct-Picker-Recovery-APK`，不放宽任何功能断言、不改产品源码、不增加 overlay retry 或 delay。
- [ ] 上述 version-contract 修正重新触发 Actions 后，必须继续读 `ci-monitor-v0345/.ci/v0345-monitor.txt` 直到 success；成功时核验 APK、`.sha256`、run 与草稿 Release URL。run `32040383825` 生成的草稿 Release 只有失败诊断、没有 APK，不能作为交付。
- [ ] v0.34.5 真机连续测试相册选择与诊断导出各 2～3 次；无障碍可开可关，但报告必须至少出现 `coverSessionId>0` 和 `direct_picker:` 原因，最终目标为 `settled`、attached/touchable=true、`possibleRecoveryLoop=false`。
- [ ] 若 v0.34.5 仍卡住，最多再进行一轮聚焦修复：依据动画/触摸/菜单症状和新诊断，整体替换错误段或增加真实输入活性证明；不得继续叠加 retry/延迟补丁。
- [ ] 若上述最后一轮仍无效，冻结悬浮恢复，保留完整失败证据，先推进其余主线；待后续系统结构稳定后再回头处理。
- [x] 从真机报告确认旧 `selfHealCount` 不能直接等同异常：系统图片/文件选择器会按设计创建 cover session；但 v0.34.3 在 `addView()` 后同步读取 `isAttachedToWindow`，会把尚未完成 attach 的健康窗口误判失败，单次 cover 最多重复重建三次。
- [x] v0.34.4 将健康验证延后到 settle window；验证完成前保持 recovery ownership，避免 watchdog / Activity 回调并发重建。
- [x] 脱敏诊断区分“一次性系统页面恢复”和“自愈次数明显高于 cover session 的疑似循环”，并输出 `selfHealsPerCoverSession`，不记录包名、窗口文字或屏幕内容。
- [x] 增加后台存活元数据：进程年龄、服务存活时间、启动/干净停止次数、可能的非干净重启、最近划掉任务、最近 trim-memory、后台 Dart ready/失败次数与时间。只记录状态、时间、计数、级别和原因枚举。
- [x] 增加 Somatic 分向可观测性：最近一次 user / assistant 已提交 turn 的检测时间、是否写入、方向累计/活跃数；不导出聊天正文、动作、部位、scene 或 narrative。
- [ ] 真机验证一次系统图片选择：一个 cover session 只产生一次恢复，最终 `settled`、attached/touchable=true、`possibleRecoveryLoop=false`。
- [ ] 做一轮明确的 AI 自发完成动作测试；预期 `latestAssistantEvaluation.result=written` 且 `aiToSelf.total>0`。仅有意图、否定或未完成动作必须保持 `no_completed_action_match`。
- [ ] 锁屏、待机、划掉 Activity 与数小时 idle 后各导出一次报告，观察服务/进程/后台 Dart 连续性。
- [ ] 当前不主动要求电池优化白名单。只有诊断出现后台受限、可能的非干净重启、后台 Dart 反复失败或长时间心跳缺口等证据时，才加入 Android 电池优化白名单引导、Xiaomi/HyperOS 自启动与后台运行提示；必要时再评估更明确的前台服务策略。

### NEXT · 自主行动公共底座

- [ ] 建立统一 `Intent → Tool Gate → Action → Outcome`，复用现有 AI Self / Desire / Thought / rhythm，不建立第二套人格、欲望或主动消息系统。
- [ ] 工具预算分开记录：公开网页搜索、普通屏幕识图、视频理解、主动联系。欲望决定“想不想做”，硬预算负责异常保护。
- [ ] 锁屏只暂停屏幕识图，不暂停自主联网；锁屏时仍可安静搜索、阅读并形成带来源候选，是否联系用户继续经过既有 Gate。
- [ ] 为每类工具增加脱敏诊断：请求/成功/失败/取消/去重次数、最近时间、耗时桶、预算剩余、阻断原因与后台执行状态；不保存网页正文、截图、聊天、账号或搜索词原文。

### NEXT · 前台 App 与屏幕视觉 MVP

- [ ] 已知主流 App 以包名映射直接识别；未知 App 依次使用系统名称/图标、千问界面识别、联网查用途，仍不确定时允许她保留“不知道”或自主询问用户。
- [ ] 成功映射缓存为 `package → label/category/icon summary`；raw package 只作本地工具输入，不进入长期 Memory、Thought 正文或脱敏导出。
- [ ] 手动“一次看当前屏幕”先行，再开放 Desire 驱动的低频自主看一眼。普通屏幕识图采用滚动窗口每小时最多 6 次，不是固定每 10 分钟执行；同画面指纹去重，App/主要画面明显变化后才有调用价值。
- [ ] 单次/低频截图优先复用 Accessibility screenshot；默认不保存截图，只保留短期 `screen_observation`、App、时间、置信度与短 TTL。敏感 App、锁屏、生成中或画面无变化时不读取屏幕。
- [ ] 连续屏幕陪伴后置为独立 Session，复用 `neutral_silence`：用户沉默不等于冷落。Android MediaProjection 每次会话授权、前台服务和可暂停状态必须显式处理。
- [ ] 悬浮聊天图片入口登记为图片系统 Phase 3：系统图片选择器、缩略图草稿、复用既有附件存储、千问视觉与 durable generation。v0.34.5 只为完整 App 已有图片入口增加通用选择器 guard，不等于悬浮聊天图片入口已实现。

### NEXT · 自主联网与媒体候选池

- [ ] discovery 结果只能进入候选池：标题、摘要、URL、来源、fingerprint、标签、安全状态、TTL 与 lifecycle；不能直接写用户 Memory 或自动发消息。
- [ ] 图片仅在她选择查看时交给千问；SQLite 保存视觉摘要与来源，不保存外部图片/视频正文。搜索成功不等于必须联系用户。
- [ ] X / Telegram Provider 必须有未登录兜底：没有账号、凭据失效或封号时，仍可使用公开网页/公开搜索能力；登录态只扩展推荐流、敏感媒体或用户会话能力，不能成为整个自主联网的单点依赖。
- [ ] X 优先使用她自己的成年账号；无账号时使用公开页面/API 可见范围。不得读取用户个人 X 内容，除非以后单独授权。
- [ ] Telegram 可暂用用户账号做“搜索隔离”：禁止读取私聊、联系人、现有频道列表、首页流、最近/收藏贴纸来推断她的兴趣；只按她自己的 Intent 搜索公开频道/贴纸，不自动加入频道。以后可迁移到独立账号。
- [ ] 视频理解列为后置可选层：首版对 20～60 秒片段抽取 6～12 帧交给千问；连续视频预算与普通每小时 6 次截图预算分离。音频不假定已理解，需要字幕、Accessibility 文本或后续 ASR。

### RULE DETAIL · 图片作者归因

- [ ] 用户发送图片不代表用户创作。除非用户明确说自己画、制作或生成，否则只视为用户分享的图片，不主动推断作者；不固定追问“哪里找的”，避免形成口癖。

## P0 · ACTIVE · v0.32.0 Somatic Contract & Daily Touch MVP

### S-1. SQLite 感官事件 / 聚合契约

- [x] schema v21 新增 `somatic_events` 与 `somatic_aggregates`，事件绑定真实 turn。
- [x] `turn_id + direction + scene_key` 唯一；durable recovery 幂等，不重复放大。
- [x] 只有 Active Brain 且 transfer lock 关闭时可写。
- [x] 时间衰减、阈值与饱和合并为纯函数；事件/聚合加入状态包和统计。
- [x] 停止并撤回 user turn 时级联删除事件，并在同一事务重建聚合。
- [x] 功能 head run #25 通过 validators、analyze、tests、release APK/Kotlin 与 A2 payload；artifact `9230553317`，APK SHA-256 `d1637769a2d63179345c06b55a13497b6d4fbfeba6176caaaa4db3dbf1265587`。
- [x] PR #6 已合并到 `main`；最终 run #26（ID `31830858189`）通过，artifact `9230919832`，APK SHA-256 `82d57aaf58284e47ad6213537e7590dcc5e3ae94f159384f19fb6169a99d0e0c`。

### S-2. 日常触觉 user-to-AI

- [x] 11 类日常触觉动作映射为稳定 scene key；限制每轮最多 3 个事件。
- [x] 明显误命中“抱怨”和反向“你抱我”不产生感觉。
- [x] 感觉在本轮 Prompt 构建前同步产生；未命中、衰减低于阈值时完全不注入。
- [x] Prompt 只注入自然语言感受，不报内部数值、不声称现实观测、不绕过 Intimacy Session。
- [x] 2026-08-15 真机诊断确认 `somatic_events=1`、`active_somatic_channels=1`；用户观察到原生 reasoning 与触觉感受一致。诊断不含正文，因此不把 `self_experience` Thought 单独当作直接因果证据。
- [x] 新安装默认 `V4 Flash + High`；已有明确选择不被迁移覆盖。
- [x] v0.32.1+53 PR #9 / run #32：新增完成动作与动作括号检测，过滤意图/否定/假设；Flutter analyze/tests、release APK 与 A2 payload 校验全部通过。
- [x] `ai_to_self` 成功 durable commit 后半强度回响；与 assistant message/job completed/aggregate 同事务，取消、失败、stale writer、恢复重跑不制造幽灵事件。
- [x] 2026-08-15 第二份真机诊断累计 `somatic_events=4`、active channel=1，说明持续有事件落库；旧报告只有总数，不能单凭它证明方向。
- [x] v0.32.2+54 诊断统计新增 `somatic_user_to_ai_events` / `somatic_ai_to_self_events`，下一份报告可直接验双向落库。
- [ ] smell / taste / sound 与可替换 corpus。

### S-3. UI 与诊断小项

- [x] v0.32.2+54 悬浮聊天每条消息在发送者标签旁显示本地 `HH:mm`，沿用真实 `created_at`。
- [x] 脱敏报告标题不再硬编码旧 `v0.31.5+47`，改读实际安装包 versionName/versionCode。
- [x] 轻视觉区分“系统已授权”与“服务已连接”，持久记录最近连接、解绑、中断时间和原因；App 不尝试越权静默重开。
- [x] 已授权但未连接时，系统页和自检明确提示进入无障碍设置重新开关并保存诊断。
- [ ] REDMI K80 Ultra 真机复现/观察轻视觉是否仍被 HyperOS 撤销；若再现，用 v0.32.2 报告中的 lifecycle 字段定位。
- [x] v0.35.2 Flutter App 与启动恢复页显式使用 `zh_CN` 和官方本地化 delegate；长按选择沿用系统/Flutter 自适应中文菜单，不自制英文菜单。

## COMPLETED · v0.31.9 TTS State & Cancelled-turn Withdrawal

### A-1. 两套聊天语音控件一致

- [x] `TtsPlaybackQueue` 对外报告 `idle / synthesizing / playing`，并绑定 assistant message owner。
- [x] App 与原生悬浮聊天统一显示 outline 喇叭 / “…” / “■”。
- [x] 自动流式 TTS 在合成首段、尚未出声时显示“…”；进入实际播放调用后切为“■”。
- [x] 点击“■”、自然播放完成、停止或失败后恢复喇叭；合成中的“…”不重复发起朗读。
- [x] 删除悬浮框左上角“停语音”和 App 顶栏重复全局停止按钮。
- [x] 保持 Meju A2 native/MNN、分句、generation-ahead、FIFO 与间隔不变。
- [x] GitHub Actions run #22 通过全部新旧 validators、Flutter analyze/tests、release Kotlin/APK、A2 payload、SHA 与 artifact 上传。
- [ ] REDMI K80 Ultra 真机验证手动朗读、自动流式朗读、合成较慢、自然结束与中途停止。

### A-2. 停止未完成生成时撤回用户轮

- [x] `cancelGenerationJobByUser()` 改为 transaction：active job 终态 fencing 与对应 user message 删除不可分割。
- [x] completed 先赢时不删除完整对话；cancel 先赢时晚到 checkpoint/assistant commit 继续被 run-token/status fence 拒绝。
- [x] App Controller 在取消结果、取消异常与 recovery 取消后从 SQLite 重载，悬浮框沿用同一真源刷新。
- [x] 删除后的输入不进入未来 Prompt、post-turn memory extraction 或 durable recovery。
- [x] schema 保持 v20，不为半成品测试存档增加迁移负担。
- [x] run #22 artifact `9228720673`；APK SHA-256 `8d42899cd64b7c0ce84a5dbb941a73cdf2797b280c7f26dbe50951e7b15ad6e8`。
- [ ] 真机验证 reasoning 前、reasoning 中、正文中与极近完成点停止；取消轮在 App/悬浮框重开后均不出现。

## COMPLETED · v0.31.8 Overlay Stop & Live Stream

### A0. 生成前即时上下文

- [x] 把“模型生成前即时 Awareness”与“节流的 Desire/Thought/Presence 内化”拆为两条链。
- [x] 普通聊天与主动联系构建 Prompt 前刷新当前 screen/lock、粗粒度 activity、busy、switching 与 signal counts。
- [x] 即时刷新不调用模型、不触发主动联系、不推进 Desire/Thought/Presence/baseline。
- [x] raw package、通知正文与 Accessibility 正文不进入 Prompt、Thought 或脱敏诊断。
- [x] Active Brain 在刷新开始、写 Awareness 前与写后重复 fencing。
- [x] 脱敏诊断新增 `database.currentContext` 的刷新时间、原因、粗粒度类别与安全边界声明。
- [x] GitHub Actions run #31 analyze/test/release APK 通过。
- [x] 首次 Actions 已通过补丁、全套静态回归与 Flutter analyze；定位唯一失败为旧规则层测试写死 6 条，已改成验证新增后的 8 个明确 key/锁定属性。
- [x] 修正版补丁、文档 ZIP 与 workflow 已由 run #31 成功执行；完整 +47 已提交到 `app/`。
- [x] 真机确认普通回复生成前 `lastRefreshReason=prompt_user_turn`，且 `desireAdvancedByRefresh=false`。
- [ ] 后续真实主动联系再确认 `lastRefreshReason=prompt_proactive` 与当下 activity 一致。

### A1. 关系身份与初始性格

- [x] 锁定女性 AI × 成年男性用户/男朋友关系事实；不得转化为性别刻板模板。
- [x] 明确她不是服务者或无条件服从者，可以不同意、拒绝、保留判断与表达有原因的情绪。
- [x] 增加可编辑、可关闭的初始性格种子：亲近坦率但不黏腻，有主见，不以恋爱感为唯一目标。
- [x] 性格种子允许调侃、吐槽、偶尔锋利和真实不高兴，同时禁止无端发脾气、操控、惩罚或为反驳而反驳。
- [x] 新规则层使用 upgrade-safe `INSERT OR IGNORE`，不覆盖用户已编辑的第一规则或其他旧层。
- [x] 长期 AI Self、Relationship、Memory 与 Desire baseline 可以逐步细化/修正种子，种子不是永久角色卡。
- [x] 冻结“性格底色窗口”架构：预设 + 可编辑文本只写现有 `03_personality_seed`，不另建第二人格真源；设计见 `docs/PERSONALITY_BASE_UI_v1.md`。
- [ ] 用户确认“蠢萌元气”默认文案后实现页面；萌感来自元气、好奇、反差和偶发小迷糊，不幼化、不持续装傻、不损害任务可靠性。
- [ ] 真机对话确认男性称谓稳定、不会每轮强调“男友”，也不会因自主性规则机械唱反调。

## COMPLETED · v0.31.4 Grounded Desire Growth

### A. 输出链清理

- [x] 旧“伴侣式内心与回应”按钮、协议、解析器、过滤预览、纠正重试和诊断完全移除，不只隐藏 UI。
- [x] 普通聊天与主动联系统一直接使用 DeepSeek 原生 `reasoning_content + content`。
- [x] 思考/正文保持流式；TTS 只读正文，流式分句不再受旧开关限制。
- [x] `ChatMessage` 删除重复 provider/mode 字段。
- [x] schema v20 重建 `messages`；覆盖安装保留用户可见历史，旧 v19 状态包可导入并丢弃退休字段。
- [x] GitHub Actions analyze/test/release APK 通过并完成真机覆盖安装。
- [x] 首次 +46 Actions 失败已定位为旧文档上下文冲突；失败发生在 `git apply --check`，没有修改仓库源码。
- [x] 交付改为源码 patch + 独立文档 ZIP，并通过“故意破坏三份旧文档后仍能应用、覆盖及整树一致”的模拟回归。
- [x] 真机确认无旧伴侣式按钮；原生双流与第一规则可直接影响思考表达。

### B. Reality Grounding

- [x] 每次普通/主动生成显式注入本机当地日期、时间、UTC offset、星期和 daypart。
- [x] SQLite 确定 last user answered、pending user turn、user spoke after assistant 与 proactive count。
- [x] 主动历史折叠为只读 `ANSWERED CHAT HISTORY`，并声明 `CURRENT_USER_TURN=NONE`。
- [x] 正文与 reasoning guard 拦截把已回答历史当当前输入；最多一次纠正，仍失败则不落库。
- [x] provenance 区分 user_message / awareness / memory / self_experience / inference / internal。
- [x] Thought 原文不再进入模型 Prompt；只提供有界结构化 `THOUGHT_DATA`。
- [x] +47 已补充生成前即时粗粒度 activity / busy / screen / switching；raw package、通知正文和 Accessibility 正文保持隔离。

### C. Desire Core v2 / 成长

- [x] 8 Drive：attachment / curiosity / reflection / duty / social / libido / stress / fatigue。
- [x] 可确定性纯策略 tick、elapsed 输入、bounded coupling、action-aware satisfy、per-drive refractory、fatigue rest gate。
- [x] Thought Pool flit/fixation/residual/dormant、重复喂养、衰减、合并、重新浮现与 response outcome。
- [x] 召唤力使用 Drive + Thought bounded diminishing boost。
- [x] Presence 只作为 Drive/Thought 输入；Gate 不重复加分。
- [x] baseline anchor/cap + 约 120 天半衰期 pullback；成长稳定但可逆。
- [x] baseline 偏移以自然“长期性格倾向”进入 Prompt；具体偏好仍由 Memory / AI Self / Relationship 保存。
- [x] `libido -> tease_or_intimacy` 只有 active intimacy/roleplay_intimacy Session 才可执行。
- [x] 真正 wildcard：高张力、正常候选不够强、6 小时 cooldown 时产生 `wildcard_share`，走完整 Gate/Grounding/satisfy。
- [x] 自驱 Thought、未完成线索、长期记忆与用户 response outcome 已进入反馈回路。
- [ ] 用真机 1～2 天诊断确认 baseline 漂移幅度、wildcard 频率和 Intimacy gate，之后才讨论数值调参。

### D. 可观测性

- [x] 脱敏诊断包含 Grounding、8 Drive、baselines、refractory、fatigue gate、Intimacy action gate、wildcard cooldown、top candidates 与 Thought provenance。
- [x] “她的内心”页显示“当前值 / 长期 baseline”、Intent、why/source、Thought lifecycle、关系内化与 rhythm。
- [x] 调试/诊断不输出聊天正文、Thought 原文、raw notification、Accessibility 或 API secret。
- [ ] 将剩余工程 reason 逐步改为第一人称内在语义，但不得把技术参数发给用户。

## RETIRED · v0.31.2 实验性输出兼容层

- [x] 用户实测评价“差强人意”；随后确认第一规则可以直接改变模型原生思考，协议层不再有必要。
- [x] v0.31.4 按用户决定删除按钮和全部运行内容，不保留隐藏 fallback。
- [x] 历史可见 reasoning/content 被 schema v20 保留；仅丢弃重复 raw/模式字段和设置计数。
- [x] 后续若 provider 再次改变输出风格，优先调整用户可编辑规则或建立新的独立方案，不复活旧协议代码。

## FROZEN · v0.31.3 HyperOS / Android 15 Overlay file-picker

- [x] v0.31.3+45 完成 bounded cover 状态机：enter detach、exit rebuild、最多 3 次、诊断计数。
- [x] 旧诊断 `coverState=idle / session=0 / enter=0 / detach=0 / recovery=0`，证明当时检测链未触发。
- [x] 2026-08-15 新诊断捕获 `accessibility_system_surface`、cover session 2、detach 2、attempt 3，但快照仍为 `bubbleAttached=false / bubbleTouchable=false / inputSuspect=true`；检测已发生而重附着不健康。
- [x] 任务继续冻结，不在感官/总账轮次盲调重建延迟或自愈次数。
- [ ] 后期重开围绕一次可复现的 enter → detach → exit → reattach/touch 时间线取证；不能再只增加 retry。
- [ ] 只有取消、确认、第三方 App 和连续 picker 都能稳定产生 session 后，才重新测试 input-channel rebuild。

## P1 · NEXT · v0.31.5 验收后

### E. Notification Experience

- [ ] App 完整前台可见时主动消息默认静音。
- [ ] App 不在前台时使用系统通知送达。
- [ ] 提示音开关、内置短提示音、试听、App 音量与震动。
- [ ] 锁屏隐私：显示正文 / 仅“她发来一条消息” / 隐藏。
- [ ] 通知点击优先进入既有悬浮聊天；inline reply 复用 durable ChatController。
- [ ] 提示音不走 TTS；聊天或悬浮窗已展开时避免重复提示。

### F. HyperOS / Android 15 长后台

- [ ] 屏幕关闭/开启数轮。
- [ ] 从最近任务划掉完整 App 后 Foreground Service / background brain 是否持续。
- [ ] 数小时 idle 后恢复 heartbeat / perception / proactive。
- [ ] Android 杀进程后的 service/process recreation。
- [ ] 开机、应用更新后的恢复。
- [ ] Xiaomi/HyperOS 电池策略、后台启动限制说明与诊断；用户当前未遇到后台被杀，本项后置，有真机证据再升优先级。
- [ ] 完整 Activity destroy 后 durable generation 仍可恢复，不依赖 Activity-owned engine。

### G. 长期记忆/成长压力测试

- [ ] 50 / 100 / 数百轮：消息、summary、memory evidence、Thought、thread 不无限膨胀。
- [ ] current_fact / inference / shared_experience / historical 冲突回归。
- [ ] AI Self 与 Relationship 不能被单次异常输出永久污染。
- [ ] baseline 在重复强化下缓慢成长、停止强化后 pullback；不能振荡或卡 cap。
- [ ] Prompt 预算与检索相关性检查。

### H. 手机 / 平板同一个“她”

- [ ] Nearby 真实授权与发现。
- [ ] Phone -> Tablet takeover；旧设备 standby、不删数据。
- [ ] Tablet -> Phone reverse takeover。
- [ ] transfer 中断/超时/重启后的 durable pending state。
- [ ] generation / Thought / Desire / Continuity 接管前后不重复。
- [ ] encrypted `.aicomp` 手动 fallback。
- [ ] lineage / generation fencing 压力测试。

## P1 · NEXT · 已确认新增任务

### M. 规则分类归并

- [x] `01_core` 与 `01_relationship` 归为“01 身份与关系”，完整保留两个锁定小节及其原始内容。
- [x] `03_behavior` 与 `03_personality_seed` 归为“03 行为与初始性格”，保留各自开关、编辑和恢复默认入口。
- [x] Prompt 使用同一组标题下的有序小节，不拼接数据库文本；以后明确同类规则可直接加入映射。
- [x] 不改 schema 和 rule row，未知 key 自动成为自定义组；重复启动、旧备份导入和 Active Brain 转移继续沿用原有独立行语义。
- [x] GitHub Actions analyze/test/release APK 通过；真机 UI 验收待用户安装确认。

### N. 真正停止生成

- [x] 发送按钮在普通生成和 durable recovery 时变成统一停止键，并显示明确停止中状态。
- [x] 独立 HTTP client + in-memory token 立即终止当前 DeepSeek 流，不关闭其他维护请求或下一轮聊天。
- [x] 同一入口停止流式 reasoning/content、Meju TTS 播放及待播队列，并作废 recovery timer。
- [x] SQLite 使用 terminal `cancelled_by_user`；单次 UPDATE 清空 run token、partial checkpoint 与 retry 时间。
- [x] checkpoint/final commit 继续受 `running + run_token` fencing；取消后的晚到 token 不落库、不复活。
- [x] Runner 轮询 SQLite ownership，Overlay/headless recovery 也能在跨引擎取消后退出。
- [x] GitHub Actions run #10（ID 31813142711）通过 validators、analyze、全部 tests、release APK、A2 原生校验与 artifact 上传；真机停止行为待用户安装确认。

### N2. 悬浮框停止与真实流式双通道

- [x] 生成期间原生悬浮框的近手发送键切换为“停止”，不再禁用。
- [x] 顶部旧停止图标明确改名“停语音”；停止生成与停止朗读不再混淆。
- [x] 后台 MethodChannel 复用持久 ChatController 的真实取消入口，覆盖 HTTP 流、TTS、SQLite terminal 与 recovery fencing。
- [x] 增加 background warm-up send epoch，防止连接期间的停止被随后启动的发送越过。
- [x] 只在悬浮框展开且生成活跃时轮询 provider 原生 reasoning/content，显示单个临时流式气泡；不合成、不落库半条回复。
- [x] 增加纯 Dart snapshot phase/序列化测试与 v0.31.8 Kotlin/Dart 静态契约 validator。
- [x] GitHub Actions run #18（ID 31818910082）通过全部 validators、Flutter analyze/tests、release APK、原生 Kotlin 编译、A2 payload 与 artifact；前三次失败均停在静态校验，未生成 APK。
- [ ] 真机确认思考期停止、正文/TTS 期停止、收起重开不复活、自然完成后临时气泡被正式消息替换。

### O. 双通道感官

- [x] 按 `docs/DUAL_CHANNEL_SENSE_v1.md` 建立 SQLite event/aggregate contract、衰减和幂等测试。
- [x] 日常触觉 user-to-AI MVP。
- [x] 成功提交后的 AI-to-self 0.5 弱回响；PR #9 已合并，run #32 全量通过，待真机脱敏诊断确认。
- [ ] smell / taste / sound、Proust 记忆候选及私密 corpus 分箱。

### P. 表情包、主动联网、桌宠与屏幕陪伴

- [ ] 表情包标签注册、安全选图与结构化多气泡。
- [ ] **兴趣候选库（用户已批准）**：由 AI Self、curiosity、reflection、共同话题和订阅驱动；只保存标题、摘要、来源/域名、URL、TTL、标签、安全状态与 lifecycle。
- [ ] 联网 discovery 与主动联系分成两个 Gate：她可以安静收藏/重看，只有产生合适 Intent 时才分享；搜索结果不得直接写用户 Memory。
- [ ] 候选池必须有 URL/fingerprint 去重、7～30 天 TTL、数量/磁盘/流量/每日上限、域名黑名单、Wi-Fi/安静时段和可见来源。
- [ ] 公开网页内容视为 untrusted data；失败/取消不产生“已阅读”，外部 prompt injection 不得进入 system、AI Self、规则或 Thought 原文。
- [ ] 精确前台 App 感知是必要项：补齐 QQ/B站等友好标签、unknown fallback 与脱敏可观测性；检测到 App 不能直接强制发言。
- [x] Android 桌宠 D0：锁定 `QCYTSN/ds-local-pet` 为架构参考，并记录用户对私人、非商业 AI Companion 的素材使用授权与来源署名；公开发布仍需换素材或另行授权。
- [x] Android 桌宠 D1（历史，已由 D1.1 取代）：v0.33.0 的 238px/66 PNG 简化播放器可运行，但错误地把 27 个素材片段当动作入口，缺少三档、原 manifest 和完整生命周期；不得继续作为动作真源。
- [x] Android 桌宠 D1.1：完整保留 417 文件与 210 张 runtime PNG，直接解析 format v4 manifest，保持 18 行为动作、28 assets、三档/方向、原帧序时长、enter/body/exit、状态优先级、程序效果与 throw physics；中文 + 原 ID 预览和 DRAGGING→FALLING→LANDING→DIZZY 已验证。
- [x] Android 桌宠 D2：在同一前台服务内完成独立 Pet window；旧悬浮球与桌宠二选一且共用聊天/TTS/后台脑。单击触碰、双击菜单、112/152/200dp 三档、拖拽→下落→落地、安全位置与锁屏/cover 暂停已通过 run #54 自动验证；REDMI K80 Ultra 真机待验。
- [x] 旧悬浮球永久保留为可选入口；与桌宠共用 WindowManager 前台服务、悬浮聊天、消息时间、真停止和 TTS 状态，不同时显示。完整 D2 说明见 `docs/DESKTOP_PET_OVERLAY_D2_v0.33.2.md`。
- [ ] Android 桌宠 D3：把现有 Desire/Thought/mood/TTS 结果映射为 `THINKING/TALKING/行动`，加入受 Gate 控制的自主走动与动作反馈；不得另建第二人格或绕过主动联系 Gate。
- [ ] 屏幕陪伴支持一次分析/自动陪看、文本/文本+语音；用户沉默必须为中性，不产生 `no_response`。

## P2 · LATER

### H0. 沉浸房间（长对话模式）

- [ ] 新增长对话入口，与当前短对话/日常聊天明确分层；暂定产品名“沉浸房间”。
- [ ] 支持会话级的长上下文策略，以及可编辑/导入的“小说规则”等专用提示词；进入和退出必须显式可见。
- [ ] 长对话规则只在该 Session 生效，不覆盖正式 `03_personality_seed`、AI Self、Desire、长期关系事实或日常活人感规则。
- [ ] 设计前与用户讨论：上下文长度与费用、历史压缩、章节/场景连续性、是否写入长期记忆、Intimacy/RP 边界和退出后的余韵。
- [ ] 当前 `v0.35.0` 不实现，只登记方案；不要把普通聊天一刀切成长回复。

### H1. 性格试穿与常驻活人感

- [x] 常驻“先反应、再整理”规则，同时覆盖可见 reasoning；禁止把普通句子自动升格成关系论文，明确任务仍完整准确。
- [x] 4 个性格底色 × 4 个相处姿态；普通试穿到期回退，可在体验门槛后转正。
- [x] 8 个特殊风格独立计时、永不转正；病娇/痴女等强风格保留虚构表现力，同时锁住现实设备、退出、隐私和成人 Session 边界。
- [x] 聊天顶栏短倒计时 + “她的内心”完整试穿间；切换重置对应计时，延长保留进度。
- [x] schema 26 保存试穿、特殊层和长期性格版本；进入状态包，脱敏诊断不导出提示词正文。
- [x] v0.35.0 Actions run `32139893450` 全绿：历史/新 validators、Kotlin、Flutter analyze、164 tests、release APK、载荷核验、SHA-256 与私有草稿 Release 上传成功。APK SHA-256 `b47493f179a9fe850a6581d2a03bcdda843983f7c4637ac7d1aa22252319dd11`。
- [x] v0.35.0 第一轮真机语言取证：普通试穿可选中 `playful × impish`，但三轮内差异仍弱，出现元表演与统一安慰式收尾；该结论已作为 v0.35.1 的直接输入，不能再写成“尚无真机数据”。
- [ ] 双倒计时、到期回退、转正门槛、重装/状态包恢复和特殊风格仍待完整真机验收。

### I. 主动联系体验二次调优

- [ ] 只根据 Grounded Desire 真机数据调整频率，不预先拍阈值。
- [ ] 评估 engaged / resolved / deferred / dismissed / no_response 的长期效果。
- [ ] 通知隐私、悬浮未读、锁屏与 proactive TTS policy 一致。
- [ ] 用户忙始终是 soft friction，不变成绝对静音。

### J. Intimacy / NSFW

- [x] libido 的候选行动已有显式 Session 硬门槛。
- [ ] Intimacy Core / Rendering 只在明确 Session 生效，普通聊天不自动色情化。
- [ ] Reference 只作低优先级参考，不能把 AI 本体变成角色卡。
- [ ] 用户中止、边界更新与 Session 结束后的 Desire/Thought 反馈回归。

### K. 隐私 / 安全 / 可靠性

- [ ] Raw notification / Accessibility / package names 永不进入长期 Prompt、Thought 或导出诊断。
- [ ] API key、本地数据库、导出包、设备 transfer 的 secret/crypto 边界复核。
- [ ] 所有 background writer 受 Active Brain / transfer lock / lease / run token fencing。
- [ ] 脱敏报告逆向检查，组合字段也不能还原聊天正文。

### L. 发布工程

- [x] v0.31.4 patch/workflow/validator/Actions/APK 完成。
- [x] v0.31.5 patch/workflow/validator/Actions/APK 完成。
- [x] 本阶段 Clean Freeze：常规 workflow 改为只从 `app/` 独立 validate/analyze/test/release build。
- [x] 删除已应用 v0.30.x / v0.31.x 临时 patch、文档 ZIP，并退役一次性 apply workflow；Git 历史保留恢复路径。
- [x] 用户确认半成品测试阶段不保留存档、每次均可卸载重装；旧 workflow 内嵌 key 彻底退役。
- [x] 测试 workflow 每次生成一次性 key，不保存 GitHub Secret、不承诺覆盖安装；正式发布前另建长期 release signing。
- [x] v0.32.2+54 PR #10 / run #41：validators、analyze、tests、release APK、A2 payload 和 artifact 上传全通过；APK SHA-256 `f6d7d4aab377cace2449d7ffc35c791a3ef5a6ee039ef68fa3ae3b63f215d3b7`。
- [x] v0.33.0+55 桌宠 D0/D1：PR #11 squash merge `339f6a065e0942c3112a360249c9e05c400e3f7a`；最终 head run #44（`31862410341`）通过素材/历史 validators、Kotlin tests、Flutter analyze/tests、release APK 和 A2 payload；artifact `9241147554`，APK SHA-256 `a231ae317854b4985639a2124ffcfd2ffaa155d74a66cfee027c4a14342b3baa`。
- [x] v0.33.1+56 桌宠 D1.1 原项目动作同构：PR #12 产品 run #47（`31867409197`）全绿；artifact `9242561565`，ZIP digest `sha256:4058b67b7d8739c57dae6442306fc6524c81229e6b542d56c15c206e2aeafac9`，APK SHA-256 `456d618776b1729353ea1735a63a139eb344cab9e1b296066bdbed04ef1759b7`；旧完整交接从 Git 历史取证。
- [x] v0.33.2+57 桌宠 D2：PR #13 产品 run #54（`31873700153`）全绿；artifact `9244295960`，ZIP digest `sha256:1c3126f90582e11c936f521215cdfb547d28cb6bb53cea01debc66d6148c5716`，APK SHA-256 `6ed7067612ef164f2412ff517da59af35340fba626b4508923ccdd7aa55b6c8b`；最终文档 head 与 merge 落款见 v26 总账。
- [ ] v0.32.2 真机确认悬浮 `HH:mm`、轻视觉 lifecycle 诊断和 Somatic 两方向计数。
- [ ] 固定正式 package/release signing；测试签名只用于开发。
- [ ] 进入正式数据保留阶段后，再验证长期 release key 下的升级安装、备份恢复与崩溃恢复。

## FROZEN · TTS

- [ ] Meju A2 已真机可用；仅剩轻微断句/节奏问题，非阻断。
- [ ] 显示版本号可能存在遗留不一致；与轻微停顿一起冻结。
- [x] `Yuki -> 有希`、A2 punctuation、generation-ahead、FIFO、native/model baseline 为 GUARDRAIL。

## GUARDRAIL

- [x] 模型原生 reasoning/content 双流；App 不再用固定协议重写“女友感”。
- [x] SQLite 为长期状态真源。
- [x] Durable Generation / run token / recovery。
- [x] Active Brain / transfer fencing 架构不可绕过。
- [x] Awareness 原始敏感数据先本地粗粒度化。
- [x] **Desire / Thought / Intent / Gate 是行为调度主干**：感知、记忆、联网、屏幕和桌宠提供输入/能力，但不得各自建立绕过 Gate 的主动触发器。
- [x] Proactive hard caps：2/2h、8/24h。
- [x] TTS A2 黄金基线。
- [x] `app/` 是 GitHub single source of truth。
- [x] Clean Freeze 后每项功能走独立分支/PR；常规 workflow 只验证和构建当前 `app/`，不在构建时应用补丁或提交源码。
- [x] 每个正式版本同步更新 HANDOFF 与本总账；大阶段保留完整源码 ZIP + SHA-256。

## v0.34.7+72 · 自动验收落款

- [x] run `32053411090` attempt 2：所有历史 validators、Kotlin 桌宠状态/物理测试、Flutter analyze/tests、release APK、原生库与 417 文件桌宠载荷、checksum、私有草稿 Release 上传全绿。
- [x] APK：`AI-Companion-v0.34.7-72-Autonomous-Action-Foundation-APK.apk`，239,478,981 bytes，SHA-256 `7df89f3ea7fbec1c316a26ecc796971b4c3338b9d0a1ab4b2a586b92c3cfd477`。
- [ ] 真机只需确认安装/启动与脱敏诊断 schema 24 / `database.autonomousActions.phase=foundation_not_scheduled`；本版没有真实 Provider 行为，不应出现自动联网或自动看屏幕。

## v0.34.8+73 · 自动验收落款

- [x] 最终 run `32061800320`：历史 validators、Kotlin 桌宠测试、Flutter analyze/tests、release APK、原生库和 417 文件桌宠载荷、checksum、草稿 Release 上传全绿。
- [x] APK：`AI-Companion-v0.34.8-73-Public-Web-Discovery-APK.apk`，239,553,049 bytes，SHA-256 `10957e7417de9686122ed7d7784a41542157f2fca3e8aa7d5af7ab56d264fc4f`。
- [x] 私有草稿 Release：`https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-fb193eb0c14190803f0a`，已核验 APK、`.sha256` 与 CI monitor 三项资产均为 uploaded。
- [x] 该真机验收由随后安装的 v0.34.9 数小时报告完成：schema 25、phase/publicWebCandidates 正常且隐私字段仍排除；发现成功不会直接发消息。

## v0.34.9+74 · CI 与真机验收落款

- [x] Actions run `32095469762`：历史源码回归、Kotlin 桌宠测试、Flutter analyze、161 条 Flutter tests、release APK、原生 TTS/417 文件资源校验、checksum 与草稿 Release 上传全绿。
- [x] APK `AI-Companion-v0.34.9-74-Layered-Web-Discovery-APK.apk`，SHA-256 `7fa1c47f4e87f50a461669098effa0e275bfa39fec336817edb9c1e94b9fe10f`。
- [x] 数小时真机报告：4/4 次 public_web succeeded、12 条 active/reviewed 候选、`provider=tavily+agnes`、Agnes enabled、预算 4/4 用尽、重复 Gate 正常、无 Provider/后台错误；标题/摘要/URL/query/interest key/Thought 正文继续脱敏。
- [x] 候选 reviewed 与 viewCount 证明短期 `WEB_CANDIDATE_DATA` 已实际读取；搜索仍不自动生成 Memory、Thought、消息或主动联系。
- [ ] Agnes 内容质量若需进一步比较，使用设置页固定公开样本人工验收；管线已通过，不需要语音 API。

## v0.35.1+76 · CI 验收落款

- [x] 最终实现 head `a564cb8a6dbcebd8071384d391b5e7527c9620a1`；Actions run `32160558352` 全绿，包含历史 validators、v0.35.1 新契约、Kotlin 桌宠状态/物理测试、Flutter analyze、164 条 Flutter tests、release APK、6 个 arm64 原生库、417 文件桌宠载荷、外观/哈欠素材与 A2 native 前缀核验。
- [x] APK `AI-Companion-v0.35.1-76-Personality-Inner-Voice-APK.apk`，约 239.8MB；SHA-256 `830332e19f774e6d62989d41fa167a4662342991d8c2de63c41869e5573083f7`。
- [x] 私有草稿 Release：`https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-7bedb31de10cf8a5062f`；APK、`.sha256` 与 CI monitor 三项资产上传成功。Draft PR #23 保持未合并，正式 Release 未发布。
- [ ] 真机 A/B 仍是产品验收：普通底色/姿态是否 1～3 轮可辨、思考与台词反差是否自然、特殊风格是否足够强、主动消息是否摆脱万能守候收尾。
