# AI Companion · 接班总账 v26

更新时间：2026-08-15（Asia/Tokyo）

> 本文件继承并取代 `AI_Companion_接班总账_v25_2026-08-15.md`。判断优先级固定为：用户最新明确决定 > GitHub `main` 实际源码与 Actions > 最新脱敏真机诊断 > 仓库 HANDOFF/任务账 > 历史对话与参考资料。讨论、设计、真机线索不得写成已实现功能。

## 0. 本轮结论

- 桌宠 D2 已完成产品实现与自动构建：v0.33.1 的原动作同构播放器进入真实 `TYPE_APPLICATION_OVERLAY`，与旧悬浮球共用唯一 `OverlayBubbleService`、悬浮聊天、未读、TTS 与后台大脑；设置中二选一，绝不同时显示，旧用户默认仍为悬浮球。
- 用户最终确认：单击必须留给摸头、戳身体、碰尾巴等触碰反应；双击才打开桌宠菜单。实现用 Android double-tap timeout 延迟确认单击，第二次按下立即撤销第一下，避免双击误触两次动作。
- 桌宠菜单提供打开聊天、小/中/大三档、切换悬浮球和关闭；实际窗口为 112/152/200dp，分别读取 187/238/306px 源素材，不再把预览清晰度误称为真实显示大小。
- 拖动超过 6dp 进入 `DRAGGING`，松手进入 `FALLING → LANDING`，重摔排队 `DIZZY`；位置独立保存并夹紧安全区，保留旧悬浮球的位置数据。
- 产品 run #54（ID `31873700153`）全绿；artifact `9244295960`，ZIP digest `sha256:1c3126f90582e11c936f521215cdfb547d28cb6bb53cea01debc66d6148c5716`。APK 238,601,828 bytes，SHA-256 `6ed7067612ef164f2412ff517da59af35340fba626b4508923ccdd7aa55b6c8b`；独立核验仍包含 417 个 source 文件与 210 张 runtime PNG。
- D2 自动验证完成，但 REDMI K80 Ultra 上的触碰区域、双击容错、三档实际尺寸、拖拽落地、横竖屏/锁屏和两种入口切换必须由用户真机确认后才能写成真机完成。

- 桌宠 D1 已按用户最新决定纠正为“原项目动作同构”：不再按视觉外观精简图片，也不把素材片段误当行为动作；完整保留用户提供包的 417 个文件、111,962,623 bytes。
- Android 端直接读取上游 format v4 `actions.json`，保持 18 个行为动作、28 组 asset、187/238/306 三档、方向素材、原始帧序、帧时长、`enter/body/exit`、优先级/中断/返回状态、程序性效果和抛掷物理。
- 210 张 runtime PNG 全部保留；201 张由当前 manifest 引用，9 张上游 fallback/runtime 文件即使当前未引用也不删除。GIF 及候选/masters/说明同样留在私有素材包；运行时仍按上游代码读取 PNG，而不是把展示 GIF 当动作源。
- 预览页使用“中文动作名 + 原始 ID”；真实拖动按上游生命周期进入 `DRAGGING → FALLING → LANDING`，重摔排队 `DIZZY`；另有显式“复位待机”，避免保持态被误判成卡死。
- `v0.33.1+56` 已完成并进入 `main`：PR #12 squash 合并提交 `93d685c2ad4f38d63b99a04c07812c26afae8695`；产品 run #47 与最终文档 head run #53 均全绿。数据库 schema 保持 21。

