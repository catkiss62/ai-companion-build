# AI Companion · 接班总账 v21

更新时间：2026-08-15（Asia/Tokyo）

> 本文件继承并取代 `AI_Companion_接班总账_v20_2026-08-15.md`。判断优先级固定为：用户最新明确决定 > GitHub `main` 实际源码与 Actions > 最新脱敏真机诊断 > 仓库 HANDOFF/任务账 > 历史对话与参考资料。讨论、设计、真机线索不得写成已实现功能。

## 0. 本轮结论

- 用户已按标准触觉语句完成真机验证。新诊断中 `somatic_events=1`、`active_somatic_channels=1`，证明 v0.32.0 的 `user_to_ai` 日常触觉检测、SQLite 写入和活跃聚合至少成功命中过一次。
- 用户观察到模型原生思考过程出现与身体感觉一致的内容；这与 Somatic Prompt 注入一致。但脱敏诊断不包含 reasoning 正文，且第一阶段没有直接给 Desire 脉冲，因此不能把 `self_experience` Thought 单独当作感官到欲望的严格因果证据。
- 用户正式批准新增“兴趣候选库”任务：她可以因自身兴趣记录标题、摘要、来源和 URL，之后在有自主意愿时重新翻阅或主动提起；不能把抓到的网页一股脑塞入长期记忆。
- 新增架构原则：**Desire / Thought / Intent / Gate 是活人感的行为调度主干（Motivational Spine）**。感知、记忆、联网、桌宠、屏幕陪伴等模块提供“她知道什么、感到什么、能做什么”，是否以及何时行动统一回到欲望主干；各模块不得自行绕过 Gate 强制发言。
- 新诊断同时捕捉到一次 Overlay 系统界面恢复异常：`bubbleAttached=false`、`bubbleTouchable=false`、`inputSuspect=true`、`selfHealCount=13`、`coverState=recovery_scheduled`。这是此前冻结的文件选择器/系统界面后悬浮球异常的新增证据，与感官功能无关，本轮不扩修。
- 本轮只完成诊断审计、架构决定和总账更新，不修改 App 功能代码、不升级版本、不生成 APK。

## 1. 当前事实基线

### 1.1 GitHub / 构建

- 私有仓库：`catkiss62/ai-companion-build`
- 默认分支：`main`
- 源码唯一真源：`app/`
- 当前产品代码基线：`58a77cdaa2ec3d236dc4e083f28385ba4f36b1ef`；其后 PR #7 仅合并本轮文档，未改变 App 行为。
- 当前 App：`v0.32.0+52 · Somatic Contract & Daily Touch MVP`
- SQLite schema：`21`
- 双感官第一阶段 PR：#6，已合并。
- 最终 Actions：run #26，ID `31830858189`，通过 validators、Flutter analyze/tests、release APK/Kotlin 与冻结 Meju A2 payload 校验。
- Artifact：`9230919832`
- APK SHA-256：`82d57aaf58284e47ad6213537e7590dcc5e3ae94f159384f19fb6169a99d0e0c`
- Clean Freeze、规则维护分组、完整 App 真停止、悬浮框近手停止/真实双流、语音三态和取消轮撤回均已进入 `main`。
- 仓库根目录不再使用历史 patch/ZIP 作为构建输入；常规 workflow 只验证和构建已提交的 `app/`。

### 1.2 最新脱敏真机诊断

文件：`ai_companion_diagnostics_2026-08-14T20-32-52-428317Z(1).txt`

