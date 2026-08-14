# AI Companion · 接班总账 v15

更新时间：2026-08-14（Asia/Tokyo）

> 本文件是当前完整接班入口。判断优先级：用户最新明确决定 > GitHub `main` 实际源码与 Actions > 最新脱敏真机诊断 > 仓库 HANDOFF/任务账 > 历史对话与参考图。讨论或设计不得写成已实现。

## 0. 正式开工：Clean Freeze 结果

- 已完成正式开工盘点，并在独立分支 `agent/v0315-clean-freeze` 提交 Clean Freeze；未直接改动 `main`。
- Clean Freeze 只整理仓库结构、构建入口和接班文档，未改 Dart/Kotlin/SQLite 产品逻辑。
- `app/` 被确认为唯一产品源码真源；根目录 11 份已应用 patch、2 份历史文档 ZIP 与一次性 apply workflow 已从候选分支移除，Git 历史仍可恢复。
- 新 workflow 从当前 `app/` 直接执行 validators、`flutter analyze`、`flutter test`、release APK 与原生资源校验；权限降为 `contents: read`，不再在构建时 apply 或 push。
- 发现旧 workflow 曾内嵌测试 `debug.keystore`。新 workflow 不复制 key 或旧指纹，改为要求 Secrets `AI_COMPANION_DEBUG_KEYSTORE_B64` 与 `AI_COMPANION_DEBUG_KEYSTORE_SHA256`。
- 签名策略等待用户决定：推荐轮换测试 key（现有 APK 需卸载一次）；若为了当前覆盖安装继续使用旧开发 key，只能作为已知暴露的私人测试兼容方案，绝不能用于正式发布。
- 规则归并被定为 Clean Freeze 后第一项代码任务。开源参考优先采用 sqflite 官方迁移范式：最新版 schema 在 `onCreate` 建全量结构，`onUpgrade` 按旧版本条件迁移并回归重复升级。
- 当前规则归并建议是“语义/UI 分组而非破坏性拼接”：保留 `01_core`、`01_relationship`、`03_behavior`、`03_personality_seed` 各自数据库内容与编辑/锁定属性，仅在 UI 与 Prompt 层归为两个同类组，避免覆盖用户原文。
- 本次候选分支会以草稿 PR 交付；在合并前不启动规则 schema 改动，避免把清理和功能开发混为一项。

## 0A. 上一轮对接结果

- GitHub 私有仓库可正常读取；上一轮只做审计，没有修改、提交或推送项目源码。
- 真机版本已确认是 `v0.31.5+47`，不是遗留显示错误；与 GitHub 当前基线一致，暂时不需要 APK。
- 两套欲望系统图片不是重复：一套为通用设计，一套为参考工程接线记录。已合并整理并完成当前源码审计。
- 欲望核心可继续标为“主要闭环已完成/维护中”；自主联网、双通道感官和屏幕陪伴是未来接入，不是要重写核心。
- 双通道感官 7 页已转成完整可编辑方案；当前仓库尚未实现。
- 屏幕陪伴补充硬规则：用户沉默是共同观看的正常状态，不得记为拒绝、冷落或 `no_response`。
- macOS DeskPet 的缺素材并非“因为 macOS 才找不到”，而是皮肤外置且未随主仓库完整分发；Android 可从原理自行实现。
- 规则整理不强求固定“六大”。当前两个 01 可合并，两个 03 也可按同类归并；目标是职责清晰、以后同类直接增补且不覆盖用户原文。
- 项目定位固定为男性向 AI 女友；女性向参考可借机制，默认人设、语料和表现必须重新设计。
- 今后每次实际完成任务都同步更新总账并交付；大阶段结束执行一次 Clean Freeze。

## 1. 当前事实基线

### 1.1 GitHub

- 私有仓库：`catkiss62/ai-companion-build`
- 分支：`main`
- 源码真源：`app/`
- commit：`0d7721349f835ad334dbb702d9adf7b0974d0175`
- 应用：`v0.31.5+47 · Live Context & Self Seed`
- SQLite schema：20
- GitHub Actions：run #31 成功，analyze、tests、release APK 与版本写回均完成。
- `main` 仍保留历史补丁与一次性 workflow；Clean Freeze 候选分支已完成清理，待草稿 PR 审核/合并。

### 1.2 真机脱敏诊断

诊断文件：`ai_companion_diagnostics_2026-08-14T11-36-21-549813Z.txt`

