#!/usr/bin/env python3
"""Static contracts for v0.40.5 album image/description binding."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
vision = read("lib/core/ai/qwen_vision_client.dart")
storage = read("lib/core/storage/companion_album_storage.dart")
discovery = read("lib/core/phone/companion_album_discovery_engine.dart")
chat = read("lib/features/chat/chat_controller.dart")
database = read("lib/core/database/app_database.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
provider_health = read("lib/core/diagnostics/provider_health.dart")
tests = read("test/image_vision_test.dart") + read(
    "test/companion_album_image_binding_test.dart"
)
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert re.search(r"^version:\s*0\.40\.(?:5\+134|6\+135|7\+136)\s*$", pubspec, re.M) or "version: 0.40.9+138" in (Path(__file__).resolve().parents[1] / "pubspec.yaml").read_text()
assert "static const int schemaVersion = 40;" in database

for token in (
    "required this.inputContentSha256",
    "final inputContentSha256 = sha256.convert(bytes).toString()",
    "这是本次唯一的相册候选图",
    "请求里只会有一张图片",
    "不存在可改为描述的第二张图或身份参考图",
    "相册也可以收藏与她无关",
):
    assert token in vision, token
assert (
    "纯色或渐变横幅" in vision
    or "像策展人一样判断图片是否具有收藏价值" in vision
)
assert "data:image/webp;base64" not in vision
assert "albumIdentityReferenceLoader" not in vision

for token in (
    "required String expectedContentSha256",
    "sourceSha != expectedContentSha256",
    "final storedSha = await contentSha256(target)",
    "storedSha != expectedContentSha256",
    "AlbumImageBindingException",
):
    assert token in storage, token

assert "observation.inputContentSha256" in discovery
assert "observation.inputContentSha256" in chat
if "caption:" in discovery:
    assert "caption: visionContext" in discovery
    assert "normalized.length <= 600" in discovery
    assert "image_description" in discovery
else:
    assert "image_description" not in discovery
assert "image_binding" in provider_health

for token in (
    "single_primary_image_sha256_v0405",
    "'primaryAssessmentImageCount': 1",
    "'identityReferenceIncludedInPrimaryRequest': false",
    "'observedBytesVerifiedBeforeCommit': true",
    "'storedBytesReReadAndVerified': true",
    "'contentHashesIncluded': false",
):
    assert token in database, token
assert (
    "'autonomousWebMetadataUsedAsVisionCaption': false" in database
    or "'autonomousWebMetadataTrust': 'bounded_untrusted_context_v04133'"
    in database
)
assert "'companionAlbumContentHashesIncluded': false" in diagnostics

for token in (
    "content, hasLength(2)",
    "hasLength(1)",
    "ordinary other image keeps observed and stored bytes identical",
    "candidate replacement after vision is rejected before save",
):
    assert token in tests, token

for token in (
    "Build AI Companion v0.40.5+134 APK (Album Image Binding)",
    "agent/v0405-album-image-binding",
    "AI-Companion-v0.40.5-134-Album-Image-Binding-APK",
    "python3 tools/validate_v0405_album_image_binding.py",
):
    assert token in workflow, token

print("v0.40.5 album image binding validation passed")
