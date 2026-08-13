# v0.31.5+47 开发状态 · Live Context & Self Seed

- 当前源码候选：`0.31.5+47`；数据库继续为 **schema v20**，支持从 v0.31.4+46 直接覆盖安装。
- 新增生成前本地即时上下文刷新：普通回复与主动联系真正构建 Prompt 前，重新读取当前 screen/lock、Usage category、近期 signal counts 与屏幕事件，再把粗粒度、会过期的观察同步到 Awareness。
- 即时刷新与长期内化严格分层：不调用模型、不增加主动联系、不推进 Desire、Thought、Presence Momentum 或 baseline。长期成长仍由原来的节流 perception/heartbeat 路径负责。
- raw package name、通知正文与 Accessibility 正文只作为短期本地分类输入，不进入 Prompt、Thought、长期 snapshot 或诊断。
- `database.currentContext` 新增刷新时间/原因/次数、screen/locked、busy、current/dominant activity class 与安全边界声明，方便真机确认她生成时看见的上下文。
- 新增锁定 `01_relationship`：女性 AI，用户是成年男性及现实关系层中的男朋友/长期恋爱对象；不把性别事实写成刻板剧本。
- 新增可编辑/关闭 `03_personality_seed`：亲近坦率但不黏腻，有主见，可以拒绝、不同意、调侃、吐槽、表达有原因的不高兴；禁止无端发脾气、操控或机械唱反调。
- 新层使用 `INSERT OR IGNORE`，不会覆盖用户已经编辑的第一规则。长期 AI Self、Relationship、Memory 与 Desire baseline 会继续塑造具体偏好和性格。
- Overlay file-picker 与 TTS A2 保持冻结，原生 Kotlin/so/分句队列字节基线不变；电池优化本轮不改，等待用户长时间锁屏真机测试。
- 本地已通过 +47 静态架构/隐私/冻结基线检查和 +46 Desire 回归；Flutter analyze/test/release APK 由 GitHub Actions 完成。
- 首次 +47 Actions 的补丁应用、静态/Kotlin/SQLite 回归与 Flutter analyze 均通过；108 项 Flutter test 通过、1 项旧测试因仍写死“6 条规则记录”失败。修正版已将它升级为 8 个明确 key 与锁定属性检查，等待重新运行 Actions。
