# 回归经验与证据入口

这是从现有记录和测试提炼的防回归索引，不是三个月全部历史问题的穷尽清单。原始过程、失败尝试和真实验证范围仍保留在唯一总账及历史专题。只有找到证据才登记为历史问题；设计提醒不冒充已复现漏洞。

| 领域 | 已有问题/容易回归的边界 | 修改时核对 | 证据 |
| --- | --- | --- | --- |
| 聊天与主动召回 | 多剧回顾曾覆盖完结，助手转题后用户简答曾归入旧剧；子集索引淘汰大集并与另一引擎争用临时文件 | 用原始说话人定话题边界，小集合不清大集，按文件哈希原子发布 | proactive_topic_evidence、local_semantic_index、turn_recall_trace 测试 |
| 普通聊天换档和重生成 | 同一消息 ID 可对应新正文；旧识图、配图或译文曾写入新数据 | 同 ID 迟到、同文换档、相册保留、旧草稿与正常回包 | [第一组修复记录](../ledger/AI_Companion_总账_v4.md)、[回归测试](../../test/reply_revision_ownership_test.dart) |
| 语义召回 | 共享缓存淘汰本轮仍要使用的向量，长查询失败并进入冷却 | 每轮持有自己的向量；缓存已满、混合命中、并发淘汰 | [v4：语义召回分段缓存修复](../ledger/AI_Companion_总账_v4.md)、[回归测试](../../test/local_semantic_index_test.dart) |
| 沉浸摘要 | 实际发送尾部消息，却按另一批消息推进摘要进度 | 最早未处理完整消息；游标只算实际覆盖；归档重新读原文 | [v4：上下文截取与 token 六项修复](../ledger/AI_Companion_总账_v4.md) |
| QQ 长材料 | 只保留开头导致尾事实丢失；图片追读和文字游标混用 | 首尾/相关片段、partial、Unicode、独立 image_cursor | [v4：+438 修复及真机待验](../ledger/AI_Companion_总账_v4.md) |
| 形态与记忆 | 取消/再生成和形式回落可能留下旧状态或错误归属 | 提交边界、形态快照、修订来源 | [记忆形态连续性](../MEMORY_FORM_CONTINUITY_2026-10-12.md)、[形态测试](../../test/playful_integrity_v04265_test.dart) |
| 游戏恢复 | 观察读取与有序写入混淆，执行状态不确定时重复操作 | 回执、幂等、停止与等待分开 | [恢复复查](../REVIEW_RECOVERY_v0.42.107.md)、[恢复测试](../../test/cedar_request_recovery_v042129_test.dart) |
| 游戏设计回退 | 曾讨论替换次数/时长方案，用户最终恢复原设计 | 先读最终决定，不按中间提议改 | [恢复原街机设计](../RESTORE_ARCADE_v0.42.106.md) |
| 作品 | 作品内互动需要详细上下文，普通聊天不宜注入全部文件；制作与交付不是同一步 | 工作区、事实依据、分享回执与独立状态 | [作品上下文](../CREATIVE_CONTEXT_UI_v0.42.98.md)、[作品事实](../CREATIVE_FACTS_v0.42.100.md)、[交付测试](../../test/creative_delivery_test.dart) |
| 长任务/token | 压缩中断未完成工具、输出被截断却当完整结果 | 完成边界、finish_reason、可重试状态 | [token/作品审查](../TOKEN_CREATIVE_AUDIT_2026-10-12.md)、[终止策略测试](../../test/final_reply_failure_policy_test.dart) |
| 文档版本 | 多入口仍标旧总账/旧“当前”；校验误匹配历史 schema 注释 | 当前入口唯一；历史标签；实际代码版本单独核对 | [整理前分析](../audits/maintenance_20261117/REPORT.md) |

储存锁、进程恢复、语音与 Live2D 的维护约束见各维护卡及测试；没有在此列出某个历史事件，不代表该领域已无风险。后续遇到新的真实问题，补充最小结论和证据链接，不复制整份总账。

- +449切字开场漏正文：SelectableText使用RenderEditable，不能只遍历RenderParagraph，否则只抓到时间/图标。+450用显式正文边界和字素级布局；回归见word_slice_bridge_test.dart。原型普通Text测试不能代替真实SelectableText.rich集成；真机反馈与结果见总账本批记录。

+456：第二组测试入口为 mcp_transport_boundary_test、qq_recovery_v042148_test、creative_delivery_test、calendar_reminder_delivery_test 和 reply_revision_ownership_test。
