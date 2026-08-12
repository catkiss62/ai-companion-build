# v0.30.0 真机检查

程序级测试先由开发侧完成。真人只检查无法在静态/JVM/CI 环境可靠模拟的 Android 行为。

## A. 后台大脑 / 悬浮聊天

1. 覆盖安装后打开一次完整 App，确认 Active Brain 与悬浮陪伴开启。
2. 深度或快速预检里确认“后台大脑连接”为通过。
3. 回到其他 App，点悬浮球：最近 8 条聊天应直接出现。
4. 在悬浮窗发送一句话：应正常生成并回写主聊天；不能长期显示“她还在重新连接”。
5. 收起/重新展开，历史仍应同步。

## B. Background Presence

1. 连续正常使用其他 App 数分钟，可包含切换窗口、收到普通通知、锁屏后重新解锁。
2. 不要求她每个事件都发消息；这是刻意设计。等待 Gate 自己判断。
3. 约 5-10 分钟后导出一次脱敏诊断。重点看 `native.capabilities.backgroundBrainReady` 与 `database.backgroundPresence` 的 lastWakeReason / lastPerceptionAt 是否推进。
4. 若她主动联系，确认文案不是“检测到你打开了XX/收到XX通知”式机械播报。

## C. 非阻断回归

- 主聊天正常。
- TTS 仍可初始化/朗读。
- reasoning 仍在正文上方。
- Active Brain / transfer_lock 无异常。
