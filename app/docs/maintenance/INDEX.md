# 模块维护目录

核对日期 2026-11-17，源码基线 v0.42.195+439/schema67。版本交付、待办和验证状态只维护在 [唯一总账 v4](../ledger/AI_Companion_总账_v4.md)。这些卡片是小改动的入口与边界，不是全代码审计证明，也不是插件接口。

> 新功能或行为变更必须同步维护资料、测试导航，并核对 App 帮助与 Agent 自查。未完成的同步项写入总账；详见 [更新流程](CHANGE_GUIDE.md)。

| 功能领域 | 维护卡 |
| --- | --- |
| 聊天、模型路由与上下文 | [CHAT](CHAT.md) |
| Agent 工具与联网 | [AGENT](AGENT.md) |
| 主动消息、欲望与感知 | [AUTONOMY](AUTONOMY.md) |
| 记忆、原文与语义召回 | [MEMORY](MEMORY.md) |
| 人格、双形态、情绪与感官 | [PERSONALITY](PERSONALITY.md) |
| 梦境、反思、愿望与关系 | [DREAM](DREAM.md) |
| QQ 接入、身份、群聊与档案 | [QQ](QQ.md) |
| Cedar 游戏厅与定时陪玩 | [CEDAR](CEDAR.md) |
| 作品集与自主创作 | [CREATIVE](CREATIVE.md) |
| 生图、相册与表情包 | [MEDIA](MEDIA.md) |
| 模拟手机、日历与日常内容 | [PHONE](PHONE.md) |
| 沉浸房间与模型对谈 | [ROOMS](ROOMS.md) |
| 语音与原生播放 | [TTS](TTS.md) |
| Live2D、桌宠与悬浮窗口 | [LIVE2D](LIVE2D.md) |
| 数据库、备份与后台恢复 | [STORAGE](STORAGE.md) |
| 界面、帮助、诊断与构建 | [UI_BUILD](UI_BUILD.md) |

- [验证导航](VERIFICATION.md)：怎么选择和运行检查。
- [回归经验](REGRESSIONS.md)：有证据的历史坑与防回归点。
- [原始分析及全量文件/文档清单](../audits/maintenance_20261117/REPORT.md)：未列在卡片里的文件从清单定位；清单是整理前快照，不滚动充当第二份总账。
- [历史文档地图](../DOCUMENTATION_MAP.md)：方案与版本专题按需查。

后续独立处理：旧版本校验器/文档轻量门禁改造；App 帮助及 Agent 自查的能力差异。当前文档整理不表示它们已修复。插件化、Agent 自改与 DSH 互通仍搁置。
