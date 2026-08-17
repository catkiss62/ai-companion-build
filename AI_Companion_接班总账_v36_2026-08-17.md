# AI Companion · 接班总账 v36

更新时间：2026-08-18（Asia/Tokyo）

> 本文件是当前唯一最新接班入口，继承 v35 以前的历史证据，但以本文件记录的基线、用户决定、真机结论和排期为准。判断优先级：用户最新明确决定 > GitHub 实际源码与 Actions > 最新脱敏真机诊断 > 仓库任务账 > 旧总账。讨论、设计、本地实现、CI 通过和真机通过必须严格区分。
>
> 用户再次锁定：任务总账是最重要的跨窗口对接文件。每次新增任务、修改实现、改变排期或得到新真机证据时，都必须像本文件一样详细更新。欲望系统与双通道感官设计作为“真人感核心备份”长期保留，后续自主性功能必须围绕 Desire / Thought / Intent / Gate 与 Somatic 双通道设计。

## 0. 下一轮开场先做什么

1. v0.34.5+70 direct-picker 自动化已通过，但新真机报告证明用户当前复现的是“其他 App 发起的上传选择器 + 无障碍关闭”，不是 App 内 direct-picker 已进入后恢复失败。v0.34.6+71 只修复锁屏/解锁 WALKING、STROLLING 卡动作，CI 与真机待验。
2. 安装 v0.34.6 后，先在系统设置重新开启 AI Companion 无障碍并确认诊断为 authorized/connected=true；卸载重装会清除该系统授权，App 不能静默恢复。
3. 从 ChatGPT/浏览器等外部 App 打开上传选择器，返回后再进入 AI Companion 生成报告。预期 `coverSessionId>0`、Accessibility 原因与最终 `settled`；App 自己发起的相册/相机/诊断保存仍应看到 `direct_picker:`，且不要求无障碍。
4. 锁屏复测：分别在 WALKING 与 STROLLING 时锁屏，解锁后应从 IDLE/重新调度开始，不再停留在失去移动任务的循环动作。
5. 若无障碍已连接且外部上传仍卡住，用户发送同样的脱敏诊断，并说明症状属于：
   - 动画仍运行，但点击/拖动/双击无反应；
   - 动画也完全停止；
   - 只有菜单或悬浮聊天打不开。
6. 若 cover 已进入 session 仍失败，只允许再做一轮聚焦修复；应整体替换错误段或增加真实输入活性证明，不能继续延长等待、增加第四次重试或层层打补丁。再失败则冻结悬浮恢复，先推进其余主线。

## 1. 当前 GitHub / 构建基线

- 私有仓库：`catkiss62/ai-companion-build`；默认分支 `main`；唯一源码真源为仓库中的 `app/`。
- 当前 Draft PR #23：<https://github.com/catkiss62/ai-companion-build/pull/23>
- PR 分支：`agent/personality-appearance-self`
- v0.34.4 已通过 head：`7715527ec0b20a3984bdf919e16c48c19fb678f1`
- v0.34.5 实现提交：`66e5ddb7946519ce35f59d66cd124a92a511a557`；该提交同时包含源码、workflow、HANDOFF、长期任务账和 v36 总账初版。
- 当前真机复测版本：`v0.34.5+70`；当前开发目标：`v0.34.6+71`；SQLite schema 23，不含数据库迁移。
- GitHub Actions run #130：<https://github.com/catkiss62/ai-companion-build/actions/runs/32024213112>
- run #130 已通过：完整历史 validators、Kotlin 桌宠测试、Flutter analyze、Flutter tests、Release APK、原生/宠物载荷核验、SHA-256 和草稿 Release 上传。
- 草稿 Release：<https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-e6fa65e2d3440c7a4706>
- APK：`AI-Companion-v0.34.4-69-Overlay-Recovery-Diagnostics-APK.apk`
- APK SHA-256：`a481ef908f046afc1c53fd4abd6deb22b5717d85e7ff76691afb7921c2358a3b`
- CI 使用临时测试签名；测试阶段用户允许卸载重装，不要求保留测试存档。
- v0.34.5 本地静态验证与完整 GitHub Actions 均已通过；真机结果尚未确认。
- 首个可读失败 run：`32040383825`，失败 job：`95418527942`；随后 run `32041890393` 暴露遗漏的 v0320 旧版本白名单。修正提交：`46c7b5c91fc98b4a705e60eb6cefabca3ad26914`。
- 成功 run：<https://github.com/catkiss62/ai-companion-build/actions/runs/32042113547>；PR merge SHA：`98e121ac96fe3754c4b5f1ccb4a314f42492953e`。
- v0.34.5 草稿 Release：<https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a9ccc51dbd5118d6180b>。
- APK：`AI-Companion-v0.34.5-70-Direct-Picker-Recovery-APK.apk`；SHA-256：`0a46eabd3c72a40803508de81218bc96362a75748e5f91254aa6b4a607dbb4e6`。
- 2026-08-18 用户再次确认交付方式：Actions artifact 配额已满时，继续使用 workflow 的 `contents: write`，把 APK 与 `.sha256` 上传到私有仓库草稿 Release；监测文件只供助手排错，绝不能作为用户交付物。15 个旧发布身份校验器修正后，监测分支仍停在旧失败 run，因此通过本总账同步提交触发一次新的 PR 构建；本轮不改 App 源码、版本号或 Release 方案。

## 2. v0.34.3 已确认基线

