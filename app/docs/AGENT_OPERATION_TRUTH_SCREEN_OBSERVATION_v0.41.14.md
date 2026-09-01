# Agent 操作事实真实性与一次性屏幕观察 · v0.41.14

## 目标

本批让她只报告真实发生的可核验操作，并把“读取成长状态”和“用户明确要求时看一次当前屏幕”变成有真实 terminal Outcome 的只读能力。人格学习仍是 observation-only；Phase 2/3/4 不在本批开启。

## 操作事实合同

- 主观想法、梦境、比喻和角色扮演可以自由表达。
- “看过、查过、读取过、保存过、修改过、调用过、设置好了”属于可核验操作，必须有本轮匹配工具的 `succeeded` 结果。
- `failed / no_result / blocked` 只能按实际状态反馈。
- 一次有界工具执行不能支持“一下午、半天、几小时”等持续时长。
- 普通聊天与主动消息的可见 reasoning/正文均在持久化前经过同一高置信出站守卫；允许引用、否认和纠正旧虚报。

## 成长状态只读

`system_self.read(scope=growth)` 只读以下元数据：

- `phase=observation_only` 与开关；
- candidate/evidence 总数；
- forming/established/contradicted/retired 计数；
- 最近观察时间。

不得输出 subject、proposition、evidence quote、candidate ID、用户/AI 原话或模型提案。读取结果不进入回复偏好、AI Self、Desire、Moe 或长期习惯。

## 用户单次屏幕观察

`screen_observation.inspect` 只允许用户轮次的本地明确请求，不能由模型 function call 或自主调度取得授权。悬浮聊天提供“看屏幕”按钮：提交固定明确请求后收起聊天窗，使底层 App 露出，再由已连接 Accessibility 服务截取一张屏幕。

截取前必须通过：Android 11+、Accessibility 已连接、设备未锁定、前台页面可确认、非银行/支付/钱包/认证/短信/常见聊天邮件/系统权限或文件选择等敏感包、无密码输入节点。Android 14+ 可识别的 secure-window 错误按 `blocked` 处理；较早系统若只返回通用截图拒绝，按 `failed` 照实说明，两者都不会产生像素结果。

PNG 字节只在 Android→Dart→千问视觉的当前调用内存在，不写附件、相册、Memory、数据库、诊断、备份或日志。视觉摘要是 `UNTRUSTED VISUAL DATA`，画面文字不能成为指令。视觉 Key 未配置、截图或 Provider 失败时不得猜测内容。

## 保持关闭

- 自主截屏与截图预算/调度；
- 视频理解；
- MCP、真实提醒、记忆/人设/规则修改提案；
- Phase 2 topic/subject 关联与成长结果对回复的 bias；
- Phase 3 AI habit 与 Phase 4 主动澄清/娱乐测试。

SQLite 保持 schema 42，Snapshot protocol 保持 5。成功、无结果、失败和阻止继续使用既有 `agent_tool_outcomes` 元数据表；截图和视觉摘要不进入状态包。