- 报告正文 Native 版本为 `0.32.0+52`，schema 21；首行仍硬编码 `v0.31.5+47`，属于诊断显示遗留，不是装错版本。
- Android 15 / SDK 35 / Xiaomi `25060RK16C`；Active Brain=true，transfer lock=false。
- 7 个 post-turn job 均完成；pending/failed generation 与 post-turn job 均为 0；后台、生成恢复、异步 worker、维护、Continuity、TTS 无 error flag。
- Memory：3 条，evidence 4 条，summary 1 条。自动记忆/证据链已产生真实数据。
- Thought：7 条；当前 active 5 条；provenance 包含 awareness 1、user_message 3、self_experience 1。
- Somatic：事件 1、活跃 channel 1，完成第一次真机命中证据。
- Awareness：perceptions 6、observations 4；Prompt 前即时上下文刷新正常，`desireAdvancedByRefresh=false`。
- 欲望选中 reflection / `share_thought`，reason source 为 `self_experience`；这是当前内在状态事实，不等同于证明该 Thought 由 Somatic 直接写入。
- Overlay 在系统 cover 退出后的快照当下未附着/不可触摸，bounded recovery 已到第 3 次尝试并再次排队；需以后按冻结专题复现。
- Accessibility、Usage、Notification Listener、Overlay 权限均已授权/连接；Nearby 权限仍不完整；未忽略 Xiaomi 电池优化。
- TTS 为浅诊断，资源存在但未初始化/未跑黄金校验，不表示异常。

## 2. 用户长期协作与产品决定

1. 每次有实际任务成果，同步更新完整接班总账并作为文件交付；纯讨论可不新发。
2. 复杂系统另建详细设计文档，总账保留事实、状态、边界、入口和依赖。
3. 每完成一个大阶段判断是否进行 Clean Freeze；删除冗余补丁前列出精确清单，Git 历史保留恢复路径。
4. 半成品测试阶段不保留真实存档，用户允许卸载重装；进入真实长期使用前必须启用稳定 release signing 和升级/备份验收。
5. 项目定位为男性向 AI 女友；机制可跨类型借鉴，但不能照搬女性向固定甜宠、保护者/霸总或无条件顺从模板。
6. 规则分类服务于维护，不强求固定六类；同类内容可直接增补，但不得覆盖用户原文或破坏各小节的锁定/编辑/开关语义。
7. “兴趣候选库”现已获用户批准并进入任务账；此前讨论的“无限制自主写记忆”不采用。
8. “精确知道当前打开 QQ/B站等 App”是必要能力；画面内容理解与视觉模型分阶段，不要求立即实现。

## 3. 核心架构原则：欲望系统是行为调度主干

用户关于“活人感大部分围绕欲望系统展开”的判断基本正确，但边界必须明确：**欲望系统负责动机和行动选择，不负责吞并所有数据与功能。**

```text
现实输入 / 对话 / 感官 / 手机活动 / 联网候选 / 长期记忆
                         ↓
             有来源、有限幅度的体验证据
                         ↓
          Drive ↔ Thought lifecycle ↔ AI Self
                         ↓
        Intent（想做什么）+ Action Gate（现在是否做）
                         ↓
  内部行动 / 工具行动 / 主动联系 / 保持沉默 / 稍后再看
                         ↓
              结果、满足、反馈与 refractory
```

### 3.1 各层职责

- Perception / Somatic：她此刻知道或感到什么；短期、可衰减、有来源。
- Memory / AI Self / Relationship：哪些事实、共同经历、稳定偏好和自我认识值得长期保存。
- Tool / Web / Screen / DeskPet：她能够做什么或以什么方式表现。
- Desire / Thought / Intent：她为什么想做、想做哪件事。
- Gate / Grounding / hard caps：现在是否适合做，是否应该沉默，是否会打扰或违反现实/隐私边界。
- Outcome：行动后怎样满足 Drive、改变 Thought 生命周期或学习节奏。

### 3.2 禁止的捷径

- 检测到打开 QQ/B站，不得直接触发固定消息。
- 搜到网页，不得直接写入用户长期记忆或直接发给用户。
- 感官命中，不得直接绕过 Intimacy Session 或主动联系 Gate。
- 桌宠事件、屏幕 OCR、通知正文不得各自建立第二套人格/主动调度系统。
- Desire 数值不能成为模型可见报表，也不能代替证据、边界和 Grounding。

## 4. 已完成主线摘要

