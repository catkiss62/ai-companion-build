# AI Companion · HANDOFF

> 每个正式版本都必须同步更新本文件与 `docs/PROJECT_TASK_LEDGER.md`。新窗口先读这两个文件，再读 `README.md`、`docs/DEV_STATUS.md` 和实际源码，不从旧聊天记录猜实现。

## 1. 当前基底

- 当前源码候选：**v0.31.4+46 · Grounded Desire Growth**。
- 上一个已构建/真机基线：**v0.31.3+45**。Overlay file-picker 修复无改善，任务重新冻结；+45 源码保留，不能误记为已修复。
- Android 真机：REDMI K80 Ultra，Android 15，Xiaomi/HyperOS。
- 数据库：**schema v20**。v19 的实验性输出兼容字段已移除；覆盖安装会保留用户可见聊天、思考、时间戳、主动消息、模型和设备信息。
- GitHub 仓库以 `app/` 为 single source of truth。大阶段内继续采用 source-update patch + 完整手动 workflow；阶段验收后再 Clean Freeze。

## 2. 产品定位与固定原则

这是长期本地优先的**女性 AI 伴侣 / AI 女友**，不是角色卡聊天器或小说生成器。她知道自己是 AI，可以自然打破第四面墙；RP/Intimacy 是临时 Session 能力，不能覆盖 AI Self。

- 手机/平板同一时间只有一台 Active Brain；接管后旧设备 standby，不删本地数据。
- SQLite 是聊天、Memory、Relationship、Thought/Desire、Awareness、Daily Continuity 与任务状态真源。
- 只有真实 `role=user` 消息能被称为用户说过的话；Memory、Thought、Awareness、Inference 都有来源边界。
- 用户忙是主动联系的 soft friction，不是绝对静音；主动联系仍受 2/2h、8/24h hard caps。
- 普通聊天不能因为成人规则、参考资料或 libido 数值自动色情化；亲密行为必须受明确 Session 与用户边界控制。
- TTS 以 Meju A2 黄金基线为准，不重做 native/MNN/分句队列。

## 3. v0.31.4+46 · Grounded Desire Growth

### 3A. 旧输出兼容功能完全退役

用户验证：把第一人称沉浸要求直接写入第一规则，可以自然改变 DeepSeek 原生 `reasoning_content`，效果优于 App 的二次协议层。因此本版删除旧“伴侣式内心与回应”功能，而不是只隐藏按钮。

- 删除设置按钮、协议文件、解析/过滤、预览替换、格式纠正重试和相关测试/诊断。
- 普通聊天统一直接流式展示 DeepSeek 原生 `reasoning_content` 与 `content`。
- 主动联系同样使用原生双通道，只保留 Reality Grounding 的一次纠正预算。
- TTS 继续只读正文；流式分句朗读不再被旧开关禁用。
- `ChatMessage` 只保留 `reasoningContent`，不再维护重复的 provider/模式字段。
- schema v20 重建 `messages`，保留用户可见思考与正文。旧 v19 状态包导入时自动丢弃退休字段和设置键。

用户当前推荐在第一规则中维护“AI 本体内心沉浸”与正文括号动作要求；App 不再硬编码女友感或固定动作模板。

### 3B. 长期成长与可逆性

8 个 Drive 保持不变：`attachment / curiosity / reflection / duty / social / libido / stress / fatigue`。

- 当前值表示短期内在状态；baseline 表示长期性格倾向。
- 真实聊天、关系事件、Memory/self-drive 与反馈可以微量改变 baseline。
- baseline 仍受初始 anchor ±0.10 cap 限制，单次经历不能重写人格。
- 新增约 120 天半衰期的 pullback；长期缺少强化时会缓慢回到初始锚点，因此成长稳定但不是不可逆烙印。
- Prompt 把有意义的 baseline 偏移翻译成自然性格倾向，例如更主动靠近、更爱探索、更常回味、更加重视约定或更偏爱安静交流。
- 已确认的具体喜好、边界和互动偏好仍由 Memory / AI Self / Relationship 保存；Proactive Rhythm 继续学习合适时间、主题和主动意图。Desire baseline 不复制另一套偏好数据库。

