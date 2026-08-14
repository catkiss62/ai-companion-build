# v0.31.7 · 真正停止生成

## 目标

用户在普通发送或 durable recovery 期间点击停止后，同一轮必须同时终止：

1. 当前 DeepSeek HTTP 流；
2. reasoning/content 的流式 UI；
3. 流式和已排队的 TTS；
4. SQLite durable generation 的自动恢复资格。

停止不是“暂时隐藏”或“只停语音”。该轮进入终态 `cancelled_by_user`，保留已经提交的用户消息，但不会补写 assistant 消息。

## 实现

- 每个模型流使用独立 HTTP client；`GenerationCancellationToken` 触发时只关闭这一轮请求，不影响 Memory 等 JSON 请求或下一轮聊天。
- `cancelGenerationJobByUser()` 单条 UPDATE 把 `pending/running/retry_wait` 变为 `cancelled_by_user`，同时清空 `run_token`、partial checkpoint 和 `next_retry_at`。
- 原有 `checkpointGenerationJob` 与 `completeGenerationJobIfCurrent` 都要求 `status=running + run_token`，因此取消后晚到 token 不能再 checkpoint，也不能原子插入 assistant。
- Runner 在流内最多约 200ms 复核一次 SQLite ownership；这使 foreground、Overlay 和 headless recovery 之间也能看到取消，而不只依赖当前 Flutter 对象。
- ChatController 的同一个停止入口先发 in-memory cancel，再停 TTS、作废 durable job，并使 recovery timer epoch 失效。
- 发送按钮在生成时直接变成停止按钮；停止过程中显示“正在停止…”。

## 竞态语义

`completed` 与 `cancelled_by_user` 谁先完成 SQLite 终态写入，谁获胜：

- cancel UPDATE 先成功：run token 被清空，晚到 completion 必须失败；
- completion transaction 先成功：回复已经完整提交，随后 stop 只能停止朗读，不能删除已完成消息。

这避免为了追求视觉上的“停止”而删除一个已经原子完成的回复。

## 不变项

- schema 继续为 v20，无迁移。
- 用户消息继续保留，便于用户直接发送下一句。
- 不修改 Meju A2 native/MNN、断句、generation-ahead 或 FIFO 基线。
- 不修改 Prompt、规则层、Desire/Thought、Memory、Overlay WindowManager。
- 测试阶段仍使用 Actions 每次生成的一次性签名，安装前卸载旧 APK。

## 验证

- cancellation token 幂等与异常语义单测；
- `cancelled_by_user` 为 terminal/non-blocking 单测；
- 静态 validator 检查 HTTP 关闭、DB fencing、runner cross-engine fence、controller/TTS 和 UI 停止入口；
- Flutter analyze、全套 tests、release APK 与 A2 native payload 校验。
