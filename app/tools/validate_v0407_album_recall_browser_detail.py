#!/usr/bin/env python3
"""Static contracts for v0.40.7 saved-album recall and browser detail."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
registry = read("lib/core/agent/agent_tool_registry.dart")
planner = read("lib/core/agent/agent_tool_planner.dart")
runner = read("lib/core/agent/agent_tool_runner.dart")
policy = read("lib/core/phone/companion_album_search_policy.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
phone = read("lib/features/phone/simulated_phone_page.dart")
chat = read("lib/features/chat/chat_page.dart")
immersive = read("lib/features/immersive/immersive_room_page.dart")
capsule = read("lib/widgets/active_trial_capsule.dart")
personality = read("lib/core/personality/personality_catalog.dart")
tests = read("test/companion_album_search_policy_test.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert re.search(r"^version:\s*0\.40\.7\+136\s*$", pubspec, re.M) or "version: 0.40.9+138" in (Path(__file__).resolve().parents[1] / "pubspec.yaml").read_text()
assert "static const int schemaVersion = 40;" in database

for token in (
    "id: 'album.search'",
    "risk: AgentToolRisk.readOnly",
    "userTurnAvailable: true",
    "autonomousAvailable: false",
):
    assert token in registry, token

for token in (
    "final explicitAlbum = RegExp(",
    "!explicitAlbum",
    "'album.search': 'album_search'",
    "'album_search': 'album.search'",
):
    assert token in planner, token

for token in (
    "item.lifecycle != CompanionAlbumItem.saved",
    "item.nsfw",
    "confidence: 'ambiguous_recent'",
):
    assert token in policy, token

for token in (
    "CompanionAlbumSearchPolicy.rank(",
    "db.companionAlbumItems(limit: 240)",
):
    assert token in runner, token

for forbidden in (
    "thumbnailPath:",
    "sourceUrl:",
    "contentSha256:",
    "visualFingerprint:",
    "perceptualHash:",
    "comment:",
):
    album_prompt = runner.split("Future<AgentToolResult> _searchAlbum", 1)[1].split(
        "Future<void> _noteAlbumSearch", 1
    )[0]
    assert forbidden not in album_prompt, forbidden

for token in (
    "'albumSearchQueryIncluded': false",
    "'albumSearchTitlesOrSummariesIncluded': false",
    "'albumSearchImageBytesOrPathsIncluded': false",
    "'albumSearchUrlsOrHashesIncluded': false",
    "'albumSearchCommentsIncluded': false",
):
    assert token in diagnostics, token

for token in (
    "class BrowserDetailPage extends StatelessWidget",
    "BrowserDetailPage(entry: entry)",
    "SelectableText(",
    "openExternalHttpsUrl(entry.url)",
    "const Text('打开原网页')",
):
    assert token in phone, token

assert "if (_specialTrial != null)" in chat
assert "if (room != null && room.specialStyleKey.isNotEmpty)" in immersive
assert "fontWeight: FontWeight.normal" in capsule
assert "'自然状态'," in personality
assert "自然状态（不加底色）" not in personality

for token in (
    "self-image intent ranks saved self image",
    "soft-deleted and nsfw entries are never searchable",
    "generic unmatched request returns bounded ambiguous recent choices",
):
    assert token in tests, token

for token in (
    "Build AI Companion v0.40.7+136 APK (Album Recall & Browser Detail)",
    "agent/v0407-album-recall-browser-detail",
    "AI-Companion-v0.40.7-136-Album-Recall-Browser-Detail-APK",
    "python3 tools/validate_v0407_album_recall_browser_detail.py",
):
    assert token in workflow, token

print("v0.40.7 album recall and browser detail validation passed")