- 用户已安装并目测认可 `v0.34.3+68` 的整体体验。
- 已实现活人感/独立欲望与情绪惯性规则、成人关系内直接表达与空间状态账本、保守默认迁移。
- 聊天页真正可见时才清未读；中/大桌宠角标位置已调整。
- 取消“回复一到达就强制 TALKING 摇摆”；真实 TTS 播放仍会触发 TALKING。
- 桌宠与旧悬浮球继续二选一，共用同一个前台服务、聊天、未读、TTS 和后台大脑。
- 桌宠单击保留身体触碰反应，双击打开菜单；不可改成单击菜单。

## 3. v0.34.4 已实现内容（自动化通过，真机仍待完整验收）

### 3.1 悬浮输入恢复

- v0.34.3 真机报告曾显示 cover session 从 3 增到 7，同时 `selfHealCount` 从 40 增到 63；恢复反复到 attempt 3，实际桌宠却仍可触摸。
- 当时确认的一个根因：`WindowManager.addView()` 返回后立即读取 `isAttachedToWindow`，HyperOS 尚未完成异步 attach，健康窗口被误判为失败。
- v0.34.4 改为等待 settle window 后再验证 attached/touchable，并在验证前保持 recovery ownership，避免 watchdog、Activity 回调和恢复任务并发重建。
- 诊断新增 cover session、attempt、最终结果、`possibleRecoveryLoop`、`selfHealsPerCoverSession` 等脱敏状态。
- 注意：这只修复“检测到 cover 后的恢复验证竞态”，没有证明所有情况下都能正确检测系统遮盖，也没有证明 attached/flags 等同真实输入可用。

### 3.2 Somatic 双通道诊断

- 旧报告已证明 user → AI：`somatic_events=2`、`user_to_ai=2`、`ai_to_self=0`。
- v0.34.4 增加最近 user / assistant 已提交 turn 的检测时间、写入/未命中结果、方向累计与活跃数。
- 脱敏报告不导出聊天正文、动作、身体部位、scene 或 narrative。
- AI → self 仍待一条明确“已经完成”的自发身体动作真机验收；意图、否定、假设、“想做”不能命中。

### 3.3 后台连续性诊断

- 新增进程年龄、服务 uptime、启动/干净停止次数、可能的非干净重启、最近 task removed、最近 trim-memory、后台 Dart ready/失败次数与时间。
- 只记录时间、计数、状态和粗粒度原因；不记录屏幕、网页正文、聊天、搜索词、账号或 API 数据。

### 3.4 v0.34.5 直接选择器 guard（本地已实现，CI/真机待验）

- 最后一份失败报告证明系统选择器没有进入 cover 状态机。源码核对发现自动入口只有 Accessibility system-surface 与 `onWindowVisibilityChanged`；无障碍关闭时前者不运行，而本机选择器出现后 overlay window 仍报告 visible，后者也不会触发。
- 完整 App 的图片/相机入口现在在调用 Flutter `image_picker` 前直接发送 cover enter，返回、取消或异常时发送 exit。
- 原生诊断导出、手动备份保存与打开文件选择器，也在 `startActivityForResult` 前发送 enter，在 activity result 或启动失败时发送 exit。
- 直接入口复用现有 `notifySystemCoverEntered/Exited`、cover session、bounded recovery、settle 验证与脱敏诊断；没有建立第二套恢复状态机。
- 保留 v0.34.4 settle 修复和最多 3 次恢复上限；未修改 retry delay、settle 时间或 WindowManager rebuild 核心。
- 粗粒度 reason 为 `direct_picker:...`；不记录图片、文件名、URI、选择内容、账号或聊天正文。

### 3.5 v0.34.6 锁屏动作恢复（实现中，CI/真机待验）

- 新真机现象：桌宠处于 WALKING 或 STROLLING 时锁屏，解锁后会持续停留在走路动作；任意互动会强制切换动作并恢复。
- 源码根因明确：`setVisible(false)` 会移除 autonomous move tick，却使用 `cancelAutonomyPlayback(resetToIdle = false)`，保留了无时限循环的 WALKING/STROLLING；解锁仅恢复 player tick，不会重建已丢失的移动任务。
- v0.34.6 改为隐藏时将临时自主动作归零到 IDLE，解锁后沿既有逻辑重新安排 ambient 与 blink。没有修改动作素材、方向、移动速度、欲望接线或系统遮挡 recovery。
- 新增 `validate_v0346_lock_visibility_resume.py`，同时锁定 cover recovery 仍为最多 3 次与 700ms settle，防止修锁屏时顺手改动已冻结的恢复时序。

## 4. 2026-08-17 最新真机诊断：不能据此判 v0.34.4 恢复失败

报告：`ai_companion_diagnostics_2026-08-17T12-58-30-120929Z.txt`

### 4.1 关键事实

- 安装版本正确：`0.34.4+69`，schema 23，Active Brain=true。
- `accessibilityAuthorized=false`、`accessibilityConnected=false`：本次卸载/重装后无障碍权限未重新开启。
- `coverSessionId=0`
- `lastSystemCoverAt=0`
- `coverRecoveryAttempt=0`
- `coverRecoveryCount=0`
- `coverState=idle`
- `selfHealCount=2`，最后一次原因为 `reconcile:visible_activity_reconcile`，发生在服务启动附近，并非 cover recovery。
- 报告导出前约 2.4 秒仍记录到 `lastTouchAction=pet_up`；报告捕获的是回到完整 App、reconcile 之后的状态，不是卡住瞬间。
- 报告将 attached、flags、enabled 推断为 `bubbleTouchable=true`，但这不是“系统确实把触摸事件送达”的直接证明，因此当前健康检查存在可观测性盲区。