- 用户补发的 v0.32.1+53 真机诊断整体健康：Active Brain=true、transfer lock=false、11 个 post-turn job 均完成，generation/post-turn 无 pending/active/failed，后台/恢复/异步维护/Continuity/TTS 均无 error flag。
- Somatic 事件累计从上一份的 1 墕到 4，当前一个活跃 channel；旧报告只给总数，不能单凭这份报告严格区分 `user_to_ai` 与 `ai_to_self`。
- v0.32.2+54 新增脱敏分向计数 `somatic_user_to_ai_events` / `somatic_ai_to_self_events`；不导出动作正文、部位、scene、聊天或 Thought 原文。
- 悬浮聊天每条消息新增本地 `HH:mm`，取真实 `created_at`；App 内原有时间显示不改。
- 诊断报告标题不再硬编码遗留 `v0.31.5+47`，改从实际安装包动态读取 versionName/versionCode。
- 轻视觉现在显式区分“系统已授权”和“AccessibilityService 已连接”，持久记录最近连接、解绑、中断时间与原因；已授权但未连接时给出恢复提示。App 不会、也不能越权静默重新启用系统无障碍服务。
- 本次报告抓取时轻视觉为“已授权 + 已连接”，所以用户曾遇到的关闭不是正常 App 设计行为；更像 HyperOS/Android 重启、崩溃或系统安全策略撤销。下一次复现以 lifecycle 字段判断。
- 桌宠主参考改为 `QCYTSN/ds-local-pet`：MIT 代码/manifest/状态机可参考，Windows 窗口层重写为 Android；该仓库视觉资产被 `ASSET_LICENSE.md` 明确排除在 MIT 外，未经额外授权不得打入 APK。
- 性格底色适合做独立窗口，但只编辑现有 `03_personality_seed`，不建立第二套人格真源。本轮冻结“预设 + 可编辑文本”和“蠢萌元气”建议文案，尚未改变她的实际性格。
- 用户补充的 `素材.zip` 共 475 项、约 112MB；目录、manifest、candidate 名称、角色 ID `dafeiyu` 与 `ds-local-pet` assets 完全对应，且包内无 LICENSE/授权文件。它是同源 assets 副本，不是独立授权来源；正式 APK 仍需权利证明。技术接入只取 runtime states + 必要 manifest，不携带 candidates/masters/source sheets/dialogue。
- `v0.32.2+54` 已完成并进入 `main`，schema 保持 21；PR #10 squash 合并，产品提交 `3ebeada99c2954ca4c13c16a7a6d24b4ffa1472b`。

## 1. 当前事实基线

### 1.1 GitHub / 构建

- 私有仓库：`catkiss62/ai-companion-build`
- 默认分支：`main`
- 源码唯一真源：`app/`
- 当前产品分支基线为 `v0.33.2+57`，产品提交 `6ff6ed8439c980d4f167310974a9ece8c7c143b1`，schema 21；PR #13 待完成纯文档 head 复验后合并。
- 当前分支：`codex/v0332-desktop-pet-overlay-d2`；PR #13。已合并 main 基底仍为 v0.33.1+56 / `93d685c2ad4f38d63b99a04c07812c26afae8695`。
- 当前版本：`v0.33.2+57`；schema 21，不做数据库迁移。
- 本版改动：在保留完整原动作同构素材/播放器的基础上新增真实系统桌宠窗口、触碰区域、双击菜单、三档实际尺寸、拖拽落地，以及与旧悬浮球互斥切换。
- Clean Freeze 继续有效：仓库根目录不使用历史 patch/ZIP 作为构建输入；workflow 只验证和构建已提交的 `app/`。
- PR #13 产品代码待文档提交与最终 head 复验后 squash 合并；main 暂未变更。
- 产品 Actions run #54（ID `31873700153`）通过 validators、Kotlin 桌宠状态/物理/触碰测试、Flutter analyze/tests、release APK、完整桌宠 payload 与 artifact 上传。
- 交付 Artifact `9244295960`，名称 `AI-Companion-v0.33.2-57-Desktop-Pet-Overlay-D2-APK`，ZIP digest `sha256:1c3126f90582e11c936f521215cdfb547d28cb6bb53cea01debc66d6148c5716`。
- 交付 APK SHA-256：`6ed7067612ef164f2412ff517da59af35340fba626b4508923ccdd7aa55b6c8b`；238,601,828 bytes。

### 1.2 最新脱敏真机诊断

文件：`ai_companion_diagnostics_2026-08-15T01-14-39-950882Z.txt`