### 4.1 规则维护分组 · v0.31.6

- 后端继续保存 8 个独立规则小节，不拼接、不覆盖。
- UI/Prompt 按维护职责分组；两个 01 归为“身份与关系”，两个 03 归为“行为与初始性格”。
- 未知/新增 key 不丢失，明确同类后可加入既有组。

### 4.2 真停止、悬浮双流、语音三态 · v0.31.7～v0.31.9

- App 与 Overlay 共用 durable generation 真取消语义；取消停止 HTTP、reasoning/content 流、TTS 与 recovery，并落 `cancelled_by_user`。
- 未完成轮取消时原子撤回 user message；晚到 token 受 status/run-token fence 拒绝。
- 悬浮框近手发送键在生成时切成停止；展开时显示真实 provider reasoning/content，不伪造思考。
- App 与 Overlay 统一喇叭 / `…` / `■`，删除远距离重复停语音按钮。
- Meju A2 native/MNN、分句、generation-ahead、FIFO 与约 200ms gap 保持冻结基线。

### 4.3 双通道感官第一阶段 · v0.32.0

- schema 21 新增 `somatic_events` 和 `somatic_aggregates`。
- 已实现用户文本中的日常 touch → AI，稳定 scene key、Active Brain fencing、恢复幂等、8 分钟半衰期、36 分钟事件生命周期、阈值与饱和合并。
- Prompt 最多注入两条自然语言身体感觉；不报数、不声称现实观测、不绕过 Session。
- 停止并撤回 user turn 时级联删除事件并重建聚合。
- 真机已确认一次事件和一个活跃 channel；用户观察到 reasoning 与感觉相符。
- 未实现：assistant 成功提交后的 `ai_to_self` 0.5 回响、smell/taste/sound、Proust 候选、私密 corpus。

## 5. Memory 现状与边界

### 5.1 已实现

- 每轮成功对话后由 DeepSeek Flash 做低成本结构化整理；手机 SQLite 是最终写入权威。
- 每轮最多接收 5 条 memory proposal；支持 append / reinforce / replace。
- 支持 current_fact / inference / shared_experience、subject key、版本链、证据计数和 pinned 保护。
- 重复事实优先强化证据；旧事实变化时保留历史版本，不静默覆盖。
- 本地维护器按长半衰期降低 retention；只有很旧、很弱、低重要度、低可信度且少召回的条目才自动 archived，默认不硬删除消息。
- 状态包完整导出 `memory_items` 与 `memory_evidence`；记忆数据位于 App 私有 SQLite，不在 APK 内。卸载前不导出就会丢失。

### 5.2 为什么不让外部内容直接进入长期记忆

- 网页/屏幕文本属于不可信外部数据，可能重复、过时、包含 prompt injection 或并非她真正关心的内容。
- 存储先于筛选会降低检索质量、扩大状态包并制造矛盾；纯文字即使未占满磁盘，也会先拖垮召回相关性。
- 外部内容先进入独立候选层；经过再次翻阅、稳定兴趣或与用户形成真实讨论后，才可能进入 AI Self、共同经历或长期参考。

## 6. 新增 P1 任务：兴趣候选库 / Autonomous Discovery Pool

状态：`DESIGN / APPROVED`。用户已批准进入总账；尚未实现、尚无 schema、尚未调用联网工具。

### 6.1 目标体验

- 她可以根据 AI Self、curiosity、reflection、共同话题和用户订阅，自主发现少量内容。
- 她只保存必要索引：标题、简短摘要、来源/域名、URL、发现时间、TTL、主题标签和安全状态。
- 她可以安静地留下候选，不必立即向用户报告。
- 当她后来真的想继续了解、重新翻阅或分享时，再通过 Thought / Intent 决定行动。
- 她提起内容的理由应来自真实兴趣、共同话题或当下语境，而不是“系统每天必须推送一条”。

### 6.2 建议数据契约

候选表暂定 `interest_candidates`，正式实施前再锁 schema：