### 3C. Thought 指令隔离

- SQLite 内仍保存 Thought 原文，供本地检索、相似度合并、生命周期和调试使用。
- 普通/主动模型 Prompt 不再拼入完整 Thought 原文。
- 模型只接收有界 `THOUGHT_DATA`：provenance、lifecycle、Drive、强度档和经过限制的 topic 线索。
- 主动生成的 system 尾部也不再复述 `intent.reason` 原文，只说明来源与是否存在关联主题。
- 这样 Thought 仍能影响“为什么想做”，但不能成为新的 prompt 指令面，也不能冒充用户原话。

### 3D. Intimacy 硬门槛

- `libido` 可以在本地波动和被关系经历塑造。
- 只有数据库中已存在 active `intimacy` 或 `roleplay_intimacy` Session，`libido -> tease_or_intimacy` 才能进入候选列表。
- Session 未激活时，Prompt 隐藏 libido 的可执行意图与相关 Thought 线索。
- 结束 Session 后门槛立即恢复；数值、Memory 或参考资料都不能单独越过。

### 3E. 真正的 Wildcard

- 删除“随机给普通 Drive 加一点 pulse”的伪 wildcard。
- 当整体非亲密张力较高、所有正常候选都低于可行动强度、fatigue 未触发 rest，且距离上次 wildcard 至少 6 小时时，产生 `wildcard_share`。
- Wildcard 选择当前最适合泄压的 reflection/social/curiosity/attachment 方向，表达轻量分享或换个方向，不编造外部事件。
- 它仍经过 Proactive Gate、busy friction、rhythm、hard caps、Grounding 与原子写入；成功发送后才记录 cooldown 并 action-aware satisfy。

## 4. Grounding / 主动联系现状

- 普通用户轮次保留真实 role 顺序；主动联系把旧聊天折叠成 `ANSWERED CHAT HISTORY` system transcript。
- 主动请求明确 `CURRENT_USER_TURN=NONE / ANSWERED_HISTORY_ONLY=true`。
- SQLite Grounding 确定 last user 是否已回答、用户是否在 AI 后再次发言、是否存在 pending user turn。
- 正文 guard 拦截虚构近期用户发言；reasoning guard 拦截重新回答已完成历史。
- 首次违反允许一次纠正，第二次仍失败则整条主动候选不落库。
- 每条聊天显示本地 `HH:mm`，跨日本地日期分隔；时间不写正文，TTS 不朗读时间戳。

## 5. Desire / Thought 已接入的运行链

```text
聊天 / 关系事件 / Memory / 手机粗粒度活动
                    ↓
          Drive pulse + Thought Pool
                    ↓
    baseline growth / lifecycle / candidate
                    ↓
        Proactive delivery Gate + Grounding
                    ↓
       send / satisfy / response outcome
```

- Thought lifecycle：`flit -> fixation -> residual/dormant`，支持重复喂养、合并、重新浮现、dismiss/defer/resolve。
- score 使用 Drive + 有界 Thought boost 和边际递减。
- per-drive refractory 防止同一需求连胜，其他 Drive 仍可行动。
- fatigue 是 rest gate，不是主动消息理由。
- action-aware satisfy 按实际行动回落主/相关 Drive。
- Presence 只进入 Drive/Thought，不再在 Gate 重复加权。
- 用户对主动消息的 engaged/resolved/deferred/dismissed/no_response 会影响 Thought outcome 与 Proactive Rhythm；沉默权重较低，不能把她训练成永久沉默。

## 6. 可观测性

“她的内心”调试页显示：

