#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(path: str, *tokens: str) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    for token in tokens:
        assert token in text, f"{path}: missing {token!r}"


require("pubspec.yaml", "version: 0.41.51+190")
require(
    "lib/core/stickers/sticker_pack.dart",
    "file_5614628",
    "1739434144_1",
    "1739434514_1",
    "嘴上骂对方笨蛋、假装不关心",
    "早点休息",
)
require(
    "lib/core/stickers/sticker_expression_service.dart",
    "if (bestScore <= 0) return null;",
    "semanticMatchScore",
)
require("test/sticker_expression_test.dart", "file_5447071", "file_5614628")
require(
    "lib/features/chat/chat_page.dart",
    "其他相册应用",
    "完整语义：${item.record.caption}",
    "_ChatImageSource.externalGallery",
)
require(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt",
    'Intent.ACTION_PICK',
    'MediaStore.Images.Media.EXTERNAL_CONTENT_URI',
    '"external_gallery_image_too_large"',
    '"external_gallery_image_empty"',
)
require(
    "docs/STICKER_SEMANTICS_GALLERY_INTEROP_v0.41.51.md",
    "成人玩笑",
    "强攻击",
    "不得让主动感知 Qwen 承担 NSFW 判定",
    "必须从提供方当前官方模型目录核对准确 model id",
)

print("v0.41.51 sticker semantics and gallery interop contract: PASS")
