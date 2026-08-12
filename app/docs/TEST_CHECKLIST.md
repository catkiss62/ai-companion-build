# v0.30.2 真机检查

程序级策略、结构、回归、Flutter analyze/test/release build 先由开发侧/CI 完成。真人只检查 Android/HyperOS 真机行为。

## A. 系统页面遮盖后的悬浮球恢复

1. 保持悬浮球开启，在 ChatGPT 等其他 App 进入“上传文件 -> 系统文件选择器”。
2. 不管是否选择文件，返回原 App；**不要打开 AI Companion 主界面**。
3. 直接点击/拖动悬浮球。预期 0.5~1.5 秒内可正常交互。
4. 再做一次系统设置页或锁屏/解锁往返。
5. 若卡死，直接打开 AI Companion 并导出脱敏诊断；重点看 `overlayTouch.inputSuspect / lastSystemCoverAt / lastCoverRecoveryAt / coverRecoveryCount`。

## B. Presence Intelligence

1. Usage / 通知访问 / Accessibility / 通知权限尽量开启。
2. 正常使用手机 5~15 分钟，可切换 App、收到普通通知、锁屏解锁；不要为了测试反复刷事件。
3. 不要求她立刻主动说话。之后直接导出浅层脱敏诊断。
4. 重点看 `database.backgroundPresence.presenceMomentum / presenceSignalClass / presenceLastThoughtAt / lastGateBreakdown`。
5. 如果主动联系，文案不能包含 App 包名、通知原文或“系统检测到”式机械播报。

## C. 非阻断回归

- 悬浮聊天历史/发送正常。
- 主聊天正常。
- TTS 仍可朗读。
- reasoning 在正文上方。
- Active Brain / transfer_lock 无异常。