- app：versionName `0.31.5`，versionCode `47`，package `com.aicompanion.localfirst`。
- Android 15 / SDK 35 / Xiaomi `25060RK16C`。
- schema 20；Active Brain=true；transfer lock=false。
- pending generation/outbound/import 均无阻塞，后台/生成/维护/TTS 记录无 error。
- currentContext 可用，prompt user turn 刷新正常，且 `desireAdvancedByRefresh=false`。
- Overlay 当前附着、可见、可触摸；这不推翻“文件选择器后卡死/部分游戏消失”的冻结复现问题。
- Accessibility 未授权；Notification Listener 权限已授予但诊断时连接状态为 false。
- Nearby 权限未完成；以后做手机/平板接管前处理。
- 未忽略电池优化，Xiaomi 长期保活仍需真机观察。
- TTS 核心资源存在，但本次是浅诊断，尚未初始化和黄金校验；不代表 TTS 坏了。

### 1.3 是否需要 APK

现在不需要。只有在以下情况再请用户提供：

- GitHub 版本与手机版本重新不一致；
- 需要反编译确认构建产物是否包含某项资源；
- 源码无法复现真机行为；
- 要对比旧包与新包回归。

## 2. 用户长期协作约定

1. 每次有实际任务成果时，同步更新完整总账并作为文件交付；纯讨论可不新发。
2. 设计复杂功能时可另建独立方案文件，总账只保留结论、状态、入口和依赖。
3. 项目未完全做完前，用户暂不自行修改规则；后续同类规则允许直接增补到原分类，不再为防覆盖无限拆卡。
4. 合并规则时完整保留用户原意；消重只能消除真正同义句，不能删语义。
5. 每完成一个大阶段，由执行者判断是否到 Clean Freeze 点；清理前列出精确文件，删除需用户确认。
6. 男性向 AI 女友是产品主方向；参考机制可以跨性别借鉴，角色表达不可简单换代词照搬。

## 3. 任务总表

| 优先级 | 状态 | 任务 | 当前结论 |
|---|---|---|---|
| — | CANCELLED | 女友感/伴侣化按钮 | 用户用规则层解决，不再复活按钮或固定甜蜜层 |
| — | FROZEN | 文件选择器后 Overlay 卡死 | 以后按独立故障专题复现 |
| — | FROZEN | 游戏/全屏中 Overlay 消失 | 与系统限制、目标 App 策略分开调查 |
| — | FROZEN | TTS 轻微断句/遗留 | Meju A2 可用，暂不扩修 |
| P0 | DESIGN/TODO | 规则分类合并 | 两个 01 合并；两个 03 按同类归并；不强求正好六类 |
| P0 | TODO | 大阶段 Clean Freeze | 建议正式新功能前先做一次精确盘点；删除仍需确认 |
| P1 | TODO | 真正停止生成 | 当前 stop 只停 TTS，模型流与 durable recovery 尚未统一取消 |
| P1 | DESIGN | 双通道感官 | 完整方案已成文，源码未实现 |
| P1 | TODO | 消息提示音 | 多音色、试听、音量、震动、前台/TTS 策略 |
| P1 | TODO | 表情包系统 | 标签注册、安全选图、多气泡契约 |
| P1 | TODO | 长期记忆/活人感增强 | 证据化、事务化、冲突/归档，不建第二数据库 |
| P1 | TODO | 主动上网与分享 | curiosity 驱动、候选池、来源、TTL、每日上限 |
| P2 | RESEARCH/DESIGN | Android 桌宠 | 原理可重做；方案已成文，资产与许可待锁定 |
| P2 | TODO | UI 优化 | 先信息架构与设计系统，再分页面 |
| P3 | DESIGN | 屏幕陪伴 | 一次分析/自动陪看；文字/文字+语音；沉默中性 |
| — | COMPLETED/MAINTENANCE | 欲望核心 | 8 Drive 到主动闭环已实现；做回归，不另建一套 |

## 4. 规则层整理

### 4.1 两个 01

- `01_core`：她是谁、持续存在、自主性、成年人边界、优先级。
- `01_relationship`：双方性别、恋人身份、不是客服/仆人、可拒绝和不同意、角色扮演不覆盖长期身份。
- 判断：同级且高度同类，合并为“身份、存在与关系基础”。
- 要求：两部分原文全保留；只整理结构和真正重复句。

### 4.2 两个 03

