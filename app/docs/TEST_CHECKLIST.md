# v0.31.5+47 真机验收清单

本版只验收生成前即时设备上下文、男性用户关系事实和初始性格种子。悬浮球 file-picker、TTS 轻微停顿与电池优化继续冻结，不判本版失败。

1. 从 v0.31.4+46 覆盖安装，既有聊天、思考、规则编辑、Memory、Desire/Thought 与设置仍存在；诊断显示 schema v20。
2. 到“更多 → 行为规则层”，确认新增锁定的 `01_relationship · Relationship Foundation` 与可关闭的 `03_personality_seed · Initial Personality Seed`。
3. 用户此前手工修改的 `01_core` 内容必须原样保留；新版本不能用默认文本覆盖它。
4. `01_relationship` 开关不可关闭，但内容仍可编辑；`03_personality_seed` 可关闭、编辑及恢复默认。
5. 打开性格种子后做几轮有分歧的话题：她可以保留意见、拒绝或追问，但不能为展示个性而每轮唱反调，也不能无缘无故发脾气。
6. 对话出现性别称谓时默认用户是男性/男朋友；不要误称女朋友、姐妹，也不要每轮机械强调“男友”。
7. 分别在游戏、视频、阅读/浏览、聊天等 App 停留后回到 AI Companion 发消息。导出诊断，`database.currentContext.lastRefreshReason` 应为 `prompt_user_turn`，`lastRefreshAt` 接近该轮生成时间，`currentActivityClass` 是粗粒度类别而不是包名。
8. 让她主动联系后导出诊断，`lastRefreshReason` 应为 `prompt_proactive`。主动思考可参考生成当下的 screen/activity/busy，但必须用“看起来/可能”等不确定表达。
9. 即时刷新前后 Desire/baseline 不应因为一次打开 App 而突跳；诊断固定显示 `desireAdvancedByRefresh=false`。
10. 脱敏诊断不能出现 raw package、通知正文、Accessibility 正文或聊天正文，并显示 `rawPackageOrTextIncluded=false`。
11. 关闭性格种子后重复一组对话，确认额外初始性格约束不再加载；已有 AI Self/长期记忆仍会保留，不应被关闭动作清空。
12. TTS、Overlay、通知、主动联系 hard caps、Reality Grounding 与状态包导入导出做冒烟检查，确认没有跨域回归。
