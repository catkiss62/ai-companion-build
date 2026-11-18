# 作品集与自主创作

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [creative_inspiration_engine.dart](../../lib/core/creative/creative_inspiration_engine.dart) | 后台创作想法入口 |
| [creative_worker.dart](../../lib/core/creative/creative_worker.dart) | 持久任务执行 |
| [creative_workspace.dart](../../lib/core/creative/creative_workspace.dart) | 文件修改与历史 |
| [creative_play.dart](../../lib/core/creative/creative_play.dart) | 作品内互动 |
| [creative_delivery.dart](../../lib/core/creative/creative_delivery.dart) | 交付与分享 |
| [creative_pages.dart](../../lib/features/creative/creative_pages.dart) | 作品 UI |

## 状态与边界

自主创作已有实现；想法→制作→预览→交付→分享各有状态。工作区文件改动需匹配内容哈希，控制目标带作品/请求身份；作品内详细上下文和普通聊天摘要用途不同。重复卡片不能仅靠展示层去重掩盖生成原因。

## 小改动如何落点

改多样性提示先看 recent_works 与想法分类；不要把用户请求伪装成自主来源。对话压缩只在已完成工具边界；存档须保留可恢复的作品文件与待办。

## 回归入口

- [creative_autonomy_test.dart](../../test/creative_autonomy_test.dart)
- [creative_workspace_test.dart](../../test/creative_workspace_test.dart)
- [creative_context_test.dart](../../test/creative_context_test.dart)
- [creative_snapshot_retention_test.dart](../../test/creative_snapshot_retention_test.dart)
- [creative_delivery_test.dart](../../test/creative_delivery_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：连续自然产出、作品内重开一局、编辑失败恢复、分享一次及导入后继续。

+456：作品完成正文使用同轮第三通道优先路由；已提交正文与通知仍独立结算。