- 首行仍硬编码 `v0.31.5+47`，但 Native 明确为 `0.32.1+53`、schema 21；这是 v0.32.1 的显示遗留，v0.32.2 已修为动态版本。
- Android 15 / SDK 35 / Xiaomi `25060RK16C`；Active Brain=true、transfer lock=false。
- 11 个 post-turn job 完成；pending/active/failed generation 均为 0；background/generation recovery/async worker/maintenance/Continuity/TTS 无错误标志。
- Somatic：事件 4、活跃 channel 1；证明事件持续落库，但旧报告未导出 direction/source，因此本份不能严格证明 `ai_to_self`。
- Thought 10 条；provenance：memory 1、user_message 6、awareness 1、self_experience 2。不得把 `self_experience` 数量直接当 Somatic 因果证明。
- Desire 选中 curiosity / check_in；gate 0.347 < 0.60，因此保持沉默，说明主动联系没有被输入强制触发。
- currentContext 可用，但 `currentActivityClass`、`dominantActivityClass` 为空，observations=0；精确 QQ/B站识别任务仍未完成。
- 轻视觉在抓取时 `accessibility=true` 且 `accessibilityConnected=true`；Overlay attached/touchable/visible/running，inputSuspect=false。
- Usage、通知访问与发送通知未授权；电池优化未忽略但 backgroundRestricted=false。按用户决定，电池提示继续后置。
- TTS 为浅检查：资源存在、未初始化、无错误；不代表本轮做了实际发声黄金测试。

## 2. 用户长期协作与产品决定

1. 每次有实际任务成果，同步更新完整接班总账并作为文件交付；纯讨论可不新发。
2. 复杂系统另建详细设计文档，总账保留事实、状态、边界、入口和依赖。
3. 每完成一个大阶段判断是否进行 Clean Freeze；删除冗余补丁前列出精确清单，Git 历史保留恢复路径。
4. 半成品测试阶段不保留真实存档，用户允许卸载重装；进入真实长期使用前必须启用稳定 release signing 和升级/备份验收。
5. 项目定位为男性向 AI 女友；机制可跨类型借鉴，但不能照搬女性向固定甜宠、保护者/霸总或无条件顺从模板。
6. 规则分类服务于维护，不强求固定六类；同类内容可直接增补，但不得覆盖用户原文或破坏各小节的锁定/编辑/开关语义。
7. “兴趣候选库”现已获用户批准并进入任务账；此前讨论的“无限制自主写记忆”不采用。
8. “精确知道当前打开 QQ/B站等 App”是必要能力；画面内容理解与视觉模型分阶段，不要求立即实现。
9. 电池优化引导后置；除非真机出现后台被杀证据，不因 Xiaomi 未忽略优化单独插队。
10. 旧悬浮球后续由桌宠入口替换；不为旧 UI 做重型翻修，但底层悬浮窗生命周期、触摸、聊天窗、时间显示和真实停止语义必须保留并复用。
11. 桌宠主参考为 `QCYTSN/ds-local-pet`；代码、manifest 与动作组织按上游结构移植到 Android。用户明确本项目完全私人、非公开、非商业，并提供了重新导出的替换包；仓库保留来源/私用边界说明，未经重新核对不得对外发布或复用素材。
12. 性格底色窗口只编辑 `03_personality_seed`；用户确认文案前不改变当前角色实际性格。

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

### 4.3 双通道感官 · v0.32.0～v0.32.1

