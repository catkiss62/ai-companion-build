# QQ 接入、身份、群聊与档案

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [qq_private_bridge](../../packages/qq_private_bridge) | 独立桥接子项目 |
| [qq_store.dart](../../lib/integrations/qq_private/qq_store.dart) | 宿主持久状态 |
| [qq_archive_reader.dart](../../lib/integrations/qq_private/qq_archive_reader.dart) | 档案读取 |
| [qq_message_material.dart](../../lib/core/qq/qq_message_material.dart) | 引用/转发等消息材料 |
| [qq_private_main.dart](../../lib/qq_private_main.dart) | 后台入口 |
| [QqPrivateService.kt](../../android/app/src/main/kotlin/com/aicompanion/localfirst/qq/QqPrivateService.kt) | Android 服务 |

## 状态与边界

本人绑定、群友身份、引用内层说话者和本群记录不可混用。长引用 partial 标记必须如实；图片描述追读游标与正文游标独立。主动生图、语音、工具权限与 App 开关并不必然相同。

## 小改动如何落点

改群聊表达从 QQ 提示与上下文入手，不默认改 App 人设。调整材料上限需同时查入库、展示、追读和预算；重复媒体需核对消息/附件回执。

## 回归入口

- [qq_archive_agent_v042139_test.dart](../../test/qq_archive_agent_v042139_test.dart)
- [qq_context_repair_v042144_test.dart](../../test/qq_context_repair_v042144_test.dart)
- [qq_media_quality_v042173_test.dart](../../test/qq_media_quality_v042173_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：本群与跨群、@与非@接话、引用长消息/多图、重连及主人绑定。
