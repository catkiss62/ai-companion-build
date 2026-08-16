from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"missing {relative}"
    return path.read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
workflow = read("../.github/workflows/build-apk.yml")
database = read("lib/core/database/app_database.dart")
message = read("lib/core/models/chat_message.dart")
attachment = read("lib/core/models/message_attachment.dart")
storage = read("lib/core/storage/message_attachment_storage.dart")
controller = read("lib/features/chat/chat_controller.dart")
page = read("lib/features/chat/chat_page.dart")
history = read("lib/core/grounding/prompt_history_policy.dart")
grounding = read("lib/core/grounding/grounding_snapshot.dart")
snapshot = read("lib/core/sync/snapshot_service.dart")
skin = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetSkinManifest.kt"
)
pet_test = read(
    "android/app/src/test/kotlin/com/aicompanion/localfirst/pet/PetOverlayContractTest.kt"
)

assert "version: 0.34.0+65" in pubspec
for historical_validator in (
    "tools/validate_v0321_ai_to_self.py",
    "tools/validate_v0322_overlay_time_diagnostics.py",
    "tools/validate_v0331_desktop_pet_source_parity.py",
    "tools/validate_v0332_desktop_pet_overlay_d2.py",
    "tools/validate_v0333_overlay_menus_unread.py",
    "tools/validate_v0334_pet_motion_modes.py",
    "tools/validate_v0335_pet_chat_action_arbiter.py",
    "tools/validate_v0336_pet_chat_state_finalization.py",
    "tools/validate_v0337_pet_falling_visual_rollback.py",
    "tools/validate_v0338_pet_semantic_autonomy.py",
):
    assert "version: 0.34.0+65" in read(historical_validator), historical_validator
assert "image_picker: ^1.2.3" in pubspec
assert "Build AI Companion v0.34.0+65 APK (Image Messages Phase 1)" in workflow
assert "AI-Companion-v0.34.0-65-Image-Messages-Phase-1-APK" in workflow
assert "0\\.34\\.0\\+65" in read("tools/validate_v0320_somatic_contract.py")
assert "static const int schemaVersion = 22;" in read(
    "tools/validate_v0313_overlay_picker.py"
)
assert "static const int schemaVersion = 22;" in database
for token in (
    "CREATE TABLE IF NOT EXISTS message_attachments",
    "FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE",
    "ALTER TABLE messages ADD COLUMN expects_reply INTEGER NOT NULL DEFAULT 1",
    "Future<void> insertMessageWithAttachments",
    "Future<List<MessageAttachment>> deleteAttachmentMessage",
    "'message_attachments',",
    "_messagesWithAttachments",
):
    assert token in database, token

for token in (
    "final List<MessageAttachment> attachments;",
    "final bool expectsReply;",
    "当前文字模型没有读取图片内容",
    "'expects_reply': expectsReply ? 1 : 0",
):
    assert token in message, token

for token in (
    "maxImageBytes = 25 * 1024 * 1024",
    "thumbnailLongestEdge = 720",
    "getApplicationSupportDirectory",
    "ui.ImageDescriptor.encoded",
    "originals/",
    "thumbnails/",
    "requireSafeRelativePath",
    "installSnapshotAttachments",
):
    assert token in storage, token

for token in (
    "ImageSource.gallery",
    "ImageSource.camera",
    "retrieveLostData()",
    "发送这张图片？",
    "附言（可选）",
    "_MissingAttachment",
    "删除图片消息？",
):
    assert token in page, token

assert "expectsReply: false" in controller
assert "insertMessageWithAttachments" in controller
assert "message.promptContent" in history
assert "!lastUser.expectsReply" in grounding

for token in (
    "'protocol_version': 3",
    "'attachment_files': attachmentFiles",
    "'missing_attachment_files': missingAttachmentFiles",
    "_validateAttachmentPayload",
    "图片附件 SHA-256 校验失败",
    "_installValidatedAttachments",
):
    assert token in snapshot, token

for token in (
    'actionId == "SLEEPING"',
    "frames = listOf(enter.frames.last())",
    "sleepingLoopHoldsTheLastEnterFrameAtEveryRasterTier",
):
    assert token in skin or token in pet_test, token

assert "class MessageAttachment" in attachment
print("v0.34.0 image-message and sleep-frame contracts verified")