- schema 21 新增 `somatic_events` 和 `somatic_aggregates`。
- 已实现用户文本中的日常 touch → AI，稳定 scene key、Active Brain fencing、恢复幂等、8 分钟半衰期、36 分钟事件生命周期、阈值与饱和合并。
- Prompt 最多注入两条自然语言身体感觉；不报数、不声称现实观测、不绕过 Session。
- 停止并撤回 user turn 时级联删除事件并重建聚合。
- 真机已确认一次事件和一个活跃 channel；用户观察到 reasoning 与感觉相符。
- v0.32.1 已实现 assistant 成功提交后的 `ai_to_self` 0.5 回响；与 durable reply 原子提交，失败/取消/stale/recovery 不制造幽灵事件。
- assistant 意图、否定、假设不命中；只有实际完成动作或明确动作括号命中。
- 2026-08-15 新报告累计 4 个 Somatic 事件，但旧格式不能分向；v0.32.2 已补分向统计，下一份报告直接确认。
- 未实现：smell/taste/sound、Proust 候选、私密 corpus。

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
| P0 | ACTIVE/VERIFY | 双通道感官 | user→AI 已真机命中；AI→self 0.5 原子回响已进 main，待真机诊断确认 |
| — | COMPLETED | `ai_to_self` 弱回响实现 | assistant 成功 durable commit 才写入；取消/失败/stale/recovery 不制造幽灵事件 |
| P1 | NEXT | smell / taste / sound | 继续复用 event/aggregate 契约；小词法先行，不用大 corpus 掩盖接线问题 |
| P1 | APPROVED/DESIGN | 兴趣候选库与主动联网 | 以 Desire 为调度主干；候选池不等于长期记忆，不等于强制分享 |
| P1 | REQUIRED/PARTIAL | 精确前台 App 感知 | 基础 Awareness 已运行；QQ/B站等精确友好标签与 unknown 诊断待完善 |
| P1 | TODO | Notification Experience | 提示音、震动、前台静音、锁屏隐私和 Overlay 入口 |
| P1 | TODO | Memory/Thought 长期压力测试 | 验证数百轮、证据合并、归档、Prompt 预算和状态包体积 |
| P1 | TODO | 手机/平板 Active Brain | Nearby 权限、双向 takeover、encrypted `.aicomp` fallback |
| P1 | TODO | 表情包 / 多气泡共同契约 | 模型提出结构化标签，传输层安全选图，不污染 TTS/Memory |
| P2 | DESIGN | 屏幕陪伴 | 一次分析优先，连续会话后置；用户沉默中性 |
| P2 | COMPLETED/REAL-DEVICE-VERIFY | Android 桌宠 D1.1 原动作同构 | 完整素材与 18 动作播放器已进 main；下一步真机逐动作检查，再进入 D2 Overlay |
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

- Xiaomi 电池优化仍未忽略，但用户当前实测未出现后台被杀；优化提示后置，不作为近期阻塞项。
- 数小时 idle、锁屏、划掉 Activity、process recreation 和开机恢复仍可在后续真机压力测试中观察，有证据再升级优先级。
- Nearby 权限缺失不影响当前单机，但会阻塞手机/平板接管测试。

## 10. 下一步建议顺序

1. 用户安装 v0.32.2+54 后，分别测试用户动作与她已完成的自发动作，再保存脱敏诊断；确认 `somatic_user_to_ai_events > 0` 且 `somatic_ai_to_self_events > 0`，“我想抱住你”不得命中。
2. 再扩 smell / taste / sound；Proust 候选仍走证据边界，不直接写 Memory。
3. 做精确前台 App 识别的小阶段：QQ/B站等包名/标签、unknown fallback、脱敏可观测性；不需要视觉模型。
4. 设计统一 `tool action / candidate / provenance / lifecycle / feedback` 契约，再实现兴趣候选库的本地表、TTL/去重/预算；首版可先用 mock discovery 验证欲望闭环，再接公开网页搜索。
5. 将表情包、联网分享、通知和屏幕陪伴都接到同一 Intent/Action/Outcome 语义，避免四套主动系统。
6. Android 桌宠 D1.1 先完成 Activity 内原动作同构与 APK 真机验收；随后 D2 接独立 Overlay window、点击聊天、拖拽落地、安全位置、横竖屏与锁屏暂停。视觉层只表现现有 AI Self/Desire/Thought/TTS，不建第二人格。
7. 旧悬浮球不单独重修；若桌宠接入暴露 WindowManager 生命周期问题，再按可复现时间线修底层。
8. 大阶段完成后再次 Clean Freeze；正式数据保留前建立稳定 release signing。

