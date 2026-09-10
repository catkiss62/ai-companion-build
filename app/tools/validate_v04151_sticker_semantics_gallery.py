#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(path: str, *tokens: str) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    for token in tokens:
        assert token in text, f"{path}: missing {token!r}"


def forbid(path: str, *tokens: str) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    for token in tokens:
        assert token not in text, f"{path}: stale {token!r}"


pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
assert any(
    version in pubspec
    for version in (
        "version: 0.41.51+190",
        "version: 0.41.52+191",
        "version: 0.41.53+192",
        "version: 0.41.54+193",
        "version: 0.41.55+197",
        "version: 0.41.55+198",
        "version: 0.41.55+199",
        "version: 0.41.56+200",
        "version: 0.41.57+201",
    )
)
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
    "item.record.caption",
    "onLongPressStart",
)
forbid(
    "lib/features/chat/chat_page.dart",
    "其他相册应用",
    "完整语义：${item.record.caption}",
    "_ChatImageSource.externalGallery",
)
forbid("lib/core/platform/android_bridge.dart", "pickExternalGalleryImage")
require(
    "docs/STICKER_SEMANTICS_GALLERY_INTEROP_v0.41.51.md",
    "成人玩笑",
    "强攻击",
    "不得让主动感知 Qwen 承担 NSFW 判定",
    "必须从提供方当前官方模型目录核对准确 model id",
)

print("v0.41.51 sticker semantics with v0.41.52 gallery cleanup: PASS")
