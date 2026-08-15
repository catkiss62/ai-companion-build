# 桌宠坠落视觉还原 D3.1.2（v0.33.7+62）

## 本版决定

- 真机确认 `falling_v2.png` 的悬空观感不如 v0.33.5，因此不再把候选图注册为运行时动作。
- 悬空、抛落、反弹和短距离轻放全部恢复 v0.33.5 的单一 `FALLING` 姿势与原切换时序。
- 删除 v0.33.6 新增的内部 `BOUNCING` 动作和物理 `floorContact` 信号，不保留 180ms 触地补帧。
- 短距离轻放恢复为原来的 `FALLING → 约 180ms → LANDING`；普通抛落稳定时恢复为直接 `LANDING`，重摔仍可接 `DIZZY`。
- 不使用 `walk_side_stand`：走路停止后回到正面姿势，保留突然转正面的可爱感。
- 哈欠动作继续保留给 D3.2：`daily_transition_00 → sleepy_yawn → sleepy_yawn（停顿）→ daily_transition_00`，建议总长约 1.2 秒，只由疲劳、深夜或准备睡觉的自主意图触发。

## 保持不变

- App 内聊天与原生悬浮聊天继续共用同一套 `THINKING/TALKING` 状态。
- TTS `synthesizing` 不触发 `TALKING`；正文流式输出与真实 TTS `playing` 才触发。
- 未读角标继续按窗口顶部 8%、右侧 21% 定位；竖屏底部安全距离继续为 16dp。
- schema 保持 21，无数据库迁移。

## 真机重点

- 确认空中重新使用上一版原 `FALLING` 姿势。
- 确认低高度轻放恢复为上一版短促悬空帧后落地。
- 确认普通抛落、反弹和重摔眩晕时序与 v0.33.5 一致。