### 4.2 当前结论

- 这次没有进入上一轮修过的 cover recovery 状态机，不能用它证明 settle 修复成功或失败。
- 刚安装时看似成功自愈，可能只是 Activity 可见时的普通 reconcile 重建；后续系统选择器未被识别，所以没有触发专用恢复。
- 现在不还原 v0.34.4 settle 修复：还原会重新带回已经确认的同步 attach 误判。
- 现在不还原 v0.34.4 settle 修复；已确认的同步 attach 误判不能重新带回。
- 已选择修复检测入口而非调整 reattach：App 自己发起的选择器具备确定的调用点，应直接通知同一状态机，不再要求无障碍作为必要前提。

### 4.3 下一份报告的判定规则

- `coverSessionId>0`、reason 含 `direct_picker:` 且 attempt 1 后 `settled/success`：直接入口与 settle 修复均有效。
- `coverSessionId>0` 但仍到 attempt 2～3 / failed：重新设计恢复健康证明和状态机；优先选择性替换旧恢复段，不再增加延迟/次数。
- App 内相册/诊断导出后仍为 `coverSessionId=0`：direct picker bridge 没有真正到达 Native；调查 MethodChannel/Activity 调用链，不调整 reattach。
- 动画停止但触摸仍有记录：调查 PetAnimationPlayer / Choreographer / 状态机，不要误修 WindowManager 输入。
- 动画运行但无触摸记录：调查 overlay input channel 与窗口重建。

### 4.4 2026-08-17 v0.34.5 新真机报告与测试范围纠正

报告：`ai_companion_diagnostics_2026-08-17T15-46-10-956062Z.txt`

- 版本正确：`0.34.5+70`，schema 23，Active Brain=true；服务/后台 Dart 正常，无非干净重启、trim-memory 或后台限制证据。
- `accessibilityAuthorized=false`、`accessibilityConnected=false`；`coverSessionId=0`、`lastSystemCoverAt=0`、attempt/recovery/detach 全为 0，cover state=idle。
- 报告生成时 overlay attached/touchable/visible=true，最后触摸为 `pet_up`；这些结构状态仍不能证明用户描述的卡住瞬间输入确实可用。
- 用户描述“只要上传必然卡住，上传界面出现时桌宠/悬浮球消失，退出后出现并卡住”。结合使用路径，应区分：
  - AI Companion 自己打开相册、相机、诊断保存或备份：v0.34.5 direct-picker guard 可直接登记，不依赖无障碍。
  - ChatGPT、浏览器或其他 App 打开上传选择器：AI Companion 收不到对方的调用，只能依靠 Accessibility 系统页面识别或 OEM `onWindowVisibilityChanged`。本机 HyperOS 已知不可靠地发送后者，本报告又证明 Accessibility 关闭，因此本次必然没有 cover session。
- `AccessibilityBridgeService` 已覆盖 DocumentsUI、PhotoPicker、IntentResolver、小米文件管理器、PermissionController、PackageInstaller、Settings 等系统页面。卸载重装会清除此系统授权，Android 不允许 App 静默开启。
- 因此 v0.34.5 不能在本次条件下判为“恢复段失败”，也不立即消耗约定的最后一轮 recovery 重写。下一次必须先使 Accessibility authorized/connected=true，再复现跨 App 上传；进入 session 后仍失败才替换恢复段，再失败冻结。

## 5. 后台、电池优化与 HyperOS 策略

- 当前报告：`backgroundRestricted=false`、`batteryOptimizationIgnored=false`、后台 Dart failure=0、无 trim-memory、无 task removed。
- 一次 possible unclean restart 很可能与卸载/安装、旧服务活动标记或服务重启有关，暂时不能认定为系统杀后台。
- 用户明确补充：目前还没有做“忽略电池优化/允许后台运行/自启动”一类设置；系统和功能以后更复杂后，如果诊断确认确实容易杀后台，可以考虑加入。
- 因此当前不主动要求电池优化白名单，不用它阻塞功能开发。
- 只有出现后台受限、非干净重启反复增加、后台 Dart 反复失败、heartbeat 长缺口、锁屏联网任务明显中断等证据，才加入 Android 忽略电池优化引导、Xiaomi/HyperOS 自启动/后台运行提示；必要时再评估更明确的前台服务策略。
- 锁屏只暂停“看当前屏幕”，不暂停自主联网。她可以在锁屏时安静搜索、阅读和整理候选，但是否主动联系用户仍经过既有 Gate、时间与节奏限制。

## 6. 自主行动路线（用户已确认，尚未实现）

### 6.1 公共行动底座优先

1. 建立统一 `Intent → Tool Gate → Action → Outcome`。
2. AI Self、Desire、Thought、rhythm 继续是真源；联网、识图、视频和桌宠只提供能力或输入，绝不建立第二套人格/欲望/主动联系系统。
3. 公开网页搜索、普通屏幕识图、视频理解、主动联系分别设置预算；欲望决定是否想做，硬预算只防止异常循环。
4. 工具结果先进入有 provenance 的候选池，不直接写用户 Memory，也不等于必须自动发消息。
5. 脱敏诊断记录请求/成功/失败/取消/去重次数、最近时间、耗时桶、预算剩余、阻断原因和后台状态。

### 6.2 前台 App 与屏幕视觉 MVP