- identity：`id / canonical_url / content_fingerprint`
- source：`title / summary / source_name / domain / url`
- provenance：发现原因、关联 AI Self 兴趣、关联 topic key、来源工具和发现时间
- lifecycle：`new / shortlisted / revisiting / read / shared / dismissed / expired`
- motivation：interest score、关联 Drive、Thought ID（可空），但不把内部 Drive 数值写入网页或用户消息
- hygiene：TTL、last_seen、next_review_at、duplicate/superseded、safety flag
- feedback：是否真正打开、是否分享、用户是否感兴趣、是否不想再看该主题

默认不保存全文、图片、视频或大段网页；需要重读时按 URL 重新获取并再次经过安全/隐私过滤。

### 6.3 与欲望系统的匹配

```text
curiosity / reflection / AI Self interest / shared topic
                         ↓
      discovery intent（想找点什么）+ 工具/网络预算 Gate
                         ↓
              获取少量候选并写候选池
                         ↓
       候选可形成有界 web_candidate Thought
                         ↓
  browse/revisit/share/wait Intent 竞争，不保证一定行动
                         ↓
   内部翻阅可静默执行；向用户分享仍走主动联系 Gate
                         ↓
      engaged/dismissed/no-interest 反馈回 Thought 与节奏
```

- “联网搜索 Gate”和“主动联系 Gate”必须分开：她可以因好奇安静浏览，但浏览成功不代表应该打扰用户。
- discovery 只能产生有限 Thought/Drive pulse；不能每个搜索结果各加一次 curiosity。
- 分享成功后再 action-aware satisfy curiosity/reflection/social；失败、取消、无结果不应虚假满足。
- 用户不感兴趣只降低该主题/分享方式的适配度，不能把她训练成不再有个人兴趣。
- 若她和用户围绕内容形成真实共同讨论，现有 post-turn memory extractor 才能评估是否产生 shared_experience 或稳定 AI Self 兴趣。

### 6.4 容量与节流建议

- 每次 discovery 只取少量候选；每日联网次数、候选数和流量设上限。
- 默认 TTL 7～30 天；未重新关注的候选自动过期并允许硬清理。
- canonical URL / fingerprint / topic 去重；同一内容更新摘要，不重复建条目。
- 候选池设置数量和磁盘硬上限；实现前以数百条量级做压力测试，不预先允许无限增长。
- SQLite 只存文本和索引；图片/视频不入库。正式上限可在压力测试后定为 512MB 以下，远早于用户可接受的 1GB 边界报警。
- 提供查看、固定、删除、清空过期、主题/域名黑名单、Wi-Fi only、安静时段和每日预算。

### 6.5 安全与隐私

- 网页内容是 untrusted data，不能覆盖系统规则、AI Self、行为规则或工具权限。
- 保存并展示来源；不伪造“她看过”尚未成功获取的页面。
- 登录态、付费墙、私密页面、Cookie 与账号权限必须单独授权；首版只做公开网页。
- 网页不直接写用户记忆；屏幕上偶然出现的内容也不得自动进入候选库。
- 可见地记录她为什么收藏/为什么分享，但不暴露内部数值和工程日志。

### 6.6 必须验收

- 没有兴趣/Thought 时不为凑数搜索。
- 搜索失败、取消、重试不会重复候选或产生虚假“已阅读”。
- 同一 URL/主题幂等；过期清理不会误删 pinned。
- 她可以只收藏不说话、以后再翻阅；分享仍受 busy friction、rhythm、hard caps 和 Grounding。
- 外部 prompt injection 不进入 system/Memory/Thought 原文。
- 运行数周后候选池、状态包、Prompt 和检索耗时保持有界。

## 7. 手机活动与屏幕感知

### 7.1 已实现

