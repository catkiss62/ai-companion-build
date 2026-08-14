# v0.32.0 · Somatic Contract & Daily Touch MVP

## 目标与阶段边界

本版是双通道感官的第一阶段，只完成两件事：建立 SQLite 事件/短期聚合契约；让用户文本中的日常触觉在同一轮回复前成为 AI 的短暂身体感觉。

“双通道”完整定义仍是 `user_to_ai` 全强度与已提交 assistant 正文的 `ai_to_self` 半强度。本版没有提前宣称第二方向完成；它会在下一小版本接入 assistant 成功提交事务后。

## SQLite schema v21

`somatic_events` 保存来源事件：

- `turn_id` 指向真实 `messages.id`，删除消息时 `ON DELETE CASCADE`。
- `channel / action / part / scene_key / direction / source` 保存结构化来源。
- `intensity` 只在本地计算；`narrative` 是 AI 身上的自然语言感觉。
- `created_at / expires_at` 保证它是短期状态。
- `UNIQUE(turn_id, direction, scene_key)` 和稳定事件 ID 保证 durable recovery 幂等。

`somatic_aggregates` 每个 channel 一行，保存当前值、最后 scene/narrative、更新时间和过期时间。它不是 Memory、AI Self、Relationship 或 Desire 的第二真源。

## 当前数据流

```text
durable user message + generation job 已提交
  -> Runner 解析日常触觉
  -> Active Brain / transfer lock 二次检查
  -> 幂等插入 somatic event 并饱和合并 aggregate
  -> PromptBuilder 读取并按时间衰减
  -> 仅达到阈值时注入自然语言身体感觉
  -> DeepSeek 正常生成
```

恢复器重新运行相同 job 时使用相同事件 ID，不会重复加值。若用户停止未完成回复，数据库在同一取消事务中撤回 user message、级联删除关联事件，并根据仍有效的其他事件重建聚合。

## 日常触觉词法

第一版覆盖：`embrace / kiss / stroke / pat / pinch / rub / nuzzle / lean / scratch / bite / hold_hand`。部位被归一化为 lips、ear_back、ear、neck、face、head、hand、shoulder、back、waist 或 sensitivity cluster。

词法刻意保守：每轮最多 3 个事件；“抱怨”不会因“抱”误命中；“你抱我”是请求 AI 动作，不算用户触碰 AI。没有命中就完全不注入，不为“在场感”硬塞表演。

## 衰减与 Prompt 红线

- 聚合采用 8 分钟半衰期，事件 36 分钟过期，脉冲用饱和函数合并，不能无限叠到失控。
- 低于 `0.18` 不注入；Prompt 最多显示两条自然语言感觉。
- 数值不进入模型文本；模型被明确要求不报数、不作状态报告。
- 叙事只能描述 AI 身上的感觉，不能声称现实中观察或确认了用户身体。
- 感官不能绕过 Intimacy Session，也不能单独触发成人化或主动消息。
- 原始事件默认不进入 Memory；未来 Proust 候选仍须走既有证据、来源和冲突机制。

## 默认模型与延期 UI 项

新安装默认模型从 V4 Pro 改为 `V4 Flash`，reasoning effort 继续为 `High`。schema 升级不覆盖已有数据库里用户明确保存的模型选择。

长按文本菜单目前出现英文选项，已登记为 UI 本地化待办。本版不改 Flutter/Android localization，避免把感官数据库与系统菜单排查绑成同一风险面。

## 自动化验收

- 亲吻嘴唇生成 `touch__kiss__lips`。
- 明显非接触/反向语句不产生事件。
- 相同 turn 恢复时事件 ID 稳定。
- 衰减到阈值以下后 Prompt 完全不出现身体感觉。
- Prompt 不包含内部强度数字，并保留边界声明。
- schema、Active Brain fencing、取消重建、状态包表、默认模型与 Runner/Prompt 接线由 v0.32.0 validator 固定。
- Python SQLite mirror 额外验证唯一约束拒绝恢复重复事件，删除 user turn 会级联撤销事件。
- 功能 head GitHub Actions run #25 已通过全部静态保护器、Flutter analyze/tests、release APK/Kotlin 和冻结 A2 原生字节校验。
- run #25 artifact：`9230553317`；APK SHA-256：`d1637769a2d63179345c06b55a13497b6d4fbfeba6176caaaa4db3dbf1265587`。

## 下一步

1. 把 `ai_to_self` 放在 assistant 消息成功提交之后，以 0.5 系数写入；取消、失败和 stale writer 不得反馈。
2. 扩展 smell / taste / sound 的保守词法与短语素材。
3. 在证据边界内设计嗅味觉的 Proust 记忆候选。
4. 私密 corpus 最后单独做 Session gate、导出和测试边界。
