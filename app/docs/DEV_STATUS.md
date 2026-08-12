# v0.30.3 开发状态 · Overlay Regression Repair

- 版本：`0.30.3+39`；数据库 schema 仍为 v18，无迁移。
- Presence Intelligence 完全继承 v0.30.2：Presence Momentum / Thought / bounded presenceBoost / Gate breakdown 不调参。
- 真机证据：v0.30.2 正常使用期间出现 `overlaySelfHealCount=28`、`overlayCoverRecoveryCount=11`，属于明显过度恢复；“打开”完整 App 也出现回归。
- v0.30.3 不再把所有 system app 当作 cover，只识别 DocumentsUI / PermissionController / PackageInstaller / Settings / Xiaomi 明确系统界面。
- Window visibility fallback 增加 scheduled/in-progress 重入锁与 8 秒最小恢复间隔；恢复自己的 remove/add visibility 回调不能再次触发恢复。
- Full Activity resume 不再无条件重建 bubble input channel；只有明确 `overlayInputSuspect` 才重建。
- 悬浮聊天“打开”改成先请求 `startActivity()`，不再先 collapse/self-heal；MainActivity.onResume 再负责收起 overlay。
- 脱敏诊断继续保留 overlayTouch，并新增 `recoveryInProgress`。
- TTS A2、Memory、Relationship、Active Brain、Transfer、Background Presence 均冻结。