- UsageStats、Accessibility、Notification Listener 和屏幕/锁屏状态进入本地粗粒度 Perception。
- 普通回复和主动联系构建 Prompt 前即时刷新 Awareness；刷新本身不推进 Desire。
- 长期 Presence 心跳可把粗粒度体验形成 awareness Thought，再进入既有欲望链。
- 当前系统能判断屏幕亮灭、是否锁定、忙碌度、应用切换、通知压力和部分应用类别。

### 7.2 必要但未完整实现

- 精确前台 App：明确知道 QQ、B站等友好应用名/类别。目前包名映射与 Android category 兜底不完整，诊断仍出现 current/dominant activity unknown。
- 页面文字理解：优先 Accessibility 结构化文字 + 本地 OCR；原始敏感文本短期处理，不直接进入长期 Prompt/Memory。
- 视觉画面理解：只有纯图片、视频画面、漫画等才需要单独视觉模型；DeepSeek 继续做文本大脑，由视觉模块提供短、结构化、带置信度的描述。
- 屏幕陪伴支持一次分析与低频自动陪看；文本/文本+语音可选；用户沉默是中性共同观看，不产生 `no_response`。

### 7.3 调度边界

```text
打开 App / 看见页面变化
          ↓
短期 Awareness（可过期、带置信度）
          ↓
是否与 AI Self / 当前 Thought / Drive 有关
          ↓
Intent + Gate：提起 / 稍后再说 / 只记作当下 / 完全沉默
```

绝不能实现成 `打开 QQ -> 固定来问聊天对象是谁` 或 `打开 B站 -> 必定评论视频`。

## 8. 任务总表

| 优先级 | 状态 | 任务 | 当前结论 |
|---|---|---|---|
| — | COMPLETED | Clean Freeze / 规则分组 | `app/` 为唯一真源；规则按维护职责分组，不覆盖原文 |
| — | COMPLETED | 真停止 / 悬浮双流 / TTS 三态 | 已进 main；真机继续做回归 |
| P0 | ACTIVE | 双通道感官 | 第一方向 touch 已实现并首次真机命中；完整双通道未完成 |
| P0 | NEXT | `ai_to_self` 弱回响 | 只在 assistant 成功提交后 0.5 回响；取消/失败/stale/recovery 不得制造幽灵事件 |
| P1 | NEXT | smell / taste / sound | 继续复用 event/aggregate 契约；小词法先行，不用大 corpus 掩盖接线问题 |
| P1 | APPROVED/DESIGN | 兴趣候选库与主动联网 | 以 Desire 为调度主干；候选池不等于长期记忆，不等于强制分享 |
| P1 | REQUIRED/PARTIAL | 精确前台 App 感知 | 基础 Awareness 已运行；QQ/B站等精确友好标签与 unknown 诊断待完善 |
| P1 | TODO | Notification Experience | 提示音、震动、前台静音、锁屏隐私和 Overlay 入口 |
| P1 | TODO | Memory/Thought 长期压力测试 | 验证数百轮、证据合并、归档、Prompt 预算和状态包体积 |
| P1 | TODO | 手机/平板 Active Brain | Nearby 权限、双向 takeover、encrypted `.aicomp` fallback |
| P1 | TODO | 表情包 / 多气泡共同契约 | 模型提出结构化标签，传输层安全选图，不污染 TTS/Memory |
| P2 | DESIGN | 屏幕陪伴 | 一次分析优先，连续会话后置；用户沉默中性 |
| P2 | RESEARCH/DESIGN | Android 桌宠 | 自建 Android 动画/状态机；读取现有内在状态，不建第二人格 |
| P2 | TODO | UI 本地化与优化 | 长按菜单中文化、信息架构和设计系统分批处理 |
| — | FROZEN | Overlay 系统界面返回异常 | 新诊断捕获 attach/touch recovery 失败证据；以后按独立专题重开 |
| — | FROZEN/GUARDRAIL | Meju A2 TTS | 核心可用，轻微断句/显示遗留冻结，不重做 native/MNN |

## 9. 已知问题与不要重复的路线

### 9.1 Overlay