## 11. 仍缺但不阻塞的资料

- 双通道原始 Markdown：`sense_dual_channel_public_intro.md`。
- 欲望原始 Markdown：`desire_public_for_ai.md`。
- `sense_corpus_scenes.md`、`sense_corpus_buckets.md`、mood/circadian 原设计文件。
- 若未来从完全私人使用转为公开分发：需重新确认素材权利、署名和再分发边界；当前私用替换包不得直接视为公开发布授权。
- Accessibility 深度内容诊断与屏幕样本：到页面文字/屏幕陪伴阶段再采集。
- 真实外部搜索 provider、计费/隐私偏好和允许的域名范围：兴趣候选库实施前再确定。

## 12. 本轮交付

- `AI_Companion_接班总账_v22_2026-08-15.md`
- `app/docs/SOMATIC_AI_TO_SELF_v0.32.1.md`
- `app/docs/ANDROID_DESKTOP_PET_PLAN_v2.md`
- `app/docs/PERSONALITY_BASE_UI_v1.md`
- App `v0.32.1+53` release APK 与同包 SHA-256 文件
- PR #9：`https://github.com/catkiss62/ai-companion-build/pull/9`
- Actions run #32：`https://github.com/catkiss62/ai-companion-build/actions/runs/31841772104`
- Artifact：`https://github.com/catkiss62/ai-companion-build/actions/runs/31841772104/artifacts/9234768624`

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


## 14. v0.33.0+55 · Android 桌宠 D0/D1

### 用户决定

- 为避免桌宠资料在长上下文后重复整理，桌宠任务提前为当前主线。
- 用户确认素材只用于其完全私人、不公开、非商业项目，并同意项目内标注来源。
- `素材-替换原图片.zip` 重新导出了全部图像容器；像素审计为 389/389 画面一致。按原素材重导出记录，不再要求用户继续重画。

### 实现

- 只从工作包选取 238px Android 运行帧：27 个动作、66 张 RGBA PNG、低于 6MiB；不打包 candidates、masters、source sheets、GIF 预览和原项目 dialogue。
- 皮肤 manifest 明确 `redistribution_allowed=false` 与 `private_noncommercial_ai_companion_only`；附 `ATTRIBUTION.md`、`LICENSE.txt`。
- Kotlin 新增 manifest loader、路径穿越/尺寸/fps/帧数校验、12MB LRU bitmap cache、逐动作帧时钟和状态优先级机。
- 普通 `PetPreviewActivity` 从系统页打开；进入后台暂停，销毁清回调与缓存。
- `OverlayBubbleService` 本阶段保持不动；文件选择器/全屏 Overlay 冻结问题未被宣称修复。

### 版本与下一步

- 版本：`v0.33.0+55`，schema 仍为 21。
- D2：同一前台服务内建立独立 Pet window，接点击聊天、拖拽、fall/land、安全位置、横竖屏和锁屏暂停；稳定前保留旧悬浮球回退。
- 完整实现说明：`docs/DESKTOP_PET_D0_D1_v0.33.0.md`。


### D0/D1 验证

- 首轮 run #42 的产品 Kotlin 编译已成功；唯一失败是 Gradle `--tests` 过滤器误施加到无测试的插件子项目。
- 将命令收窄为 `:app:testDebugUnitTest` 后，run #43（ID `31861829909`）通过新素材 validator、全部历史 validators、Kotlin 单测、Flutter analyze/tests、release APK 和冻结 A2 payload 校验。
- artifact：`9240951958`；artifact ZIP digest：`sha256:6eb939e60cefbaeaea8bce7333a5e201a158ebf8b8e21f3df4cfc40e4cc123c4`。
- APK SHA-256：`db532702a4b0e5412613f05e71b940688ba467e53b747aedf762e6d42dcd2d1a`。


### 最终合并落款

