# v0.31.9 · TTS State & Cancelled-turn Withdrawal

## 目标

本版只解决两个交互一致性问题：让 App 与原生悬浮聊天准确显示同一条语音的合成/播放状态；让用户停止尚未完成的回复时，整条未完成 user turn 从后续对话事实中撤回。

## TTS 状态契约

`TtsPlaybackQueue` 是唯一状态真源，新增三态与 owner：

- `idle`：没有有效会话，显示 `Icons.volume_up_outlined` 对应的 outline 喇叭。
- `synthesizing`：TTS session 已建立，但当前没有音频正在播放；包括文本清理、切句、native 合成、等待下一段 WAV，以及自动流式 TTS 尚未拿到首个可播段。显示“…”且禁止重复点击。
- `playing`：队列已把一段 prepared audio 交给 `playPrepared()`，直至该 Future 完成。显示“■”，点击即 `stop()`。

每个 session 可携带 `ownerId=assistantMessageId`。手动朗读、完整回复自动朗读、流式自动朗读、悬浮框打开后主动消息朗读都绑定真实 assistant ID；结束或 stop 后 owner 清空。

这只是 Dart 调度层状态外显，不修改冻结的 Meju A2 native/MNN、文本替换、断句、generation-ahead、多段 FIFO 和 ready-audio 间隔。

## 两套界面

### Flutter App

- 每条 assistant 气泡按 owner 显示喇叭 / “…” / “■”。
- 流式临时气泡按当前 generation 的 assistant ID 显示自动 TTS 状态。
- 移除顶部重复的全局停止语音图标；停止离正在播放的消息更近。

### Android WindowManager 悬浮聊天

- 删除左上角“停语音”。
- 用本地 vector drawable 表现与 Flutter `volume_up_outlined` 同类的 outline 喇叭，不再使用彩色 emoji。
- 展开期间每 160ms 通过 `ttsSnapshot` 只读 phase + owner；收起立刻停止 UI 轮询。
- 手动点击后先乐观显示“…”以覆盖 MethodChannel 往返；后台真状态随后校正。播放中的“■”会先乐观回到喇叭再请求 stop。
- generation snapshot 携带 assistant ID，使流式临时气泡不会误显示另一条旧消息的手动朗读状态。

## 取消轮撤回契约

旧行为把 user message 与 generation job 一起创建，但停止只更新 job，所以用户输入仍在 `messages`，未来 Prompt 会再次读取。

新版 `cancelGenerationJobByUser()` 在一个 SQLite transaction 内：

1. 读取 job status 与 `user_message_id`；
2. 仅当状态为 `pending / running / retry_wait` 时写入 `cancelled_by_user`，清空 partial、run token 与 retry；
3. 同一 transaction 删除该 user message，并清理理论上不应存在的同轮 post-turn job；
4. 对已经是 `cancelled_by_user` 的旧半完成状态执行幂等清理；
5. 若状态已是 `completed` 或其他非活动终态，不删除任何消息。

因此：

- cancel transaction 先赢：晚到 checkpoint/final commit 因 status/run-token 不匹配而失败，user turn 也不可被未来 Prompt、Memory extraction 或恢复器读取。
- completion transaction 先赢：完整 user/assistant 对保留；稍晚的停止最多停止语音，不制造孤立 assistant。

取消前已经在内存中发生的网络读取无法“逆转时间”，但取消后的 partial assistant 不落库，用户原文不再存在于语言历史或后续记忆抽取输入。生成前例行维护和非文本通用 Drive tick 不作为用户原话保存。

## 数据与边界

- App 版本：`0.31.9+51`。
- SQLite schema：20，无迁移。
- 不改 API、Prompt builder、行为规则、Desire/Thought 模型、Memory 模型、主动联系、权限与 Active Brain。
- 不宣称修复冻结中的文件选择器返回后悬浮球触摸问题。

## 自动验证

- TTS queue 测试覆盖 owner 与 `synthesizing -> playing -> idle`。
- 流式自动 TTS 测试覆盖首段音频前即进入 synthesizing。
- cancellation contract 测试守住 transaction、active-status fence 与 user-role 精确删除。
- v0.31.9 validator 同时检查 Flutter、Dart bridge、Kotlin overlay、drawable、数据库和版本契约。
- 完整 Actions 仍运行全部历史 validators、Flutter analyze/test、release APK 与 A2 native payload 字节校验。

## 真机验收

1. App 手动点喇叭：慢合成时“…”；出声后“■”；点击停止回喇叭；自然结束也回喇叭。
2. 悬浮框重复同一流程，确认喇叭外观不是 emoji，左上角无“停语音”。
3. 开启自动流式朗读：发送后首段未出声时临时回复气泡出现“…”；出声切“■”。
4. reasoning 尚未开始、reasoning 中、正文中分别停止：刚发送的 user 气泡和临时 assistant 都消失。
5. 收起/重开悬浮框、打开完整 App、重启进程后，取消轮都不复活，也不被下一轮回答引用。
6. 极接近完成点反复测试：只允许“完整 user+assistant 都保留”或“两者都不落历史”，不得出现孤立 assistant。
