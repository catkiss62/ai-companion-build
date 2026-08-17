# AI Companion · 接班总账 v34

更新时间：2026-08-17（Asia/Tokyo）

> 本文件继承 `AI_Companion_接班总账_v33_2026-08-16.md` 的历史证据，只重写当前基线、最新真机结论和后续路线。判断优先级仍为：用户最新明确决定 > GitHub 实际源码/Actions > 最新脱敏真机诊断 > 仓库任务账 > 历史记录。讨论、设计和本地修改不得写成已经通过 CI 或真机验证。

## 1. 当前开发基线

- 仓库：`catkiss62/ai-companion-build`；默认分支 `main`；源码真源 `app/`。
- 当前 Draft PR #23：`https://github.com/catkiss62/ai-companion-build/pull/23`。
- PR 分支：`agent/personality-appearance-self`；用户已安装并目测通过 `v0.34.3+68`。
- `v0.34.3+68` 已实现：活人感/独立欲望与情绪惯性规则、NSFW 直接表达与空间状态账本、保守默认迁移、聊天页真正可见时清未读、中/大桌宠角标偏移，以及取消回复到达时的 TALKING 摇摆；真实 TTS 播放仍可 TALKING。
- 本轮本地目标版本：`v0.34.4+69`，schema 继续为 23，不做数据库迁移。
- 本轮范围：修复系统选择器后的悬浮输入恢复误判；增加后台存活与 Somatic 脱敏可观测性；更新自主联网/屏幕感知路线。自主联网和屏幕识图本体尚未实现。

## 2. 最新脱敏诊断结论

### 2.1 Desire / Thought

- 欲望核心运行正常；Drive、baseline、Thought provenance、冷却、主动 Gate 与硬频率门槛没有异常暴涨或重复推进。
- 手机忙碌、最近已主动联系等条件可以阻止发送；说明 Desire 不会绕过现有 rhythm/Gate 强制打扰。

### 2.2 双通道感官

- 2026-08-17 10:01 UTC 报告记录：`somatic_events=2`、`user_to_ai=2`、`ai_to_self=0`、`active_somatic_channels=1`。
- 这份报告已经正向证明 user → AI 触摸通道正常；AI → self 为 0 只说明尚未在已提交回复中命中明确的自发完成动作，不足以判故障。
- v0.34.4 诊断增加最近 user/assistant 已提交 turn 的检测时间、写入/未命中结果、方向累计与活跃数；不导出聊天正文、动作、部位、scene 或 narrative。
- 真机定向验收仍需一条明确已完成的自发动作；意图、否定、假设和“想做”不得命中。

### 2.3 悬浮窗恢复

- 报告从 cover session 3 增至 7，但 `selfHealCount` 从 40 增至 63；`coverRecoveryCount=0`，最终停在 attempt 3 / `recovery_scheduled`，同时桌宠实际仍可触摸。
- 明确根因：`WindowManager.addView()` 后立即读取 `isAttachedToWindow`。HyperOS 可能尚未完成 attach，旧代码因此把健康窗口误判失败，并在同一个系统图片/文件选择器会话中重复重建。
- v0.34.4 改为在 settle window 后再验证 attached/touchable；验证前保持 recovery ownership，避免 watchdog 与 Activity callback 并发重建。
- 诊断区分正常一次性 cover 恢复与疑似循环，并输出 cover session、自愈比率和最终状态。真机目标是一场系统选择器会话只恢复一次，最终 `settled`、attached/touchable=true。

## 3. 后台存活与电池策略

- 锁屏只暂停“看当前屏幕”，不暂停自主上网。锁屏时允许安静搜索/阅读候选；是否主动联系仍经过既有 Gate、时间和节奏限制。
- v0.34.4 增加脱敏后台连续性字段：进程年龄、服务 uptime、启动/干净停止次数、可能的非干净重启、最近划掉任务、最近 trim-memory、后台 Dart ready/失败次数与时间。
- 诊断只含时间、计数、状态、级别和原因枚举，不含屏幕、网页、聊天、搜索词、账号或 API 数据。
- 当前 Xiaomi 报告为 `backgroundRestricted=false`、`batteryOptimizationIgnored=false`，且用户尚未观察到明确后台被杀；因此电池优化提示继续后置。
- 只有后续复杂功能加入后出现后台受限、非干净重启、后台 Dart 反复失败、心跳长缺口或锁屏任务明显中断等证据，才加入 Android 电池优化白名单引导、Xiaomi/HyperOS 自启动/后台运行提示；必要时再评估更明确的前台服务策略。

## 4. 自主性路线（确认版）

### 4.1 公共行动底座