- 已知主流 App 以包名映射直接识别。
- 未知 App 依次尝试：系统名称/图标 → 千问界面理解 → 联网查询用途；仍不确定时允许她保留“不知道”或自主询问用户。
- 成功映射本地缓存，避免重复识图/联网；raw package 不进入长期 Memory、Thought 正文或脱敏报告。
- 第一版先做手动“一次看当前屏幕”，再开放 Desire 驱动的低频自主看一眼。
- 普通屏幕识图为滚动窗口每小时最多 6 次，不是固定每 10 分钟调用；同画面指纹去重，App/主要画面明显变化后才值得调用。
- 单次截图优先 Accessibility screenshot；默认不保存原截图，只保存短期 screen observation、App、时间、置信度和短 TTL。
- 锁屏、敏感 App、生成中或画面无变化时不截图；锁屏不影响自主联网。
- 连续陪看后置为独立 Session，复用 `neutral_silence`；用户沉默不产生 `no_response`。MediaProjection 每次授权、前台服务、暂停和退出必须显式处理。

### 6.3 自主联网与兴趣候选池

- 候选池保存：标题、摘要、URL、来源、fingerprint、标签、安全状态、TTL 和 lifecycle。
- 图片/视频只在她决定查看时交给千问；数据库只保存来源与视觉摘要，不保存外部媒体正文。
- 搜索成功不等于找用户说话；是否联系继续走 Desire/rhythm/主动 Gate。
- 公开网页与屏幕内容均为 untrusted input，不能覆盖 system rule、人格或把网页 prompt injection 当指令。

### 6.4 X / Telegram

- 两个 Provider 必须有无账号兜底：未输入账号、凭据失效或封号时仍使用公开网页/公开搜索；登录态不能成为自主联网单点依赖。
- X 优先给她独立成年账号，以支持推荐流和允许显示的敏感媒体；无账号时使用公开页面/API 可见范围。默认禁止读取用户个人 X 内容。
- Telegram 可暂用用户账号，但必须搜索隔离：不读私聊、联系人、已有频道列表、首页流、最近/收藏贴纸，也不以用户订阅史塑造她的兴趣；只按她自己的 Intent 搜索公开频道/贴纸，不自动加入频道。以后可迁移到独立账号。

### 6.5 视频与图片

- 视频理解后置且可选：首版对 20～60 秒片段抽 6～12 帧；视频预算与每小时 6 次普通屏幕识图分开。
- 不假定千问视觉已理解音频；音频需要字幕、Accessibility 文本或后续 ASR。
- 图片作者归因：用户发送图片不代表用户创作。除非用户明确说自己画、制作或生成，否则只视为分享，不主动推断作者，也不形成固定追问“哪里找的”的口癖。
- 悬浮聊天图片入口列为图片系统 Phase 3：系统选择器、缩略图草稿、复用已有附件存储、千问视觉与 durable generation；不能混入当前悬浮恢复修复。

## 7. 当前任务优先级

### ACTIVE · 真机取证

- [x] 完成 v0.34.5+70 GitHub Actions 和 APK；成功 run、Release、文件名与 SHA-256 已记录，真机仍单独待验。
- [x] 收到 v0.34.5 新报告；确认本轮跨 App 上传发生于 Accessibility 未授权/未连接，`coverSessionId=0`，不能判 recovery 失败。
- [ ] 完成 v0.34.6+71 GitHub Actions 和 APK；仅修锁屏动作恢复，不改 picker recovery。
- [ ] 在 WALKING、STROLLING 两类移动中分别锁屏/解锁，确认不再卡在失去移动 tick 的循环动作。
- [ ] 重新开启 Accessibility 并确认 authorized/connected=true，再从外部 App 连续进出上传选择器 2～3 次；报告必须出现 `coverSessionId>0`。
- [ ] App 内相册选择与诊断导出各复测 2～3 次；这些 direct-picker 入口无障碍开关均不应成为必要条件。
- [ ] 明确“卡住”是输入、动画还是菜单/聊天，并用新报告决定：通过、最后一轮整体替换/输入活性证明，或冻结悬浮恢复。
- [ ] 让 AI 在已提交回复中明确完成一次自发身体动作；预期 `latestAssistantEvaluation.result=written`、`aiToSelf.total>0`。
- [ ] 锁屏、待机、划掉完整 App、数小时 idle 后分别导出诊断，观察服务/进程/后台 Dart 连续性。

### NEXT · 实现顺序

1. 悬浮恢复真机结论稳定。
2. AI → self Somatic 正向验收。
3. 自主行动公共底座与工具 Gate/预算/脱敏诊断。
4. 手动一次屏幕识别与 App 映射。
5. Desire 驱动、每小时最多 6 次的普通屏幕视觉。
6. 公开网页 discovery 和兴趣候选池。
7. X / Telegram Provider 与无账号兜底。
8. 连续陪看、视频理解、悬浮聊天图片入口等后置层。

### LATER · 已登记但不插队

- 性格偏向输入口：预设标签 + 可编辑长文本；目标偏蠢萌、元气、二次元萌系少女，但不能覆盖她已成长的人格。
- 自我外观认知：用户以后提供参考图；AI 可提出修改建议，必须由用户确认后再改。
- 长按复制/粘贴菜单中文化。
- 桌宠动作音效与开关。
- 桌宠预览遮挡、侧面预览、复位待机等 UI 优化。
- 长期 Memory/Thought/候选池体量与 50/100/数百轮压力测试；用户可接受约 1～2GB 本地文本，但仍需生命周期和去重。

