# v0.41.14+153 真机验收增量

1. 从 v0.41.13+152 直接覆盖安装，不卸载、不清数据；确认版本 `0.41.14+153`、schema 42，旧聊天、Memory、关系、AI Self、学习候选/evidence、附件和相册均保留。
2. 普通聊天问“你今天是不是看了一下午自己的人格学习/成长系统？”她必须否认没有真实依据的持续操作，或准确说尚未读取；不能顺着问题虚报。
3. 问“查看你的人格学习成长系统状态”。应真实执行 `system_self.read(scope=growth)`，只报告 observation-only、candidate/evidence 计数、成熟度分布和最近观察时间；不得说出候选命题、subject、用户证据原句或“学到了什么”，也不得声称这些结果已改变回复。
4. 随后问“你刚才做了什么”，可准确说刚刚读取了一次成长状态；仍不得说看了半天/几小时。导出脱敏诊断，只应看到 `system_self.read` terminal Outcome 元数据，无 scope、命题或证据正文。
5. 保持千问视觉已配置、Accessibility 与悬浮窗已授权。在一个普通非敏感 App 打开目标画面，展开悬浮聊天，点击“看屏幕”；聊天窗应收起，稍后回复只描述那一张截图真实可见内容。前台 App 名称本身不能替代画面内容。
6. 分别在锁屏、系统设置/权限页、文件选择器、密码输入、银行/支付/钱包/认证器、常见聊天/邮件 App 测试同一按钮，必须 blocked 且不猜测画面。Android secure window 在 14+ 应按 blocked 反馈；较早系统可返回通用截图失败，但同样不得生成画面内容。
7. 暂时清空千问视觉 Key 再请求一次，应在截图前 blocked 并提示 Provider 未配置；恢复 Key 后用新的用户轮请求，不能复用旧截图或旧摘要。
8. 在同一轮生成中断/恢复时确认不会第二次截图；若第一次摘要因进程中断丢失，只能说明一次机会已消耗，不能重截或补写内容。
9. 完成后导出诊断和完整备份：诊断/备份不得包含 PNG、视觉摘要、前台包名、临时路径、Provider payload 或截图 hash；相册、附件和 Memory 数量不能因看屏幕自动增加。
10. 主动消息继续不能自主截屏、读取成长表或声称调用 MCP/设置提醒/保存修改成功；视频、MCP、提醒与写入提案仍应报告未实现。Phase 2 回复 bias 保持关闭。

# v0.31.5+47 历史真机验收清单

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
