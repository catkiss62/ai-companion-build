# 生图、相册与表情包

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [illustration_client.dart](../../lib/core/illustration/illustration_client.dart) | 生图请求 |
| [illustration_prompt.dart](../../lib/core/illustration/illustration_prompt.dart) | 提示词与预设 |
| [safe_public_image_downloader.dart](../../lib/core/media/safe_public_image_downloader.dart) | 外部图片下载 |
| [assistant_image_attachment_service.dart](../../lib/core/media/assistant_image_attachment_service.dart) | 助手图片附件 |
| [sticker_pack_storage.dart](../../lib/core/stickers/sticker_pack_storage.dart) | 表情包资源 |
| [message_attachment_storage.dart](../../lib/core/storage/message_attachment_storage.dart) | 聊天附件存储 |

## 状态与边界

生成成功、文件入库、消息挂图、相册收藏和分享回执是不同环节。图片文字描述不能冒充实际识图；QQ 与 App 来源/开关要分别核对。删除表情包或文件不应破坏备份引用一致性。

## 小改动如何落点

改预设时保持各画风独立；改下载/存储时检查来源限制、大小、引用计数与存档。改识图按钮只动布局也要覆盖窄屏和长文案。

## 回归入口

- [illustration_flow_test.dart](../../test/illustration_flow_test.dart)
- [image_vision_test.dart](../../test/image_vision_test.dart)
- [companion_album_image_binding_test.dart](../../test/companion_album_image_binding_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：生成失败重试、同图只入库一次、删除后导出、长图/多图与窄屏识图弹窗。