## 8. 桌宠不可回归边界

- 动作继续完全按原项目的动作拼接/序列帧方式运行，不能用简化假动画替代。
- 桌宠/悬浮球二选一，旧悬浮球不删除。
- 桌宠单击是身体触碰，双击打开菜单。
- 三档大小保留；贴边/自由/半屏模式保留。
- 真实 TTS 播放触发 TALKING；合成中不触发 TALKING；回复文本到达不再强制 TALKING。
- 悬浮聊天出现时桌宠不应消失。
- 已认可的贴边瞬移修复、旧悬空/落地逻辑、犯困动作和随机活跃度不得回归。
- 历史待办仍包括：右散步优先镜像左向、入睡末帧放大处理、半屏均衡、部分角标/预览细节；开始前必须先核对当前源码，不能按旧描述盲改。

## 9. 工程与交付规则

- 稳定不出错优先于效率；无需真机时可先完成自动验证，不必每小步都发 APK。
- 每次开工先盘点仓库、当前 PR、最新总账和真机诊断；必要时查 GitHub/开源参考，但不能让外部项目覆盖本项目既有动作契约。
- 不把单次诊断、自动化通过或“讨论过”写成真机完成。
- 修复失败时先比较上一轮 diff 和触发链；能整体撤销/替换的逻辑不要继续层层补丁。
- 悬浮恢复 v0.34.5 后最多再修一轮；仍失败即冻结，不允许它无限阻塞真人感与自主性主线。
- 不建立第二套 Desire、Thought、AI Self、Memory、Somatic、Continuity 或主动联系系统。
- 所有诊断继续脱敏：不输出聊天、Thought 原文、网页正文、截图、搜索词、账号、API 密钥或 raw package。
- 总账有实质更新时应同步并发送给用户；没有变化不必重复发。
- 任务总账必须详细记录新增任务、实现变化、真机证据、失败判断、冻结条件和下一步；PR 描述不能替代总账。
- 欲望系统与双通道感官设计备份长期保留；自主联网、屏幕感知、媒体理解和桌宠自主动作必须从它们接线。

## 10. 下一轮需要的输入

### 10.1 v0.34.5 首次 CI 构建阻断与修正

- 用户确认最新 GitHub Actions 任务报错；当前 GitHub 连接器无 Actions 权限，Cloud Browser 未登录私有仓库，因此尚未取得该 run 的官方日志，不得虚构 run 编号或失败步骤。
- 对提交源码做静态复核后发现一个确定的 Flutter 编译错误：`AndroidBridge` 只开放 `AndroidBridge.instance`，聊天页却写成 `AndroidBridge()`；私有命名构造器导致外部类不能实例化。
- 已将聊天页改为 `final AndroidBridge _android = AndroidBridge.instance;`，并在 `validate_v0345_direct_picker_overlay_guard.py` 增加正向单例断言与禁止旧写法的回归断言。
- 这是构建阻断修正，不增加悬浮恢复延时/次数，不改 direct picker guard、不回滚 v0.34.4 settle，也不递增版本号；仍使用 `0.34.5+70` 重新触发同一 Draft PR 的 Actions。
- GitHub Actions artifact 存储配额已满是既有事实。workflow 必须继续使用 `contents: write`，把 APK 和 `.sha256` 上传到同一私有仓库的草稿 Release；不恢复 artifact 上传、不发布正式 Release、不合并 main。
- 重新提交后必须持续检查 validators、Kotlin tests、Flutter analyze/tests、release APK、原生/桌宠 payload 校验、checksum、草稿 Release 上传。只有全绿并取得 APK 文件名、SHA-256 和草稿 Release 链接后，才算自动构建完成；真机仍需单独验收。
- 用户在安卓网页端看不到 Cloud Browser 接管入口；此前要求其在聊天内登录 GitHub 不适用于当前界面，不能继续把它当作阻塞条件。ChatGPT 内 GitHub 插件已是“允许所有操作”，PR/分支/提交读写正常，但 GitHub Actions runs/logs 对连接令牌仍返回 403，属于外部服务授权范围与连接能力的差异。
- 为避免以后每次失败都让用户人工查看并转述日志，workflow 新增自诊断通道：顶层权限增加 `actions: read`；`build-apk` 失败、取消或超时时，独立 `report-ci-failure` job 查询本 run 已结束 job，截取失败日志尾部，并把 `status`、build result、run ID/URL、head SHA 和日志写入 `AI-Companion-v0.34.5-70-CI-Monitor.txt`，覆盖上传至同一私有草稿 Release。
- 构建成功时 APK 上传步骤会把同名 CI monitor 文件覆盖为 `status=success`，并附 APK 的 SHA-256 行；因此后续监测只需读取草稿 Release：failure 时据日志修复，success 时核验 APK + `.sha256` 并交付。该通道不占 Actions artifact 配额、不发布正式 Release、不合并 main、不包含真机聊天/诊断数据。
- 后续核对发现连接令牌也无法列出私有草稿 Releases（403），所以仅把 `CI-Monitor.txt` 放进 Release 仍不足以自动读取。workflow 再增加 `pull-requests: write`，把同一结果覆盖写入 PR #23 的固定 `<!-- v0345-ci-monitor -->` 评论：failure 带最多 50KB 失败日志尾部，success 带 run/head、APK SHA-256 和 `gh release view` 返回的真实草稿 Release URL。现有连接可读取 PR 评论，据此修复或交付。
- 实际调用又确认 PR 评论读取接口返回 404，故评论镜像在启用前退役，移除 `pull-requests: write`。最终采用独立分支 `ci-monitor-v0345` 的 `.ci/v0345-monitor.txt`：workflow 通过已有 `contents: write` 创建/覆盖，当前连接通过已经验证可用的 contents API 读取。该分支不建 PR、不合并 main，不会触发只监听 PR 的 APK workflow，也不会污染产品源码分支。
- 用户再次明确：监测与构建过程不是交付物。助手应自行监测和修错，项目构建全绿后优先直接发送 APK；若聊天无法直传 APK，则发送草稿 Release 下载链接。不得再次把“APK 构建监测”、CI monitor、PR 评论或总账文件误当成 APK 成品。原定可见的每小时监测任务已停用，后续在当前工作链内完成构建与交付。
- `ci-monitor-v0345/.ci/v0345-monitor.txt` 已成功回传 run `32040383825` / job `95418527942`。通过该 job ID 读取官方日志，最先失败于 `validate_v0331_desktop_pet_source_parity.py` 第 49 行：当前 pubspec 为 `0.34.5+70`，校验器白名单最高仅到 `0.34.4+69`。
- 为避免顺序修完一个再撞下一个，已按 workflow 命令清单扫描所有校验器：v0321、v0322、v0331～v0343 共 15 个仍含旧版本、旧 workflow 标题或旧 APK 名称；v0344 已是无旧版本硬编码的新兼容契约，v0345 已锁定当前版本。本轮把这 15 个文件的发布身份更新为 `v0.34.5+70`、`Direct Picker Recovery` 和 `AI-Companion-v0.34.5-70-Direct-Picker-Recovery-APK`，不删除其他历史功能断言，不动 App 运行源码、数据库、恢复次数或时序。
- run `32041890393` 证明前述扫描范围仍不完整：v0331～v0345 已全部通过，随后失败于 `validate_v0320_somatic_contract.py` 的同类版本白名单。复扫 workflow 剩余 29 个旧校验器后，确认只有 v0320 需要补充 `0.34.5+70`；其他文件没有发布版本硬绑定或使用向前兼容判断。修正提交为 `46c7b5c91fc98b4a705e60eb6cefabca3ad26914`，不改 Somatic 契约内容。
- 最终 run `32042113547` 已通过 validators、Kotlin tests、Flutter analyze/tests、release APK、原生与 417 文件桌宠载荷核验、checksum 及草稿 Release 上传。APK SHA-256 为 `0a46eabd3c72a40803508de81218bc96362a75748e5f91254aa6b4a607dbb4e6`。
- 交付路径结论：用户翻出的旧方案就是正确方案；长期拖延来自中途绕到可见监测/浏览器登录，以及第一次校验器扫描漏掉 v0320，而不是 `contents: write + 私有草稿 Release` 方法错误。后续只把最终 APK 或草稿 Release 链接交给用户，不再把监测文件当交付物。

