#!/usr/bin/env python3
"""Static source contract for v0.41.40 narrow runtime fixes."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
runner = read("lib/core/agent/agent_tool_runner.dart")
moe_adapter = read("lib/core/integration/moe_input_adapter.dart")
moe_policy = read("lib/core/moe/application/moe_dynamics_policy.dart")
moe_models = read("lib/core/moe/domain/moe_models.dart")
album_model = read("lib/core/models/companion_album.dart")
album_storage = read("lib/core/storage/companion_album_storage.dart")
album_repo = read("lib/core/phone/simulated_phone_repository.dart")
album_ui = read("lib/features/phone/simulated_phone_page.dart")
snapshot = read("lib/core/sync/snapshot_service.dart")
android = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
moe_tests = read("test/moe_dynamics_policy_test.dart")
album_tests = read("test/companion_album_image_binding_test.dart")

require(pubspec, "version: 0.41.40+179", "build identity")
require(database, "static const int schemaVersion = 52;", "schema identity")
require(
    database,
    "if (version < 52) {\n        await _stabilizeV52ExpressionAlbumBrowser(txn);",
    "schema-51 backup import stabilization",
)

for needle in (
    "recordUserTurnBrowserVisits",
    "v.origin = 'user_turn'",
    "'origin': 'user_turn'",
    "candidate.isVerifiedRead",
):
    require(database, needle, "explicit browser history")
require(runner, "DeepSeekPublicWebAppraiser", "user web semantic appraisal")
require(runner, "recordUserTurnBrowserVisits", "user web browser persistence")
require(database, "'browserHistory':", "browser origin diagnostics")

require(moe_models, "const int moePolicyVersion = 2;", "moe v2 policy")
for needle in (
    "_relaxTowardDriveTargets",
    "_diminishedPulse",
    "_recipeAxesCompatible",
    "if (cooling && !status.active) continue;",
):
    require(moe_policy, needle, "dynamic expression balance")
for forbidden in (
    "add(MoeAxis.unfilteredDirectness, 2);\n        tags.add('honest_disclosure');",
    "(attachment - .5) * 6",
):
    if forbidden in moe_adapter:
        raise AssertionError(f"legacy per-turn ratchet remains: {forbidden}")
require(moe_tests, "drive influence follows elapsed time", "time-based test")
require(moe_tests, "repeated pulses diminish", "saturation test")

for needle in (
    "original_path",
    "original_content_sha256",
    "user_tags_json",
    "attachCompanionAlbumOriginal",
):
    require(database, needle, "album schema/migration")
for needle in ("anime", "landscape", "sticker"):
    require(album_model, f"'{needle}'", f"album tag {needle}")
for needle in ("saveOriginal", "'originals'", "25 * 1024 * 1024"):
    require(album_storage, needle, "album original storage")
require(album_repo, "_recoverUserMessageAlbumOriginals", "legacy original recovery")
require(database, "'originalStorage':", "album original diagnostics")
require(snapshot, "'album/originals/'", "snapshot original whitelist")
require(album_ui, "InteractiveViewer", "album zoom/pan")
require(album_ui, "保存原图到手机相册", "album export action")
require(album_ui, "FilterChip", "album multi-tag UI")
require(android, "MediaStore.Images.Media", "Android gallery export")
require(album_tests, "album path guard accepts only originals", "path guard test")

if "萌属性" in "\n".join(
    read(path)
    for path in (
        "lib/features/chat/chat_page.dart",
        "lib/features/chat/chat_quick_settings_pages.dart",
        "lib/features/inner/inner_page.dart",
        "lib/features/self/personality_appearance_page.dart",
    )
):
    raise AssertionError("legacy visible Moe label remains")

print("v0.41.40 expression, album-original and browser source contract validated")
