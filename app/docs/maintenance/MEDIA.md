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

## +442 多图展示

[chat_attachment_gallery.dart](../../lib/features/chat/chat_attachment_gallery.dart)只负责App同一消息附件分页，默认第一页，横滑切图、圆点标记，识图状态对应当前图。单图沿用原缩略图尺寸；图片区固定高度避免横滑时聊天跳动。异步识图更新保留页码，附件身份变化重置；点开图仍走原放大入口。相册保存仍由原识图/用户要求流程决定，新增分页不增加收藏按钮，也不改变模型所见顺序或存档。悬浮原生列表保持原展示。

回归：[chat_attachment_gallery_test.dart](../../test/chat_attachment_gallery_test.dart)，覆盖分页/操作目标/状态更新/批次变化、单图、窄屏大字体下纵向聊天滚动；保留原缩略图回归。真机检查横滑、放大返回、上下滚动和混合长宽图片。

## +443 悬浮图片

原生[OverlayImageGallery.kt](../../android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayImageGallery.kt)显示同条消息当前图片和圆点，横滑切换，纵滑释放给聊天列表。单图沿用原样。Service仍通过原异步缩略图tag/window epoch防迟到回灌；页码按消息及附件路径组暂存于当前窗口，换组重置、关闭窗口释放，未新增识图或存储行为。回归[OverlayImageGalleryTest.kt](../../android/app/src/test/kotlin/com/aicompanion/localfirst/OverlayImageGalleryTest.kt)覆盖切换/边界、纵滑、取消、恢复页码和缺图。

## +447 收集表情

入口：CollectedStickerStorage、CollectedStickersPage、QqCollectCandidate。统一固定pack ID companion-collected-v1，caption复用现有语义字段，来源qq/web/album/user用于筛选；不新增自动小类。单张上传和手动相册添加由用户填写语义，QQ在原回复调用中返回收藏候选和语义，联网在原识图评估中返回collect_sticker/sticker_caption；不新增逐图付费调用。自动开关在“收集的表情”。

收藏先提交共享原图所有权，再插入SQLite索引，崩溃只会留下保守持有的额外引用，不能出现已提交索引指向不存在原图；收藏包扫描时会核对索引并清理这种额外映射，再执行原有迁移与校验；其他图库仍保持精确清单检查。单图6MB，PNG/JPEG/GIF/WebP，解码校验与尺寸限制，完整动画原件保留；内容hash去重，不因跨来源再复制图片。普通备份portable_state v3仅包含这一本收集库（manifest/index/实际原图），恢复只替换这一个子目录，继续沿用原有恢复日志/回滚；其他外部图库和模型保持本地。

回归：collected_stickers_v042203_test.dart、portable_snapshot_v04256_test.dart、原shared_stickers与sticker_workbench测试。必须验证收藏→重启→选用→删除来源→备份恢复，语义编辑与开关。自动收藏失败不宣称成功、不回退原图保存；QQ收藏不依赖多人复读门槛。

+447验证入口：`collected_stickers_v042203_test.dart`、`sticker_workbench_v04274_test.dart`、`portable_snapshot_v04256_test.dart`。联网收藏在写入前复核当前任务与相册原图归属；QQ复核会话与识图记录。已通过完整CI3533项测试，真机待验。v3存档须使用+447及后续兼容版恢复，旧APK不支持；历史v1/v2仍可导入。

## +448 相册表情入口
只查询saved、非NSFW、原图stored且有效标签含sticker的相册项；手动标签同等生效。过滤先于40条分页，使用saved_at/id游标，避免最近200条截断。入口直接读取CompanionAlbumStorage缩略图，cacheWidth168，不生成副本；按收集库原图hash标记已收藏。QQ直接收藏与联网先相册后独立选择的流程保留。验证：album_sticker_picker_v042204_test.dart（旧图可达、手动增删标签、无原图/删除排除、同时间/新增记录分页）。

收集的表情使用独立 ZIP 合并导入，内外入口均识别；主存档保留本机收藏与手改语义。
