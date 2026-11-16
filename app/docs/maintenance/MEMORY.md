# 记忆、原文与语义召回

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [memory_brain.dart](../../lib/core/memory/memory_brain.dart) | 召回装配 |
| [conversation_history_reader.dart](../../lib/core/history/conversation_history_reader.dart) | 会话原文读取 |
| [memory_retrieval_policy.dart](../../lib/core/memory/memory_retrieval_policy.dart) | 召回选择策略 |
| [memory_revision.dart](../../lib/core/memory/memory_revision.dart) | 事实修订 |
| [memory_page.dart](../../lib/features/memory/memory_page.dart) | 记忆展示 |
| [local_semantic_index.dart](../../lib/core/memory/local_semantic_index.dart) | 本地语义分段、查询向量与缓存 |

## 状态与边界

摘要和原文不是同一证据。召回片段应保留来源、角色、日期和修订关系；未召回不能说不存在。+439 修复正在执行查询的向量被共享缓存淘汰；QQ 时间预算与 App 分段策略不同。中段未入库的旧材料不能靠新版本恢复。

## 小改动如何落点

修改裁剪必须覆盖首尾、Unicode、零预算及长消息。语义缓存改动需测试命中/未命中混合与并发淘汰；不要删除原关键词/日期路径。记忆星谷展示类别与事实归属要一并核对。

## 回归入口

- [local_semantic_index_test.dart](../../test/local_semantic_index_test.dart)

- [memory_revision_continuity_test.dart](../../test/memory_revision_continuity_test.dart)
- [memory_browse_repository_v04257_test.dart](../../test/memory_browse_repository_v04257_test.dart)
- [conversation_history_v042126_test.dart](../../test/conversation_history_v042126_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：索引 ready 后连续长查询、事实纠正、按日期追读与 App/QQ 隔离。
