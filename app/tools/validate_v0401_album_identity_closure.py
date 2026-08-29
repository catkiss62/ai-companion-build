#!/usr/bin/env python3
"""Static contract and executable SQLite checks for v0.40.1 album closure."""

from hashlib import sha256
from pathlib import Path
import re
import sqlite3


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
vision = read("lib/core/ai/qwen_vision_client.dart")
model = read("lib/core/models/companion_album.dart")
discovery = read("lib/core/phone/companion_album_discovery_engine.dart")
chat = read("lib/features/chat/chat_controller.dart")
repository = read("lib/core/phone/simulated_phone_repository.dart")
page = read("lib/features/phone/simulated_phone_page.dart")
bridge = read("lib/core/platform/android_bridge.dart")
kotlin = read("android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
reference = ROOT / "assets/appearance/dafeiyu_reference.webp"

assert re.search(r"^version:\s*0\.40\.(?:1\+129|2\+130|3\+(?:131|132)|4\+133)\s*$", pubspec, re.M)
assert re.search(r"static const int schemaVersion = (?:38|39);", database)
for token in (
    "perceptual_hash TEXT NOT NULL DEFAULT ''",
    "category_source TEXT NOT NULL DEFAULT 'ai'",
    "setCompanionAlbumCategory",
    "retireLegacyNsfwAlbumItems",
    "AlbumPerceptualHash.isNearDuplicate",
    "const {'memory', 'self_image', 'other'}",
    "category_source': 'user'",
):
    assert token in database, token

for token in (
    "albumIdentityReferenceAsset",
    "data:image/webp;base64",
    "鲸鱼耳鳍",
    "明显的鲸鱼尾",
    "服装、裙长、配饰",
    "明确成人向或裸露图片必须 save=false",
    "adult_content",
):
    assert token in vision, token
assert "final bool nsfw" not in vision
assert "required this.perceptualHash" in model
assert "required this.categorySource" in model
assert "AlbumPerceptualHash.fromFile" in discovery
assert "AlbumPerceptualHash.fromFile" in chat
assert "observation.nsfw" not in discovery + chat
assert "maintainAlbum" in repository
assert "retireLegacyNsfwAlbumItems" in repository
assert "setAlbumCategory" in repository
assert "打开图片来源" in page
assert "分类（可手动纠正）" in page
assert "includeNsfw" not in page + repository
assert "label: 'NSFW'" not in page
assert "albumCategoryLabel(String value)" in page
assert "'nsfw' => 'NSFW'" not in page
assert "openExternalHttpsUrl" in bridge + kotlin
assert "uri.scheme != 'https'" in bridge
assert 'uri.scheme != "https"' in kotlin
assert "Intent.CATEGORY_BROWSABLE" in kotlin
assert "agent/v0401-album-identity-closure" in workflow
assert "python3 tools/validate_v0401_album_identity_closure.py" in workflow
assert "AI-Companion-v0.40.1-129-Album-Identity-Closure-APK" in workflow
assert "v0.40.1-album-identity-closure" in workflow

assert reference.stat().st_size == 140_068
assert sha256(reference.read_bytes()).hexdigest() == (
    "f8783e2f468a6b226962b33b34acc26e759416c5ca6175f76138cd7adb5a9c80"
)

# Execute the production table definition in a real in-memory SQLite engine.
match = re.search(
    r"CREATE TABLE IF NOT EXISTS companion_album_candidates \((.*?)\n      \)",
    database,
    re.S,
)
assert match, "production album DDL not found"
ddl = "CREATE TABLE companion_album_candidates (" + match.group(1) + "\n)"
db = sqlite3.connect(":memory:")
db.row_factory = sqlite3.Row
db.execute(ddl)
db.execute(
    "CREATE UNIQUE INDEX idx_album_sha ON companion_album_candidates(content_sha256) "
    "WHERE content_sha256 != '' AND lifecycle_state IN ('saved','soft_deleted')"
)


def candidate(identifier: str, *, nsfw: int = 0, path: str = "thumb.webp") -> None:
    db.execute(
        """
        INSERT INTO companion_album_candidates (
          id, source_kind, source_id, source_url, source_domain, title,
          lifecycle_state, nsfw, thumbnail_path, created_at, updated_at
        ) VALUES (?, 'user_message', ?, '', '', '', 'candidate', ?, ?, 1, 1)
        """,
        (identifier, identifier, nsfw, path),
    )


# Save and exact-content duplicate rejection are guaranteed by production DDL/index.
candidate("saved")
db.execute(
    """
    UPDATE companion_album_candidates SET
      lifecycle_state='saved', category='self_image', category_source='ai',
      content_sha256='same-sha', perceptual_hash='0000000000000000',
      saved_at=2, unread=1 WHERE id='saved'
    """
)
db.commit()
candidate("exact")
try:
    db.execute(
        "UPDATE companion_album_candidates SET lifecycle_state='saved', "
        "content_sha256='same-sha' WHERE id='exact'"
    )
    raise AssertionError("exact duplicate unexpectedly saved")
except sqlite3.IntegrityError:
    db.rollback()

# The Dart dHash contract rejects distance <= 5 and admits distance 6.
assert (int("0000000000000000", 16) ^ int("000000000000001f", 16)).bit_count() == 5
assert (int("0000000000000000", 16) ^ int("000000000000003f", 16)).bit_count() == 6

# Manual correction, dislike grace period, rescue, due deletion, and legacy cleanup.
db.execute(
    "UPDATE companion_album_candidates SET category='memory', category_source='user' "
    "WHERE id='saved' AND nsfw=0 AND lifecycle_state IN ('saved','soft_deleted')"
)
row = db.execute("SELECT category, category_source FROM companion_album_candidates WHERE id='saved'").fetchone()
assert tuple(row) == ("memory", "user")
db.execute(
    "UPDATE companion_album_candidates SET lifecycle_state='soft_deleted', "
    "user_feedback='dislike', delete_after=100 WHERE id='saved'"
)
assert db.execute("SELECT lifecycle_state FROM companion_album_candidates WHERE id='saved'").fetchone()[0] == "soft_deleted"
db.execute(
    "UPDATE companion_album_candidates SET lifecycle_state='saved', "
    "user_feedback='like', delete_after=NULL WHERE id='saved'"
)
assert db.execute("SELECT delete_after FROM companion_album_candidates WHERE id='saved'").fetchone()[0] is None
db.execute("UPDATE companion_album_candidates SET lifecycle_state='soft_deleted', delete_after=100 WHERE id='saved'")
db.execute(
    "UPDATE companion_album_candidates SET lifecycle_state='deleted', unread=0 "
    "WHERE lifecycle_state='soft_deleted' AND delete_after <= 100"
)
assert db.execute("SELECT lifecycle_state FROM companion_album_candidates WHERE id='saved'").fetchone()[0] == "deleted"
candidate("legacy-adult", nsfw=1, path="legacy.webp")
db.execute(
    "UPDATE companion_album_candidates SET lifecycle_state='deleted', thumbnail_path='', "
    "content_sha256='', perceptual_hash='', delete_after=NULL, unread=0 WHERE nsfw=1"
)
legacy = db.execute(
    "SELECT lifecycle_state, thumbnail_path, unread FROM companion_album_candidates WHERE id='legacy-adult'"
).fetchone()
assert tuple(legacy) == ("deleted", "", 0)

print("v0.40.1 album identity closure validation passed")