- PR #11 已 squash 合并：`339f6a065e0942c3112a360249c9e05c400e3f7a`；最终 head run #44（`31862410341`）全绿，artifact `9241147554`，APK SHA-256 `a231ae317854b4985639a2124ffcfd2ffaa155d74a66cfee027c4a14342b3baa`，artifact digest `sha256:7748f41b826dfce5a468aad6d8dab6cb014a5fd6c786723044b0d243a4a1ea2b`。

## 15. v0.33.1+56 · Android 桌宠 D1.1 原项目动作同构

### 15.1 为什么纠正 v0.33.0

- v0.33.0 没有按相似外观逐帧删除，但只选 238px 运行帧，并把 27 个图片片段做成简化播放器；这会丢失三档尺寸、`enter/body/exit`、原始持续时间和动作状态关系。
- 用户明确指出相似图片可能是像素级序列帧，100MB 对 APK 可接受，要求先完整保留并完全按原项目写法拼接；这个决定高于 v0.33.0 的体积优化目标。
- `DRAGGING` 上游本来就是一张保持帧配合程序性漂浮；它的退出条件是松手事件，不是自动播完。旧预览看起来“卡住”的主要原因是生命周期缺失，而不是应该删除或补帧。

### 15.2 素材真源与完整性

- 用户输入：`素材-替换原图片.zip`，111,254,557 bytes，SHA-256 `f89d24c6509851b853b70914f91064a0b47cc7509f02bdadce2054f2b6f8491e`。
- 安全解包后：417 个文件、111,962,623 bytes；确定性 tree SHA-256 `caa4939627ee3a773566d4c793e355df5de98ad38698ddeb5b67519d03715582`。
- 与上游目录逐路径一致；389 个视觉文件经过重新编码，先前审计确认解码像素一致；非图像 manifest/说明字节一致。
- 上游 `assets/manifests/actions.json`：format 4，SHA-256 `3db9c886c7ebb0a73df996796cc10f1649fda39b0d3e8b86dad053085ac3ac59`。
- GitHub 单文件上传受限，因此私有仓库保存 151 个 737,280-byte 分片（末片较小）及 `asset_pack.json`；CI 的安全恢复脚本先验证 ZIP SHA、路径/符号链接、文件数、总字节和 tree hash，再恢复到 Android assets。分片自身不进入 APK，避免重复占用空间。

### 15.3 动作协议

- 18 个行为动作：`IDLE`、`BLINK`、`GLANCE`、`THINKING`、`WALKING`、`HAPPY`、`HEAD_PAT`、`TALKING`、`ANGRY`、`POKE_REACT`、`TAIL_REACT`、`EATING`、`SWEEPING`、`SLEEPING`、`DRAGGING`、`FALLING`、`LANDING`、`DIZZY`。
- 中文标签：待机、眨眨眼、四处看看、发呆、散步、开心、被摸摸、说话、生气、被戳、尾巴被碰、吃东西、扫地、睡觉、抓取中、落下、着陆、眩晕。
- 28 组 asset；210 张 187/238/306px runtime PNG 全保留，其中 201 张由 manifest 直接引用，9 张保留作上游 fallback/runtime 资料。
- Android loader 不建立第二份简化真源，直接解析原 manifest；保持最近尺寸选择、左右/前后方向、原始 frame duration 与 exact frame order。
- 播放器保持 `enter/body/exit`，同素材 90ms crossfade，不相关姿势 clean cut；状态机保持 priority、interruptible、duration、return_state 和 queued return。
- 程序性效果与 throw physics 按上游公式移植；拖拽移动阈值 6px，松手强制进入 falling，物理稳定后 landing，重摔再 dizzy。

### 15.4 预览与边界

- 普通 `PetPreviewActivity` 仍是隔离预览，不替换旧悬浮球，也不宣称已完成系统级桌宠。
- 按钮显示中文名与原始 ID；状态栏显示 phase、asset、当前尺寸档和 frame index；可切左右/背面/正面及 187/238/306px。
- 动作按钮用于逐项检查，角色区域用于真实拖拽状态链；“复位待机”仅为验证保持态的逃生按钮。
- D2 才把同一个播放器接入独立 Overlay Pet window，并复用点击聊天、悬浮聊天时间、旧 Overlay 生命周期和回退入口。