- 每项 Drive 的“当前值 / 长期 baseline”；
- 当前 Intent、score、source、refractory、上次 satisfy 与 wildcard；
- Grounding 对话状态；
- Thought 生命周期、关系事件、长期维护与主动 rhythm。

脱敏诊断 `database.desireCore` 包含 drives、baselines、refractory、fatigue gate、Intimacy action gate、wildcard cooldown、top candidates 与 Thought provenance 计数，不包含 Thought 原文或聊天正文。

## 7. Overlay · FROZEN

- 系统文件选择器在 `TYPE_APPLICATION_OVERLAY` 上方是正常窗口层级；故障是退出后悬浮球可见却无法点击，进入 AI Companion 后恢复。
- v0.31.3+45 实现 bounded cover session：enter 退役旧 input channel，exit 后重建，最多 3 次。
- 真机诊断为 `coverState=idle / session=0 / enter=0 / detach=0 / recovery=0`，证明检测链根本没触发，而不是重建失败。
- 同份诊断 `accessibility=false / accessibilityConnected=false`。以后重开必须先验证 cover detection 与权限前提，禁止继续只调重建延迟/次数。
- 本轮 v0.31.4 不修改任何 Kotlin Overlay/WindowManager 行为。

## 8. TTS · FROZEN / GUARDRAIL

- 行为参考：`MejuTTS_A2_OriginalNative_v2.5.apk`。
- `Yuki -> 有希` 只改朗读文本。
- 只按 `。！？；.!?;` 分句；A2 generation-ahead + FIFO + ready WAV 约 200ms gap。
- 原始 `libbertvits2.so` 前 635,352 bytes SHA-256：`a1ca5180532aae3a7c378371f6ddb44bbf35d8826a8b8750db4fd12179c5551b`。
- 轻微断句停顿和显示版本号遗留一并冻结，不能为了显示重做已可用引擎。

## 9. 下一阶段任务

任务真源：`docs/PROJECT_TASK_LEDGER.md`。

P1：

- v0.31.4 Actions 构建与真机验收；通过后进行本阶段仓库整合/Clean Freeze。
- Notification Experience：前台静音、外部/锁屏通知、提示音/震动/隐私、点击进入悬浮聊天。
- HyperOS 长后台：锁屏、划掉 App、数小时 idle、process recreation、boot/package replaced。
- 50/100/数百轮 Memory/Thought/summary/thread 压力测试。
- 手机/平板 Active Brain 双向 takeover 与 encrypted `.aicomp` fallback。

P2：

- Grounded Desire 真机数据后的主动频率二次调优。
- Intimacy Session 更深整合，但继续保持普通聊天不自动色情化。
- 隐私/安全/可靠性审计与正式 release signing。

## 10. GitHub / 交付流程

- 当前补丁输入必须是仓库中已提交的 `app/` v0.31.3+45。
- 上传 `v0314-grounded-desire-growth.patch` 到仓库根目录。
- 首份 +46 交付曾因仓库内三份项目文档与源码 ZIP 的文档上下文不同，在 `git apply --check` 阶段退出；没有应用源码、没有产生提交，也不是 Flutter 编译错误。
- 修正版将源码补丁与 `v0314-project-docs.zip` 分离：代码保持严格 patch，六份文档经 SHA-256 校验后覆盖到 `app/docs/`，避免文档先前被更新时阻断源码升级。
- 用交付包中的 workflow 完整替换 `.github/workflows/build-v028-apk.yml`，手动运行。
- workflow 顺序：检查 +45 基线 → SHA-256 检查 → `git apply --check --directory=app` → 新 validator/schema 镜像 → 既有 SQLite/TTS/Android 回归 → Flutter analyze/test → release APK → commit `app/`。
- 测试 APK 使用固定测试签名，可覆盖安装；正式发布再换私有签名。
- 大阶段验收后再删除已应用临时 patch，进行完整源码 ZIP/SHA-256 与 Clean Freeze。