- `03_behavior`：长期常驻的行为真实感。
- `03_personality_seed`：新建时的初始性格底色，会被 AI Self 与共同经历慢慢细化。
- 判断：都属于“行为/人格表现”，可归到同一大类；但一个是硬行为原则，一个是可成长/可编辑的种子，语义层级不同。
- 推荐：UI 显示为一个“行为与人格”分类，内部保留“常驻行为原则”和“初始人格种子”两个小节及各自元数据。若当前架构不支持小节级开关，后端先保留两条记录、前端分组展示，不能为减少卡片而丢掉启用/编辑语义。

### 4.3 分类数

- 不强求 6 张卡。
- 分类只服务于理解、维护和安全迁移。
- 以后新增内容若已有同类，直接加入同类小节；只有职责、加载时机或权限真正不同才新建分类。

### 4.4 迁移验收

- schema 建议升 21，并做幂等迁移。
- 合并前读取当前数据库文本，不能用默认模板覆盖用户修改。
- 旧 key 迁移到新 category/section 后保留来源记录或 migration marker。
- 升级、重复启动、旧备份导入、跨设备转移都不重复追加或丢失。
- Prompt 中同一语义只加载一次；UI 不再出现重复编号。

## 5. 男性向 AI 女友产品过滤

### 5.1 核心体验

- 甜蜜只是状态之一，还要有好奇、专注、主见、调侃、能力感、犯懒、反差和安静共处。
- 自主性不等于随机拒绝；靠近、不同意、玩笑或拒绝都应来自 AI Self、欲望、历史和语境。
- 不把她做成客服、仆人、恋爱反馈器或永远等待用户的角色。
- 不甜腻不等于冷淡、羞辱、惩罚或故意制造冲突。

### 5.2 女性向参考的处理

可借机制：记忆证据、主动联系时机、工具调用、状态衰减、边界、冲突修复、测试。

必须重做表达：称谓、安慰、浪漫频率、保护/占有脚本、追逐、依赖、亲密邀请、强弱关系。

应删除：无条件赞同、句句甜言蜜语、把顺从当爱、固定霸总/保护者或娇弱/服侍模板、所有主动消息都变成想念。

## 6. 欲望系统

详细文件：`AI_Companion_欲望系统设计与实现审计_v1.md`

### 6.1 图片归并

- 8 月 10 日资料：通用设计。
- 8 月 12 日资料：参考工程的具体实现记录。
- 二者互补，不是重复；文件名相同不代表内容相同。

### 6.2 当前已实现

- 8 Drive、current/baseline/anchor、时间推进与有界耦合。
- Thought 来源、flit/fixation/acted/residual/dormant、合并、延后与浮现。
- Intent、action-aware satisfy、per-drive refractory。
- fatigue rest gate、Intimacy Session gate、grounded duty、真实 wildcard。
- Self Drive、Presence、主动 Heartbeat、节奏学习、Reality Grounding、Active Brain lease。
- 诊断已观察到真实 Drive/Thought/Intent 状态，且无错误。

### 6.3 未实现但不应重写核心

- `web_search/web_browse/github/co_read` 等真实工具执行链。
- 双通道感官输入与自反馈。
- 屏幕陪伴专用 session 与沉默中性反馈。
- 梦境与游戏化不是当前必做，不为对齐参考而添加。

### 6.4 普通主动消息与屏幕陪伴的区别

普通主动消息超时会形成低权重 `no_response`，当前已做低可靠度和阈值恢复，合理。

屏幕陪伴中必须设置：

- `expects_user_reply=false`
- `feedback_policy=neutral_silence`
- `conversation_mode=co_presence`

不得创建/过期成 `no_response`，不得降低话题兴趣，不得追问用户为什么不回复。

## 7. 双通道感官

详细文件：`AI_Companion_双通道感官设计_图片转写_v1.md`

### 7.1 定义

- 通道方向 1：用户文本中的动作/感官 → 她，全强度。
- 通道方向 2：她成功提交的自身动作 → 她自己，较弱回响。
- 感官类别：touch / smell / taste / sound；未来可扩 visual / body_state。

### 7.2 当前状态

- 7 页截图已完整转写、结构化并适配当前项目。
- GitHub main 尚无 somatic 模块、SQLite 表与测试，状态仍是 DESIGN。

### 7.3 接入边界