### 15.5 版本、PR 与验证

- 版本：`v0.33.1+56`；schema 21，无数据库迁移。
- 分支：`codex/v0331-desktop-pet-source-parity`；PR #12：`https://github.com/catkiss62/ai-companion-build/pull/12`。
- 上游参考：`https://github.com/QCYTSN/ds-local-pet`；审计 HEAD `d78094b2cf04e1cc3be5d14a31cfedd8ed059579`。
- 产品实现提交：`a3265e794cb700330b92cf88b29efb88845b01b2`；历史 validator 兼容提交：`2a91cff88a567489ff1332a730d029311fb5c697`；Kotlin mutable-exit 编译修复：`bab971bf944458d2d2bb4b973fc03c7138104a5e`。
- 产品 run #47（`31867409197`）与最终 head run #53（`31868202889`）均全绿；后者再次验证最终文档 head 不改变构建真源。
- 交付 artifact `9242561565`；ZIP digest `sha256:4058b67b7d8739c57dae6442306fc6524c81229e6b542d56c15c206e2aeafac9`。
- APK 238,499,224 bytes；SHA-256 `456d618776b1729353ea1735a63a139eb344cab9e1b296066bdbed04ef1759b7`。下载后独立读取 APK 再确认 417 source 文件、210 runtime PNG、1 原始 actions manifest、1 中文标签表。
- PR #12 已 squash 合并到 `main`：`93d685c2ad4f38d63b99a04c07812c26afae8695`。D1.1 工程状态为 COMPLETED，仍需用户真机逐动作视觉验收；系统级 Overlay 桌宠属于 D2，尚未实现。

## 16. v0.33.2+57 · Android 系统桌宠 D2

### 16.1 用户最终决定

- 桌宠与旧悬浮球都保留，系统设置提供二选一模式；二者不得同时出现。已有安装默认维持悬浮球，避免升级后入口突变。
- 桌宠单击用于原角色互动：头部摸摸、身体/脸部被戳、左右中下部尾巴被碰；双击才打开选项菜单。
- 三档不能只切素材清晰度，必须改变手机屏幕上的真实桌宠大小；原项目的 187/238/306px 三档仍分别作为对应源素材。
- 当前 D2 先保证窗口、触碰、拖拽、聊天入口和兼容性。Desire/Thought/mood/TTS 自动选择动作属于 D3，不能把调度故障与 Overlay 生命周期故障混为一轮。

### 16.2 窗口架构与模式切换

```text
OverlayBubbleService（唯一前台服务）
├─ 主入口二选一
│  ├─ legacy Bubble window
│  └─ PetOverlayWindow
└─ 共用 Chat overlay / unread / TTS / background brain
```

- 没有建立第二个前台服务或第二套聊天状态；同一服务根据 `overlayEntryMode=bubble|pet` 创建一个入口。
- 切换模式时移除旧入口并创建新入口；现有悬浮聊天框、消息时间、生成停止、流式内容、TTS 三态与主动联系链不复制。
- `pet_x/pet_y` 与旧 `bubble_x/bubble_y` 分离保存；切回悬浮球不会丢掉原悬浮球位置。
- 锁屏、聊天展开和系统 cover 时暂停/隐藏桌宠并关闭菜单；恢复后沿用原服务的 Overlay 健康检查和重新附着路径。
- 数据库 schema 继续为 21；模式、大小和位置只存 Android `overlay_state` preferences。用户当前允许卸载重装，不要求迁移半成品测试存档。

### 16.3 实际尺寸

| 档位 | Overlay window | 约可见角色高度 | 源素材档 |
|---|---:|---:|---:|
| 小 | 112dp | 约 98dp | 187px |
| 中 | 152dp | 约 134dp | 238px |
| 大 | 200dp | 约 176dp | 306px |

- 切换大小保持角色底部与中心位置，再按当前屏幕安全区夹紧；横竖屏或可用区域变化时重新限制坐标。
- 三档继续读取同一 format v4 `actions.json`，动作、方向、enter/body/exit、帧序与时长不变，只切素材 tier 与真实窗口 dp。

