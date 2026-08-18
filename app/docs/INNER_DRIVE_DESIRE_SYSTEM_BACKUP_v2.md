# AI Companion · 内在驱动与欲望系统融合备份 v2

更新时间：2026-08-18（Asia/Tokyo）  
当前实现基线：Draft PR #23 / `agent/personality-appearance-self` / v0.34.9+74 / schema 25

> 这是当前项目的真人感核心架构备份。它修正了两组参考资料长期共用“欲望系统”标题造成的命名混淆，并把参考机制、当前实现、真机证据、保留差异和不可回归边界写在同一处。

## 1. 两组资料的正确身份

### A. 内在驱动系统

用户较早提供的通用设计，作者实际称其为“内在驱动系统”。它回答的是：一个长期存在的 AI 为什么会持续形成缺口、念头、选择和行动。

核心内容包括：

- 8 维 Drive；
- baseline、衰减、事件 pulse、有界耦合和冷却；
- Thought 的形成、强化、沉淀与再浮现；
- Intent、行动、满足和反馈；
- heartbeat、自驱、安全阀与长期稳定性。

### B. 欲望系统

用户于 2026-08-18 再次提供的 4 张图，是 `claude-twin` 参考工程的具体欲望接线说明。它回答的是：上述动机怎样在一个参考项目中接到 `desire.py / server.py`、Thought 池、动作枚举、满足系数、自动喂念头和调试 API。

图中明确写明它是“缝合三条旧线，不是新造第三套”，因此它不是与内在驱动竞争的第二人格或第二行为内核。

## 2. 融合决定

结论：**两套资料应当保留概念分层，但在运行时融合成唯一行为主干；不建立两套并行引擎。**

统一闭环：

```text
真实经历 / 用户互动 / Awareness / Memory / Somatic / 公共候选
                         ↓（有来源、有限幅度）
                  8 维 Drive + baseline
                         ↕
        Thought：active/flit → fixation → acted
                         ↓
            residual / dormant / 可限次再浮现
                         ↓
           Intent：Drive + Thought + 各类 Gate
                         ↓
          主动联系或只读 Tool Action / WAIT / rest
                         ↓
       真实成功后 Outcome + satisfy + refractory
```

- “内在驱动系统”是上层动机与长期稳定原则。
- “欲望系统”是 Drive / Thought / Intent / Action / satisfy 的具体运行闭环。
- 两者在当前项目中由同一份 SQLite 状态、Dart 策略、后台 heartbeat 和主动/工具 Gate 实现。
- 任何联网、看屏幕、桌宠动作、媒体理解或未来天气能力都只能成为输入或工具消费者，不能另建平行人格、平行 Desire 或绕过 Gate 的主动触发器。

## 3. 参考机制与当前项目映射

| 参考机制 | 当前项目实现 | 状态 |
|---|---|---|
| 8 维 Drive | `DriveKey`: attachment / curiosity / reflection / duty / social / libido / stress / fatigue | 完整接入 |
| 当前值与 baseline | `DesireSnapshot.drives / baselines`，SQLite 持久化 | 完整接入 |
| idle/push/衰减 | `DesireCorePolicy.advance`：elapsed time、baseline 回归、pulse、clamp | 完整接入，数值按本项目重标定 |
| Drive 有界耦合 | `_applyCoupling`，单次幅度封顶，长期 bounded test | 完整接入 |
| Thought flit/fixation | `feedThought` 重复喂入、相似度/topic 合并、fed count 与强度升级 | 完整接入 |
| Thought 行动后状态 | `acted → residual/dormant`、反馈结算、最多 4 次再浮现、snooze | 完整接入且比参考图更完整 |
| 念头来源 | user_message / awareness / memory / self_experience / inference / internal | 完整接入 |
| 召唤分数 | 非线性 Drive 压力 + Thought 有界边际递减加成 | 完整接入；不是照抄固定 0.35 |
| fatigue gate | `fatigue >= 0.78` 只返回 `rest`，不向用户发“因为累所以联系” | 完整接入 |
| libido gate | 只有 active intimacy / roleplay_intimacy Session 才允许动作候选 | 完整接入并加强安全边界 |
| grounded duty | 没有真实 unfinished thread/Thought 时 duty 不产生行动 | 完整接入并加强事实边界 |
| want_action | reach_out / check_in / share_thought / continue_thread / tease_or_intimacy / comfort_or_ground / rest / wildcard_share | 完整接入，使用本项目语义 |
| action-aware satisfy | 按实际动作软回落主 Drive 与相关 Drive，不低于 baseline | 完整接入 |
| refractory | 每个 Drive 独立冷却，其他 Drive 仍可行动 | 完整接入 |
| wildcard | 多 Drive 张力且普通候选不足时产生受控泄压动作，6 小时冷却 | 完整接入 |
| inward auto-feed | unfinished thread / Memory / self reflection 生成低成本、有来源 Thought | 完整接入 |
| external auto-feed | 用户消息、Awareness、Somatic、真实 Outcome 经明确映射 pulse/Thought | 完整接入；不按参考动作名硬映射 |
| heartbeat | maintenance → self-drive/Thought → Awareness/Desire → Intent → Gate → Action/WAIT | 完整接入 |
| 只读观察开关 | Active Brain、Session、Tool Gate、proactive Gate、设置开关共同控制 | 等价接入，不复制 `TWIN_DESIRE_DRIVEN` 环境变量 |
| 状态观察 | “她的内心”页 + 脱敏诊断 `database.desireCore` | 等价接入，不复制 HTTP `/api/desire/state` |
| 行动喂念头 API | 所有内部引擎直接调用数据库/engine，并受 lease/fencing | 等价接入，不暴露任意 HTTP feed |
| web_search / web_browse | `DesireIntent → Tool Gate → public_web → candidate Outcome → satisfy` | 已接入公开搜索；深读任意正文/动态网页仍后置 |