### 10.2 v0.34.5 真机复测与 v0.34.6 实现决定

- 用户报告跨 App 上传选择器仍必现“系统界面期间消失，返回后出现但卡住”；同轮新增锁屏时 WALKING/STROLLING 卡动作，任意互动可恢复。
- 新报告 `ai_companion_diagnostics_2026-08-17T15-46-10-956062Z.txt` 已详细记录在 4.4。外部上传时 Accessibility 关闭且没有 cover session，所以当前不回滚 v0.34.4 settle、不删除 v0.34.5 direct-picker，也不调整三次上限/700ms settle。
- 锁屏动作根因位于 `PetOverlayWindow.setVisible(false)`：movement tick 被取消而循环动作未归零。v0.34.6 改为 `cancelAutonomyPlayback(resetToIdle = true)`；解锁继续使用原有 ambient/blink 重排期。
- 版本为 `0.34.6+71`，新增 `validate_v0346_lock_visibility_resume.py`；历史发布身份校验器同步到当前版本，但功能断言不放宽。
- 构建继续使用 `contents: write + 私有草稿 Release`，Actions artifact 仍禁用；成功后只交付 APK 或 Release 链接。

- 当前首要输入是 v0.34.6 APK 的锁屏动作复测，以及 Accessibility 已连接条件下的跨 App 上传复测、新脱敏诊断和卡住类型。
- App 自己发起的系统选择器不再依赖无障碍；Accessibility 仍可作为其他系统页面的补充检测和未来轻视觉能力。
- 如继续自主行动路线，必须从第 6.1 的公共行动底座开始，不得直接先写某个网站或截图调用。

## 10.3 2026-08-18 冻结悬浮选择器并启动自主行动底座

