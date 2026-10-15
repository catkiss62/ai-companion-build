# +350 恢复原自主游玩选项

2026-10-14 12:21（北京时间）用户改变决定：游戏厅恢复原来的“三次操作＋30分钟”方式。基线+349，目标0.42.106+350，分支agent/v042106-restore-arcade-modes。

普通play_game/resume_game/self_reset_and_resume恢复原progress/resumeCheckpoint入口，不授予10分钟窗口；原三次有效状态变化或25分钟检查点继续回到Desire竞争。长选项play_game_session/resume_game_session仍授予原30分钟窗口，兴趣/疲劳/饱和判定与操作调度间隔保留。移除自主10分钟入口和参数；+349旧10分钟自主时钟在升级/恢复后不再生效，不自动换成30分钟。用户明确委托的1—30分钟任务仍是独立任务，10分钟委托不受影响。

保留+349手机记录按需读取、来源与塔罗信息、购物车默认隔离、愿望机制处置；这些文件不做回退。保留已经通过的时钟身份/恢复保护、到期不多走一步以及明确夜间限时的兼容修复。用户本次变更是恢复自主游玩选择方式。

正常回归覆盖三次操作检查点、30分钟到期、旧10分钟自主预算失效、用户10分钟委托、重复进入与恢复保护，以及原手机/愿望回归。CI PASSED / APK READY / TRUE DEVICE PENDING。只进行正常测试和构建，额外整体Astra审查留待后续。


## 交付证据

APK于2026-10-14构建完成，2026-10-15续接后核对并补齐交付记录。源码7587b6115dd5ea0a111a69a6cc86cfc874c235cb / 本地794b5ec，同树0415798239d1fb529cabc1e23a5d06c41382310f。327项相关回归与23项发布身份案例通过。完整Actions38511927400 / build115683624278成功：150源码门、Kotlin、Dart分析、2178全量Flutter、168打包前回归、Android15/8的52/22项全部通过。

Release412349810保持Draft，APK资产639268243，737289985 bytes。版本0.42.106+350与包名已核对；SHA-256 1bf59a21d901a97e39e866709ec7c5eeca4939291b76cf915d5d461db5352ef3，证书305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148与+349一致。

[下载更新APK](https://github.com/catkiss62/ai-companion-build/releases/download/untagged-55ff52cf3685d6f2081a/AI-Companion-v0.42.106-350-Original-Arcade-Modes-APK.apk)。源码与交付证据已保存到项目；真机验收和额外整体Astra审查待后续，未合并main或公开发布。完整证据见AI_Companion_当前总账.md的+350正式交付。
