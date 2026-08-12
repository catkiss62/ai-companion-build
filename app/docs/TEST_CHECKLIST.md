# v0.30.3 真机检查

本轮只验 Overlay 回归，不调 Presence 权重。

1. 悬浮球正常点击、拖动、展开/收起聊天。
2. 悬浮聊天点“打开”，必须回到完整 AI Companion。
3. ChatGPT -> 上传文件 -> 进入系统文件选择器 -> 返回；不要打开 AI Companion，等约 1 秒后直接点/拖悬浮球。
4. 重复第 3 步 2~3 次即可，不需要高频压力操作。
5. 正常使用一段时间后直接导出浅层脱敏诊断，不点深度自检。重点看 `selfHealCount / coverRecoveryCount / recoveryInProgress`：正常操作不应像 v0.30.2 那样快速增长到几十次。
6. Presence 只做观察：若有主动联系可记录；没有也不判失败，本轮不改变 v0.30.2 Presence Intelligence。