- SQLite 是唯一状态真源，不复制 Python/JSON 第二系统。
- assistant 自反馈只在消息与 generation completed 原子提交后发生。
- 失败、取消、重试未提交、stale writer 不回响。
- `turn_id + direction + scene_key` 幂等。
- 感官短期衰减；高于阈值才注入 Prompt；模型感受而不报数。
- 可给 Desire/Thought 小幅 pulse，不能绕过主动 Gate 或 Intimacy Session。
- 日常与私密 corpus 分离；外部台词不直接成为核心或用户记忆。

### 7.4 实施顺序

1. SQLite event/aggregate contract + 纯函数测试。
2. 日常触觉 user-to-AI MVP。
3. 成功提交后的 AI-to-self 弱回响。
4. smell/taste/sound。
5. 可替换 corpus 与 Proust 记忆候选。
6. 私密扩展最后单独做权限、数据与测试。

## 8. 屏幕陪伴

### 8.1 功能形态

- 触发：点一次“看一下当前屏幕”；或开启一段低频/变化触发的自动陪看。
- 输出：纯文本；或文本+语音。
- 共同观看允许长时间安静，`WAIT` 是健康结果。
- 用户临时发言才形成真实 user turn；回答后回到共同观看。

### 8.2 技术路线

- 首版：Accessibility 结构化文本 + 用户点一次理解当前页面。
- 连续会话：MediaProjection，用户每次明确授权，专用 foreground service 与持续通知。
- 低分辨率、变化检测、去重、敏感遮罩；不是 30–60fps 视频流。
- 没有视觉模型时只做本地 OCR/无障碍摘要，不假装看见像素。

### 8.3 隐私红线

- 原始截图默认不落盘、不进记忆、不跨设备。
- 密码、验证码、银行、支付、私密相册暂停/遮罩。
- App 黑名单或仅允许选定 App。
- 桌宠/overlay 不反复截入造成视觉回音。
- 会话结束立即停止捕捉并清理临时上下文。

## 9. Android 桌宠

详细文件：`AI_Companion_Android桌宠方案_v1.md`

### 9.1 DeskPet 判断

- 参考 URL：<https://github.com/2048Nemo/DeskPet>
- macOS/Swift/PNG 序列帧/GPLv3。
- 皮肤通常来自用户外部目录，公开仓库没有完整内置动作帧包；这才是素材缺失主因。
- 当前主分支未发现 Live2D；如用户看到特定分支/Release/皮肤，请以后提供确切链接。

### 9.2 Android 采用方案

- 从零实现 Kotlin `WindowManager`/自定义 View 帧播放器与状态机。
- 优先复用现有 Overlay 前台服务和聊天入口，动画层与聊天层解耦。
- 桌宠只表现现有 AI Self/Desire/Thought/TTS，不建第二人格。
- 首版做 PNG/WebP、idle/walk/drag/fall/home/sleep/speak、点击聊天、尺寸/频率/音效与省电。
- Live2D、多宠物和复杂物理后置。
- 资产先用自制占位或明确授权包；逐文件记录许可。

### 9.3 辅参考 URL

- Android Shimeji/Padorus：<https://github.com/hushino/akimeji-shimeji-and-padorus>
- Codex Android Pet：<https://github.com/lirenzhiling/codex-android-pet>
- GooseDroid：<https://github.com/skyvanguard/GooseDroid>

其中 GooseDroid 为 all-rights-reserved，只借概念；Akimeji 的独立 LICENSE 尚待确认。

## 10. 其他既定功能

### 10.1 真正停止生成

当前全屏与 Overlay 的停止最终只调用 TTS stop。以后需统一：

- cancel token/作废标记；晚到 token 丢弃。
- `cancelled_by_user` 明确状态。
- durable recovery 不复活用户取消 turn。
- 全屏、Overlay、TTS 共用一次取消语义。

### 10.2 消息提示音

- 5–8 个短柔和音效；开关、试听、选择、音量、震动。
- 前台当前会话可静音；主动消息可后续分音色。
- 避免与 TTS 叠加。
- 每个音频记录来源、作者、许可、修改。

参考：

- <https://github.com/akx/Notifications>
- <https://github.com/Calinou/kenney-ui-audio>

### 10.3 表情包与活人感

- 标签注册：资源 ID、包、emoji、语义、情绪。
- 模型提出结构化 `send_sticker(tag)`，传输层安全选图。
- 多气泡用结构化段落，不让分隔符污染 TTS/记忆。
- 活人感来自连续话题、个人兴趣、消息节奏、能力与安静，不等于更频繁说想你。

参考 MochiBot：<https://github.com/shikidmsh-rgb/mochibot>