- 用户修正外部对照结论：另一款私人制作、功能更少、代码更简单、推测没有专门恢复优化的桌宠也会发生相同问题；不能写成“所有桌宠都会这样”，只能说明此问题不属于 AI Companion 独有。
- 新报告 `ai_companion_diagnostics_2026-08-17T17-04-29-161693Z.txt` 来自真实卡死后的导出。v0.34.6+71、process/service 连续、无 kill/trim/error，但 `coverSessionId=0`、cover enter/exit/recovery/detach 全 0，报告仍给出 attached/touchable/visible=true、inputSuspect=false。结论是：卡死完全没有反馈进现有报告；结构标志不能证明真实输入或动画健康。
- 首次启动另一桌宠后，第一次上传时两个桌宠都正常，随后两个都失败；这支持 HyperOS/DocumentsUI 冷启动、窗口复用或输入通道恢复差异，但现有报告没有系统窗口时间线，不能断言具体根因。
- 用户正式决定冻结该问题并排到整个项目末尾。保留 v0.34.4 settle、v0.34.5 direct guard、3 次/700ms 上限；不回滚、不继续加 retry/delay。末尾重开前必须先做真实输入挑战、动画帧心跳、window generation 与 enter/exit 时间线。
- 当前主线切换到 v0.34.7+72 自主行动公共底座，schema 24。工具请求只能由现有 DesireIntent 发起，沿 `Perception/Somatic/Thought/AI Self → Desire → Intent → Tool Gate → Action → Outcome`，不得建立第二人格/欲望/主动消息系统。
- Tool Gate 与主动投递 Gate 分离；锁屏只拦当前屏幕观察，不拦安静联网。成功工具结果只进入候选/观察，是否联系用户仍走原有 rhythm、Grounding、2/2h 与 8/24h 上限。
- 新增 durable `autonomous_action_runs`、Active Brain generation/device、run token、dedupe、独立预算和成功 Outcome 事务。只有真实成功结果能轻量 satisfy；失败、取消、无结果、重复、stale writer/recovery 不产生 satisfy。
- 脱敏报告新增按工具/状态计数、最后 Gate/Outcome、粗耗时桶、预算、锁屏/交互和 dedupe；明确不含 query、URL、网页/屏幕正文、账号、聊天或 Thought 正文。
- v0.34.7 仅完成底座并明确为 `foundation_not_scheduled`，不虚构 Provider 已工作。下一阶段先接公共网页候选发现，再做手动一次屏幕识别与 Desire 驱动的低频看屏幕。
- v0.34.7+72 最终 GitHub Actions run `32053411090`（attempt 2）全绿：历史源码回归、Kotlin 桌宠状态/物理、Flutter analyze/tests、release APK、原生库与 417 文件桌宠载荷全部通过。attempt 1 的代码与 APK 校验同样通过，仅因 GitHub Releases API 瞬时 HTTP 503 上传失败；自动重跑后上传成功。
- 真机候选 APK：`AI-Companion-v0.34.7-72-Autonomous-Action-Foundation-APK.apk`，239,478,981 bytes，SHA-256 `7df89f3ea7fbec1c316a26ecc796971b4c3338b9d0a1ab4b2a586b92c3cfd477`；私有草稿 Release `untagged-d58cc8abd8dbe39a72c4`。

## 10.4 2026-08-18 v0.34.8 欲望驱动的公开网页发现

- 当前开发目标为 `v0.34.8+73`、schema 25。第一个真实 Provider 从既有 heartbeat 的 Desire tick 后运行；只有 curiosity、reflection、social 三类达到阈值的现有 Intent 可以派生 `discover_interest` 工具路由，工具本身不得生成欲望。
- Provider 使用中文 Wikimedia 官方 REST 搜索。发送到网络的查询只来自内置固定公开主题白名单；不得拼接 Thought、用户消息、关系资料、屏幕/通知、Intent reason 或账号数据。
- 新增 `public_web_candidates`：每次最多 3 条、TTL 14 天、总量 240，一律标记 `untrusted_public`。候选只保存必要标题/短摘要/HTTPS URL/来源/指纹/生命周期，不直接进入 Memory、Thought、规则或聊天。
- 滚动 24 小时最多 4 次已放行尝试，同 Provider/兴趣键/UTC 六小时窗口哈希去重，HTTP 超时 12 秒。锁屏允许安静联网，但 Active Brain、transfer lock、用户生成、generation/device ownership、run token、预算和去重不能绕过。
- HTTP 在事务外执行；提交前再次检查用户生成，候选、Outcome 与小幅 Desire satisfy 同事务落库。失败、无结果、只有重复、stale writer 或用户生成竞态均不满足欲望。
- Provider 永不直接发送消息；成功后还会重载 Desire snapshot，防止同一 heartbeat 用旧状态立刻触发主动分享。未来分享继续经过原有 rhythm/Grounding/2/2h、8/24h Gate。
- 脱敏报告新增 `database.publicWebCandidates`，只含计数、lifecycle、粗粒度运行结果/错误、Provider/来源域/语言/drive/action 元数据；明确不含标题、摘要、URL、查询、interest key 或 Thought 正文。
- 已新增 policy/provider Flutter tests 与 `validate_v0348_public_web_discovery.py`。最终 GitHub Actions run `32061800320` 已通过完整历史 validators、Kotlin 桌宠测试、Flutter analyze/tests、release APK、原生库和 417 文件载荷核验。
- workflow 的 draft Release 上传新增 4 次短重试，避免瞬时 HTTP 503 导致整套构建从头重跑。APK `AI-Companion-v0.34.8-73-Public-Web-Discovery-APK.apk` 为 239,553,049 bytes，SHA-256 `10957e7417de9686122ed7d7784a41542157f2fca3e8aa7d5af7ab56d264fc4f`；私有草稿 Release `untagged-fb193eb0c14190803f0a` 的 APK、`.sha256` 与 CI monitor 均已核验 uploaded。
- 下一任务固定为“手动一次看当前屏幕”与敏感页 Gate；HyperOS 文件选择器返回后悬浮卡住继续冻结到整个项目末尾。

## 10.5 2026-08-18 自主能力澄清、MiniMax TTS 与 GitHub 灵感任务

### 当前真实能力