### 16.4 单击、双击、长按与拖拽

- 区域分类照 `ds-local-pet/pet/interaction.py` 的归一化几何移植：头部为 `HEAD_PAT`，脸/身体为 `POKE_REACT`，左右侧中下部尾巴区为 `TAIL_REACT`。
- 5 秒内累计三次 poke 排队 `ANGRY`；头/脸长按仍可 `HEAD_PAT`。
- 单击先等待系统 double-tap timeout；若第二次 ACTION_DOWN 落在双击条件内，立即取消第一下的待执行单击。双击不会先触发两次摸/戳动作。
- 双击菜单：打开现有悬浮聊天、小/中/大、切换为悬浮球、关闭菜单。
- 移动超过 6dp 后取消点击判定，进入 `DRAGGING`；WindowManager 参数随手指实际移动。松手进入 `FALLING`，稳定后 `LANDING`，重摔排队 `DIZZY`。

### 16.5 代码与测试

- 新增 `PetOverlayWindow.kt`：系统桌宠窗口、触碰状态机、双击菜单、拖拽/抛落、尺寸和位置持久化。
- 新增纯 Kotlin `PetOverlayContract.kt` 与 `PetOverlayContractTest.kt`：不依赖 Android UI 验证头/脸/身体/尾巴分区以及三档 dp/素材映射。
- `OverlayBubbleService.kt`：同一服务内切换 bubble/pet，动态按当前入口真实宽高夹紧位置，共用聊天、TTS、未读和后台脑。
- `SystemBridge.kt` / `android_bridge.dart` / `system_page.dart`：新增模式与大小桥接、设置页二选一和统一开关。
- `validate_v0332_desktop_pet_overlay_d2.py`：冻结共享服务、互斥入口、双击优先、三档尺寸、桥接与 UI 契约；历史 validators 同步接受新版本，未放松既有行为断言。

### 16.6 GitHub、构建与交付

- 分支：`codex/v0332-desktop-pet-overlay-d2`；PR #13：`https://github.com/catkiss62/ai-companion-build/pull/13`。
- 产品提交：`6ff6ed8439c980d4f167310974a9ece8c7c143b1`。
- 产品 Actions run #54（ID `31873700153`）全绿：安全恢复完整素材、源和历史 validator、Kotlin 桌宠测试、Flutter analyze/tests、release APK、APK native/payload 核验与 artifact 上传全部通过。
- artifact `9244295960`，名称 `AI-Companion-v0.33.2-57-Desktop-Pet-Overlay-D2-APK`，ZIP digest `sha256:1c3126f90582e11c936f521215cdfb547d28cb6bb53cea01debc66d6148c5716`。
- APK 238,601,828 bytes；SHA-256 `6ed7067612ef164f2412ff517da59af35340fba626b4508923ccdd7aa55b6c8b`。下载后独立读取 APK，确认 417 source 文件、210 runtime PNG、原始 actions manifest 和中文标签均存在。
- 最终文档 head run 与 squash merge SHA：在 PR #13 合并后补记。产品 APK 已由产品 run 固定，不因纯文档提交重打后更换交付散列。

### 16.7 当前边界与真机清单

- 自动测试能证明契约与构建成立，不能证明 REDMI K80 Ultra 上的视觉手感。状态为 `IMPLEMENTED / AUTOMATION PASS / DEVICE VERIFY`。
- 真机至少验证：悬浮球默认不变；设置切桌宠后只出现一个入口；头/身体/尾巴单击；双击只开菜单不误触；小/中/大实际尺寸明显不同；拖拽松手落地；打开聊天与消息时间；切回悬浮球；旋转、锁屏、解锁和 App 进出后可恢复。
- D3 再接 `THINKING/TALKING` 与 TTS、Desire/Thought/mood 行为选择、自主走动和动作反馈。桌宠只表现现有 AI Self，不建立第二人格或第二套欲望系统。