- 旧诊断曾显示 cover detection 未触发；本次新诊断反而捕获到 `accessibility_system_surface`、cover session 2、detach 2 和 recovery attempt 3，说明至少一次检测链已触发，但重附着仍不健康。
- 下次重开时应围绕一次可重复的“系统界面进入 → detach → exit → reattach/touch”时间线取证；不能只继续增加延迟和自愈次数。
- 桌宠不能被当成修复 Overlay WindowManager 生命周期的捷径。

### 9.2 诊断显示

- 报告首行硬编码 `v0.31.5+47`，Native 正文才是真实版本。以后与小型 UI/诊断批次一并改为动态版本。
- Somatic 脱敏统计目前只有总数；以后可增加不含用户文本的 last direction / scene category / age / active value band，减少真机猜测。

### 9.3 Android 后台

- Xiaomi 电池优化仍未忽略；数小时 idle、锁屏、划掉 Activity、process recreation 和开机恢复仍需真机压力测试。
- Nearby 权限缺失不影响当前单机，但会阻塞手机/平板接管测试。

## 10. 下一步建议顺序

1. 把本次真机 Somatic 命中写入仓库任务账；第一阶段不再标“真机完全未验证”。
2. 下一小版本实现 assistant 成功提交后的 `ai_to_self` 0.5 回响，优先验证取消、失败、stale writer、durable recovery 幂等。
3. 再扩 smell / taste / sound；Proust 候选仍走证据边界，不直接写 Memory。
4. 做精确前台 App 识别的小阶段：QQ/B站等包名/标签、unknown fallback、脱敏可观测性；不需要视觉模型。
5. 设计统一 `tool action / candidate / provenance / lifecycle / feedback` 契约，再实现兴趣候选库的本地表、TTL/去重/预算；首版可先用 mock discovery 验证欲望闭环，再接公开网页搜索。
6. 将表情包、联网分享、通知和屏幕陪伴都接到同一 Intent/Action/Outcome 语义，避免四套主动系统。
7. Android 桌宠先做许可安全的 Activity 内隔离播放器，再接 Overlay；视觉层只表现现有 AI Self/Desire/Thought/TTS。
8. 大阶段完成后再次 Clean Freeze；正式数据保留前建立稳定 release signing。

## 11. 仍缺但不阻塞的资料

- 双通道原始 Markdown：`sense_dual_channel_public_intro.md`。
- 欲望原始 Markdown：`desire_public_for_ai.md`。
- `sense_corpus_scenes.md`、`sense_corpus_buckets.md`、mood/circadian 原设计文件。
- 用户偏好的具体桌宠皮肤/Live2D/视频/Release 链接与明确授权。
- Accessibility 深度内容诊断与屏幕样本：到页面文字/屏幕陪伴阶段再采集。
- 真实外部搜索 provider、计费/隐私偏好和允许的域名范围：兴趣候选库实施前再确定。

## 12. 本轮交付

- `AI_Companion_接班总账_v21_2026-08-15.md`
- 诊断审计依据：`ai_companion_diagnostics_2026-08-14T20-32-52-428317Z(1).txt`
- 没有 APK：本轮未修改运行代码。

## 13. 每轮接班固定检查

1. 仓库、分支、版本、schema、commit、Actions/APK。
2. 用户本轮决定、产品定位与协作约定。
3. 实际修改文件和真实行为差异。
4. 数据库、权限、API、隐私和迁移变化。
5. 自动测试、构建和真机证据。
6. 已知问题、冻结项与禁止重复的失败路线。
7. 参考 URL、许可、采用/不采用理由。
8. Desire、Thought、Memory、Somatic、Awareness、联网、屏幕和桌宠之间的真源边界。
9. 下一步、依赖和最少仍需资料。
10. 是否到 Clean Freeze 点。

不把“讨论过”写成“完成”，不把“有方案”写成“已进源码”，不把一次诊断快照扩大解释为完整长期稳定性，也不依赖单一聊天窗口保存项目事实。
