# D3.2 桌宠动作语义分层与自主调度（v0.33.8+63）

## 目标

让桌宠消费现有的 Desire、Thought、视觉 mood 与空闲时长，而不是新建第二套人格、随机性格或主动消息系统。Dart 仍是内在状态的唯一权威；Android 只接收不含 Thought 正文的只读投影并播放已注册动作。

## 状态投影

- Desire：读取 8 个既有 drive，选择当前主导 drive 与强度。
- Thought：只读取 metadata；活跃 Thought 的 drive 与 strength 可以提高 `THINKING` 的优先级，正文不会跨 MethodChannel。
- mood：不是新数据库字段，而是 Desire / Thought 的只读视觉投影：`calm`、`sleepy`、`tense`、`warm`、`curious`、`reflective`。
- Active Brain / transfer lock：复用 `brainWorkAllowed()`；待机脑或转移冻结时关闭自主动作消费。
- 空闲时长：只在桌宠无触摸、无聊天、无物理运动时累计；用户触摸或进入对话后重新计时。

## 仲裁顺序

1. 抛掷、拖拽、落地和触摸反应。
2. 对话生成与真正的 TTS 播放。
3. Desire / Thought / mood 语义动作。
4. 低频 `BLINK` / `GLANCE` 微动作。

TTS `synthesizing` 继续保持无 `TALKING`，并暂停自主动作；只有 `playing` 才进入 `TALKING`。聊天面板展开时也暂停自主动作。

## 动作映射与节奏

- 12 秒以上空闲：允许低频 `BLINK` / `GLANCE`，18 秒冷却，使用稳定时间桶而不是新随机数系统。
- 45 秒以上空闲且语义强度足够：
  - curiosity / curious → `WALKING`；自由/半屏模式内做约 2.2 秒受边界约束的水平移动，结束后直接回正面 `IDLE`。
  - reflection / duty / 强 Thought → `THINKING`。
  - attachment / social / libido / warm → `HAPPY`。
  - stress / tense → `GLANCE`。
- fatigue、深夜或 sleepy → `YAWNING`。
- sleepy 且空闲至少 3 分钟：哈欠结束后进入 `SLEEPING`。

语义动作冷却为 55 秒。任意触摸、聊天、TTS、拖拽或抛掷都可立即打断自主动作。

## 哈欠帧序列

运行时新增内部动作 `YAWNING`，但不改上游 18 项注册表：

`daily_transition_00 → sleepy_yawn → sleepy_yawn → daily_transition_00`

共 1.2 秒，每帧 300ms；重复 `sleepy_yawn` 形成约 600ms 的哈欠停顿。素材来自完整 417 文件源包中的 PNG 候选，不依赖 GIF。

## 明确不做

- 不使用 `walk_side_stand`；侧走结束直接切回正面更符合已确认的萌感。
- 不使用 `falling_v2`；悬空、轻放 180ms 触地帧与落地逻辑保持 v0.33.7 的完整回滚结果。
- 不让动作反向修改 Desire / Thought，也不让动作层发送主动消息。