1. 建立统一 `Intent → Tool Gate → Action → Outcome`。
2. AI Self / Desire / Thought / rhythm 继续是真源；联网、识图、视频和桌宠只提供能力或输入。
3. 工具预算分为公开网页搜索、普通屏幕识图、视频理解、主动联系；欲望决定是否想做，硬预算防异常循环。
4. 工具结果先成为带 provenance 的候选，不直接写用户 Memory，不等于自动发消息。
5. 脱敏诊断记录请求/成功/失败/取消/去重次数、最近时间、耗时桶、预算和阻断原因。

### 4.2 App 感知与屏幕视觉 MVP

- 已知主流 App 由包名映射直接识别；未知 App 依次读取系统名称/图标、用千问理解界面、联网查用途，仍不确定时允许她保留“不知道”或自主询问用户。
- 成功映射本地缓存，避免重复识图/联网；raw package 不进入长期 Memory、Thought 正文或脱敏报告。
- 第一版先做手动“一次看当前屏幕”，再开放 Desire 驱动的低频自主看一眼。
- 普通屏幕识图采用滚动窗口每小时最多 6 次；不是固定每 10 分钟调用。同画面指纹去重，App/主要画面变化明显后才有价值。
- 单次截图优先 Accessibility screenshot；默认不保存截图，只保留短期 `screen_observation`、App、时间、置信度与短 TTL。
- 锁屏、敏感 App、生成中或画面无变化时不截图；锁屏不影响自主联网。
- 连续陪看后置为独立 Session，复用 `neutral_silence`；用户沉默不产生 `no_response`。MediaProjection 每次授权、前台服务、暂停/退出必须显式处理。

### 4.3 自主联网与候选池

- 候选保存标题、摘要、URL、来源、fingerprint、标签、安全状态、TTL 与 lifecycle；图片/视频只在她决定查看时交给千问。
- 图片只保存来源与视觉摘要，不保存外部图片正文；搜索成功仍不等于找用户说话。
- 视频理解后置：首版对 20～60 秒片段抽 6～12 帧；视频预算与每小时 6 次普通屏幕识图分开。千问视觉不默认理解音频，需字幕、Accessibility 文本或以后 ASR。

### 4.4 X / Telegram

- 两个 Provider 都必须有无账号兜底。未输入账号、凭据失效或封号时，仍使用公开网页/公开搜索可见范围；登录态不能成为自主联网的单点依赖。
- X 优先给她独立成年账号，以支持推荐流和允许显示的敏感媒体；无账号时使用公开页面/API。默认禁止读取用户个人 X 内容。
- Telegram 可暂用用户账号，但采用搜索隔离：不读私聊、联系人、已有频道列表、首页流、最近/收藏贴纸，也不以用户订阅史塑造她的兴趣；只按她自己的 Intent 搜索公开频道/贴纸，不自动加入频道。以后可迁移到独立账号。

## 5. 图片系统后续项

- 图片默认归因规则：用户发送图片不代表用户创作。除非用户明确说自己画、制作或生成，否则只视为分享图片，不主动推断作者；不固定追问“哪里找的”，避免形成口癖。
- 悬浮聊天图片入口登记为图片系统 Phase 3：系统图片选择器、缩略图草稿，并复用 App 已有附件存储、千问视觉和 durable generation；不在 v0.34.4 的悬浮恢复修复中混做。

## 6. 本轮真机验收顺序

1. 安装 `v0.34.4+69`，打开一次系统图片选择器后返回；确认桌宠可触摸，导出诊断。
2. 预期 `coverState=settled`、attached/touchable=true、`possibleRecoveryLoop=false`，且一次新 cover session 只增加约一次 self-heal。
3. 让她在回复中明确写出一个已经完成的自发身体动作，随后立即导出诊断；预期 AI → self 的 latest result 为 `written`。
4. 分别在锁屏/待机、划掉完整 App、数小时 idle 后导出报告，观察服务 uptime、possible unclean restart、后台 Dart ready/failure 与 heartbeat。
5. 两项通过后进入自主行动公共底座，再做前台 App 感知、每小时最多 6 次的屏幕视觉 MVP 和公开网页 discovery 候选池。

## 7. 不可回归边界

- 不建立第二套 Desire、Thought、AI Self、Memory、Somatic 或主动联系系统。
- 公开网页与屏幕内容是 untrusted input；不能写 system rule、覆盖人格或把 prompt injection 当指令。
- 桌宠与悬浮球继续二选一并共用同一前台服务、聊天、未读、TTS 和后台大脑。
- 桌宠单击保留触碰反应，双击打开选项；真实 TTS 才使用 TALKING，回复到达不再强制摇摆。
- 数据库 schema 23 保持；本轮不迁移用户数据。
- 未经真机/CI 证明的项目只能写 `PLANNED`、`LOCAL IMPLEMENTED` 或 `REAL-DEVICE VERIFY`，不得写成完成。