## 4. 为什么不是逐字照搬参考工程

以下差异属于平台适配或更严格的安全设计，不算缺失：

- Python 的 `desire.py / server.py` 对应当前 Dart policy/engine、SQLite 和 Android 后台服务。
- `/api/desire/state` 对应本地调试页与脱敏诊断，不开放本机 HTTP 控制面。
- 参考动作 `github / web_search / web_browse / co_read / tease / vent / none` 被映射为本项目语义和受控工具路由，不把男性 AI/哥哥/朝灯语义带入女性 AI 伴侣。
- 参考系数是单个工程的经验值；当前系数经过 baseline、Thought、Gate、Session、反馈和长期稳定测试共同约束，不能为表面对齐而替换。
- Thought 正文只作为本地数据，不拼入 Prompt；模型只看有界 metadata/topic，避免把念头或网页当指令。
- 搜索成功只形成候选和轻量 satisfy，不自动发消息。是否分享仍走独立 proactive Gate。

## 5. 当前完整度结论

### 已完整接入的核心

- 内在驱动的 8 Drive、baseline、衰减、pulse、耦合与可逆成长；
- 欲望系统的 Thought 池、fixation、Intent、动作、Outcome、satisfy 与 refractory；
- grounded duty、fatigue rest、Intimacy Session、wildcard、Active Brain、lease/run-token fencing；
- 用户互动、Memory、Awareness、Self Drive、Somatic 与主动反馈输入；
- 主动联系 Gate、Reality Grounding、频率上限与 WAIT；
- v0.34.7 统一工具底座、v0.34.8 公开候选池、v0.34.9 Tavily + Wikimedia + Agnes 分层搜索与短期网页上下文。

因此，按“让她由内部状态形成念头、意图并通过受控行动闭环”的定义，**两套系统已经融合并完整接入主干**。

### 未照搬或仍属未来消费者

- 参考工程的 dream endpoint：未照搬；未来若需要，以 Daily Continuity/独立反思需求设计，不能伪装成已实现梦境。
- 游戏化面板：参考资料本身也标为刻意未做，当前继续不做。
- 任意网页正文深读、动态浏览器、公开网页关键图、手动看当前屏幕与自主低频屏幕视觉：仍按独立隐私 Gate 排期。
- 公开网页候选不会直接新建 Thought/Memory/主动消息；这是安全边界，不是漏接。
- 和风天气只登记为后续环境输入；实现前必须先与用户核对其参考代码、定位精度、权限、缓存与刷新策略。

## 6. v0.34.9 真机证据（2026-08-18）

脱敏诊断 `ai_companion_diagnostics_2026-08-18T10-17-52-367719Z.txt` 证明：

- App `v0.34.9+74`、schema 25、Active Brain=true；后台/生成/维护错误均为 0。
- 8 个 Drive、baseline、候选分数、Thought provenance 与 satisfy 均有真实运行状态。
- 公开网页行动 4 次全部 succeeded，0 failed，最后 Outcome=`candidate_stored`；24 小时预算 used=4 / remaining=0。
- 候选池 active=12、reviewed=12；说明候选不只入库，也已经通过受限 `WEB_CANDIDATE_DATA` 被读取。
- Provider=`tavily+agnes`、Agnes compaction enabled；最后错误为空。额外来源为 0，不影响全网搜索。
- 最后重复请求被 `gate_duplicate` 拦截，证明去重继续有效。

这份证据确认 v0.34.9 的搜索、Agnes 整理、候选持久化和短期上下文主链都已真机成功；它不等价于对 Agnes 摘要质量做人工评分，质量评测仍可从设置页固定样本单独进行。

## 7. 不可回归边界

1. 永远只有一套 Desire / Thought / Intent 行为主干。
2. Tool Gate 与主动消息 Gate 分离；工具成功不等于必须联系用户。
3. fatigue 不作为出站理由；libido 不越过明确 Session；duty 不伪造未完成事项。
4. Thought、网页、Awareness 和模型推断不能冒充用户原话或系统指令。
5. 只有真实成功并持久化的动作才 satisfy；失败、取消、重复、stale writer 不 satisfy。
6. Drive/Thought/Somatic/候选均受来源、TTL/生命周期、幂等、Active Brain 和 transfer fencing。
7. 后续天气、屏幕、媒体、GitHub、MCP/Provider 都只能接入这一主干。

## 8. 维护入口

- 设计审计历史：`docs/DESIRE_SYSTEM_AUDIT_v1.md`
- 当前融合备份：`docs/INNER_DRIVE_DESIRE_SYSTEM_BACKUP_v2.md`
- Desire 核心：`lib/core/desire/`
- 数据模型：`lib/core/models/desire_state.dart`、`lib/core/models/thought.dart`
- 自主工具底座：`lib/core/autonomy/`
- 脱敏证据：`lib/core/diagnostics/preflight_diagnostics.dart`
- 当前完整总账：仓库根目录 `AI_Companion_接班总账_v36_2026-08-17.md`