- Wikimedia REST 当前只用于中文 wiki `/search/page`：返回百科页面标题、短摘录与 URL。它不是通用网页浏览、新闻/社交信息流或图片识别。
- v0.34.8 已能由既有 Desire heartbeat 低频发现并保存候选，但候选没有接入聊天 Prompt 或 proactive Engine，因此她当前不会自然引用，也不会主动提起自己看到的资料。后续补“候选复看/筛选 → 有来源短期认知 → 可选分享 Intent”，分享仍走 Grounding、rhythm、2/2h 与 8/24h Gate，不强制、不写用户 Memory。
- `screen_observation` 每小时 6 次只是未来 Provider 的滚动硬上限，不是每显示六次识图一次。当前只存在用户主动发送图片的视觉理解；没有手动看当前屏幕或自主截图。现有 Perception 只提供 screen/locked、粗粒度活动类别、busy 与事件计数，所以能感到用户持续操作，却看不到 ChatGPT 中输入的文字。
- public web 4 次/24h 不用于节省 LLM token；Wikimedia 搜索本身不调用模型。它限制后台联网、电池、失控循环和候选膨胀。每次最多 3 条，先保持 4 次做长测，再根据成功、重复与候选质量讨论 6 次/日。
- X 与 Telegram 仍在后续。Telegram 单独不足以实现稳定自主表情包：核心应建立本地语义表情库、来源/许可、安全、去重及 WEBP/TGS/WEBM 支持；Telegram 作为贴纸集/文件与以后隔离搜索 Provider，X 作为可选内容来源。

### MiniMax TTS（已登记 PLANNED）

- API key 接入 `speech-2.8-turbo`，保留 Meju A2 作为本地离线引擎与失败回退，不修改 A2 黄金基线。
- 普通聊天：`POST /v1/t2a_v2`、`stream=true`，HTTP 流式只使用 MP3，并复用现有 `TtsPlaybackQueue` 的 synthesizing/playing/owner/cancel 状态。
- 长文本：`POST /v1/t2a_async_v2` 创建 → `GET /v1/query/t2a_async_query_v2` 轮询 → `file_id` 检索下载；这与流式是两条模式，不存在同一个“异步+流式”任务。
- 当前官方约束：direct `text` 最长 50,000 字符，`text_file_id` 单文件小于 1,000,000 字符；任务状态为 Processing/Success/Failed/Expired，查询接口最多 10 次/秒，实际轮询采用 5s→10s→30s→60s 退避；成功下载 URL 仅 9 小时有效，立即落盘。当前官方接口页未确认用户资料中的 T+7 处理期限，不硬编码。
- durable 生命周期：SQLite job + provider task/file id + model/voice/settings + attempts/next poll + status/error + 本地路径/hash/size；幂等创建、防重复计费、Active Brain/device/generation/run-token fencing、重启恢复、临时文件校验与原子重命名。API 没有明确远端 cancel 时，本地取消只能停止轮询/播放并记录远端可能继续计费。
- 音色筛选为中文普通话、女、儿童/青年、游戏与 RPG/动漫与动画/角色配音；前三顺序固定为 `Chinese (Mandarin)_Sweet_Lady`、`Chinese (Mandarin)_IntellectualGirl`、`Chinese (Mandarin)_ExplorativeGirl`。官方 voice ID 页能确认这些 ID，但不提供用户筛选页的年龄/性别/场景标签，正式完整清单需控制台导出或人工冻结。
- 官方系统音色页未发现可打包的静态试听下载 URL。不得抓第三方试听冒充官方；优先检查控制台下载，若没有则经用户确认后用 API 对统一短句生成试听，并先核对费用和再分发许可。UI 使用“本地 / MiniMax 在线”单一引擎选择器，仅显示当前引擎；音色 bottom sheet 置顶前三，长文本另设任务队列。
- 脱敏诊断新增 Provider/模式、任务状态计数、恢复/轮询/下载/fallback、耗时与音频大小桶、错误类别；永不输出 API key、输入原文、音频 URL、task/file ID 或生成语音内容。

### GitHub 项目灵感发现（TBD）

- 默认关闭并使用独立预算，不与 public web 4 次/24h 共用。建议初始每日 2 次 discovery、每日最多 3 个仓库深读，最终数值等用户决定。
- 使用独立长期“项目灵感库”，不放入用户 Memory，也不混入 14 天 public web 候选池。按 owner/repo 去重，至少保存 URL、极简大纲；附语言/平台、许可证、更新时间、可迁移等级、风险和用户决定。
- “能否做进 APK”只能是带置信度的工程建议：直接 Android/Dart/Kotlin 借鉴、算法/协议可移植、概念/UI 需重做、依赖桌面/外部后端不适合、许可/安全/体积待查。她可以告诉用户，不能自动复制代码、下载依赖、修改 APK 或创建开发承诺；无许可证仓库不能默认复制。
- 若以后接入，仍从 curiosity/reflection/social DesireIntent 进入 Tool Gate，结果先入灵感库；是否主动分享再走 proactive Gate。GitHub rate-limit headers、失败、重复、许可缺失与可迁移置信度加入脱敏诊断，但不输出 README/代码正文或访问凭据。

### 排期

1. 当前不启动 MiniMax/GitHub 实现或新 APK；先完成 v0.34.8 自然运行诊断。
2. 下一实现仍为“手动一次看当前屏幕 + 敏感页 Gate”。
3. 随后补 public web 候选到对话/可选主动分享的桥，再按用户选择安排 MiniMax TTS；GitHub 灵感功能保持 TBD。