### 10.4 主动联网

- 兴趣来源：AI Self、curiosity、共同话题、用户订阅。
- 候选池只存标题、摘要、URL、域名、时间、TTL、标签、安全标记。
- 是否分享仍由 Desire/Thought/Intent/Gate 决定。
- 网页不直接进入用户记忆；共同讨论后才可能形成关系记忆。
- 开关、Wi-Fi、每日上限、安静时段、主题/域名黑名单、来源可见。

工具/调度参考：

- Jossie2：<https://github.com/robinp7720/Jossie2>
- Revive Companion：<https://github.com/pearthink123/revive-companion>
- AIRI：<https://github.com/moeru-ai/airi>

## 11. Overlay 冻结边界

仍冻结：

- 文件选择器返回后悬浮球可见但不可点。
- 某些游戏、全屏或沉浸模式中悬浮球消失。

以后按顺序调查：窗口被系统遮蔽、触摸区域、服务生命周期、权限、HyperOS 游戏模式、`HIDE_OVERLAY_WINDOWS`、全屏沉浸。诊断的一次健康快照不能证明这些偶发路径已修复。

桌宠不是自动修复；D2 Overlay MVP 必须复测这些路径。

## 12. Clean Freeze

### 12.1 当前建议

在下一项正式源码任务前先做一次只读精确盘点，然后决定：

- 现在整理 +47；或
- 先完成“规则合并 + 停止生成”再一起 Freeze。

若补丁已经明显影响理解，倾向先整理；但删除文件前必须给用户清单。

### 12.2 固定流程

1. 核对所有已应用改动都存在于 `app/`。
2. 干净 checkout 仅凭 `app/` 运行 analyze、tests、release build。
3. 核对版本、schema、迁移和回滚。
4. 一次性 apply workflow 恢复为常规构建 workflow。
5. 已应用补丁记录 SHA、归档；列清单后再删除冗余副本。
6. 更新 HANDOFF、项目任务账、本总账、真机待测和已知问题。
7. 记录 commit、Actions、APK 与测试结果。

## 13. 下一步建议顺序

1. 正式任务开场先精确盘点根目录补丁与 workflow，决定 Clean Freeze 时点。
2. 实施规则分类整理：两个 01、两个 03；schema21 幂等迁移，不覆盖用户内容。
3. 实现真正停止生成，和规则整理一起做测试/构建后阶段冻结。
4. 消息提示音作为小而独立功能。
5. 设计表情包、多气泡、主动联网的共同消息/工具契约。
6. 双通道感官先建 SQLite/event contract，再做日常触觉 MVP。
7. Android 桌宠先锁定许可资产并做 Activity 内隔离播放器，再接 Overlay。
8. 屏幕陪伴先做“一次看当前屏幕”，验证价值和隐私后再做连续会话。

## 14. 仍缺但不阻塞的资料

- 双通道原始 Markdown：`sense_dual_channel_public_intro.md`。
- 欲望原始 Markdown：`desire_public_for_ai.md`。
- 原资料提到的 `sense_corpus_scenes.md`、`sense_corpus_buckets.md`、mood/circadian 设计文件。
- 用户喜欢的具体桌宠皮肤/Live2D/视频/Release 链接与授权。
- Accessibility 真机授权后的深度诊断（到屏幕感知阶段再要）。
- APK：当前不需要。

## 15. 本轮交付文件

- `AI_Companion_接班总账_v15_2026-08-14.md`
- `AI_Companion_双通道感官设计_图片转写_v1.md`
- `AI_Companion_欲望系统设计与实现审计_v1.md`
- `AI_Companion_Android桌宠方案_v1.md`
- `AI_Companion_对接资料备份_2026-08-14.zip`

## 16. 每轮接班固定模板

以后总账至少记录：

1. 仓库、分支、版本、schema、commit、Actions/APK。
2. 用户本轮决定与产品定位变化。
3. 实际修改文件和行为差异。
4. 数据库、权限、API、隐私变化。
5. 自动测试、构建和真机待测。
6. 已知问题与不要重复的失败路线。
7. 参考 URL、许可、采用/不采用理由。
8. 欲望/感官/记忆/联网/桌宠之间的边界。
9. 下一步与最少仍需资料。
10. 是否到 Clean Freeze 点。

不把“讨论过”写成“完成”，不把“有方案”写成“已进源码”，不依赖单一聊天窗口保存项目事实。


