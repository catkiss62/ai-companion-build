from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"missing {relative}"
    return path.read_text(encoding="utf-8")


db = read("lib/core/database/app_database.dart")
album = read("lib/core/models/companion_album.dart")
storage = read("lib/core/storage/companion_album_storage.dart")
discovery = read("lib/core/phone/companion_album_discovery_engine.dart")
repository = read("lib/core/phone/simulated_phone_repository.dart")
page = read("lib/features/phone/simulated_phone_page.dart")
vision = read("lib/core/ai/qwen_vision_client.dart")
chat = read("lib/features/chat/chat_controller.dart")
provider = read("lib/core/autonomy/layered_public_web_provider.dart")
recovery = read("lib/core/maintenance/recovery_orchestrator.dart")
pubspec = read("pubspec.yaml")
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.38.10+109" in pubspec
assert "static const int schemaVersion = 33;" in db
assert "_createV33Tables" in db
assert "CREATE TABLE IF NOT EXISTS companion_album_candidates" in db
assert "CREATE TABLE IF NOT EXISTS companion_browser_visits" in db
for column in ("image_url", "image_domain", "image_description"):
    assert column in db
for lifecycle in (
    "candidate",
    "recognized",
    "saved",
    "rejected",
    "expired",
    "soft_deleted",
    "deleted",
):
    assert lifecycle in album or lifecycle in db
assert "a.status = 'succeeded'" in db
assert "a.outcome_kind = 'candidate_stored'" in db
assert "a.reason_source NOT LIKE 'diagnostic_%'" in db
assert "maxPerDay.clamp(1, 3)" in db
assert "phoneEnabled && !diagnosticRun && browserUsed < 3" in db
assert "Duration(hours: 1)" in db
assert "commentsIncluded': false" in db
assert "imageBodiesIncluded': false" in db

assert "rootFolderName = 'companion_album'" in storage
assert "6 * 1024 * 1024" in storage
assert "pruneUnreferencedFiles" in storage
assert "fisharchive.pages.dev/stickers/manifest.json" in discovery
assert "4 * 1024 * 1024" in discovery
assert "MessageAttachmentStorage" in discovery
assert "runOneIfDue" in recovery

assert "assessForAlbum" in vision
assert "albumPreferenceHint" in vision
assert '"save":true' in vision
assert "用户审美反馈只作为弱偏好" in vision
assert "assessForAlbum: albumEnabled" in chat
assert "CompanionAlbumStorage().saveThumbnail" in chat
assert "visionSummary: observation.albumSave ? observation.summary : ''" in chat

assert "'include_images': true" in provider
assert "'include_image_descriptions': true" in provider
assert "item['images']" in provider
assert "albumItems" in repository
assert "browserVisits" in repository
assert "albumUnread" in repository
assert "notesUnread" in repository

assert "'assets/appearance/chat_avatar.webp'" in page
assert "AnimatedScale" in page
assert "class UnlockSuccessOverlay" in page
assert "phoneTime(entry.createdAt)" in page
assert (
    "final chartHeight = history.length <= 1" in page
    or "MoodChartLayout.build" in page
)
assert "badge:" in page and page.count("badge:") == 2
assert "class AlbumDetailPage" in page
for label in ("👍 喜欢", "👎 不喜欢", "➖ 不判断", "修改留言", "删除"):
    assert label in page
assert "List<CompanionBrowserVisit>" in page
assert "这里只显示她真正完成的自主公开网页搜索" in page
assert "actions: actions" in page
assert "title: '查手机'" not in page

assert "python3 tools/validate_v03810_real_album_browser_ui.py" in workflow
assert "AI-Companion-v0.38.10-109-Real-Album-Browser-UI-APK" in workflow

print("v0.38.10 real album/browser and phone UI validation passed")
