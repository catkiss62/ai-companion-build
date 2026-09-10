#!/usr/bin/env python3
"""Static contracts for v0.41.56 worldbooks and shared media references."""

from hashlib import sha256
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def dart_block(source: str, name: str) -> str:
    match = re.search(rf"const {name} = r?'''(.*?)''';", source, re.S)
    assert match, name
    return match.group(1)


assert "version: 0.41.59+203" in read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
assert "static const int schemaVersion = 59;" in database

worldbooks = read("lib/core/reference/world_book_content_v04156_user.dart")
natural = dart_block(worldbooks, "worldBookNaturalDialogueV04157")
engine = dart_block(worldbooks, "worldBookInferenceEngineV04156")
humor = dart_block(worldbooks, "worldBookHumorV04156User")
assert len(natural) == 2242
assert sha256(natural.encode()).hexdigest() == (
    "13189a1fcb24f10eb071f455356ffd902d3eafa1abb8466a28580b768bf9a393"
)
assert len(engine) == 3390
assert sha256(engine.encode()).hexdigest() == (
    "4d833705025b8f07ab8723d11c398109b581979a8e5f7111bc9d277724588c19"
)
assert sha256(humor.encode()).hexdigest() == (
    "187507db7ab3a59e817656c0b695a63e661460a34a083f99b73a4d4c276ddb0b"
)
for token in (
    "这不是第二次触发概率",
    "不代表命中后必须造梗",
    "由她根据当前互动自然判断",
):
    assert token in humor

presets = read("lib/core/reference/world_book_presets.dart")
for token in (
    "content: worldBookNaturalDialogueV04157",
    "name: '推演思维引擎'",
    "content: worldBookInferenceEngineV04156",
    "priority: 950",
    "scope: 'immersive'",
    "name: '日常对话规则'",
    "priority: 900",
    "content: worldBookHumorV04156User",
    "probability: 30",
):
    assert token in presets, token

expression = read("lib/core/ai/dialogue_expression_plan.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
for retired in (
    "DialogueHumorDevice",
    "subjectivePlayfulness",
    "primaryDevice",
    "secondaryDevice",
    "主造法",
    "本轮造梗",
):
    assert retired not in expression + prompt, retired

# Scan only effective current prompt bodies. Historical migration literals are
# intentionally retained for byte-exact upgrade matching and are never loaded.
rules_04125 = read("lib/core/rules/rule_layer_content_v04125.dart")
rules_04127 = read("lib/core/rules/rule_layer_content_v04127.dart")
rules_04155 = read("lib/core/rules/rule_layer_content_v04155_user_defaults.dart")
effective_prompts = "\n".join(
    (
        dart_block(rules_04125, "ruleContentV04125_01_core"),
        dart_block(rules_04125, "ruleContentV04125_08_runtime_identity"),
        dart_block(rules_04127, "ruleContentV04127VisibleInnerVoice"),
        dart_block(rules_04155, "ruleContentV04155_04IntimacyCore"),
        dart_block(rules_04155, "ruleContentV04155_05IntimacyRendering"),
        dart_block(rules_04155, "ruleContentV04155_06IntimacyReference"),
        dart_block(rules_04155, "ruleContentV04155_ImmersiveGlobal"),
        dart_block(rules_04155, "ruleContentV04155_ImmersiveNsfwSource"),
        natural,
        engine,
        humor,
        prompt,
        read("lib/core/reference/reference_library.dart"),
    )
)
assert not re.search(
    r"未成年|成年人|成年男性|成年女性|年龄模糊|男孩子|\badult\b|\bminor\b",
    effective_prompts,
    re.I,
)

for token in (
    "CREATE TABLE IF NOT EXISTS media_blobs",
    "message_ref_count",
    "album_ref_count",
    "ALTER TABLE message_attachments ADD COLUMN blob_id",
    "ALTER TABLE companion_album_candidates ADD COLUMN blob_id",
    "migrateMediaBlobReferences",
    "deleteMediaCacheBlobs",
    "takeUnreferencedMediaBlobs",
):
    assert token in database, token

attachment_storage = read("lib/core/storage/message_attachment_storage.dart")
optimizer = read("lib/core/storage/media_storage_optimizer.dart")
cache_page = read("lib/features/settings/media_cache_page.dart")
snapshot = read("lib/core/sync/snapshot_service.dart")
chat = read("lib/features/chat/chat_controller.dart")
for token in (
    "MediaBlobStorage.toReferencePath(canonical.originalPath)",
    "registerMediaBlob(blob)",
    "removeUnreferencedMediaBlob",
):
    assert token in attachment_storage, token
for token in (
    "Future<MediaOptimizationReport> scan()",
    "final plan = await _buildPlan()",
    "originalContentSha256 != sha",
    "migrateMediaBlobReferences",
    "cleanupPending",
    "media_storage_optimizer_last_completed_at', ''",
    "takeUnreferencedMediaBlobs",
):
    assert token in optimizer, token
for token in (
    "扫描旧重复副本",
    "确认清理",
    "相册仍在引用的图片不会列入这里",
    "取消全选",
    "deleteMediaCacheBlobs",
):
    assert token in cache_page, token
assert "attachment.blobId.isNotEmpty" in chat
assert "adds an independent DB reference without copying bytes" in chat
for token in (
    "'protocol_version': 6",
    "protocolVersion: 6",
    "'media_files': mediaFiles",
    "_validateMediaPayload",
    "_validateMediaReferences",
    "缺少共享媒体来源标识",
    "prepareSnapshotInstall",
):
    assert token in snapshot, token

workflow = read("../.github/workflows/build-apk.yml")
assert "validate_v04156_worldbook_media_refs.py" in workflow
assert "validate_v04157_chat_media_expression.py" in workflow
assert "AI-Companion-v0.41.59-203-Tiandou-Pitch-Recovery-APK" in workflow

print("v0.41.56 worldbook and shared media reference contracts passed")
