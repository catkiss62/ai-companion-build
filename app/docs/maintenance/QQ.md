# QQ 接入、身份、群聊与档案

核对基线：2026-11-17 / +444。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

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

## +444 保持偏好与图片观察

保存并启动不重写自动保持偏好；UI查询以请求序号拒绝旧快照，空返回不能解释成false。显式关闭、解绑、恢复存档仍取消勾选。原生保留20次变更（时间/前后值/固定原因码），诊断导出qqConnectionPreference；普通故障不改用户偏好。不要用运行状态替代勾选状态。

QQ专用结构化观察入口：[qq_vision_observation.dart](../../lib/core/ai/qq_vision_observation.dart)。同次识图返回画面、类型、关键文字、OCR和完整性，QQ输出token上限8192以容纳多字段，App仍4096；画面约100字是软目标，单字段/总6000字符是明确标记的存储保护，QQ接话材料提取画面和关键文字。旧结果仍可读，新缓存版本独立；较长观察沿现有图片游标追读。App默认解析/1800字符上限不变。

[qq_illustration_audit.dart](../../lib/integrations/qq_private/qq_illustration_audit.dart)保留20次资格/选择/生成/图片实际回执阶段，诊断导出不含正文、凭据或群号；与既有错误记录结合，判断未选择或被语音/复读/SVG优先替代。未修改生图概率/冷却/媒体优先级，未新增模型请求。

回归：[qq_observation_v2_test.dart](../../test/qq_observation_v2_test.dart)、[qq_connection_preference_test.dart](../../test/qq_connection_preference_test.dart)、[QqPrivateServiceTest.kt](../../android/app/src/test/kotlin/com/aicompanion/localfirst/qq/QqPrivateServiceTest.kt)。真实偶发取消根因仍需新诊断，不将薄弱处修补写成现场根因确认。

+456：同操作确定未发送并且来源、群与原图仍有效时，恢复后直接使用已保存的原图；部分投递及未知送达均不整批重发。
